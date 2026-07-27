#!/usr/bin/env python3

from __future__ import annotations

import copy
import json
import os
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


class NamedConfigTest(unittest.TestCase):
    def test_named_public_configs_have_exact_schema(self) -> None:
        for environment in ("staging", "production"):
            with self.subTest(environment=environment):
                config = load_config(environment)
                pipeline.validate_named_config(config, environment=environment)
                pipeline.validate_source_web_identity(REPO_ROOT, config)

    def test_staging_and_production_share_only_backend_public_clients(self) -> None:
        staging = load_config("staging")
        production = load_config("production")

        runtime_differences = {
            key
            for key in pipeline.RUNTIME_KEYS
            if staging["runtime"][key] != production["runtime"][key]
        }
        self.assertEqual(runtime_differences, {"APP_ENV", "APP_SITE_URL"})
        self.assertEqual(staging["web"], production["web"])

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
        toolchain = {
            "flutter": {
                "frameworkVersion": "test",
                "frameworkRevision": "5" * 40,
                "engineRevision": "6" * 40,
                "dartSdkVersion": "test",
            },
            "python": "test",
            "bash": "test",
            "platform": "test",
        }
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
        toolchain = {
            "flutter": {"frameworkVersion": "test"},
            "python": "test",
            "bash": "test",
            "git": "test",
            "zlib_compile": "test",
            "zlib_runtime": "test",
            "platform": "test",
        }
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
        prepared = {
            "schema_version": 1,
            "environment": "staging",
            "build_id": "a" * 64,
            "build_version": "staging-test-aaaaaaaaaaaa",
            "build_timestamp": "2023-11-14T22:13:20Z",
            "source_epoch": 1_700_000_000,
            "source": {
                "parent_commit": "1" * 40,
                "parent_tree": "2" * 40,
                "parent_mobile_gitlink": "3" * 40,
                "mobile_commit": "3" * 40,
                "mobile_tree": "4" * 40,
                "source_epoch": 1_700_000_000,
            },
            "inputs": {
                "config_path": pipeline.ENVIRONMENT_CONFIGS["staging"],
                "config_sha256": "5" * 64,
                "runtime_env_sha256": pipeline.sha256_bytes(
                    pipeline.canonical_json_bytes(config["runtime"])
                ),
                "builder_files": list(pipeline.BUILDER_FILES),
                "builder_sha256": "6" * 64,
                "lockfile_path": "pubspec.lock",
                "lockfile_sha256": "7" * 64,
                "toolchain": {"test": True},
                "toolchain_sha256": "8" * 64,
            },
            "runtime": config["runtime"],
            "web": config["web"],
        }
        prepared["inputs"]["toolchain_sha256"] = pipeline.sha256_bytes(
            pipeline.canonical_json_bytes(prepared["inputs"]["toolchain"])
        )
        identity_inputs = {
            "schema_version": pipeline.SCHEMA_VERSION,
            "environment": prepared["environment"],
            "source": prepared["source"],
            "config_sha256": prepared["inputs"]["config_sha256"],
            "runtime_env_sha256": prepared["inputs"]["runtime_env_sha256"],
            "builder_sha256": prepared["inputs"]["builder_sha256"],
            "lockfile_sha256": prepared["inputs"]["lockfile_sha256"],
            "toolchain_sha256": prepared["inputs"]["toolchain_sha256"],
        }
        prepared["build_id"] = pipeline.sha256_bytes(
            pipeline.canonical_json_bytes(identity_inputs)
        )
        prepared["build_version"] = (
            f"staging-{prepared['source']['mobile_commit'][:7]}-"
            f"{prepared['build_id'][:12]}"
        )

        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            state = root / "state"
            pipeline.write_json(state / "prepared.json", prepared)
            pipeline.write_json(state / "runtime-env.json", config["runtime"])
            build_root = root / "source"
            authority_root = root / "authority"
            authority_root.mkdir()
            import shutil

            shutil.copytree(REPO_ROOT / "web", build_root / "web")
            raw = build_root / "build/web"
            raw.mkdir(parents=True)
            (raw / ".last_build_id").write_text(
                "1234567890abcdef1234567890abcdef",
                encoding="utf-8",
            )
            (raw / "manifest.json").write_text(
                json.dumps(config["web"]["manifest"]),
                encoding="utf-8",
            )
            index = (REPO_ROOT / "web/index.html").read_text(encoding="utf-8")
            (raw / "index.html").write_text(
                index.replace(
                    "{{flutter_service_worker_version}}",
                    "123",
                ),
                encoding="utf-8",
            )
            bootstrap = (
                REPO_ROOT / "web/flutter_bootstrap.js"
            ).read_text(encoding="utf-8")
            (raw / "flutter_bootstrap.js").write_text(
                bootstrap.replace(
                    "{{flutter_service_worker_version}}",
                    "123",
                ),
                encoding="utf-8",
            )
            pipeline.write_json(
                raw / "version.json",
                {
                    "app_name": "mobile",
                    "version": "1.0.0",
                    "build_number": "1",
                    "package_name": "mobile",
                },
            )

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
