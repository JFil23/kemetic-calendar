# Web release build contract

## Authority

A release web artifact is determined by:

- exact parent commit and tree;
- exact mobile commit and tree, paired by the parent `mobile` gitlink;
- one tracked named public configuration;
- one tracked environment-specific icon set and its digest;
- builder digest;
- dependency lockfile digest;
- normalized Flutter, engine, Dart, Python, Bash and platform identity.

The Flutter/Dart compiler authority is pinned to Flutter 3.35.3, Dart 3.9.2,
framework revision `a402d9a4376add5bc2d6b1e33e53edaae58c07f8` and engine
revision `ddf47dd3ff96dbde6d9c614db0d7f019d7c7a2b7`. A different
reported version, revision, SDK commit or SDK tree fails before compilation.
The Flutter SDK checkout must be clean and its HEAD must equal the framework
revision reported by Flutter. The complete toolchain digest includes the SDK commit/tree,
the Dart executable, dart2js, Dart CLI, frontend-server and Flutter-tools
snapshots, const-finder and font-subset tools, the complete Dart SDK, host
engine, material-font, web and patched SDK trees, and the Bash, Git, Python and
tar executables. The Python runtime and standard-library tree used for
packaging are also bound; version labels alone are not treated as proof.

The supported environment names are `staging` and `production`. Environment
files, automatic config discovery and process-level client/identity overrides
are not release authorities.

The build ID is the SHA-256 of that canonical input tuple, including the
selected icon-set digest. The build timestamp is the parent commit time in UTC,
not the wall clock.

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
`https://kemet-rc.pages.dev`.

`kemet-rc` is the dedicated staging Pages project. Its root branch may receive
only sealed staging artifacts whose named `APP_SITE_URL` is exactly that origin;
the production `kemet` project remains ineligible for staging artifacts. The
runtime `version.json` receipt is the authority for actual source,
configuration, toolchain and build identity.

Production retains the `Kemetic Calendar` / `ḥꜣw` installation identity and
canonical production icons. Staging materializes `Kemet Release Candidate` /
`Kemet RC` and a separately tracked, visibly distinct RC icon set. Both retain
`id`, `start_url` and `scope` as `/`, with identical standalone/display and
routing semantics. The same public Supabase, Firebase and push configuration is
currently shared, so staging is isolated by origin, browser storage, service
worker and artifact identity—not by backend data.

PWA manifest, HTML/Apple title, icons, runtime `env.json`, build-version
literals and deterministic `version.json` are materialized inside the fresh
tracked-source extraction before Flutter compilation. The finalizer validates
Flutter output, audits/omits `.last_build_id`, creates manifests and packages;
it never patches runtime/PWA payload bytes after compilation.

The versioned environment-delta contract names every permitted changed
deployable body and every permitted field difference in the outer release
receipt and runtime `version.json`. It requires source/tree/gitlink,
build timestamp, builder, lockfile, compiler/toolchain, payload population,
routing/scope fields and every other common field to remain equal. The
staging/production comparison verifies both sealed archives first and rejects
unknown, empty, duplicate or incorrectly bound delta reasons.

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
source tree, materializes the named pre-compilation web inputs, and resolves the
checksum-bound lockfile through the fixed official package host into a fresh,
internally owned package cache. Ambient Dart, Flutter and Pub variables are
rejected. Ignored and untracked source files therefore cannot enter the build,
and a pre-expanded external package cache cannot supply compiler inputs. The
resolved extraction's lockfile must remain byte-identical to the recorded
source lockfile. The builder revalidates source/config/icon/builder/lock/
toolchain authority after compilation and before packaging.

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

The upload helper requires the externally authorized archive SHA-256 and
validates the requested project/branch against the sealed `site_origin` before
Wrangler can run. It verifies and extracts the archive, and uploads that exact
root. It never rebuilds.
After Wrangler succeeds, the helper must verify both the immutable deployment
and stable alias against the local payload. Every retrievable body must match
its manifest hash. `_headers` and `_redirects` are Pages controls. Exactly five
versioned clean-URL redirects are allowed and must return HTTP 308 to their
same-origin canonical destinations. Any missing body, stale alias, unexpected
redirect, origin escape, identity mismatch or classification drift fails
closed without retry, rebuild, redeploy, promotion or rollback. The Wrangler
version is fixed, but npm's transitive download integrity is not part of this
artifact-build proof; network upload remains a separately authorized release
operation.

The exact `_headers` and `_redirects` bodies are hash-bound by the served
contract. Every tracked `_redirects` rule is parsed as a same-origin HTTP 200
rewrite; external destinations, unsupported statuses, duplicates or malformed
rules fail before upload. The immutable hostname must use Cloudflare Pages'
exact deployment shape: one eight-character lowercase hexadecimal deployment
label before the declared project's `pages.dev` hostname. Mutable branch
aliases and nested subdomains are rejected. Upload logs, attempt receipts and
served-verification logs are preserved in a sibling
`web-deployment-receipts/` directory on both success and failure, so deployment
evidence never mutates the sealed release directory.
Each deployment receipt binds the verifier, deploy helper and served-contract
hashes used for that attempt.

## Evidence interpretation

The unrecorded RC manifest mutation found during reconstruction is a credible
contributor to installed-app identity confusion. It is not, by itself, proof
of why Safari chrome appeared; OAuth container changes, scope escape, wrong-icon
launch and embedded-browser entry remain separate possibilities.
