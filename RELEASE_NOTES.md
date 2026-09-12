# Connex Lab v0.5.29

This release removes the large-construction Undo/Redo stall without giving back the instant placement improvements from v0.5.28. SIMULATE intentionally keeps its conservative whole-construction validation path; this release targets history restore only.

### Fast Undo/Redo history restore
- Common adjacent Undo/Redo operations now diff the current and target history snapshots instead of destroying and recreating the entire construction.
- Unchanged rods, connectors, meshes, colliders and joints are reused in place using their stable piece/connection IDs.
- A one-piece placement Undo removes only the added body and affected connection; Redo recreates only that body/connection.
- Transform/type/length history updates can reuse the existing body and only rebuild that piece when its actual geometry type changes.
- One authoritative connection-graph and editor refresh is performed after the history diff instead of repeating UI/highlight/ATTACH reconstruction throughout the inherited restore chain.
- Complex/legacy states and O-Ring topology changes retain the proven conservative full-restore fallback rather than sacrificing correctness for speed.

### Compatibility safeguards
- Reused bodies explicitly regain the normal BUILD collision layer/mask and current physics settings, matching the behavior previously obtained implicitly by reconstructing every body.
- The currently selected bottom Parts palette item remains transient UI state and is no longer changed by fast Undo/Redo.
- Pending visible-first placement bookkeeping is flushed before history navigation so Undo cannot race the deferred placement commit.
- Load/recovery behavior is unchanged; the fast path is limited to adjacent interactive history operations.

### Measured large-build performance
The v0.5.29 staging runtime was tested on the shared GitHub Actions runner with a 160-piece background construction plus the real placement target:
- Instant placement, 162 existing bodies: **2.46 ms** tap → real part created.
- Deferred placement finalize: **34.06 ms**.
- Undo after the placement: **43.32 ms total**, **7.94 ms history core**.
- Redo: **48.02 ms total**, **8.06 ms history core**.
- Undo preserved **162/162 unchanged body instances** and removed only the newly added body/connection.
- Redo preserved **162/162 unchanged body instances** and created only the missing body/connection.

The dedicated regression therefore verifies both latency and implementation behavior: it fails if unchanged construction bodies are secretly recreated even if the wall-clock timing happens to remain low.

### Preserved behavior
- v0.5.28 visible-first placement remains active and construction-size-resistant.
- The obsolete v0.1.7 duplicate whole-build auto-fuse scan remains retired from normal commits.
- Corrected O-Ring behavior is unchanged: simple CROSS-style mounting on the rod with its real physical collision stop for AXLE-mounted connectors.
- SOCKET, AXLE and CROSS topology/physics behavior is unchanged.
- Save/load topology, ATTACH selection/reconnect, rigidity, collision policy, updater behavior and palette-safe history remain covered by regressions.
- SIMULATE remains deliberately conservative and may still take longer on large constructions because it validates the complete build before physics starts.

### Regression coverage
The complete v0.5.29 staging suite passes, including editor, save/load, ATTACH, socket, CROSS, AXLE, rigidity, O-Ring, simulation, placement and large-history performance tests.
- O-Ring stability: **min_gap=0.292**, **mount_drift=0.056**.
- Moving-host O-Ring/AXLE stop: **min_gap=1.374**, **mount_drift=0.029**.
- General physics stability: **gap=0.016**, **radial=0.155**, **vmax=14.51**, **wmax=4.33**.
- 62-body visible placement regression: **1.49 ms**.
- 162-body visible placement regression: **2.46 ms**.

### Android
- versionCode: 53
- versionName: `0.5.29`
- package ID: `com.pixel375.connex`
- Permanent Connex signing certificate retained for in-place update compatibility.