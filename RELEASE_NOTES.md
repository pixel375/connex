# Connex Lab v0.5.28

This release changes BUILD placement from a synchronous "do everything, then draw" path into a visible-first pipeline. It specifically targets the remaining ~1 second placement delay reported on Android after v0.5.27 and keeps the perceived placement latency effectively independent of construction size.

### Instant visible-first placement
- The real rod, connector or O-Ring body and its direct joint are created immediately when the user taps.
- Android/Desktop then gets a rendered frame before history, targeted auto-connect reconciliation and the final editor UI refresh run.
- Undo/history correctness is preserved: the authoritative history commit still completes immediately after that first visible frame.
- Placement selection UI repaint is also deferred until after the first draw. Profiling showed this had become the largest remaining synchronous cost once the connection scans were removed.

### Large-build scaling changes
- Additive CREATE operations now maintain their new connection records incrementally instead of repeatedly rebuilding the entire connection graph.
- Redundant full graph rebuilds inside the create transaction are bypassed; destructive/topology-changing operations keep the conservative full rebuild path.
- Connector socket picking no longer rebuilds the entire connection graph merely to decide which visible socket was tapped.
- The targeted auto-connect cache updates only the newly created/selected part during additive placement instead of rescanning every body.
- The Parts browser does no placement-time card rebuild while its panel is closed.
- Delete, Disconnect, ATTACH reconnect, load/restore and SIMULATE retain their existing full validation/safety behavior.

### Measured placement latency
The exact v0.5.28 staging runtime was tested on the shared GitHub Actions runner using real connector-socket → rod creation:
- 62 existing bodies: **1.55 ms** tap → real part created.
- 162 existing bodies: **2.36 ms** tap → real part created.
- 162-body deferred finalize: **47.04 ms** total after the visible mutation.
  - history capture: 1.06 ms
  - targeted auto-connect: 3.27 ms
  - final UI refresh: 42.68 ms
- Five repeated placement calls completed in 3.64 ms total, with a worst individual placement of 0.94 ms.

The new regression requires the real new body to exist synchronously while history finalization is still pending, and tests this against a 160-piece background construction. This is deliberately different from the older benchmark that measured the entire synchronous commit path.

### Preserved behavior
- Corrected O-Ring behavior is unchanged: simple CROSS-style mounting on the rod with its real physical collision stop for AXLE-mounted connectors.
- SOCKET, AXLE and CROSS topology/physics behavior is unchanged.
- Immediate ATTACH-marker tracking remains intact; the old failed marker-throttling approach was not reintroduced.
- Saves remain newest-first, automatic/recovery saves remain capped at five, named saves remain unlimited, and autosave file work remains off the interactive UI thread.
- Update checking, Deselect behavior, save/load topology, Undo/Redo, rigidity and simulation behavior remain covered by the historical regressions.

### Regression coverage
- Full editor, save/load, ATTACH, socket, CROSS, AXLE, rigidity, O-Ring, simulation and performance regression suites pass on the v0.5.28 staging runtime.
- O-Ring stability regression: the mounted O-Ring stayed pinned and its real collider stopped the AXLE hub.
- Moving-host O-Ring regression: the physical O-Ring could not pass through a stationary AXLE hub.

### Android
- versionCode: 52
- versionName: `0.5.28`
- package ID: `com.pixel375.connex`
- Permanent Connex signing certificate retained for in-place update compatibility.