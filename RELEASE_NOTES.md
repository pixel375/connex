# Connex Lab v0.5.14

Focused corrective release for the O-Ring Stop regression introduced in v0.5.13. Camera and editor geometry behavior are intentionally unchanged.

### O-Ring Stops are exact rod-relative physical stops
v0.5.13 made O-Rings follow their host rod visually, but copied their stopper collision onto that same rod. AXLE joints intentionally exclude collision between the mounted connector and its axle rod, so an axle connector could pass through the copied stopper. Other attached pieces could still strike the proxy shape, which could inject the violent impulses seen in the device video.

v0.5.14 removes that proxy system. During SIMULATE, the real O-Ring body itself remains the collider and is locked exactly to its host rod as a kinematic rod-relative follower. Its editable BUILD weld is temporarily detached so the tiny O-Ring body is not separately solved against the rod and cannot stretch away under repeated axle impacts. Only O-Ring-versus-host-rod self-collision is excluded.

The normal AXLE joint is left completely unchanged: longitudinal sliding and axle rotation remain free until the connector physically reaches the O-Ring. Because the O-Ring transform is rod-relative, it follows every fall, rotation and movement of the host rod exactly. In BUILD/Restore, the O-Ring returns to its original editable body, parent and fixed mount.

No host-rod collision proxy, moving proxy body, replacement AXLE joint, rewritten AXLE travel limit, enlarged O-Ring collider or O-Ring-specific CCD is used.

### Impact stability
The stopper no longer depends on a separately simulated tiny rigid-body weld during SIMULATE. This removes the mount-flex failure that appeared under repeated loaded contact while preserving ordinary physical collision against axle connectors and other construction pieces. Existing global construction physics settings and the emergency runaway guard remain unchanged.

### Validation
The regression suite covers all retained behavior from v0.5.2 onward plus two O-Ring-specific stress fixtures:
- a long axle with two independently sliding hubs, asymmetric spokes and O-Rings above/below;
- the device-video topology: a closed rectangular frame riding a vertical axle with an O-Ring immediately below the loaded hub, followed through an extended ground-impact run.

The v0.5.14 tests require that the ordinary AXLE joint stays live with free Y slide and free Y rotation, the O-Ring remains collidable and exactly rod-relative during SIMULATE, its BUILD weld is detached only while simulating and restored afterward, no proxy or replacement AXLE system exists, no connector crosses the physical 0.43 contact clearance, O-Rings follow their host rods without drift, closed SOCKET geometry stays intact, all body states remain finite, and the emergency runaway guard is never needed during the normal fixtures.

### Signing / update compatibility
- Android versionCode is 38;
- Android versionName is `0.5.14`;
- package ID remains `com.pixel375.connex`;
- the permanent Connex signing certificate is retained so the APK installs as an in-place update over v0.5.13.
