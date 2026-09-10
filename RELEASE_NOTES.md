# Connex Lab v0.5.14

Focused corrective release for the O-Ring Stop regression introduced in v0.5.13. Camera and editor geometry behavior are intentionally unchanged.

### O-Ring Stops are physical rod-mounted stops again
v0.5.13 made O-Rings follow their host rod visually, but copied their stopper collision onto that same rod. AXLE joints intentionally exclude collision between the mounted connector and its axle rod, so an axle connector could pass through the copied stopper. Other attached pieces could still strike the proxy shape, which could inject the violent impulses seen in the device video.

v0.5.14 removes the proxy system and restores the simpler behavior used by the older implementation. An O-Ring is once again a real collision body fixed directly to its host rod. The fixed mount excludes only O-Ring-versus-host-rod self-collision. The normal AXLE joint is left completely alone: longitudinal sliding and axle rotation remain free until the connector physically reaches the O-Ring.

Because the O-Ring is physically mounted to the rod, it follows the rod when the rod falls, rotates or moves. The same contact also prevents the inverse failure case where the rod tries to fall through the hole in an axle connector. In BUILD, the O-Ring remains an editable rod-mounted part.

No host-rod collision proxy, moving proxy body, replacement AXLE joint, or artificial AXLE travel limit is used.

### Impact stability
O-Rings remain ordinary dynamic construction pieces during SIMULATE and use their existing fixed mount to the rod. Continuous collision detection is enabled for the physical O-Ring during simulation so the thin stopper is less likely to tunnel during a fast impact. Existing construction stability settings and the emergency runaway guard remain unchanged.

### Validation
The regression suite covers all retained behavior from v0.5.2 onward plus two O-Ring-specific stress fixtures:
- a long axle with two independently sliding hubs, asymmetric spokes and physical O-Rings above/below;
- the device-video topology: a closed rectangular frame riding a vertical axle with a physical O-Ring immediately below the loaded hub, followed through an extended ground-impact run.

The v0.5.14 tests require that the ordinary AXLE joint stays live with free Y slide and free Y rotation, O-Ring mount joints stay attached to their rods, no proxy or replacement AXLE system exists, no connector crosses the physical 0.43 contact clearance, O-Rings fall with their host rods, closed SOCKET geometry stays intact, all body states remain finite, and the emergency runaway guard is never needed during the normal fixtures.

### Signing / update compatibility
- Android versionCode is 38;
- Android versionName is `0.5.14`;
- package ID remains `com.pixel375.connex`;
- the permanent Connex signing certificate is retained so the APK installs as an in-place update over v0.5.13.
