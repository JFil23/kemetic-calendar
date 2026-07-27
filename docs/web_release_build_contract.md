# Web release build contract

## Authority

A release web artifact is determined by:

- exact parent commit and tree;
- exact mobile commit and tree, paired by the parent `mobile` gitlink;
- one tracked named public configuration;
- builder digest;
- dependency lockfile digest;
- normalized Flutter, engine, Dart, Python, Bash and platform identity.

The Flutter SDK checkout must be clean and its HEAD must equal the framework
revision reported by Flutter. The toolchain digest includes the SDK commit/tree,
the Dart executable, dart2js, Dart CLI, frontend-server and Flutter-tools
snapshots, const-finder and font-subset tools, the complete Dart SDK, host
engine, material-font, web and patched SDK trees, and the Bash, Git, Python and
tar executables. The Python runtime and standard-library tree used for
packaging are also bound; version labels alone are not treated as proof.

The supported environment names are `staging` and `production`. Environment
files, automatic config discovery and process-level client/identity overrides
are not release authorities.

The build ID is the SHA-256 of that canonical input tuple. The build timestamp
is the parent commit time in UTC, not the wall clock.

## Public configuration

`config/web/staging.public.json` and
`config/web/production.public.json` contain browser-public client identifiers
only. Their schema is closed: unknown fields fail the build. Service-role keys,
private keys, passwords, client secrets and database credentials fail
validation.

The staging and production configs currently use the same public Supabase,
Firebase and push-client values. Staging is a build/run-mode distinction, not
backend data isolation.

The production site authority is `https://kemet.pages.dev`. The staging site
authority is the owner-selected stable RC origin
`https://rc-198d9d4.kemet-autostab-20260714.pages.dev`.

PWA manifest and HTML identity are declared in both named configs and validated
against the tracked templates. The builder does not apply an undocumented RC
overlay.

## `.last_build_id`

Flutter 3.35.3 creates `build/web/.last_build_id` from its build-system
configuration identity, which includes the absolute output path. Flutter uses
the marker only to clean stale files when a later build reuses that output
directory.

No Kemet runtime, generated JavaScript, bootstrap, service worker or Pages
control file reads it. It is therefore:

- retained in the temporary raw `build/web` until Flutter is finished;
- included in the raw audit manifest;
- omitted exactly once when creating the immutable deployment payload;
- forbidden in the payload manifest and archive.

It is never rewritten to manufacture deterministic bytes.

`version.json` is runtime-visible and follows the opposite policy: it remains
in the payload and is generated deterministically.

## Packaging and upload

The builder first extracts exact tracked mobile `HEAD` into a fresh temporary
source tree and resolves the checksum-bound lockfile through the fixed official
package host into a fresh, internally owned package cache. Ambient Dart,
Flutter and Pub variables are rejected. Ignored and untracked source files
therefore cannot enter the build, and a pre-expanded external package cache
cannot supply compiler inputs. The resolved extraction's lockfile must remain
byte-identical to the recorded source lockfile. The builder revalidates
source/config/builder/lock/toolchain authority after compilation and before
packaging.

The deployment payload is staged separately from raw Flutter output under
`dist/web-releases/`, outside Flutter's cleanup target.
Directories and files are sorted; ownership, modes and timestamps are fixed;
gzip carries no filename or current timestamp; xattrs, symlinks and AppleDouble
entries are rejected.

The release directory contains:

- the staged `web/` root;
- `payload-manifest.sha256`;
- a deterministic `.tar.gz`;
- `release-receipt.json`.

The upload helper requires the externally authorized archive SHA-256, verifies
and extracts the archive, and uploads that exact root. It never rebuilds.
Its Wrangler version is fixed, but npm's transitive download integrity is not
part of this artifact-build proof; network upload remains a separately
authorized release operation.

## Evidence interpretation

The unrecorded RC manifest mutation found during reconstruction is a credible
contributor to installed-app identity confusion. It is not, by itself, proof
of why Safari chrome appeared; OAuth container changes, scope escape, wrong-icon
launch and embedded-browser entry remain separate possibilities.
