#!/usr/bin/env python3
"""Deterministic isolation and exact-serving contracts for haw-info."""
from __future__ import annotations

import json
import shutil
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

import public_site as site

ROOT = Path(__file__).resolve().parents[1]


class FakeFetcher:
    def __init__(self, responses):
        self.responses = responses
        self.calls = []

    def __call__(self, url):
        self.calls.append(url)
        return self.responses[url]


class PublicSiteTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.repo = Path(self.temporary.name)
        shutil.copytree(ROOT / "public-site", self.repo / "public-site")
        self.source = self.repo / "public-site"

    def edit(self, name, before, after):
        path = self.source / name
        text = path.read_text()
        self.assertIn(before, text)
        path.write_text(text.replace(before, after, 1))

    def seal(self):
        with patch.object(site, "source_identity", return_value=("a" * 40, "b" * 64)), \
                patch.object(site, "git", return_value=b"dist/public-site-releases/\n"):
            return site.seal(self.repo)

    def responses(self, release, origin=site.ORIGIN):
        receipt, bodies, _ = site.verify_seal(release)
        responses = {}
        for route, name in site.ROUTES.items():
            url = origin + route
            responses[url] = site.HttpResult(200, {"content-type": "text/html; charset=utf-8"}, bodies[name], url)
        redirects = {"/index.html": "/", **site.ALIASES}
        for route in site.ROUTES:
            if route != "/":
                redirects[route + ".html"] = route
                redirects[route + "/"] = route
        for path, target in redirects.items():
            url = origin + path
            responses[url] = site.HttpResult(308, {"location": target}, b"", url)
        for path in ["/__haw_public_missing_" + receipt["seal_sha256"][:12], "/main.dart.js",
                     "/flutter_service_worker.js", "/env.json", "/version.json"]:
            url = origin + path
            responses[url] = site.HttpResult(404, {"content-type": "text/html"}, bodies["404.html"], url)
        return responses

    def test_actual_source_has_only_static_pages_and_valid_links(self):
        bodies, documents = site.validate_payload(ROOT / "public-site")
        self.assertEqual(set(bodies), site.FILES)
        self.assertEqual(len(documents), 6)
        self.assertIn("google-calendar", documents["privacy.html"].ids)

    def test_payload_rejects_every_app_or_server_artifact(self):
        for name in ["main.dart.js", "env.json", "_worker.js", "flutter_service_worker.js", "secret.env", "receipt.json"]:
            with self.subTest(name=name):
                path = self.source / name
                path.write_text("forbidden")
                with self.assertRaisesRegex(site.PublicSiteError, "exactly six"):
                    site.validate_payload(self.source)
                path.unlink()
        for name in ["functions", "assets"]:
            path = self.source / name
            path.mkdir()
            with self.assertRaisesRegex(site.PublicSiteError, "exactly six"):
                site.validate_payload(self.source)
            path.rmdir()

    def test_missing_page_and_symlink_are_rejected(self):
        original = self.source / "terms.html"
        body = original.read_bytes()
        original.unlink()
        with self.assertRaisesRegex(site.PublicSiteError, "exactly six"):
            site.validate_payload(self.source)
        target = self.repo / "elsewhere.html"
        target.write_bytes(body)
        original.symlink_to(target)
        with self.assertRaisesRegex(site.PublicSiteError, "symlinks"):
            site.validate_payload(self.source)

    def test_html_cannot_execute_or_load_runtime_assets(self):
        original = (self.source / "index.html").read_text()
        injections = ["<script>alert(1)</script>", '<script src="/main.dart.js"></script>',
                      '<iframe src="https://kemet.pages.dev"></iframe>', '<form action="/login"></form>',
                      '<a href="javascript:alert(1)">go</a>', '<p onclick="alert(1)">go</p>',
                      '<meta http-equiv="refresh" content="0;url=/privacy">',
                      '<link rel="manifest" href="/manifest.json">',
                      '<style>p{background:u/**/rl(https://example.com/x)}</style>',
                      '<style>@import "https://example.com/x";</style>']
        for injection in injections:
            with self.subTest(injection=injection):
                (self.source / "index.html").write_text(original.replace("</body>", injection + "</body>"))
                with self.assertRaises(site.PublicSiteError):
                    site.validate_payload(self.source)
        (self.source / "index.html").write_text(original)

    def test_credentials_cannot_be_embedded_even_as_text(self):
        for text in ["client_secret=private-value", "SUPABASE_SERVICE_ROLE_KEY=private-value",
                     "GOCSPX-private-value", "-----BEGIN PRIVATE KEY-----"]:
            with self.subTest(text=text):
                original = (self.source / "index.html").read_text()
                self.edit("index.html", "</body>", "<p>" + text + "</p></body>")
                with self.assertRaisesRegex(site.PublicSiteError, "Credential-like"):
                    site.validate_payload(self.source)
                (self.source / "index.html").write_text(original)

    def test_internal_links_and_fragments_are_checked(self):
        original = (self.source / "index.html").read_text()
        for href in ["/missing", "/privacy.html", "/privacy#missing", "/privacy?secret=1",
                     "https://haw-info.pages.dev/missing"]:
            with self.subTest(href=href):
                self.edit("index.html", 'href="/privacy"', 'href="' + href + '"')
                with self.assertRaises(site.PublicSiteError):
                    site.validate_payload(self.source)
                (self.source / "index.html").write_text(original)
        self.edit("index.html", 'href="/privacy"', 'href="/privacy#google-calendar"')
        site.validate_payload(self.source)

    def test_controls_reject_runtime_rewrites_external_redirects_and_headers(self):
        controls = [("_redirects", "/* /index.html 200\n"),
                    ("_redirects", "/privacy https://kemet.pages.dev/privacy 308\n"),
                    ("_redirects", "/about /about 308\n"),
                    ("_headers", "/\n  Set-Cookie: session=bad\n")]
        for name, addition in controls:
            with self.subTest(addition=addition):
                path = self.source / name
                original = path.read_text()
                path.write_text(original + addition)
                with self.assertRaises(site.PublicSiteError):
                    site.validate_payload(self.source)
                path.write_text(original)

    def test_seal_is_deterministic_and_receipt_is_outside_isolated_payload(self):
        first = self.seal()
        second = self.seal()
        self.assertEqual(first, second)
        self.assertEqual(first.parent, self.repo / "dist/public-site-releases")
        receipt, bodies, _ = site.verify_seal(first)
        self.assertEqual(receipt["source_commit"], "a" * 40)
        self.assertEqual(set(path.name for path in (first / "payload").iterdir()), site.FILES)
        self.assertEqual(receipt["files"], {name: site.sha(body) for name, body in bodies.items()})
        self.assertEqual(set(path.name for path in first.iterdir()), {"payload", "receipt.json"})
        self.edit("support.html", "<h1>", '<h1 id="updated">')
        changed = self.seal()
        self.assertNotEqual(first, changed)
        self.assertEqual((first / "payload/support.html").read_bytes(), bodies["support.html"])

    def test_payload_tamper_and_receipt_tamper_fail_closed(self):
        release = self.seal()
        path = release / "payload/privacy.html"
        original = path.read_bytes()
        path.write_bytes(original + b"\n")
        with self.assertRaisesRegex(site.PublicSiteError, "hash mismatch"):
            site.verify_seal(release)
        path.write_bytes(original)
        receipt_path = release / "receipt.json"
        receipt = json.loads(receipt_path.read_bytes())
        receipt["source_commit"] = "c" * 40
        receipt_path.write_bytes(site.canonical_json(receipt))
        with self.assertRaisesRegex(site.PublicSiteError, "Seal identity mismatch"):
            site.verify_seal(release)

    def test_uncommitted_source_or_tool_cannot_claim_head(self):
        bodies, _ = site.validate_payload(self.source)
        (self.repo / "scripts").mkdir()
        (self.repo / site.SCRIPT).write_bytes(b"tool")

        def committed(repo, *args):
            if args == ("rev-parse", "HEAD"):
                return b"a" * 40
            if args == ("ls-tree", "--name-only", "HEAD:public-site"):
                return "\n".join(sorted(site.FILES)).encode()
            path = args[1].removeprefix("HEAD:")
            return b"tool" if path == site.SCRIPT else bodies[path.removeprefix("public-site/")]

        with patch.object(site, "git", side_effect=committed):
            self.assertEqual(site.source_identity(self.repo, bodies), ("a" * 40, site.sha(b"tool")))
            wrong = dict(bodies, **{"privacy.html": bodies["privacy.html"] + b"\n"})
            with self.assertRaisesRegex(site.PublicSiteError, "Commit public-site/privacy.html"):
                site.source_identity(self.repo, wrong)
            (self.repo / site.SCRIPT).write_bytes(b"changed tool")
            with self.assertRaisesRegex(site.PublicSiteError, "Commit the sealing tool"):
                site.source_identity(self.repo, bodies)

    def test_exact_live_matrix_covers_pages_redirects_links_and_isolation(self):
        release = self.seal()
        for origin in [site.ORIGIN, "https://1234abcd.haw-info.pages.dev"]:
            fetch = FakeFetcher(self.responses(release, origin))
            result = site.verify_live(release, origin, fetch=fetch)
            self.assertEqual(set(fetch.calls), set(fetch.responses))
            self.assertEqual(len(fetch.calls), len(set(fetch.calls)))
            self.assertEqual(result["verified_paths"]["/main.dart.js"], 404)
            self.assertEqual(result["verified_paths"]["/privacy.html"], 308)
            self.assertEqual(result["verified_paths"]["/privacy"], 200)

    def test_live_wrong_body_or_content_type_or_status_fails_for_each_page(self):
        release = self.seal()
        for route in site.ROUTES:
            for status, headers, body in [(200, {"content-type": "text/html"}, b"old app shell"),
                                           (200, {"content-type": "application/json"}, None),
                                           (404, {"content-type": "text/html"}, None)]:
                with self.subTest(route=route, status=status, headers=headers, body=body):
                    responses = self.responses(release)
                    url = site.ORIGIN + route
                    responses[url] = site.HttpResult(status, headers, body if body is not None else responses[url].body, url)
                    with self.assertRaises(site.PublicSiteError):
                        site.verify_live(release, fetch=FakeFetcher(responses))

    def test_live_self_loop_origin_escape_and_wrong_redirect_status_fail(self):
        release = self.seal()
        for path in ["/index.html", "/privacy.html", "/terms/", "/account-deletion", "/about"]:
            for status, location in [(308, path), (308, "https://kemet.pages.dev/"),
                                     (308, "/support"), (301, "/privacy"), (308, "")]:
                with self.subTest(path=path, status=status, location=location):
                    responses = self.responses(release)
                    url = site.ORIGIN + path
                    responses[url] = site.HttpResult(status, {"location": location}, b"", url)
                    with self.assertRaises(site.PublicSiteError):
                        site.verify_live(release, fetch=FakeFetcher(responses))

    def test_live_soft404_wrong404_body_and_exposed_app_assets_fail(self):
        release = self.seal()
        baseline = self.responses(release)
        for url, response in baseline.items():
            if response.status != 404:
                continue
            for replacement in [site.HttpResult(200, response.headers, response.body, url),
                                site.HttpResult(404, response.headers, b"generic 404", url)]:
                with self.subTest(url=url, status=replacement.status):
                    responses = dict(baseline)
                    responses[url] = replacement
                    with self.assertRaises(site.PublicSiteError):
                        site.verify_live(release, fetch=FakeFetcher(responses))

    def test_transport_followed_redirect_and_wrong_host_are_rejected(self):
        release = self.seal()
        responses = self.responses(release)
        url = site.ORIGIN + "/"
        response = responses[url]
        responses[url] = site.HttpResult(response.status, response.headers, response.body, site.ORIGIN + "/other")
        with self.assertRaisesRegex(site.PublicSiteError, "followed a redirect"):
            site.verify_live(release, fetch=FakeFetcher(responses))
        for origin in ["https://kemet.pages.dev", "https://main.haw-info.pages.dev", "http://haw-info.pages.dev",
                       "https://1234abcd.haw-info.pages.dev.evil.example"]:
            with self.assertRaisesRegex(site.PublicSiteError, "restricted to haw-info"):
                site.verify_live(release, origin, fetch=FakeFetcher({}))
        self.assertIsNone(site.NoRedirect().redirect_request(None, None, 308, "", {}, "https://example.com"))


if __name__ == "__main__":
    unittest.main()
