# Connex Lab v0.1.4

Selection, rotation controls, deletion, axle stops, and physics-stability update.

### Selection and connector controls
- tapping a connector body/hub now selects it instead of rotating it;
- the selected piece gets a bright outline/halo so the edit target is obvious;
- connector rotation moved to explicit `Rotate Y` and `Rotate X` buttons using local connector axes and 45° steps;
- `Reset Rotation` returns the selected connector to the orientation it had when first placed;
- all rotations and rotation resets still validate existing rod/socket directions and axle alignment before being accepted;
- in SOCKET mode, tapping an actual free outer socket still places a rod;
- AXLE mode now selects a connector first and uses a separate `Insert Axle` action, keeping connector body taps as selection gestures.

### O-Ring axle-stop connector
- added a physical `O-Ring Connector` intended for axle rods;
- press `Place O-Ring Connector`, then tap an existing axle rod at the desired position;
- the ring locks to that axle rod and physically prevents a sliding hub/axle connector from travelling past it during simulation;
- multiple O-rings can be placed on the same axle, including one on each side of a sliding connector;
- O-rings can be selected, highlighted, deleted, restored through Undo/Redo, and participate in simulation with the axle;
- placement is rejected on ordinary non-axle rods.

### Delete
- `Delete` removes the selected rod, connector, or O-ring axle stop;
- joints involving the deleted piece are removed;
- occupied connector sockets, rod ends, and axle-hub state are recalculated from the remaining graph so freed connection points become usable again;
- deleting the final main construction piece creates a new editable starting connector;
- delete operations are included in Undo/Redo history.

### Starting connector / gravity
- the starting connector is no longer pinned during simulation;
- every rod and connector, including the first piece, is released under the same gravity and rigid-body rules.

### Physics stability
The delayed shaking/explosion seen in closed and highly connected builds was traced to redundant rigid constraints plus internal collision impulses.

v0.1.4 changes the simulation graph before physics release:
- fixed-joint cycles are reduced to a spanning rigid graph, so redundant closed-loop fixed constraints do not fight each other;
- all bodies belonging to the same fixed rigid component ignore collision with each other, matching the behavior of one rigid assembly and preventing internal overlap impulses;
- axle joints that are already redundant because both endpoints belong to the same rigid component are suppressed for the simulation run;
- duplicate axle constraints between the same two rigid components are also suppressed;
- unrelated bodies and unrelated cross/axle pieces continue to collide physically;
- O-ring axle stops remain rigidly attached to their host axle and collide with sliding axle connectors as physical end-stops;
- all pieces are velocity-cleared and kept frozen for several physics frames while the stabilized graph initializes, then released simultaneously;
- returning to BUILD restores the full construction joint graph and original collision behavior.

This is intended to fix the pattern where a model looks correct for the first few seconds, then one rod begins to shake and the oscillation spreads until the entire model flies apart.

### APK signing
The attached APK is debug-signed for direct sideload/testing. It is not a Play Store production-signed package.
