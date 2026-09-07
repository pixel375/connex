# Connex Lab v0.1.2

Device-test stability and interaction correction.

### Fixed
- camera now starts above the build instead of below the floor;
- camera orbit is constrained so it cannot drop underneath the ground plane and hide the model;
- connector/rod materials are double-sided for safer viewing angles;
- one touchscreen tap can no longer fire both touch and emulated-mouse world input, fixing the duplicate-rod placement bug;
- an additional short tap debounce prevents accidental duplicate world placements;
- Rotate no longer changes any future connector orientation.

### Rotate Last behavior
- Rotate targets only the most recently placed connector;
- newly attached connectors begin at 0° and can be rotated afterward in 45° steps;
- selecting a different rod or connector does not change the Rotate target;
- rotation locks when extra rods would make the edit structurally unsafe.

### Starting piece
- a startup panel now lets the user choose either a connector or rod as the first piece;
- the starting connector/rod type can be selected before building;
- the starting piece can be rotated in 45° steps before placement;
- the chosen starting piece becomes the anchored root for simulation.

### Simulation stability
- rods/connectors now collide with the ground but not with each other, avoiding large overlapping self-collision impulses around connector hubs;
- rigid-body velocities are cleared before simulation starts;
- joint frames are rebound to the current edited build pose before release;
- physics release is delayed by one physics frame so constraints initialize while all pieces are still frozen.

### APK signing
The attached APK is debug-signed for direct sideload/testing. It is not a Play Store production-signed package.
