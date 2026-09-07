# Connex Lab v0.1.5

UI, persistent controls, edit tools, axle placement, cross-rotation geometry, and procedural visual refinement.

### CREATE / EDIT separation
- added a top-bar `CREATE / EDIT` switch;
- CREATE taps only place parts and never rotate/select by accident;
- EDIT taps only select parts and never create something by accident;
- the selected EDIT target receives a vivid cyan emissive outline that remains visible on white connectors.

### Reorganized UI
- permanent top utility bar: CREATE/EDIT, Undo, Redo, Simulate/Build, Restore, Restart, Center, Options, Help;
- permanent bottom rod/connector palette with SOCKET / AXLE / CROSS mode;
- collapsible right rotation/edit panel;
- collapsible left movement/axle-slide panel;
- rounded dark panels, stronger visual hierarchy, consistent button states, and cleaner mobile spacing.

### Persistent Options
- new Options panel backed by `user://connex_settings.cfg`;
- reverse horizontal orbit;
- reverse vertical orbit;
- reverse horizontal pan;
- reverse vertical pan;
- camera sensitivity slider;
- build-grid visibility toggle;
- rotation/move panel collapsed state also persists;
- changes save immediately and survive app restarts.

### Rotation
- X, Y, and Z rotation are all available in both directions using 45° steps;
- explicit Mount-axis rotation added for the actual physical connection axis;
- Reset Rotation retained;
- failed rotations are transactional: if validation fails, transform/occupancy/joints are left untouched;
- this specifically avoids the intermittent state corruption seen after blocked rotations on highly symmetric 8-way connectors.

### Cross-mounted connector fix
- cross connectors now remember the rod and snap anchor that created the cross mount;
- rotation around the cross mount uses the host rod axis, not the connector's own hub axis;
- the connector centre orbits around the cross snap point while its basis rotates, keeping the snapped jaw on the rod;
- whichever local X/Y/Z axis is actually aligned with the cross rod can perform the rotation, while the dedicated Mount buttons always use the correct mount axis;
- invalid off-axis rotations are rejected without mutating the build.

### O-Ring Stop
- removed the separate O-Ring placement button;
- `O-Ring Stop` is now a normal choice in the connector palette;
- selecting it in CREATE and tapping an axle rod places the stop;
- the O-Ring outer diameter is smaller and more proportional to a real axle stop/spacer;
- O-Rings remain selectable, deletable, Undo/Redo-restorable, movable along their axle, and physical during simulation.

### Axle construction
- AXLE mode can still insert the selected rod through a connector hub;
- AXLE mode can now also place the selected connector onto an existing rod as a sliding axle connector;
- this works even when the rod is already connected into a larger construction;
- `Axle − / Axle +` in EDIT slides compatible rods/connectors along the actual axle axis;
- O-Ring Stops can be repositioned along their host axle with the same controls.

### Movement
- collapsible left EDIT panel adds camera-plane Forward/Back/Left/Right movement plus world Y+/Y−;
- fixed-connected pieces move as one rigid component so normal socket connections remain intact;
- generic movement is rejected when it would pull a component sideways through an axle;
- axle-aligned movement is handled by the dedicated Axle controls.

### Piece visuals
- rods now use a more K'NEX-like fluted/cross shaft profile;
- rod ends include narrower necks, stop collars, and flattened keyed locking tongues;
- connector hubs are thinner/open and include a raised axle collar;
- radial sockets use a clearer open two-jaw shape with mouth gap, tip rounding, and stop ridge;
- all geometry remains procedural; no copied third-party K'NEX meshes are included.

### Physics
- v0.1.4's stabilized simulation graph remains in use: redundant fixed cycles are suppressed for the simulation run and rigidly fixed components avoid internal self-collision;
- the first connector remains unpinned; all construction pieces use the same gravity rules;
- O-Ring Stops remain rigidly attached to their axle and physically block sliding connectors.

### APK signing
The attached APK is debug-signed for direct sideload/testing. It is not a Play Store production-signed package.
