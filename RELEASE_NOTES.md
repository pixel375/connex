# Connex Lab v0.5.9

Camera-control and simulation-stability release following the v0.5.8 closed-loop SOCKET fix.

### Camera controls rebuilt
- one-finger drag now has one clear job: orbit;
- two-finger movement pans the view while pinch/spread zooms;
- when a second finger joins, control transfers cleanly to the two-finger gesture;
- after a two-finger gesture, the remaining finger stays inert until all fingers are lifted, preventing the common 2→1 handoff jump and accidental tap/selection;
- orbit sensitivity is viewport-relative instead of being tied to raw screen pixels, making the same gesture more consistent across phone/tablet resolutions;
- existing reverse-axis and camera-sensitivity settings remain supported;
- editor gizmo/tool drags retain priority over camera gestures.

### Delayed physics explosion fixed
The unstable behavior was not primarily a gravity/friction setting problem. The project still contained the legacy v0.1.4 workaround for an over-constrained fixed-joint graph. v0.5.8 had to restore real closed-loop SOCKET joints so visible connections did not open, but restoring the entire redundant 6DOF weld also restored the solver condition that could build energy over time and produce waving frames, jumping axles, spinning parts, and explosive motion.

v0.5.9 keeps the v0.5.8 physical-connection guarantee while changing how only redundant closed-loop SOCKET edges are represented during SIMULATE:
- every real SOCKET stays solver-active and positionally closed;
- the three redundant angular locks on a cycle-closing SOCKET are released during simulation;
- the rest of the rigid connection path continues to determine orientation;
- BUILD/Restore returns those sockets to their full authoritative fixed constraints;
- existing duplicate-axle suppression remains active.

### Regression guard retained
The v0.5.8 rule is permanent: a real closed-loop SOCKET must never be made non-physical merely to simplify the solver graph. GitHub issue #42 records this invariant for future physics work.

### Validation
- all previous editor/attachment regressions through v0.5.8 pass on the v0.5.9 runtime;
- a deterministic camera test verifies one-finger orbit, two-finger pan/zoom, and no 2→1 handoff jump;
- the v0.5.8 closed-loop test still verifies every real SOCKET remains active and closed;
- a new 420-physics-frame stress test runs a closed flat frame plus a horizontal axle assembly and watches socket separation, axle radial escape, and runaway velocity;
- validated stress-run maxima were 0.151 socket gap, 0.155 axle radial offset, 14.60 linear speed, and 5.97 angular speed, all below the instability guards.

### Signing / update compatibility
- Android versionCode is 33;
- Android versionName is `0.5.9`;
- package ID remains `com.pixel375.connex`;
- the existing permanent Connex signing certificate is retained for an in-place update over v0.5.8.
