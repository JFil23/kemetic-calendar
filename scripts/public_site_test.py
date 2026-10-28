#!/usr/bin/env python3
"""Deterministic isolation and exact-serving contracts for haw-info."""
from __future__ import annotations

import json
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

import public_site as site
import import_public_site_reference as reference

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
        for name, asset in site.ASSETS.items():
            url = origin + "/" + name
            responses[url] = site.HttpResult(200, {"content-type": asset["content_type"]}, bodies[name], url)
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

    def test_entire_website_roundtrips_to_the_exact_user_reference(self):
        bodies, _ = site.validate_payload(ROOT / "public-site")
        restored = reference.reconstruct(bodies["index.html"],
                                         {name: bodies[name] for name in site.ASSETS}, site.REFERENCE)
        # This binds every CSS declaration, word, script, hotspot, sheet,
        # screenshot, font and film byte to the supplied document, including
        # behavior and visuals that an import graph cannot express.
        self.assertEqual(site.sha(restored), reference.REFERENCE_SHA256)
        self.assertEqual(site.REFERENCE["reference_sha256"], reference.REFERENCE_SHA256)

    def test_customer_contact_controller_requires_acknowledgement_and_retains_failures(self):
        node = shutil.which("node")
        self.assertIsNotNone(node, "Node is required to verify the shipped contact controller.")
        result = subprocess.run([node, "--test", str(ROOT / "scripts/public_site_contact_test.mjs")],
                                text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_customer_copy_and_contact_keep_the_existing_app_destination(self):
        text = (self.source / "index.html").read_text()
        self.assertIn('action="/api/contact" method="post"', text)
        self.assertIn('id="support-submit" type="submit">Submit ', text)
        self.assertIn('href="mailto:info@thisishaw.com"', text)
        self.assertEqual(text.count('href="https://kemet.pages.dev/"'), 4)
        self.assertIn('Do I need to download an app?', text)
        self.assertIn('Do I need an account?', text)
        for removed in ('Website concept', 'work-in-progress form', 'Continue to email',
                        'support-copy', 'fictional demo activity', 'The app’s actual',
                        'Enlarge the real', 'ḥꜣw Manim film'):
            self.assertNotIn(removed, text)
        edits = site.REFERENCE['customer_facing_revision']
        self.assertTrue(edits)
        with self.assertRaisesRegex(ValueError, 'recorded boundary'):
            reference.apply_revision('unrelated document', edits)

    def test_original_demo_graph_and_all_resources_are_complete(self):
        import re
        text = (self.source / "index.html").read_text()
        data = json.loads(re.search(r'<script type="application/json" id="native-demo-data">(.*?)</script>',
                                    text, re.S)[1])
        self.assertEqual(len(data["states"]), 90)
        self.assertEqual(len(data["sheets"]), 69)
        replacement = site.REFERENCE.get("film_replacement")
        baseline = set(site.ASSETS) - ({replacement["asset"]} if replacement else set())
        self.assertEqual(len(baseline), 109)
        for target in data["starts"].values():
            self.assertIn(target, data["states"])
        for name, state in data["states"].items():
            for field in ("asset", "bodyAsset", "topAsset", "bottomAsset"):
                if field in state:
                    resource = data["assets"].get(state[field], state[field])
                    self.assertIn(resource.removeprefix("/"), site.ASSETS, (name, field))
            for hit in state.get("hotspots", []):
                if "target" in hit:
                    self.assertIn(hit["target"], data["states"], (name, hit))
        for name, sheet in data["sheets"].items():
            self.assertIn(name, data["states"])
            self.assertIn(sheet["fallback"], data["states"])

    def test_updated_film_is_the_exact_supplied_mp4_with_accurate_labels(self):
        film = site.REFERENCE["film_replacement"]
        expected = "cfd092f349fd938b06501ab3dcf78a6fbb4391c6601df69d4e1b39c763b080d6"
        self.assertEqual(film["asset"], f"assets/{expected}.mp4")
        self.assertEqual(film["source_filename"], "Ep01Calendar_G_TUESDAY_RESTORED_1080p60_20261028.mp4")
        self.assertEqual(site.sha((self.source / film["asset"]).read_bytes()), expected)
        self.assertEqual(site.ASSETS[film["asset"]]["bytes"], 9_215_011)
        self.assertEqual(film["duration_seconds"], 136.142563)
        self.assertEqual(len(site.ASSETS), 110)
        page = (self.source / "index.html").read_text()
        self.assertIn(f'filmUrl="/{film["asset"]}";video.src=filmUrl;', page)
        self.assertIn('aria-label="Play the film, 2 minutes 16 seconds"', page)
        self.assertIn('WATCH THE FILM &nbsp; 02:16', page)
        self.assertNotIn(f'filmUrl="/{film["reference_asset"]}"', page)

    def test_reference_assets_cannot_be_missing_replaced_or_extended(self):
        for name in site.ASSETS:
            path = self.source / name
            original = path.read_bytes()
            with self.subTest(name=name):
                path.write_bytes(original + b"tamper")
                with self.assertRaisesRegex(site.PublicSiteError, "asset hash or size mismatch"):
                    site.validate_payload(self.source)
                path.write_bytes(original)
        path.unlink()
        with self.assertRaisesRegex(site.PublicSiteError, "approved asset allowlist"):
            site.validate_payload(self.source)
        path.write_bytes(original)
        extra = self.source / "assets/extra.js"
        extra.write_text("alert('unapproved')")
        with self.assertRaisesRegex(site.PublicSiteError, "approved asset allowlist"):
            site.validate_payload(self.source)

    def test_payload_rejects_every_app_or_server_artifact(self):
        for name in ["main.dart.js", "env.json", "_worker.js", "flutter_service_worker.js", "secret.env", "receipt.json"]:
            with self.subTest(name=name):
                path = self.source / name
                path.write_text("forbidden")
                with self.assertRaisesRegex(site.PublicSiteError, "exactly six"):
                    site.validate_payload(self.source)
                path.unlink()
        for name in ["functions", "assets/unapproved"]:
            path = self.source / name
            path.mkdir()
            with self.assertRaisesRegex(site.PublicSiteError, "Directories|exactly six"):
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
        # The legal pages retain every original text-only restriction. Landing
        # execution is separately limited to the exact supplied implementation.
        original = (self.source / "support.html").read_text()
        injections = ["<script>alert(1)</script>", '<script src="/main.dart.js"></script>',
                      '<iframe src="https://kemet.pages.dev"></iframe>', '<form action="/login"></form>',
                      '<a href="javascript:alert(1)">go</a>', '<p onclick="alert(1)">go</p>',
                      '<meta http-equiv="refresh" content="0;url=/privacy">',
                      '<link rel="manifest" href="/manifest.json">',
                      '<style>p{background:u/**/rl(https://example.com/x)}</style>',
                      '<style>@import "https://example.com/x";</style>']
        for injection in injections:
            with self.subTest(injection=injection):
                (self.source / "support.html").write_text(original.replace("</body>", injection + "</body>"))
                with self.assertRaises(site.PublicSiteError):
                    site.validate_payload(self.source)
        (self.source / "support.html").write_text(original)
        landing = (self.source / "index.html").read_text()
        for injection in injections:
            with self.subTest(landing_injection=injection):
                (self.source / "index.html").write_text(landing.replace("</body>", injection + "</body>"))
                with self.assertRaisesRegex(site.PublicSiteError, "exact approved"):
                    site.validate_payload(self.source)
        (self.source / "index.html").write_text(landing)

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
        original = (self.source / "support.html").read_text()
        for href in ["/missing", "/privacy.html", "/privacy#missing", "/privacy?secret=1",
                     "https://haw-info.pages.dev/missing"]:
            with self.subTest(href=href):
                self.edit("support.html", 'href="/privacy"', 'href="' + href + '"')
                with self.assertRaises(site.PublicSiteError):
                    site.validate_payload(self.source)
                (self.source / "support.html").write_text(original)
        self.edit("support.html", 'href="/privacy"', 'href="/privacy#google-calendar"')
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
        self.assertEqual({path.relative_to(first / "payload").as_posix()
                          for path in (first / "payload").rglob("*") if path.is_file()}, site.FILES)
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
        tools = {name: ("tool:" + name).encode() for name in site.SOURCE_TOOLS}
        for name, body in tools.items():
            (self.repo / name).write_bytes(body)

        def committed(repo, *args):
            if args == ("rev-parse", "HEAD"):
                return b"a" * 40
            if args == ("ls-tree", "-r", "--name-only", "HEAD:public-site"):
                return "\n".join(sorted(site.FILES)).encode()
            path = args[1].removeprefix("HEAD:")
            return tools[path] if path in tools else bodies[path.removeprefix("public-site/")]

        with patch.object(site, "git", side_effect=committed):
            expected_tool_hash = site.sha(site.canonical_json({name: site.sha(body) for name, body in tools.items()}))
            self.assertEqual(site.source_identity(self.repo, bodies), ("a" * 40, expected_tool_hash))
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

    def test_live_assets_require_exact_bytes_mime_and_success(self):
        release = self.seal()
        samples = {asset["content_type"]: name for name, asset in site.ASSETS.items()}
        for media, name in samples.items():
            for status, mime, body in [(404, media, b"missing"), (200, "text/html", b"wrong type"),
                                       (200, media, b"replaced asset")]:
                with self.subTest(name=name, status=status, mime=mime):
                    responses = self.responses(release)
                    url = site.ORIGIN + "/" + name
                    responses[url] = site.HttpResult(status, {"content-type": mime}, body, url)
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
