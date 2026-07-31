#!/usr/bin/env python3
from __future__ import annotations

import copy
import hashlib
import json
import tempfile
import unittest
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
        self.origin = "https://immutable.example.pages.dev"
        self.alias = "https://rc-198d9d4.example.pages.dev"
        self.receipt = {
            "environment": "staging",
            "build_id": "a" * 64,
            "build_version": "staging-test-aaaaaaaaaaaa",
            "site_origin": "https://rc-198d9d4.example.pages.dev",
            "inputs": {
                "config_sha256": "b" * 64,
                "icon_set_sha256": "c" * 64,
            },
        }
        self.version = canonical_json(
            {
                "environment": "staging",
                "build_id": "a" * 64,
                "inputs": {
                    "config_sha256": "b" * 64,
                    "icon_set_sha256": "c" * 64,
                },
            }
        )
        self.environment = canonical_json(
            {"APP_SITE_URL": "https://rc-198d9d4.example.pages.dev"}
        )
        self.bodies = {
            "web/_headers": b"headers-control",
            "web/_redirects": b"redirects-control",
            "web/index.html": b"index-body",
            "web/delete-account.html": b"delete-body",
            "web/privacy.html": b"privacy-body",
            "web/support.html": b"support-body",
            "web/terms.html": b"terms-body",
            "web/version.json": self.version,
            "web/env.json": self.environment,
            "web/manifest.json": b'{"name":"Kemet RC"}\n',
            "web/main.dart.js": b"compiled-app",
        }
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
            if path in self.contract["pages_controls"]:
                continue
            if path in redirect_by_manifest:
                rule = redirect_by_manifest[path]
                responses[origin + rule["request_path"]] = verifier.HttpResult(
                    308,
                    {"location": rule["destination"]},
                    b"",
                    origin + rule["request_path"],
                )
                responses[origin + rule["canonical_body_path"]] = verifier.HttpResult(
                    200,
                    {},
                    body,
                    origin + rule["canonical_body_path"],
                )
            else:
                request_path = verifier.request_path_for_manifest_path(path)
                responses[origin + request_path] = verifier.HttpResult(
                    200,
                    {},
                    body,
                    origin + request_path,
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

    def test_all_bodies_match_on_immutable_and_alias(self) -> None:
        immutable, _ = self.verify(self.origin)
        alias, _ = self.verify(self.alias)
        self.assertEqual(immutable["unaccounted_entries"], [])
        self.assertEqual(alias["unaccounted_entries"], [])
        self.assertEqual(
            immutable["verified_retrievable_entries"],
            len(self.manifest) - 2,
        )

    def test_immutable_body_mismatch_fails(self) -> None:
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

    def test_missing_body_fails(self) -> None:
        responses = self.responses_for(self.origin)
        responses.pop(self.origin + "/main.dart.js")
        with self.assertRaisesRegex(
            verifier.ServedVerificationError, "status 200"
        ):
            self.verify(responses=responses)

    def test_unexpected_extra_contract_classification_fails(self) -> None:
        contract = copy.deepcopy(self.contract)
        contract["pages_controls"].append("web/not-in-payload")
        with self.assertRaisesRegex(
            verifier.ServedVerificationError, "absent from the payload"
        ):
            verifier.classify_manifest(self.manifest, contract)

    def test_expected_redirect_and_canonical_body_pass(self) -> None:
        result, _ = self.verify()
        self.assertEqual(
            {item["status"] for item in result["redirect_results"]},
            {308},
        )

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

    def test_redirect_unexpectedly_replaced_by_body_fails(self) -> None:
        responses = self.responses_for(self.origin)
        responses[self.origin + "/terms.html"] = verifier.HttpResult(
            200, {}, self.bodies["web/terms.html"], self.origin + "/terms.html"
        )
        with self.assertRaisesRegex(
            verifier.ServedVerificationError, "Redirect status mismatch"
        ):
            self.verify(responses=responses)

    def test_body_unexpectedly_replaced_by_redirect_fails(self) -> None:
        responses = self.responses_for(self.origin)
        responses[self.origin + "/main.dart.js"] = verifier.HttpResult(
            308,
            {"location": "/main.dart.js.next"},
            b"",
            self.origin + "/main.dart.js",
        )
        with self.assertRaisesRegex(
            verifier.ServedVerificationError, "body status 200"
        ):
            self.verify(responses=responses)

    def test_pages_controls_are_not_fetched_as_bodies(self) -> None:
        result, fetcher = self.verify()
        self.assertEqual(
            result["pages_controls"],
            ["web/_headers", "web/_redirects"],
        )
        self.assertNotIn(self.origin + "/_headers", fetcher.calls)
        self.assertNotIn(self.origin + "/_redirects", fetcher.calls)

    def test_origin_escaping_redirect_fails(self) -> None:
        responses = self.responses_for(self.origin)
        responses[self.origin + "/support.html"] = verifier.HttpResult(
            308,
            {"location": "https://kemet.pages.dev/support"},
            b"",
            self.origin + "/support.html",
        )
        with self.assertRaisesRegex(
            verifier.ServedVerificationError, "escapes the expected origin"
        ):
            self.verify(responses=responses)

    def test_wrong_build_or_config_identity_fails(self) -> None:
        wrong_version = canonical_json(
            {
                "environment": "staging",
                "build_id": "d" * 64,
                "inputs": {
                    "config_sha256": "e" * 64,
                    "icon_set_sha256": "c" * 64,
                },
            }
        )
        bodies = dict(self.bodies)
        bodies["web/version.json"] = wrong_version
        manifest = {
            path: hashlib.sha256(body).hexdigest()
            for path, body in bodies.items()
        }
        responses = self.responses_for(self.origin, bodies=bodies)
        with self.assertRaisesRegex(
            verifier.ServedVerificationError, "build identity is wrong"
        ):
            self.verify(manifest=manifest, responses=responses)

    def test_alias_serving_older_otherwise_valid_artifact_fails(self) -> None:
        old_version = canonical_json(
            {
                "environment": "staging",
                "build_id": "f" * 64,
                "inputs": {
                    "config_sha256": "b" * 64,
                    "icon_set_sha256": "c" * 64,
                },
            }
        )
        bodies = dict(self.bodies)
        bodies["web/version.json"] = old_version
        manifest = {
            path: hashlib.sha256(body).hexdigest()
            for path, body in bodies.items()
        }
        responses = self.responses_for(self.alias, bodies=bodies)
        with self.assertRaisesRegex(
            verifier.ServedVerificationError, "build identity is wrong"
        ):
            self.verify(self.alias, manifest=manifest, responses=responses)

    def test_failure_is_single_attempt_with_no_automatic_action(self) -> None:
        responses = self.responses_for(self.origin)
        responses.pop(self.origin + "/main.dart.js")
        fetcher = FakeFetcher(responses)
        with self.assertRaises(verifier.ServedVerificationError):
            verifier.verify_served_origin(
                origin=self.origin,
                manifest=self.manifest,
                contract=self.contract,
                receipt=self.receipt,
                fetcher=fetcher,
            )
        self.assertEqual(fetcher.calls.count(self.origin + "/main.dart.js"), 1)

    def test_contract_is_exactly_five_308_same_origin_redirects(self) -> None:
        self.assertEqual(len(self.contract["redirect_only"]), 5)
        self.assertEqual(
            {item["status"] for item in self.contract["redirect_only"]},
            {308},
        )
        self.assertEqual(
            {item["request_path"] for item in self.contract["redirect_only"]},
            {
                "/index.html",
                "/delete-account.html",
                "/privacy.html",
                "/support.html",
                "/terms.html",
            },
        )

    def test_deployment_target_must_equal_sealed_site_origin(self) -> None:
        self.assertEqual(
            verifier.validate_deployment_target(
                receipt=self.receipt,
                project="example",
                branch="rc-198d9d4",
                alias_url=self.alias,
            ),
            self.alias,
        )
        with self.assertRaisesRegex(
            verifier.ServedVerificationError,
            "does not match the sealed artifact origin",
        ):
            verifier.validate_deployment_target(
                receipt=self.receipt,
                project="example",
                branch="different-preview",
            )

    def test_staging_cannot_target_production_branch(self) -> None:
        with self.assertRaisesRegex(
            verifier.ServedVerificationError,
            "staging artifact cannot target",
        ):
            verifier.validate_deployment_target(
                receipt=self.receipt,
                project="example",
                branch="production",
            )

    def test_staging_can_target_dedicated_rc_project_root(self) -> None:
        receipt = copy.deepcopy(self.receipt)
        receipt["site_origin"] = "https://kemet-rc.pages.dev"
        self.assertEqual(
            verifier.validate_deployment_target(
                receipt=receipt,
                project="kemet-rc",
                branch="production",
                alias_url="https://kemet-rc.pages.dev",
            ),
            "https://kemet-rc.pages.dev",
        )

    def test_immutable_origin_must_belong_to_declared_project(self) -> None:
        self.assertEqual(
            verifier.validate_immutable_project_origin(
                immutable_url="https://0123abcd.example.pages.dev",
                project="example",
                alias_url=self.alias,
            ),
            "https://0123abcd.example.pages.dev",
        )
        with self.assertRaisesRegex(
            verifier.ServedVerificationError,
            "8-lowercase-hex",
        ):
            verifier.validate_immutable_project_origin(
                immutable_url="https://0123abcd.other.pages.dev",
                project="example",
                alias_url=self.alias,
            )

    def test_mutable_or_malformed_pages_hosts_are_not_immutable(self) -> None:
        for invalid_url in (
            "https://main.example.pages.dev",
            "https://another-branch.example.pages.dev",
            "https://foo.0123abcd.example.pages.dev",
            "https://0123abc.example.pages.dev",
            "https://0123abcdef.example.pages.dev",
            "https://0123ABCD.example.pages.dev",
            "https://0123abcd.EXAMPLE.pages.dev",
            "https://user@0123abcd.example.pages.dev",
            "https://0123abcd.example.pages.dev:443",
        ):
            with self.subTest(invalid_url=invalid_url):
                with self.assertRaisesRegex(
                    verifier.ServedVerificationError,
                    "8-lowercase-hex",
                ):
                    verifier.validate_immutable_project_origin(
                        immutable_url=invalid_url,
                        project="example",
                        alias_url=self.alias,
                    )

    def test_pages_controls_match_exact_hashes_and_reject_external_rewrites(
        self,
    ) -> None:
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
                verifier.ServedVerificationError,
                "Unsafe or unsupported",
            ):
                verifier.validate_pages_controls(
                    release_dir=release_dir,
                    manifest=manifest,
                    contract=changed_contract,
                )

    def test_pages_control_hash_drift_fails_before_served_classification(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            release_dir = Path(temporary)
            (release_dir / "web").mkdir()
            (release_dir / "web/_headers").write_text("changed")
            (release_dir / "web/_redirects").write_text("/* /index.html 200\n")
            with self.assertRaisesRegex(
                verifier.ServedVerificationError,
                "Pages-control hash drifted",
            ):
                verifier.validate_pages_controls(
                    release_dir=release_dir,
                    manifest={
                        "web/_headers": hashlib.sha256(b"changed").hexdigest(),
                        "web/_redirects": hashlib.sha256(
                            b"/* /index.html 200\n"
                        ).hexdigest(),
                    },
                    contract=self.contract,
                )

    def test_wrangler_output_yields_one_non_alias_immutable_origin(self) -> None:
        result = verifier.extract_immutable_origin(
            upload_result=(
                "Deployment complete: "
                "https://0123abcd.kemet-autostab-20260714.pages.dev\n"
                "Alias: https://rc.kemet-autostab-20260714.pages.dev\n"
            ),
            project="kemet-autostab-20260714",
            alias_origin="https://rc.kemet-autostab-20260714.pages.dev",
        )
        self.assertEqual(
            result,
            "https://0123abcd.kemet-autostab-20260714.pages.dev",
        )

    def test_wrangler_output_rejects_aliases_and_nested_subdomains(self) -> None:
        for invalid_url in (
            "https://main.kemet-autostab-20260714.pages.dev",
            "https://other-branch.kemet-autostab-20260714.pages.dev",
            "https://foo.0123abcd.kemet-autostab-20260714.pages.dev",
            "https://0123ABCD.kemet-autostab-20260714.pages.dev",
            "https://0123abcd.KEMET-AUTOSTAB-20260714.pages.dev",
            "https://user@0123abcd.kemet-autostab-20260714.pages.dev",
            "https://0123abcd.kemet-autostab-20260714.pages.dev:443",
        ):
            with self.subTest(invalid_url=invalid_url):
                with self.assertRaisesRegex(
                    verifier.ServedVerificationError,
                    "found=\\[\\]",
                ):
                    verifier.extract_immutable_origin(
                        upload_result=f"Deployment complete: {invalid_url}\n",
                        project="kemet-autostab-20260714",
                        alias_origin=(
                            "https://rc.kemet-autostab-20260714.pages.dev"
                        ),
                    )


if __name__ == "__main__":
    unittest.main()
