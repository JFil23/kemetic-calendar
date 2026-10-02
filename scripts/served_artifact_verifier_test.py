#!/usr/bin/env python3
from __future__ import annotations

import copy
import hashlib
import json
import os
import subprocess
import tempfile
import unittest
from unittest.mock import patch
from pathlib import Path

import served_artifact_verifier as verifier


ROOT = Path(__file__).resolve().parents[1]
CONTRACT_PATH = ROOT / verifier.CONTRACT_PATH


def canonical_json(value):
    return (
        json.dumps(value, sort_keys=True, separators=(",", ":")) + "\n"
    ).encode("utf-8")


class FakeFetcher:
    def __init__(self, responses):
        self.responses = responses
        self.calls = []

    def __call__(self, url):
        self.calls.append(url)
        return self.responses.get(
            url,
            verifier.HttpResult(404, {}, b"missing", url),
        )


class ServedArtifactVerifierTest(unittest.TestCase):
    def setUp(self) -> None:
        self.contract = verifier.load_contract(CONTRACT_PATH)
        self.origin = "https://0123abcd.kemet-rc.pages.dev"
        self.alias = "https://kemet-rc.pages.dev"
        self.source = {
            "app_commit": "3" * 40,
            "app_tree": "4" * 40,
            "source_epoch": 1_700_000_000,
        }
        self.pwa_identity = {
            "name": "Kemet Release Candidate",
            "short_name": "Kemet RC",
            "id": "/",
            "start_url": "/",
            "scope": "/",
            "display": "standalone",
        }
        self.receipt = {
            "environment": "staging",
            "build_id": "a" * 64,
            "build_version": "staging-3333333-aaaaaaaaaaaa",
            "site_origin": self.alias,
            "source": self.source,
            "pwa_identity": self.pwa_identity,
            "inputs": {
                "config_sha256": "b" * 64,
                "icon_set_sha256": "c" * 64,
            },
        }
        self.version = canonical_json(
            {
                "environment": "staging",
                "app_env": "staging",
                "build_id": self.receipt["build_id"],
                "build_version": self.receipt["build_version"],
                "source": self.source,
                "inputs": self.receipt["inputs"],
            }
        )
        self.environment = canonical_json(
            {"APP_ENV": "staging", "APP_SITE_URL": self.alias}
        )
        self.bodies = {
            "web/_headers": b"headers-control",
            "web/_redirects": b"redirects-control",
            "web/.well-known/apple-app-site-association": b'{"applinks":{}}\n',
            "web/index.html": b"index-body",
            "web/version.json": self.version,
            "web/env.json": self.environment,
            "web/manifest.json": canonical_json(self.pwa_identity),
            "web/main.dart.js": b"compiled-app",
        }
        for index in range(66):
            self.bodies[f"web/assets/test-{index:02d}.bin"] = (
                f"asset-{index:02d}".encode("ascii")
            )
        self.manifest = {
            path: hashlib.sha256(body).hexdigest()
            for path, body in self.bodies.items()
        }

    def responses_for(self, origin, *, bodies=None):
        bodies = bodies or self.bodies
        responses = {}
        redirect_by_manifest = {
            item["manifest_path"]: item
            for item in self.contract["redirect_only"]
        }
        for path, body in bodies.items():
            if path in self.contract["pages_controls"] or path in redirect_by_manifest:
                continue
            request_path = verifier.request_path_for_manifest_path(path)
            headers = (
                {"content-type": "application/json; charset=utf-8"}
                if request_path == verifier.AASA_PATH
                else {}
            )
            responses[origin + request_path] = verifier.HttpResult(
                200,
                headers,
                body,
                origin + request_path,
            )
        index_body = bodies["web/index.html"]
        for route in self.contract["application_routes"]:
            responses[origin + route] = verifier.HttpResult(
                200,
                {},
                index_body,
                origin + route,
            )
        for rule in self.contract["redirect_only"]:
            responses[origin + rule["request_path"]] = verifier.HttpResult(
                rule["status"],
                {"location": rule["destination"]},
                b"",
                origin + rule["request_path"],
            )
        for rule in self.contract["public_redirects"]:
            responses[origin + rule["request_path"]] = verifier.HttpResult(
                rule["status"], {"location": rule["destination"]}, b"",
                origin + rule["request_path"],
            )
        return responses

    def verify(self, origin=None, *, manifest=None, responses=None):
        origin = origin or self.origin
        fetcher = FakeFetcher(
            responses if responses is not None else self.responses_for(origin)
        )
        result = verifier.verify_served_origin(
            origin=origin,
            manifest=manifest or self.manifest,
            contract=self.contract,
            receipt=self.receipt,
            fetcher=fetcher,
        )
        return result, fetcher

    def test_payload_routes_aasa_identity_and_public_redirects_are_all_verified(self) -> None:
        immutable, _ = self.verify(self.origin)
        alias, _ = self.verify(self.alias)
        for result in (immutable, alias):
            self.assertEqual(result["classification_counts"], {
                "direct_bodies": 71,
                "redirect_only": 1,
                "pages_controls": 2,
                "total": 74,
            })
            self.assertEqual(result["verified_direct_bodies"], 71)
            self.assertEqual(len(result["app_route_results"]), 6)
            self.assertEqual(result["aasa"]["content_type"], "application/json")
            self.assertEqual(result["verified_public_redirects"], 18)
            self.assertEqual(result["public_redirect_results"], [
                {**rule, "body_sha256": hashlib.sha256(b"").hexdigest()}
                for rule in self.contract["public_redirects"]
            ])
            self.assertNotIn("verified_public_bodies", result)
            self.assertNotIn("waived_legal_failures", result)
            self.assertEqual(result["verdicts"], {
                "PAYLOAD_VERIFIED": True,
                "APP_ROUTING_VERIFIED": True,
                "IDENTITY_VERIFIED": True,
                "AASA_VERIFIED": True,
                "LEGAL_ROUTING_VERIFIED": True,
            })
            self.assertEqual(result["unaccounted_entries"], [])

    def test_local_release_uses_real_http_public_redirects_and_rejects_corruption(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            release_dir = Path(temporary)
            bodies = dict(self.bodies)
            for control in self.contract["pages_controls"]:
                bodies[control] = (ROOT / control).read_bytes()
            for name, body in bodies.items():
                path = release_dir / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes(body)
            manifest = {
                name: hashlib.sha256(body).hexdigest() for name, body in bodies.items()
            }
            (release_dir / "payload-manifest.sha256").write_bytes(
                verifier.release.manifest_bytes(sorted(manifest.items()))
            )
            receipt = {**self.receipt, "payload": {"manifest_file": "payload-manifest.sha256"}}
            # Sealing is covered by the release-pipeline suite. Exercise the local
            # HTTP server, controls, manifest parsing and all served checks here.
            with patch.object(verifier.release, "verify_release", return_value=receipt):
                result = verifier.verify_local_release(
                    release_dir=release_dir, contract_path=CONTRACT_PATH,
                )
                self.assertEqual(result["verified_public_redirects"], 18)
                self.assertEqual(len(result["app_route_results"]), 6)
                self.assertTrue(all(result["verdicts"].values()))
                (release_dir / "web/main.dart.js").write_bytes(b"wrong app body")
                with self.assertRaisesRegex(verifier.ServedVerificationError, "body hash mismatch"):
                    verifier.verify_local_release(
                        release_dir=release_dir, contract_path=CONTRACT_PATH,
                    )

    def test_payload_cardinality_follows_the_sealed_manifest(self) -> None:
        bodies = dict(self.bodies)
        bodies.pop("web/assets/test-64.bin")
        bodies.pop("web/assets/test-65.bin")
        manifest = {
            path: hashlib.sha256(body).hexdigest()
            for path, body in bodies.items()
        }

        result, _ = self.verify(
            manifest=manifest,
            responses=self.responses_for(self.origin, bodies=bodies),
        )

        self.assertEqual(result["classification_counts"], {
            "direct_bodies": 69,
            "redirect_only": 1,
            "pages_controls": 2,
            "total": 72,
        })
        self.assertEqual(result["verified_direct_bodies"], 69)

    def test_direct_body_mismatch_fails(self) -> None:
        responses = self.responses_for(self.origin)
        responses[self.origin + "/main.dart.js"] = verifier.HttpResult(
            200, {}, b"changed", self.origin + "/main.dart.js"
        )
        with self.assertRaisesRegex(
            verifier.ServedVerificationError, "body hash mismatch"
        ):
            self.verify(responses=responses)

    def test_alias_body_mismatch_fails(self) -> None:
        responses = self.responses_for(self.alias)
        responses[self.alias + "/manifest.json"] = verifier.HttpResult(
            200, {}, b"older", self.alias + "/manifest.json"
        )
        with self.assertRaisesRegex(
            verifier.ServedVerificationError, "body hash mismatch"
        ):
            self.verify(self.alias, responses=responses)

    def test_missing_body_fails_once_without_automatic_action(self) -> None:
        responses = self.responses_for(self.origin)
        responses.pop(self.origin + "/main.dart.js")
        fetcher = FakeFetcher(responses)
        with self.assertRaisesRegex(verifier.ServedVerificationError, "status 200"):
            verifier.verify_served_origin(
                origin=self.origin,
                manifest=self.manifest,
                contract=self.contract,
                receipt=self.receipt,
                fetcher=fetcher,
            )
        self.assertEqual(fetcher.calls.count(self.origin + "/main.dart.js"), 1)

    def test_unserved_payload_entry_fails(self) -> None:
        manifest = dict(self.manifest)
        manifest["web/unexpected.bin"] = "d" * 64
        with self.assertRaisesRegex(
            verifier.ServedVerificationError, "Expected body status 200"
        ):
            self.verify(manifest=manifest)

    def test_missing_contract_classification_fails(self) -> None:
        contract = copy.deepcopy(self.contract)
        contract["pages_controls"].append("web/not-in-payload")
        with self.assertRaisesRegex(
            verifier.ServedVerificationError, "absent from the payload"
        ):
            verifier.classify_manifest(self.manifest, contract)

    def test_wrong_redirect_destination_fails(self) -> None:
        responses = self.responses_for(self.origin)
        responses[self.origin + "/privacy.html"] = verifier.HttpResult(
            308,
            {"location": "/wrong"},
            b"",
            self.origin + "/privacy.html",
        )
        with self.assertRaisesRegex(
            verifier.ServedVerificationError, "destination mismatch"
        ):
            self.verify(responses=responses)

    def test_every_public_route_requires_exact_external_redirect(self) -> None:
        for rule in self.contract["public_redirects"]:
            path = rule["request_path"]
            for status, location, body in (
                (308, path, b""),
                (200, None, self.bodies["web/index.html"]),
                (200, None, b"retired public HTML"),
                (301, rule["destination"], b""),
                (302, rule["destination"], b""),
                (404, None, b"missing"),
                (308, "https://unapproved.example/privacy", b""),
                (308, rule["destination"] + "?injected=1", b""),
                (308, rule["destination"] + "#fragment", b""),
                (308, None, b""),
            ):
                with self.subTest(path=path, status=status, location=location):
                    responses = self.responses_for(self.origin)
                    responses[self.origin + path] = verifier.HttpResult(
                        status, {"location": location} if location else {}, body,
                        self.origin + path,
                    )
                    with self.assertRaises(verifier.ServedVerificationError):
                        self.verify(responses=responses)

    def test_public_redirect_rejects_wrong_path_on_approved_host(self) -> None:
        responses = self.responses_for(self.origin)
        responses[self.origin + "/privacy"] = verifier.HttpResult(
            308, {"location": self.contract["public_site_origin"] + "/terms"}, b"",
            self.origin + "/privacy",
        )
        with self.assertRaisesRegex(verifier.ServedVerificationError, "destination mismatch"):
            self.verify(responses=responses)

    def test_missing_public_redirect_fails_once(self) -> None:
        responses = self.responses_for(self.origin)
        responses.pop(self.origin + "/privacy")
        fetcher = FakeFetcher(responses)
        with self.assertRaisesRegex(verifier.ServedVerificationError, "status mismatch"):
            verifier.verify_served_origin(
                origin=self.origin, manifest=self.manifest, contract=self.contract,
                receipt=self.receipt, fetcher=fetcher,
            )
        self.assertEqual(fetcher.calls.count(self.origin + "/privacy"), 1)

    def test_app_verification_never_fetches_website_bodies(self) -> None:
        result, fetcher = self.verify()
        self.assertEqual(result["verified_public_redirects"], 18)
        self.assertTrue(all(url.startswith(self.origin + "/") for url in fetcher.calls))
        self.assertFalse(any(self.contract["public_site_origin"] in url for url in fetcher.calls))

    def test_public_site_content_cannot_enter_app_payload(self) -> None:
        for path in (*verifier.RETIRED_PUBLIC_HTML_PATHS,
                     "web/public-site/index.html", "web/assets/public-site/privacy.html"):
            with self.subTest(path=path):
                manifest = {**self.manifest, path: "a" * 64}
                with self.assertRaisesRegex(verifier.ServedVerificationError, "Public-site content"):
                    verifier.classify_manifest(manifest, self.contract)

    def test_all_existing_app_routes_still_require_the_app_shell(self) -> None:
        for route in self.contract["application_routes"]:
            with self.subTest(route=route):
                responses = self.responses_for(self.origin)
                responses[self.origin + route] = verifier.HttpResult(
                    200, {"content-type": "text/html"}, b"separate website body",
                    self.origin + route,
                )
                with self.assertRaisesRegex(verifier.ServedVerificationError, "body hash mismatch"):
                    self.verify(responses=responses)

    def test_root_404_cannot_disable_native_spa_fallback(self) -> None:
        manifest = dict(self.manifest)
        manifest["web/404.html"] = "f" * 64
        with self.assertRaisesRegex(verifier.ServedVerificationError, "disables native SPA"):
            verifier.classify_manifest(manifest, self.contract)

    def test_body_unexpectedly_replaced_by_redirect_fails(self) -> None:
        responses = self.responses_for(self.origin)
        responses[self.origin + "/main.dart.js"] = verifier.HttpResult(
            308,
            {"location": "/main.dart.js.next"},
            b"",
            self.origin + "/main.dart.js",
        )
        with self.assertRaisesRegex(verifier.ServedVerificationError, "body status 200"):
            self.verify(responses=responses)

    def test_pages_controls_are_not_fetched_as_bodies(self) -> None:
        result, fetcher = self.verify()
        self.assertEqual(result["pages_controls"], ["web/_headers", "web/_redirects"])
        self.assertNotIn(self.origin + "/_headers", fetcher.calls)
        self.assertNotIn(self.origin + "/_redirects", fetcher.calls)

    def test_origin_escaping_redirect_fails(self) -> None:
        responses = self.responses_for(self.origin)
        responses[self.origin + "/index.html"] = verifier.HttpResult(
            308,
            {"location": "https://haw-info.pages.dev/"},
            b"",
            self.origin + "/index.html",
        )
        with self.assertRaisesRegex(
            verifier.ServedVerificationError, "escapes the expected origin"
        ):
            self.verify(responses=responses)

    def test_wrong_build_identity_fails(self) -> None:
        bodies = dict(self.bodies)
        version = json.loads(self.version)
        version["build_id"] = "d" * 64
        bodies["web/version.json"] = canonical_json(version)
        manifest = {
            path: hashlib.sha256(body).hexdigest()
            for path, body in bodies.items()
        }
        with self.assertRaisesRegex(
            verifier.ServedVerificationError, "build identity is wrong"
        ):
            self.verify(
                manifest=manifest,
                responses=self.responses_for(self.origin, bodies=bodies),
            )

    def test_wrong_app_env_or_site_origin_fails(self) -> None:
        for field, value, message in (
            ("APP_ENV", "prod", "APP_ENV identity is wrong"),
            ("APP_SITE_URL", "https://old.example", "site-origin identity is wrong"),
        ):
            with self.subTest(field=field):
                bodies = dict(self.bodies)
                runtime = json.loads(self.environment)
                runtime[field] = value
                bodies["web/env.json"] = canonical_json(runtime)
                manifest = {
                    path: hashlib.sha256(body).hexdigest()
                    for path, body in bodies.items()
                }
                with self.assertRaisesRegex(verifier.ServedVerificationError, message):
                    self.verify(
                        manifest=manifest,
                        responses=self.responses_for(self.origin, bodies=bodies),
                    )

    def test_contract_is_exact_and_public_redirects_are_complete(self) -> None:
        self.assertEqual(self.contract["schema_version"], 4)
        self.assertEqual(len(self.contract["redirect_only"]), 1)
        self.assertEqual(len(self.contract["application_routes"]), 6)
        self.assertEqual(self.contract["public_site_origin"], "https://haw-info.pages.dev")
        expected = {
            route + suffix: self.contract["public_site_origin"] + destination
            for route, destination in {
                "/about": "/", "/privacy": "/privacy", "/terms": "/terms",
                "/support": "/support", "/delete-account": "/delete-account",
                "/account-deletion": "/delete-account",
            }.items() for suffix in ("", ".html", "/")
        }
        self.assertEqual({rule["request_path"]: rule["destination"]
                          for rule in self.contract["public_redirects"]}, expected)
        self.assertTrue(all(rule["status"] == 308 for rule in self.contract["public_redirects"]))
        self.assertNotIn("legal_self_loop_waiver", self.contract)

    def test_contract_cannot_omit_redirects_or_accept_unsafe_targets(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / "contract.json"
            for mutation in (
                lambda c: c["public_redirects"].pop(),
                lambda c: c["public_redirects"].append(c["public_redirects"][0]),
                lambda c: c["public_redirects"][0].update(destination="/about"),
                lambda c: c["public_redirects"][0].update(destination=c["public_site_origin"] + "/wrong"),
                lambda c: c["public_redirects"][0].update(request_path="/settings"),
                lambda c: c["public_redirects"][0].update(destination=c["public_site_origin"] + "/?x=1"),
                lambda c: c.update(schema_version=3),
            ):
                contract = copy.deepcopy(self.contract)
                mutation(contract)
                path.write_text(json.dumps(contract))
                with self.assertRaises(verifier.ServedVerificationError):
                    verifier.load_contract(path)

    def test_contract_rejects_an_entirely_substituted_public_host(self) -> None:
        contract = copy.deepcopy(self.contract)
        original = contract["public_site_origin"]
        contract["public_site_origin"] = "https://unapproved.example"
        for rule in contract["public_redirects"]:
            rule["destination"] = rule["destination"].replace(original, contract["public_site_origin"], 1)
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / "contract.json"
            path.write_text(json.dumps(contract))
            with self.assertRaises(verifier.ServedVerificationError):
                verifier.load_contract(path)

    def test_two_canonical_deployment_targets_only(self) -> None:
        self.assertEqual(
            verifier.validate_deployment_target(
                receipt=self.receipt,
                project="kemet-rc",
                branch="main",
                alias_url=self.alias,
            ),
            self.alias,
        )
        production = copy.deepcopy(self.receipt)
        production["environment"] = "production"
        production["site_origin"] = "https://kemet.pages.dev"
        self.assertEqual(
            verifier.validate_deployment_target(
                receipt=production,
                project="kemet",
                branch="main",
                alias_url="https://kemet.pages.dev",
            ),
            "https://kemet.pages.dev",
        )
        for project, branch in (
            ("kemet-rc", "feature"),
            ("new-kemet-rc", "main"),
            ("kemet", "main"),
            ("kemet-rc", "production"),
        ):
            with self.subTest(project=project, branch=branch):
                with self.assertRaisesRegex(
                    verifier.ServedVerificationError, "two-lane model"
                ):
                    verifier.validate_deployment_target(
                        receipt=self.receipt,
                        project=project,
                        branch=branch,
                    )

    def test_immutable_origin_must_belong_to_declared_project(self) -> None:
        self.assertEqual(
            verifier.validate_immutable_project_origin(
                immutable_url=self.origin,
                project="kemet-rc",
                alias_url=self.alias,
            ),
            self.origin,
        )
        for invalid_url in (
            "https://main.kemet-rc.pages.dev",
            "https://feature.kemet-rc.pages.dev",
            "https://foo.0123abcd.kemet-rc.pages.dev",
            "https://0123ABCD.kemet-rc.pages.dev",
            "https://0123abcd.kemet.pages.dev",
        ):
            with self.subTest(invalid_url=invalid_url):
                with self.assertRaisesRegex(
                    verifier.ServedVerificationError, "8-lowercase-hex"
                ):
                    verifier.validate_immutable_project_origin(
                        immutable_url=invalid_url,
                        project="kemet-rc",
                        alias_url=self.alias,
                    )

    def test_cloudflare_metadata_requires_latest_production_main(self) -> None:
        good = {
            "Id": "12345678-1234-1234-1234-123456789abc",
            "Environment": "Production",
            "Branch": "main",
            "Deployment": self.origin,
        }
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / "deployments.json"
            for mutation, message in (
                (lambda rows: rows, None),
                (
                    lambda rows: [{**rows[0], "Environment": "Preview"}],
                    "outside production/main",
                ),
                (
                    lambda rows: [{**rows[0], "Branch": "feature"}],
                    "outside production/main",
                ),
                (
                    lambda rows: [
                        {**rows[0], "Deployment": "https://deadbeef.kemet-rc.pages.dev"},
                        rows[0],
                    ],
                    "not the latest production deployment",
                ),
            ):
                with self.subTest(message=message):
                    path.write_text(json.dumps(mutation([good])), encoding="utf-8")
                    if message is None:
                        result = verifier.validate_cloudflare_deployment_metadata(
                            metadata_path=path,
                            immutable_url=self.origin,
                            receipt=self.receipt,
                            project="kemet-rc",
                            branch="main",
                        )
                        self.assertEqual(result["environment"], "production")
                        self.assertEqual(result["branch"], "main")
                        self.assertEqual(result["stable_alias"], self.alias)
                    else:
                        with self.assertRaisesRegex(
                            verifier.ServedVerificationError, message
                        ):
                            verifier.validate_cloudflare_deployment_metadata(
                                metadata_path=path,
                                immutable_url=self.origin,
                                receipt=self.receipt,
                                project="kemet-rc",
                                branch="main",
                            )

    def test_pages_controls_match_exact_hashes_and_reject_external_rewrites(self) -> None:
        manifest = dict(self.manifest)
        with tempfile.TemporaryDirectory() as temporary:
            release_dir = Path(temporary)
            (release_dir / "web").mkdir()
            for path in self.contract["pages_controls"]:
                source = ROOT / path
                destination = release_dir / path
                destination.write_bytes(source.read_bytes())
                manifest[path] = hashlib.sha256(destination.read_bytes()).hexdigest()
            result = verifier.validate_pages_controls(
                release_dir=release_dir,
                manifest=manifest,
                contract=self.contract,
            )
            self.assertGreater(len(result["redirect_rewrite_rules"]), 1)
            redirects = release_dir / "web/_redirects"
            redirects.write_text("/escape https://kemet.pages.dev 200\n")
            changed_contract = copy.deepcopy(self.contract)
            changed_hash = hashlib.sha256(redirects.read_bytes()).hexdigest()
            changed_contract["pages_control_sha256"]["web/_redirects"] = changed_hash
            manifest["web/_redirects"] = changed_hash
            with self.assertRaisesRegex(
                verifier.ServedVerificationError, "Unsafe or unsupported"
            ):
                verifier.validate_pages_controls(
                    release_dir=release_dir,
                    manifest=manifest,
                    contract=changed_contract,
                )

    def test_controls_reject_html_canonicalization_cycles_and_spa_overrides(self) -> None:
        for rule in (
            "/privacy /privacy.html 200",
            "/privacy /index.html 200",
            "/priv* /privacy 200",
            "/* /index.html 200",
            "/account-deletion /account-deletion 308",
            "/account-deletion /terms 308",
            "/escape https://outside.example/path 308",
        ):
            with self.subTest(rule=rule), tempfile.TemporaryDirectory() as temporary:
                release_dir = Path(temporary)
                (release_dir / "web").mkdir()
                redirects = release_dir / "web/_redirects"
                redirects.write_text(rule + "\n")
                contract = copy.deepcopy(self.contract)
                manifest = dict(self.manifest)
                for path in contract["pages_controls"]:
                    body = redirects.read_bytes() if path.endswith("_redirects") else (ROOT / path).read_bytes()
                    contract["pages_control_sha256"][path] = hashlib.sha256(body).hexdigest()
                    manifest[path] = contract["pages_control_sha256"][path]
                with self.assertRaises(verifier.ServedVerificationError):
                    verifier.validate_pages_controls(
                        release_dir=release_dir, manifest=manifest, contract=contract,
                    )

    def test_controls_require_both_account_deletion_aliases(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            release_dir = Path(temporary)
            (release_dir / "web").mkdir()
            path = release_dir / "web/_redirects"
            body = (ROOT / "web/_redirects").read_text().replace(
                "/account-deletion/ https://haw-info.pages.dev/delete-account 308\n", ""
            ).encode()
            path.write_bytes(body)
            contract = copy.deepcopy(self.contract)
            manifest = dict(self.manifest)
            for control in contract["pages_controls"]:
                digest = hashlib.sha256(body if control.endswith("_redirects") else (ROOT / control).read_bytes()).hexdigest()
                contract["pages_control_sha256"][control] = digest
                manifest[control] = digest
            with self.assertRaisesRegex(verifier.ServedVerificationError, "omits a public redirect"):
                verifier.validate_pages_controls(
                    release_dir=release_dir, manifest=manifest, contract=contract,
                )

    def test_wrangler_output_yields_only_exact_immutable_origin(self) -> None:
        result = verifier.extract_immutable_origin(
            upload_result=f"Deployment complete: {self.origin}\nAlias: {self.alias}\n",
            project="kemet-rc",
            alias_origin=self.alias,
        )
        self.assertEqual(result, self.origin)
        for invalid_url in (
            self.alias,
            "https://main.kemet-rc.pages.dev",
            "https://foo.0123abcd.kemet-rc.pages.dev",
            "https://0123ABCD.kemet-rc.pages.dev",
        ):
            with self.subTest(invalid_url=invalid_url):
                with self.assertRaisesRegex(verifier.ServedVerificationError, "found"):
                    verifier.extract_immutable_origin(
                        upload_result=f"Deployment complete: {invalid_url}\n",
                        project="kemet-rc",
                        alias_origin=self.alias,
                    )

    def test_actual_helper_passes_rc_project_and_main_to_wrangler(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            fake_bin = root / "bin"
            fake_bin.mkdir()
            release_dir = root / "release"
            release_dir.mkdir()
            capture = root / "npx-arguments.txt"
            fake_python = fake_bin / "python3"
            fake_python.write_text(
                """#!/bin/sh
case "$*" in
  *"web_release_pipeline.py verify"*)
    while [ "$#" -gt 0 ]; do
      if [ "$1" = "--extract-to" ]; then mkdir -p "$2/web"; fi
      shift
    done
    ;;
  *"served_artifact_verifier.py extract-immutable-url"*)
    echo "https://0123abcd.kemet-rc.pages.dev"
    ;;
  *"served_artifact_verifier.py record-upload-attempt"*|*"served_artifact_verifier.py verify"*)
    while [ "$#" -gt 0 ]; do
      if [ "$1" = "--receipt" ]; then printf '{}\n' > "$2"; fi
      shift
    done
    ;;
esac
exit 0
""",
                encoding="utf-8",
            )
            fake_npx = fake_bin / "npx"
            fake_npx.write_text(
                """#!/bin/sh
printf '%s\n' "$*" >> "$CAPTURE_PATH"
case "$*" in
  *"pages deploy"*)
    echo "Deployment complete: https://0123abcd.kemet-rc.pages.dev"
    ;;
  *"pages deployment list"*)
    printf '%s\n' '[{"Id":"12345678-1234-1234-1234-123456789abc","Environment":"Production","Branch":"main","Deployment":"https://0123abcd.kemet-rc.pages.dev"}]'
    ;;
esac
exit 0
""",
                encoding="utf-8",
            )
            fake_python.chmod(0o755)
            fake_npx.chmod(0o755)
            environment = dict(os.environ)
            environment["PATH"] = f"{fake_bin}:{environment['PATH']}"
            environment["CAPTURE_PATH"] = str(capture)
            subprocess.run(
                [
                    str(ROOT / "scripts/deploy_cloudflare_pages.sh"),
                    str(release_dir),
                    "e" * 64,
                    "staging",
                ],
                cwd=ROOT,
                env=environment,
                check=True,
                capture_output=True,
                text=True,
            )
            calls = capture.read_text(encoding="utf-8").splitlines()
            self.assertEqual(len(calls), 2)
            command, deploy_arguments = calls[0].split(" pages deploy ", 1)
            payload_root, target_arguments = deploy_arguments.rsplit(
                " --project-name ", 1
            )
            self.assertEqual(
                command,
                "--yes wrangler@4.114.0",
            )
            self.assertTrue(payload_root.endswith("/web"))
            self.assertEqual(target_arguments, "kemet-rc --branch main")
            self.assertEqual(
                calls[1],
                "--yes wrangler@4.114.0 pages deployment list --project-name kemet-rc --environment production --json",
            )
            self.assertNotIn("codex", "\n".join(calls).lower())


if __name__ == "__main__":
    unittest.main()
