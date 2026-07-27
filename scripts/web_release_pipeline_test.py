#!/usr/bin/env python3

from __future__ import annotations

import copy
import json
import os
import re
import shutil
import struct
import tempfile
import unittest
from pathlib import Path
from unittest import mock

import web_release_pipeline as pipeline


REPO_ROOT = Path(__file__).resolve().parent.parent


def load_config(environment: str) -> dict:
    return json.loads(
        (
            REPO_ROOT
            / pipeline.ENVIRONMENT_CONFIGS[environment]
        ).read_text(encoding="utf-8")
    )


def prepared_fixture(environment: str) -> dict:
    config = load_config(environment)
    toolchain = pinned_toolchain_fixture()
    source = {
        "parent_commit": "1" * 40,
        "parent_tree": "2" * 40,
        "parent_mobile_gitlink": "3" * 40,
        "mobile_commit": "3" * 40,
        "mobile_tree": "4" * 40,
        "source_epoch": 1_700_000_000,
    }
    inputs = {
        "config_path": pipeline.ENVIRONMENT_CONFIGS[environment],
        "config_sha256": pipeline.sha256_file(
            REPO_ROOT / pipeline.ENVIRONMENT_CONFIGS[environment]
        ),
        "runtime_env_sha256": pipeline.sha256_bytes(
            pipeline.canonical_json_bytes(config["runtime"])
        ),
        "icon_set": config["web"]["icon_set"],
        "icon_set_sha256": pipeline.icon_set_digest(REPO_ROOT, config["web"]),
        "builder_files": list(pipeline.BUILDER_FILES),
        "builder_sha256": "6" * 64,
        "lockfile_path": "pubspec.lock",
        "lockfile_sha256": "7" * 64,
        "toolchain": toolchain,
        "toolchain_sha256": pipeline.sha256_bytes(
            pipeline.canonical_json_bytes(toolchain)
        ),
    }
    identity_inputs = {
        "schema_version": pipeline.SCHEMA_VERSION,
        "environment": environment,
        "source": source,
        "config_sha256": inputs["config_sha256"],
        "runtime_env_sha256": inputs["runtime_env_sha256"],
        "icon_set_sha256": inputs["icon_set_sha256"],
        "builder_sha256": inputs["builder_sha256"],
        "lockfile_sha256": inputs["lockfile_sha256"],
        "toolchain_sha256": inputs["toolchain_sha256"],
    }
    build_id = pipeline.sha256_bytes(pipeline.canonical_json_bytes(identity_inputs))
    return {
        "schema_version": 1,
        "environment": environment,
        "build_id": build_id,
        "build_version": f"{environment}-3333333-{build_id[:12]}",
        "build_timestamp": "2023-11-14T22:13:20Z",
        "source_epoch": 1_700_000_000,
        "source": source,
        "inputs": inputs,
        "runtime": config["runtime"],
        "web": config["web"],
    }


def recompute_prepared_identity(prepared: dict) -> None:
    identity_inputs = {
        "schema_version": pipeline.SCHEMA_VERSION,
        "environment": prepared["environment"],
        "source": prepared["source"],
        "config_sha256": prepared["inputs"]["config_sha256"],
        "runtime_env_sha256": prepared["inputs"]["runtime_env_sha256"],
        "icon_set_sha256": prepared["inputs"]["icon_set_sha256"],
        "builder_sha256": prepared["inputs"]["builder_sha256"],
        "lockfile_sha256": prepared["inputs"]["lockfile_sha256"],
        "toolchain_sha256": prepared["inputs"]["toolchain_sha256"],
    }
    prepared["build_id"] = pipeline.sha256_bytes(
        pipeline.canonical_json_bytes(identity_inputs)
    )
    prepared["build_version"] = (
        f"{prepared['environment']}-3333333-{prepared['build_id'][:12]}"
    )


def pinned_toolchain_fixture() -> dict:
    policy = pipeline.PINNED_FLUTTER_TOOLCHAIN
    return {
        "flutter": {
            key: policy[key]
            for key in (
                "frameworkVersion",
                "channel",
                "repositoryUrl",
                "frameworkRevision",
                "engineRevision",
                "dartSdkVersion",
                "devToolsVersion",
            )
        },
        "flutter_sdk_commit": policy["flutter_sdk_commit"],
        "flutter_sdk_tree": policy["flutter_sdk_tree"],
        "python": "test",
        "bash": "test",
        "git": "test",
        "tar": "test",
        "zlib_compile": "test",
        "zlib_runtime": "test",
        "platform": "test",
    }


def create_fixture_release(
    root: Path,
    environment: str,
    *,
    prepared_mutator=None,
    source_mutator=None,
) -> Path:
    prepared = prepared_fixture(environment)
    if prepared_mutator is not None:
        prepared_mutator(prepared)
        recompute_prepared_identity(prepared)
    build_root = root / f"{environment}-source"
    state = root / f"{environment}-state"
    authority = root / f"{environment}-authority"
    authority.mkdir(parents=True)
    shutil.copytree(REPO_ROOT / "web", build_root / "web")
    shutil.copytree(REPO_ROOT / "config", build_root / "config")
    shutil.copyfile(REPO_ROOT / "pubspec.yaml", build_root / "pubspec.yaml")
    if source_mutator is not None:
        source_mutator(build_root)
    pipeline.write_json(state / "prepared.json", prepared)
    pipeline.write_json(state / "runtime-env.json", prepared["runtime"])
    pipeline.materialize_release_inputs(build_root=build_root, state_dir=state)
    raw = build_root / "build/web"
    shutil.copytree(build_root / "web", raw)
    (raw / ".last_build_id").write_text("a" * 32, encoding="utf-8")
    (raw / "main.dart.js").write_text(
        json.dumps(
            {
                "app_env": prepared["runtime"]["APP_ENV"],
                "site_origin": prepared["runtime"]["APP_SITE_URL"],
            },
            sort_keys=True,
        ),
        encoding="utf-8",
    )
    with mock.patch.object(
        pipeline,
        "compute_prepared_release",
        return_value=prepared,
    ):
        return pipeline.finalize_release(
            build_root=build_root,
            authority_root=authority,
            state_dir=state,
        )


class NamedConfigTest(unittest.TestCase):
    def test_named_public_configs_have_exact_schema(self) -> None:
        for environment in ("staging", "production"):
            with self.subTest(environment=environment):
                config = load_config(environment)
                pipeline.validate_named_config(config, environment=environment)
        pipeline.validate_source_web_identity(REPO_ROOT)

    def test_staging_and_production_share_only_backend_public_clients(self) -> None:
        staging = load_config("staging")
        production = load_config("production")

        runtime_differences = {
            key
            for key in pipeline.RUNTIME_KEYS
            if staging["runtime"][key] != production["runtime"][key]
        }
        self.assertEqual(runtime_differences, {"APP_ENV", "APP_SITE_URL"})
        self.assertEqual(staging["web"]["icon_set"], "staging")
        self.assertEqual(production["web"]["icon_set"], "production")
        self.assertEqual(
            staging["web"]["manifest"]["name"],
            "Kemet Release Candidate",
        )
        self.assertEqual(staging["web"]["manifest"]["short_name"], "Kemet RC")
        self.assertEqual(
            staging["web"]["html"]["apple_mobile_web_app_title"],
            "Kemet RC",
        )
        self.assertEqual(
            {
                key: value
                for key, value in staging["web"]["manifest"].items()
                if key not in {"name", "short_name"}
            },
            {
                key: value
                for key, value in production["web"]["manifest"].items()
                if key not in {"name", "short_name"}
            },
        )
        for key in ("id", "start_url", "scope"):
            self.assertEqual(staging["web"]["manifest"][key], "/")
            self.assertEqual(production["web"]["manifest"][key], "/")

    def test_tracked_rc_icons_are_distinct_and_dimensionally_exact(self) -> None:
        staging = load_config("staging")
        production = load_config("production")
        self.assertNotEqual(
            pipeline.icon_set_digest(REPO_ROOT, staging["web"]),
            pipeline.icon_set_digest(REPO_ROOT, production["web"]),
        )
        for name, expected_dimension in (
            ("Icon-192.png", 192),
            ("Icon-512.png", 512),
            ("Icon-maskable-192.png", 192),
            ("Icon-maskable-512.png", 512),
        ):
            path = REPO_ROOT / pipeline.ICON_SETS["staging"] / name
            body = path.read_bytes()
            self.assertEqual(body[:8], b"\x89PNG\r\n\x1a\n")
            width, height = struct.unpack(">II", body[16:24])
            self.assertEqual((width, height), (expected_dimension, expected_dimension))
            self.assertEqual(body[25], 6, "RC PNG must preserve an alpha channel")

    def test_unknown_config_field_is_rejected(self) -> None:
        config = load_config("staging")
        config["runtime"]["UNDECLARED"] = "value"
        with self.assertRaisesRegex(pipeline.ReleaseInputError, "unknown"):
            pipeline.validate_named_config(config, environment="staging")

    def test_private_credential_field_is_rejected(self) -> None:
        config = load_config("staging")
        config["runtime"]["DATABASE_PASSWORD"] = "not-allowed"
        with self.assertRaises(pipeline.ReleaseInputError):
            pipeline.validate_named_config(config, environment="staging")

    def test_service_role_value_is_rejected(self) -> None:
        config = load_config("staging")
        config["runtime"]["SUPABASE_ANON_KEY"] = "service_role_not_public_credential"
        with self.assertRaisesRegex(pipeline.ReleaseInputError, "sb_publishable_"):
            pipeline.validate_named_config(config, environment="staging")


class AmbientInputTest(unittest.TestCase):
    def test_unpinned_flutter_toolchain_is_rejected(self) -> None:
        toolchain = pinned_toolchain_fixture()
        toolchain["flutter"]["frameworkVersion"] = "3.99.0"
        with self.assertRaisesRegex(
            pipeline.ReleaseInputError,
            "left the pinned release authority",
        ):
            pipeline.require_pinned_flutter_toolchain(toolchain)

    def test_forbidden_ambient_inputs_are_rejected_by_name(self) -> None:
        forbidden = (
            "ENV_FILE",
            "SOURCE_DATE_EPOCH",
            "APP_SITE_URL",
            "APP_OTHER",
            "SUPABASE_URL",
            "SUPABASE_ANON_KEY",
            "FIREBASE_WEB_API_KEY",
            "WEB_BUILD_VERSION",
            "WEB_SOURCE_MAPS",
            "WEB_PUSH_PUBLIC_KEY",
            "WEB_MANIFEST_NAME",
            "PWA_ID",
            "PUB_CACHE",
            "PUB_HOSTED_URL",
            "FLUTTER_STORAGE_BASE_URL",
            "DART_VM_OPTIONS",
        )
        for name in forbidden:
            with self.subTest(name=name):
                with self.assertRaisesRegex(pipeline.ReleaseInputError, name):
                    pipeline.reject_forbidden_environment({name: "override"})

    def test_unrelated_ambient_input_is_ignored(self) -> None:
        pipeline.reject_forbidden_environment({"UNRELATED_NOISE": "one"})

    def test_prepared_identity_ignores_unrelated_ambient_values(self) -> None:
        source = {
            "parent_commit": "1" * 40,
            "parent_tree": "2" * 40,
            "parent_mobile_gitlink": "3" * 40,
            "mobile_commit": "3" * 40,
            "mobile_tree": "4" * 40,
            "source_epoch": 1_700_000_000,
        }
        toolchain = pinned_toolchain_fixture()
        with tempfile.TemporaryDirectory() as first, tempfile.TemporaryDirectory() as second:
            with (
                mock.patch.object(
                    pipeline,
                    "require_clean_paired_repositories",
                    return_value=source,
                ),
                mock.patch.object(
                    pipeline,
                    "normalized_toolchain",
                    return_value=toolchain,
                ),
            ):
                first_prepared = pipeline.prepare_release(
                    environment="staging",
                    repo_root=REPO_ROOT,
                    state_dir=Path(first),
                    environ={"UNRELATED_NOISE": "one"},
                )
                second_prepared = pipeline.prepare_release(
                    environment="staging",
                    repo_root=REPO_ROOT,
                    state_dir=Path(second),
                    environ={"UNRELATED_NOISE": "two"},
                )
        self.assertEqual(first_prepared["build_id"], second_prepared["build_id"])
        self.assertEqual(
            first_prepared["build_timestamp"],
            second_prepared["build_timestamp"],
        )

    def test_source_history_and_epoch_are_part_of_build_identity(self) -> None:
        base_source = {
            "parent_commit": "1" * 40,
            "parent_tree": "2" * 40,
            "parent_mobile_gitlink": "3" * 40,
            "mobile_commit": "3" * 40,
            "mobile_tree": "4" * 40,
            "source_epoch": 1_700_000_000,
        }
        changed_source = dict(base_source)
        changed_source["parent_commit"] = "9" * 40
        changed_source["source_epoch"] = 1_700_000_001
        toolchain = pinned_toolchain_fixture()
        with tempfile.TemporaryDirectory() as first, tempfile.TemporaryDirectory() as second:
            with mock.patch.object(
                pipeline,
                "normalized_toolchain",
                return_value=toolchain,
            ):
                with mock.patch.object(
                    pipeline,
                    "require_clean_paired_repositories",
                    return_value=base_source,
                ):
                    first_prepared = pipeline.prepare_release(
                        environment="staging",
                        repo_root=REPO_ROOT,
                        state_dir=Path(first),
                        environ={},
                    )
                with mock.patch.object(
                    pipeline,
                    "require_clean_paired_repositories",
                    return_value=changed_source,
                ):
                    second_prepared = pipeline.prepare_release(
                        environment="staging",
                        repo_root=REPO_ROOT,
                        state_dir=Path(second),
                        environ={},
                    )
        self.assertNotEqual(first_prepared["build_id"], second_prepared["build_id"])
        self.assertNotEqual(
            first_prepared["build_timestamp"],
            second_prepared["build_timestamp"],
        )


class BuildOrchestrationTest(unittest.TestCase):
    def test_builder_uses_clean_git_extraction_and_persistent_dist(self) -> None:
        build_script = (REPO_ROOT / "scripts/build_web_release.sh").read_text(
            encoding="utf-8"
        )
        pipeline_source = (
            REPO_ROOT / "scripts/web_release_pipeline.py"
        ).read_text(encoding="utf-8")
        self.assertIn("git archive --format=tar HEAD", build_script)
        self.assertNotIn("flutter clean", build_script)
        self.assertLess(
            build_script.index("web_release_pipeline.py materialize"),
            build_script.index('flutter build "${build_args[@]}"'),
        )
        self.assertIn('PUB_CACHE="$STATE_DIR/pub-cache"', build_script)
        self.assertIn('PUB_HOSTED_URL="https://pub.dev"', build_script)
        self.assertIn("verify-lockfile", build_script)
        self.assertIn("dist/web-releases", pipeline_source)
        self.assertIn("require_prepared_current", pipeline_source)
        self.assertIn("flutter_tools_snapshot", pipeline_source)
        self.assertIn('"const_finder_snapshot"', pipeline_source)
        self.assertIn('"font_subset"', pipeline_source)
        self.assertIn('"dart_sdk": sha256_tree', pipeline_source)
        self.assertIn('"python_stdlib": sha256_tree', pipeline_source)
        self.assertIn('"host_executables"', pipeline_source)
        finalize_source = pipeline_source.split("def finalize_release(", 1)[1].split(
            "def parse_manifest(", 1
        )[0]
        self.assertNotIn("inject_build_version(raw_root", finalize_source)
        self.assertNotIn("write_json(raw_root", finalize_source)
        self.assertNotIn("shutil.copyfile(source, raw_root", finalize_source)
        self.assertIn("require_compiled_web_matches_materialization", finalize_source)

    def test_deployment_flow_requires_both_served_verifications(self) -> None:
        deploy = (
            REPO_ROOT / "scripts/deploy_cloudflare_pages.sh"
        ).read_text(encoding="utf-8")
        self.assertIn("served_artifact_verifier.py verify", deploy)
        self.assertIn("served_artifact_verifier.py preflight-target", deploy)
        self.assertLess(
            deploy.index("served_artifact_verifier.py preflight-target"),
            deploy.index('"${CMD[@]}"'),
        )
        self.assertIn("--immutable-url", deploy)
        self.assertIn("--alias-url", deploy)
        self.assertIn("record-upload-attempt", deploy)
        self.assertLess(
            deploy.index("record-upload-attempt"),
            deploy.index('if [[ "$WRANGLER_STATUS" -ne 0 ]]'),
        )
        self.assertIn("web-deployment-receipts", deploy)
        self.assertNotIn('SERVED_RECEIPT="$RELEASE_DIR/', deploy)
        self.assertNotIn("retry", deploy.lower())

    def test_pinned_flutter_copies_materialized_version_after_generation(self) -> None:
        pipeline.verify_flutter_web_version_override_contract()

    def test_finalize_rejects_changed_prepared_authority(self) -> None:
        prepared = {
            "environment": "staging",
            "runtime": {"sentinel": "before"},
        }
        changed = copy.deepcopy(prepared)
        changed["runtime"]["sentinel"] = "after"
        with tempfile.TemporaryDirectory() as temporary:
            state = Path(temporary)
            pipeline.write_json(state / "runtime-env.json", prepared["runtime"])
            with mock.patch.object(
                pipeline,
                "compute_prepared_release",
                return_value=changed,
            ):
                with self.assertRaisesRegex(
                    pipeline.ReleaseInputError,
                    "changed between preparation and finalization",
                ):
                    pipeline.require_prepared_current(
                        authority_root=REPO_ROOT,
                        state_dir=state,
                        prepared=prepared,
                    )


class PreCompilationMaterializationTest(unittest.TestCase):
    def _fixture(self, environment: str):
        temporary = tempfile.TemporaryDirectory()
        root = Path(temporary.name)
        build_root = root / "source"
        state = root / "state"
        shutil.copytree(REPO_ROOT / "web", build_root / "web")
        shutil.copytree(REPO_ROOT / "config", build_root / "config")
        shutil.copyfile(REPO_ROOT / "pubspec.yaml", build_root / "pubspec.yaml")
        prepared = prepared_fixture(environment)
        pipeline.write_json(state / "prepared.json", prepared)
        pipeline.write_json(state / "runtime-env.json", prepared["runtime"])
        return temporary, build_root, state, prepared

    def test_staging_identity_is_fully_materialized_before_flutter(self) -> None:
        temporary, build_root, state, prepared = self._fixture("staging")
        self.addCleanup(temporary.cleanup)

        record = pipeline.materialize_release_inputs(
            build_root=build_root,
            state_dir=state,
        )

        manifest = pipeline.load_json(build_root / "web/manifest.json")
        self.assertEqual(manifest["name"], "Kemet Release Candidate")
        self.assertEqual(manifest["short_name"], "Kemet RC")
        self.assertEqual(
            (manifest["id"], manifest["start_url"], manifest["scope"]),
            ("/", "/", "/"),
        )
        index = (build_root / "web/index.html").read_text(encoding="utf-8")
        self.assertIn("<title>Kemet Release Candidate</title>", index)
        self.assertIn(
            'name="apple-mobile-web-app-title" content="Kemet RC"',
            index,
        )
        self.assertNotIn("{{flutter_service_worker_version}}", index)
        self.assertIn(prepared["build_version"], index)
        version = pipeline.load_json(build_root / "web/version.json")
        self.assertEqual(version["build_id"], prepared["build_id"])
        self.assertEqual(version["inputs"]["icon_set"], "staging")
        self.assertEqual(version["app_name"], "mobile")
        self.assertEqual(version["version"], "1.0.0")
        self.assertEqual(version["build_number"], "1")
        self.assertEqual(
            pipeline.icon_body_digest(
                [
                    build_root / "web/icons" / name
                    for name in pipeline.ICON_PATHS
                ]
            ),
            prepared["inputs"]["icon_set_sha256"],
        )
        self.assertIn("version.json", record["runtime_affecting_paths"])
        self.assertEqual(
            record["web_input_file_count"],
            len(record["web_input_manifest"]),
        )

    def test_compiled_output_must_preserve_materialized_web_inputs(self) -> None:
        temporary, build_root, state, _ = self._fixture("production")
        self.addCleanup(temporary.cleanup)
        pipeline.materialize_release_inputs(build_root=build_root, state_dir=state)
        raw = build_root / "build/web"
        shutil.copytree(build_root / "web", raw)
        (raw / "env.json").write_text('{"tampered":true}\n', encoding="utf-8")

        with self.assertRaisesRegex(
            pipeline.ReleaseInputError,
            "diverged from pre-compilation web inputs",
        ):
            pipeline.require_compiled_web_matches_materialization(
                raw_root=raw,
                state_dir=state,
            )

    def test_environment_delta_allowlist_is_closed_and_routing_safe(self) -> None:
        contract = pipeline.load_json(
            REPO_ROOT / "config/web/environment-delta-contract.v1.json"
        )
        self.assertEqual(
            contract["manifest_fields"],
            ["name", "short_name"],
        )
        self.assertEqual(
            contract["required_fixed_values"],
            {
                "display": "standalone",
                "id": "/",
                "scope": "/",
                "start_url": "/",
            },
        )
        self.assertEqual(
            set(contract["icon_body_paths"]),
            {f"web/icons/{name}" for name in pipeline.ICON_PATHS},
        )


class EnvironmentDeltaValidationTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.temporary = tempfile.TemporaryDirectory()
        cls.root = Path(cls.temporary.name)
        cls.staging = create_fixture_release(cls.root / "base", "staging")
        cls.production = create_fixture_release(cls.root / "base", "production")
        cls.contract_path = (
            REPO_ROOT / "config/web/environment-delta-contract.v1.json"
        )

    @classmethod
    def tearDownClass(cls) -> None:
        cls.temporary.cleanup()

    def test_exact_structural_environment_delta_passes(self) -> None:
        result = pipeline.validate_environment_delta(
            self.staging,
            self.production,
            contract_path=self.contract_path,
        )
        self.assertEqual(result["unexplained_differences"], [])
        self.assertEqual(
            result["release_receipt_differences"],
            sorted(
                pipeline.load_json(self.contract_path)["release_receipt_fields"]
            ),
        )
        self.assertEqual(
            result["version_receipt_differences"],
            sorted(pipeline.load_json(self.contract_path)["version_receipt_fields"]),
        )

    def test_cross_source_release_receipt_is_rejected(self) -> None:
        def change_source(prepared: dict) -> None:
            prepared["source"]["parent_commit"] = "9" * 40

        production = create_fixture_release(
            self.root / "cross-source",
            "production",
            prepared_mutator=change_source,
        )
        with self.assertRaisesRegex(
            pipeline.ReleaseInputError,
            "Release-receipt environment delta drifted",
        ):
            pipeline.validate_environment_delta(
                self.staging,
                production,
                contract_path=self.contract_path,
            )

    def test_common_version_receipt_field_drift_is_rejected(self) -> None:
        def change_package_version(build_root: Path) -> None:
            pubspec = build_root / "pubspec.yaml"
            content = pubspec.read_text(encoding="utf-8")
            pubspec.write_text(
                re.sub(
                    r"(?m)^version:\s*.+$",
                    "version: 9.9.9+9",
                    content,
                    count=1,
                ),
                encoding="utf-8",
            )

        production = create_fixture_release(
            self.root / "version-drift",
            "production",
            source_mutator=change_package_version,
        )
        with self.assertRaisesRegex(
            pipeline.ReleaseInputError,
            "Version-receipt environment delta drifted",
        ):
            pipeline.validate_environment_delta(
                self.staging,
                production,
                contract_path=self.contract_path,
            )

    def test_extra_deployable_body_difference_is_rejected(self) -> None:
        def change_install_script(build_root: Path) -> None:
            path = build_root / "web/install.js"
            path.write_text(
                path.read_text(encoding="utf-8") + "\n// unexplained\n",
                encoding="utf-8",
            )

        production = create_fixture_release(
            self.root / "body-drift",
            "production",
            source_mutator=change_install_script,
        )
        with self.assertRaisesRegex(
            pipeline.ReleaseInputError,
            "deployable delta is unexplained",
        ):
            pipeline.validate_environment_delta(
                self.staging,
                production,
                contract_path=self.contract_path,
            )

    def test_tampered_archive_is_rejected_before_comparison(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            production = Path(temporary) / "production"
            shutil.copytree(self.production, production)
            receipt = pipeline.load_json(production / "release-receipt.json")
            archive = production / receipt["payload"]["archive_file"]
            with archive.open("ab") as handle:
                handle.write(b"tampered")
            with self.assertRaisesRegex(
                pipeline.ReleaseInputError,
                "Archive hash does not match",
            ):
                pipeline.validate_environment_delta(
                    self.staging,
                    production,
                    contract_path=self.contract_path,
                )

    def test_staged_web_tree_tamper_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            production = Path(temporary) / "production"
            shutil.copytree(self.production, production)
            (production / "web/_redirects").write_text(
                "/* /different.html 200\n",
                encoding="utf-8",
            )
            with self.assertRaisesRegex(
                pipeline.ReleaseInputError,
                "Staged payload does not match manifest",
            ):
                pipeline.verify_release(production)

    def test_reason_vocabulary_is_closed_and_path_bound(self) -> None:
        contract = pipeline.load_json(self.contract_path)
        with tempfile.TemporaryDirectory() as temporary:
            contract_path = Path(temporary) / "contract.json"
            unknown = copy.deepcopy(contract)
            unknown["deployable_body_paths"]["web/env.json"].append("unknown")
            pipeline.write_json(contract_path, unknown)
            with self.assertRaisesRegex(
                pipeline.ReleaseInputError,
                "unknown reasons",
            ):
                pipeline.validate_environment_delta(
                    self.staging,
                    self.production,
                    contract_path=contract_path,
                )

            duplicate = copy.deepcopy(contract)
            duplicate["deployable_body_paths"]["web/env.json"].append(
                "runtime.APP_ENV"
            )
            pipeline.write_json(contract_path, duplicate)
            with self.assertRaisesRegex(
                pipeline.ReleaseInputError,
                "nonempty unique string list",
            ):
                pipeline.validate_environment_delta(
                    self.staging,
                    self.production,
                    contract_path=contract_path,
                )

            inaccurate = copy.deepcopy(contract)
            inaccurate["reason_bindings"]["manifest.name"] = ["web/index.html"]
            pipeline.write_json(contract_path, inaccurate)
            with self.assertRaisesRegex(
                pipeline.ReleaseInputError,
                "reason-to-body bindings drifted",
            ):
                pipeline.validate_environment_delta(
                    self.staging,
                    self.production,
                    contract_path=contract_path,
                )


class PayloadPolicyTest(unittest.TestCase):
    def test_last_build_id_is_the_only_declared_omission(self) -> None:
        self.assertEqual(pipeline.DEPLOYMENT_OMISSIONS, (".last_build_id",))

    def test_payload_copy_omits_marker_and_preserves_well_known(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            raw = root / "raw"
            payload = root / "payload"
            (raw / ".well-known").mkdir(parents=True)
            (raw / ".last_build_id").write_text("build-tool-state", encoding="utf-8")
            (raw / ".well-known/assetlinks.json").write_text("{}", encoding="utf-8")
            (raw / "index.html").write_text("index", encoding="utf-8")

            omissions = pipeline.copy_deployment_payload(raw, payload)

            self.assertEqual(omissions, [".last_build_id"])
            self.assertFalse((payload / ".last_build_id").exists())
            self.assertTrue((payload / ".well-known/assetlinks.json").is_file())

    def test_deterministic_archives_ignore_source_mtimes(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            first = root / "first"
            second = root / "second"
            first.mkdir()
            second.mkdir()
            for payload in (first, second):
                (payload / "nested").mkdir()
                (payload / "index.html").write_text("same", encoding="utf-8")
                (payload / "nested/value.json").write_text('{"same":true}\n', encoding="utf-8")
            os.utime(first / "index.html", (1, 1))
            os.utime(second / "index.html", (2, 2))
            first_archive = root / "first.tar.gz"
            second_archive = root / "second.tar.gz"

            pipeline.create_deterministic_archive(first, first_archive, epoch=123)
            pipeline.create_deterministic_archive(second, second_archive, epoch=123)

            self.assertEqual(
                pipeline.sha256_file(first_archive),
                pipeline.sha256_file(second_archive),
            )

    def test_finalize_and_verify_exclude_marker(self) -> None:
        config = load_config("staging")
        prepared = prepared_fixture("staging")

        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            state = root / "state"
            pipeline.write_json(state / "prepared.json", prepared)
            pipeline.write_json(state / "runtime-env.json", config["runtime"])
            build_root = root / "source"
            authority_root = root / "authority"
            authority_root.mkdir()
            shutil.copytree(REPO_ROOT / "web", build_root / "web")
            shutil.copytree(REPO_ROOT / "config", build_root / "config")
            shutil.copyfile(REPO_ROOT / "pubspec.yaml", build_root / "pubspec.yaml")
            pipeline.materialize_release_inputs(
                build_root=build_root,
                state_dir=state,
            )
            raw = build_root / "build/web"
            shutil.copytree(build_root / "web", raw)
            (raw / ".last_build_id").write_text(
                "1234567890abcdef1234567890abcdef",
                encoding="utf-8",
            )
            (raw / "main.dart.js").write_text("compiled", encoding="utf-8")

            with mock.patch.object(
                pipeline,
                "compute_prepared_release",
                return_value=prepared,
            ):
                release_dir = pipeline.finalize_release(
                    build_root=build_root,
                    authority_root=authority_root,
                    state_dir=state,
                )
                receipt = pipeline.verify_release(release_dir)

            self.assertEqual(
                receipt["payload"]["omitted_raw_build_files"],
                [".last_build_id"],
            )
            self.assertFalse((release_dir / "web/.last_build_id").exists())
            self.assertIn("dist/web-releases", release_dir.as_posix())

            receipt_path = release_dir / "release-receipt.json"
            mixed_receipt = json.loads(receipt_path.read_text(encoding="utf-8"))
            mixed_receipt["build_version"] = "mixed-sidecar-identity"
            pipeline.write_json(receipt_path, mixed_receipt)
            with self.assertRaisesRegex(
                pipeline.ReleaseInputError,
                "Release build_version is inconsistent",
            ):
                pipeline.verify_release(release_dir)


if __name__ == "__main__":
    unittest.main()
