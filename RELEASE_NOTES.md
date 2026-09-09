# Connex Lab v0.5.6

Axle-placement auto-attachment and Android camera correction release.

### The missing-joint bug from the device screenshots is fixed at its source
- v0.5.5 could geometrically normalize a SOCKET connection only after that connection already existed in the graph;
- placing an 8-port connector onto a central axle beside several existing rod ends created only the AXLE record, leaving the visually adjacent side rods completely unconnected;
- SIMULATE could therefore normalize nothing for those rods, and they fell away exactly as shown in the device report;
- v0.5.6 explicitly discovers and creates those missing SOCKET records before physics begins.

### Axle-mounted connectors auto-dock to surrounding rods
- a newly placed connector on an axle may freely roll around that axle before radial socket connections exist;
- v0.5.6 uses that real physical degree of freedom to examine nearby free rod ends and candidate connector slots;
- it chooses the axle roll that produces the greatest number of compatible surrounding rod/socket matches;
- it then runs the normal socket-fusion system so each matched rod becomes a real connection in the graph;
- this happens immediately after axle placement and again as a final safety pass when SIMULATE is pressed;
- once radial connections exist, the auto-dock pass does not arbitrarily rotate the connector again.

### Existing v0.5.5 geometry closure remains active
- newly created socket connections still use the closed-loop geometry projection introduced in v0.5.5;
- build transforms and joint rest geometry are refreshed after auto-docking;
- redundant closed-loop physics constraints are suppressed only after missing connections have been discovered and the attachment geometry has been normalized.

### Camera zoom and movement stabilized
- two-finger pinch zoom now uses the ratio between finger distances instead of a raw screen-pixel delta, making it consistent across phone resolutions and pixel densities;
- two-finger pan still follows camera screen X/Y, but its speed is bounded at extreme zoom distances so a small finger movement cannot throw the view across the scene;
- the wide 3–420 camera distance range remains available;
- both active fingers are marked as part of a camera gesture, preventing the stationary finger from becoming an accidental world tap when a pinch ends;
- mouse-wheel zoom is multiplicative as well, matching the smoother distance scaling.

### Validation
- all previous behavioral regressions through v0.5.5 remain active;
- the new v0.5.6 regression reproduces the reported setup with a vertical axle, an 8-port connector, and three surrounding free rod ends;
- it requires all three side rods to become real SOCKET graph connections after axle placement;
- it adds another close unrecorded rod and requires simulation preflight to discover and fuse it before physics;
- it verifies the resulting socket geometry is actually closed;
- it also verifies bounded high-distance panning, monotonic ratio-based pinch zoom, and the 3–420 zoom limits;
- Android export and permanent release signing must pass before publication.

### Signing / update compatibility
- Android versionCode is 30;
- Android versionName is `0.5.6`;
- package ID remains `com.pixel375.connex`;
- v0.5.6 uses the existing permanent Connex signing certificate and updates in place over v0.5.5.
