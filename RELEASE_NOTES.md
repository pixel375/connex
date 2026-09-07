# Connex Lab v0.1.3

Structural editing, camera, history, and connection-fidelity update.

### Connector editing
- the app starts immediately with the first connector visible in-world; there is no pre-build picker;
- the starting connector can be swapped with Conn ◀/▶ exactly like later connectors;
- tapping a connector hub rotates that specific connector 45° on its primary valid axis;
- Tilt 45° adds a second connector rotation axis;
- connector rotations and connector-type swaps are accepted only when every already-connected rod still maps to a real socket and any through-hub axle remains aligned;
- with one rod attached, primary rotation naturally rotates around that attached rod axis; structurally impossible tilts are rejected instead of breaking the model.

### Camera and workspace
- build platform expanded to 500 × 500 world units;
- camera zoom range expanded substantially;
- one-finger drag orbits;
- two-finger drag pans the camera target while pinch changes zoom;
- desktop right/middle drag also pans;
- Center View restores the starting camera position.

### Connections and auto-fuse
- occupied connector sockets can no longer redirect a tap into a neighboring free socket;
- a second rod is explicitly rejected when the chosen socket is occupied;
- a new rod whose free end lands on a compatible free socket automatically fuses to that existing connector;
- a free rod end placed onto an existing compatible connector fuses instead of creating a duplicate connector;
- newly placed connectors scan coincident free rod ends and valid 90° rod-body cross-snaps and create the missing structural joints;
- the same fuse pass runs before simulation so visually coincident valid geometry does not fall apart when physics starts.

### Physics
- rods and connectors again physically collide with otherwise-unconnected construction pieces while still colliding with the floor;
- each joint excludes collision only for its own connected pair, preventing the old hub self-collision explosions without making unrelated cross/axle pieces ghost through one another;
- this specifically restores physical contact between cross connections and nearby axle rods;
- velocities are still cleared and constraints are initialized while frozen before release.

### History and reset
- full-state Undo/Redo added;
- connector swaps, valid rotations, rod changes, placements, and automatic fuses are stored in build history;
- Restart returns to a single editable starting connector and clears the old build/history;
- Restore Pose remains separate from Restart and only returns a simulated build to its construction pose.

### APK signing
The attached APK is debug-signed for direct sideload/testing. It is not a Play Store production-signed package.
