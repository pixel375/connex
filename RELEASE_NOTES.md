# Connex Lab v0.5.14

Focused corrective release for the O-Ring Stop regression introduced in v0.5.13. Camera and editor geometry behavior are intentionally unchanged.

### O-Ring Stops now constrain the real axle slide
v0.5.13 made O-Rings follow their host rod correctly, but its physical stopper collision was copied onto that same rod. AXLE joints intentionally exclude collision between the mounted connector and its axle rod, so the connector could pass through the copied O-Ring stopper. Other attached pieces could still hit that proxy shape, creating the violent impulses seen in the device video.

v0.5.14 removes both the v0.5.13 host-rod collision proxy and the experimental moving proxy-body replacement. During SIMULATE, each O-Ring remains a collisionless visual follower of its host rod while the existing AXLE Generic6DOF joint receives temporary lower/upper limits on its real Y sliding degree of freedom, calculated from O-Ring positions on that rod. The axle keeps its intended free rotation and all other axle constraints unchanged. Leaving SIMULATE restores the original free-slide settings for BUILD editing.

This means an O-Ring stopper no longer depends on connector-vs-rod collision, adds no extra rigid/animatable physics body, and cannot become a drifting/world-anchored collision source.

### Impact stability
Hard Generic6DOF limits can briefly overshoot their exact coordinate during a heavily asymmetric impact. The stopper therefore arms the native axle limit slightly before the true connector/O-Ring contact point using a measured solver guard band. The O-Ring itself is not moved and the validation still measures the real connector-to-ring clearance on every physics frame. This avoids both visible crossing and the extra collision body that caused the v0.5.13 runaway behavior, while retaining the existing mobile solver settings, CCD and emergency runaway guard.

### Validation
The regression suite covers all retained behavior from v0.5.2 onward plus two O-Ring-specific stress fixtures:
- a long axle with two independently sliding hubs, asymmetric spokes and O-Rings above/below;
- the device-video topology: a closed rectangular frame riding a vertical axle with an O-Ring immediately below the loaded hub, followed through an extended ground-impact run.

The v0.5.14 tests require that no connector crosses an O-Ring, no O-Ring proxy body or host-rod proxy collision exists, visible O-Rings remain locked to their host rods, closed SOCKET geometry stays intact, all body states remain finite, and the emergency runaway guard is never needed during the normal fixtures.

### Signing / update compatibility
- Android versionCode is 38;
- Android versionName is `0.5.14`;
- package ID remains `com.pixel375.connex`;
- the permanent Connex signing certificate is retained so the APK installs as an in-place update over v0.5.13.
