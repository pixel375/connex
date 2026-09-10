# Connex Lab v0.5.16

This release replaces the overcomplicated O-Ring axle-stop experiments with the same simple physical mounting model already used successfully by CROSS connectors.

### O-Ring Stop simplification
An O-Ring is now treated as a dedicated **CROSS-only round stop**. Selecting O-Ring Stop and tapping a rod always creates this mount regardless of whether the bottom connection selector currently says SOCKET, AXLE, or CROSS.

The O-Ring is fixed directly to its host rod with the normal fixed-joint mechanism used by CROSS connections. Its real collision body stays enabled during SIMULATE, so a connector sliding on an AXLE is stopped by ordinary physical contact with the O-Ring instead of by a hidden travel-range solver.

O-Rings remain movable along the rod shaft while building. Moving one updates both the visible/collision body and its fixed-joint anchor so the stop remains genuinely attached at the new location.

### Removed O-Ring special-case physics
The v0.5.13-v0.5.15 O-Ring follower, rod-owned proxy, dedicated collision-layer follower, predictive velocity limiting, and coordinate correction paths are no longer used. O-Ring fixed joints are not detached during simulation, and O-Rings are not made collisionless/kinematic followers.

Normal AXLE connectors remain normal AXLE connectors: slide along the rod stays free and rotation around the axle stays free. The O-Ring does not rewrite AXLE joint limits; it simply occupies physical space and blocks the connector when they touch.

### Regression coverage
The O-Ring regressions now verify the new physical model directly: the fixed mount remains active in SIMULATE, the real collider remains enabled, build-time shaft movement moves the mount correctly, AXLE limits remain untouched, a moving AXLE hub cannot pass through a stationary O-Ring, and a moving rod/O-Ring cannot pass through a stationary AXLE hub.

All retained v0.5.15 editor improvements remain in place, including full 11/14-point socket picking, CROSS socket-to-rod creation, free-part creation, and socket re-seat.

### Android / update compatibility
- Android versionCode: 40
- Android versionName: `0.5.16`
- package ID: `com.pixel375.connex`
- permanent Connex signing certificate retained for in-place update compatibility.
