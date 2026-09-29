# Visible loading follow-up — September 29, 2026

Reference: ScreenRecording_09-29-2026 16-31-22_1.MP4, inspected in timed frames.
Served starting RC: 3a50346ea17b98d48cac4c1c39cb4ad9c7a9a630.

The prior persistence release did not establish the requested navigation
experience. This recording still shows a first Pages calendar load, Reminders
loading then failing, full-page flow detail spinners, and prolonged Reading
House Chat loading in landscape. The existing populated visuals remain the
contract; no geometry, typography, content, or five-flow extents are changed.

## Changes

- Owned filing pages use the backend-owned get_owned_filing_page_v1 RPC. It
  evaluates the existing security-invoker classification view over batches of
  raw candidate IDs, continuing until it has the requested classified page.
  It preserves ordering, offsets, date boundaries, RLS, deletion and all row
  fields. It does not classify locally or truncate coverage to one batch.
- House Chat uses the existing account-scoped bounded warm store for summaries
  and complete message pages. It restores before rendering when available,
  refreshes in the background, retains confirmed content on transient failures,
  removes it on explicit access denial, and fences departed-account responses.
  Passive warming does not mark messages read. Actual viewing retains read
  acknowledgement behavior without waiting for the acknowledgement to paint.
- Complete supplied share/post payloads seed the canonical detail immediately,
  avoiding a FutureBuilder loading frame despite already having the data.
- Primary Calendar projections resolve their required flows/visibility data
  instead of silently skipping the whole warm attempt when a sibling job has
  not completed. Flow detail jobs no longer stop at the first three flows or
  abort all subsequent flows when one read fails. Feed and own-post detail
  jobs are queued independently under the existing concurrency bound.
- Revisiting a collection retains its known rows immediately while restoring
  and refreshing, with the existing Notes date-boundary invalidation intact.

## Evidence before release

- Backend logs at the recording time contain filing SELECT timeouts and a
  get_calendar_flow_events_v2 timeout. These were real server failures.
- Transaction-rolled-back authenticated live tests of the new function:
  first Reminders page: 904 ms in one measured run; exact complete JSON matches
  for offsets 0 and 50 against the original view; current Notes page also
  matches; an unrelated principal returns zero rows.
- Local backend smoke covers page offsets 0, 50, 100, 150 and 250, authoritative
  view equivalence, another account, anonymous denial and security invoker.
- Backend source contracts: 71 passed.
- Focused app suite: 37 passed. Additional first-frame/room checks: 18 passed
  (overlapping counts). Full release gate and live replay remain required.

## Four laws and acceptance limits

The shared warm-state boundary is reused, not replaced. Reading House retains
its existing repository/controller and visual renderer; filing retains the
existing backend classification view. Existing visual references remain the
comparison target. The new recording, not passing unit tests, is the acceptance
reference. Cold data is still unknown until a successful read; this change does
not fabricate empty pages or claim that all latency is solved. The recorded
calendar hydration timeout remains a separate performance check: this patch
reduces competing filing work but does not rewrite the calendar RPC. Browser
replay and physical iOS timing must be distinguished in the release report.
