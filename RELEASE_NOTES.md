# Connex Lab v0.5.18

This release follows real-device testing of an older build save and fixes a migration failure that v0.5.17 did not fully recover. It also adds the requested inverse CROSS workflow for putting a rod through a connector socket at the rod midpoint and sliding that rod in BUILD.

### Repair already-corrupted legacy AXLE saves
Some v0.5.16-and-earlier saves could lose the original AXLE identity before v0.5.17 ever saw them. In those files, an AXLE hub/shaft pair could already be stored or reconstructed as a fixed/socket relationship. That causes two visible symptoms: the AXLE does not slide in SIMULATE, and BUILD movement can be rejected with `a rod end would leave its exact socket` even though the rod is visibly passing through the connector hub as an AXLE.

v0.5.18 adds a legacy-only recovery path for saves that do not yet contain the modern stable-UID AXLE table. It recognizes the unambiguous AXLE geometry — connector hub centered on the rod axis, connector hub axis aligned with the rod, and matching rigid/joint context — removes the false direct fixed/socket joint, recreates one canonical AXLE, and recalculates occupancy and connection metadata. Modern v0.5.17+ saves with explicit AXLE identity are never guessed from geometry.

After a legacy save is healed, saving it again writes the recovered AXLE relationships into the explicit stable-UID AXLE table, so subsequent loads no longer depend on migration inference.

### CROSS rods through connector sockets
CROSS mode now works in both directions. The existing behavior of placing a connector crosswise onto a rod remains. In CREATE with CROSS selected, tapping a free connector socket now inserts the currently selected rod through that socket with the socket positioned at the rod midpoint.

This is stored as a real CROSS connection to the exact clicked socket, not as a rod-end SOCKET connection. The connector socket is marked occupied and the rod is selected immediately after placement.

### Slide CROSS rods in MOVE
A rod that is mounted through one CROSS socket can now be repositioned along its own shaft in BUILD. In MOVE, the ordinary XYZ gizmo is replaced for that rod by one `SLIDE` axis aligned with the rod and drawn beside it for easier dragging. Movement uses the existing 0.5-unit snap, moves only the rod while the connector stays fixed, keeps the socket on the usable rod length, and updates the CROSS joint anchor/host offset as the rod moves.

The connection remains an ordinary fixed CROSS joint during SIMULATE; the sliding behavior is an editing convenience, matching how the user positions a physical rod through a connector before running the simulation. Save/load preserves both the CROSS topology and the adjusted rod position.

### Regression coverage
The release gates now include a deliberately corrupted legacy-save regression that turns AXLE relationships into the same false fixed/socket state, verifies the bad exact-socket constraint is removed, verifies BUILD axle slide works again, and verifies the healed save persists explicit AXLE identity.

A second regression verifies CROSS + socket creates a midpoint rod, MOVE exposes the rod-axis slide gizmo beside it, dragging moves only the rod and updates the CROSS host offset, and the result survives save/load. The existing four-post AXLE/CROSS-stop regression is also retained, along with the prior O-Ring, closed-loop, rigidity, editor, and long-running physics tests.

### Android / update compatibility
- Android versionCode: 42
- Android versionName: `0.5.18`
- package ID: `com.pixel375.connex`
- permanent Connex signing certificate retained for in-place update compatibility.
