# Connex Lab v0.5.14

Focused corrective release for the O-Ring Stop regression introduced in v0.5.13. Camera and editor geometry behavior are intentionally unchanged.

### O-Ring Stops are exact rod-relative physical stops
v0.5.13 made O-Rings follow their host rod visually, but copied their stopper collision onto that same rod. AXLE joints intentionally exclude collision between the mounted connector and its axle rod, so an axle connector could pass through the copied stopper. Other attached pieces could still strike the proxy shape, which could inject the violent impulses seen in the device video.

v0.5.14 removes that proxy system. During SIMULATE, the real O-Ring body itself remains the collider and becomes a frozen kinematic stop whose world transform is synchronized from its host rod every physics tick. This keeps the O-Ring exactly rod-relative while avoiding a separately solved tiny rigid-body weld that can stretch under repeated loaded impacts.

The existing O-Ring mount remains bound during SIMULATE only to preserve O-Ring-versus-host-rod collision exclusion. All six of that mount's linear/angular constraints are temporarily disabled, so it contributes no weld force and cannot pull on the mechanism. Its original fixed constraints are restored when returning to BUILD.

The O-Ring is not reparented beneath its host RigidBody3D. The normal AXLE joint is left completely unchanged: longitudinal sliding and axle rotation remain free until the connector physically reaches the O-Ring. In BUILD/Restore, the O-Ring returns to its ordinary editable frozen state and fully constrained mount.

No host-rod collision proxy, moving proxy body, replacement AXLE joint, rewritten AXLE travel limit, enlarged O-Ring collider, nested physics-body parenting, or O-Ring-specific CCD is used.

### Impact stability
The stopper no longer depends on a separately simulated tiny rigid-body weld during SIMULATE. The ring stays locked to the host rod transform while retaining ordinary construction collision against axle connectors and other pieces. Existing global construction physics settings and the emergency runaway guard remain unchanged.

### Validation
The regression suite covers retained behavior from v0.5.2 onward plus two O-Ring-specific stress fixtures:
- a long axle with two independently sliding hubs, asymmetric spokes and O-Rings above/below;
- the device-video topology: a closed rectangular frame riding a vertical axle with an O-Ring immediately below the loaded hub, followed through an extended ground-impact run.

The v0.5.14 tests require that the ordinary AXLE joint stays live with free Y slide and free Y rotation, the O-Ring remains collidable and essentially drift-free relative to its host rod, its mount remains bound but has all six constraints disabled only during SIMULATE, the original fixed mount is restored in BUILD, no proxy or replacement AXLE system exists, no connector crosses the physical 0.43 contact clearance, closed SOCKET geometry stays intact, all body states remain finite, and the emergency runaway guard is never needed during the normal fixtures.

### Signing / update compatibility
- Android versionCode is 38;
- Android versionName is `0.5.14`;
- package ID remains `com.pixel375.connex`;
- the permanent Connex signing certificate is retained so the APK installs as an in-place update over v0.5.13.
