# Device-verified stability baseline

## Accepted source and artifact receipt

- Device-tested mobile source: `67f725fe2fd8f0ed43b65df510d8abdbc8377b53`
  (`fix: preserve drawer utility history`).
- Isolated preview build: `67f725f-drawer-history-short-iphone-20260717`.
- Isolated preview URL:
  `https://drawer-history-67f725f.kemet-autostab-20260714.pages.dev`.
- The served preview matched the locally recorded artifact:
  - `main.dart.js` SHA-256:
    `201b618e7142543109e10ea3791bb2069a114d295d25a4029ee2e87bdc9d2330`
  - `flutter_bootstrap.js` SHA-256:
    `f0bd649502456f941373694f43d10bdf3af05e106642e81f4f0535492bc5c8d6`
  - `index.html` SHA-256:
    `5d5ae321bef91badaa7ed3cb6c204138ed1608c21547620a8da7ae85813b65f3`
  - `version.json` SHA-256:
    `4e6afae936963e5162934940487558dcecffd02f57a2c70b0d8d4bf973cb2d60`
- Passing physical-iPhone recording SHA-256:
  `1d17f8ea826e4702c37ab0d5d167e84d0106f4e862ef3707e6832bdb63492f01`.

This receipt names only the public preview, source identity, and artifact
digests. It intentionally contains no backend URL, credential, generated
configuration, or deployment secret.

## Frozen interaction contract

- The drawer is opaque behind one translated foreground; its header, routed
  surface, and persistent `GlobalMenuBubble` move together.
- Drawer-row navigation is requested immediately and closes independently.
  A newer explicit drawer selection wins over every older callback.
- Calendar, Planner, Library, Journal, Inbox, Reflections, and Settings replace
  the primary base. Calendars, Flows, Profile, and later utility/detail routes
  push above that base. X pops only the top surface and exposes the same mounted
  underlying state.
- Valid base-plus-overlay history restores without an automatic Calendar reset.
  Planner remains termination-safe: its critical primary-route snapshot is
  durable before the route request.
- Calendar rendering, topology, viewport restoration, scrolling, and Today are
  frozen at Calendar baseline `6a0945f65b26702c8f68d5193d48d0875d749682`.
  Mounted Today remains one in-place viewport command, not a route rebuild.

Any runtime change to these contracts requires a new device gate. This baseline
hardening commit may change tests and documentation only.
