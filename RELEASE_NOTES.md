# Connex Lab v0.5.19

This release follows Android device testing of v0.5.18 and fixes three editor issues around ATTACH selection, Undo/Redo overlays, and CROSS placement on the 11-point/14-point spatial connector sockets.

### Precise ATTACH selection in crowded builds
Connector attachment points no longer use the oversized 72–108 px capture regions that could steal a tap from a nearby rod. ATTACH picking is now body-aware with a much tighter marker radius. In AXLE and CROSS modes, when the physical ray lands on a rod, that exact rod shaft wins over nearby connector markers and the tapped shaft position is used.

This keeps connector sockets easy to select while allowing rods that run close to dense connector clusters to remain selectable.

### Attachment points follow Undo/Redo immediately
Undo, Redo and snapshot restore now explicitly invalidate and rebuild both the attachment spatial index and the visible attachment-point overlay after transforms are restored. Green/orange ATTACH markers therefore move back with the construction immediately instead of remaining at the previous rotation until another click or editor action.

### Correct CROSS direction on 11/14-point top and bottom sockets
CROSS orientation is now based on the plane of the specific socket. The ordinary flat ring still places a CROSS rod perpendicular to the connector face. The top and bottom half-ring sockets on the 11-point and 14-point 3D connectors instead use the half-ring's own plane, so their CROSS rods run horizontally through those spatial sockets rather than incorrectly standing vertical.

The same socket-plane rule is used for direct CROSS creation, ATTACH snapping, validation, automatic CROSS detection, and saved connection rest geometry.

### Existing v0.5.18 fixes retained
Legacy AXLE save healing, midpoint CROSS rod insertion, BUILD-time CROSS rod sliding, physical O-Ring behavior, AXLE/CROSS stop collision behavior and save/load repair remain in place.

### Regression coverage
A new v0.5.19 gate verifies that a physical rod tap wins over nearby connector markers, Undo immediately rebuilds attachment points at the restored pose, ordinary planar CROSS placement remains correct, and both 11-point top and 14-point bottom spatial sockets use the proper horizontal CROSS direction. The legacy AXLE repair, midpoint CROSS slide, socket workflow, four-post AXLE/CROSS stop, O-Ring, closed-loop, rigidity and long-running physics regressions remain enabled.

### Android / update compatibility
- Android versionCode: 43
- Android versionName: `0.5.19`
- package ID: `com.pixel375.connex`
- permanent Connex signing certificate retained for in-place update compatibility.
