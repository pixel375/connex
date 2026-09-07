# Connex Lab v0.2.0

Major interaction, placement, and connection-system rewrite.

### Persistent selected-piece workflow
- CREATE / EDIT modes are removed from the UI;
- the newest rod, connector, or O-Ring becomes selected automatically;
- selection remains on that piece until another piece is created or the user presses `Select` and taps one older piece;
- `Select` is a one-shot action and cancels immediately after a successful selection;
- normal construction taps do not silently change selection;
- rotation, movement, delete, axle slide, and compatible type edits act on the persistent selected piece.

### Explicit connection graph
- socket, cross, axle, and O-Ring connections are now stored as explicit graph records;
- socket records remember the exact connector socket and exact rod end instead of rediscovering them from the current transform;
- cross records remember the exact socket, host rod, and position along the host rod;
- axle records keep their real rod/hub relationship;
- automatic overlap fusion produces the same connection records as manual placement;
- occupancy is rebuilt from the connection graph so a socket that already contains a rod stays unavailable.

### Mount-relative rotation solver
- removed the old local X/Y/Z rotation workflow that could change meaning after each rotation;
- free/root assemblies use camera-relative Up / Down / Left / Right 45-degree rotation controls;
- mounted connectors use Roll left/right around the actual incoming socket rod, cross rod, or axle axis;
- the selected connector's fixed downstream branch moves with it around the chosen pivot instead of trying to rotate the connector while leaving every attached child rod behind;
- closed rigid loops are detected and block a pivot rotation rather than corrupting connection state;
- every connection is preview-validated before any transform changes;
- impossible rotation buttons are disabled before the user presses them;
- invalid rotation attempts are literal no-ops: no transform, connection, home orientation, joint frame, occupancy, auto-fuse, or Undo/Redo state changes;
- Reset Rotation returns to the connector's placement orientation through the same transactional solver.

### Placement upgrades
- manual socket placement records exact socket/end identity immediately;
- rod-end connector placement uses a stable mount frame aligned to the incoming rod;
- cross placement creates a connector plane that contains the host rod and records the real cross axis;
- AXLE can insert a rod through a connector or place a sliding connector on any existing rod, including rods already connected at their ends;
- O-Ring Stop remains in the connector list and is placed directly on axle rods;
- valid overlapping free rod ends and sockets are fused bidirectionally before every saved BUILD state and again before simulation;
- valid automatic cross overlaps are retained after rod-end/socket matching gets priority.

### UI / settings
- top bar now uses `Select`, Undo, Redo, Simulate, Restore, Restart, Center, Options, and Help;
- bottom rod/connector palette remains always visible;
- right rotation panel uses camera arrows plus explicit mount Roll and Reset Rotation;
- left movement panel remains collapsible;
- selected piece retains the strong cyan outline;
- persistent reverse orbit/pan controls, camera sensitivity, grid visibility, and collapsed panel state are retained.

### Simulation preflight
- the same explicit connection graph is rebuilt before physics;
- all joint frames are refreshed from the authoritative connection geometry before release;
- the existing stable-simulation pass still suppresses redundant closed-loop solver constraints and self-collision inside rigidly connected components.

### APK signing
The attached APK is debug-signed for direct sideload/testing. It is not a Play Store production-signed package.
