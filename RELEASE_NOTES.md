# Connex Lab v0.1.6

Small UI clarity patch on top of v0.1.5.

### CREATE / EDIT mode selector
- replaced the single mode button whose label changed between CREATE and EDIT;
- CREATE and EDIT are now two separate buttons that are always visible side-by-side;
- the active mode is highlighted with a bright accent and a dot indicator;
- tapping CREATE always enters CREATE directly;
- tapping EDIT always enters EDIT directly;
- the Rotate and Move panel headers explicitly show `EDIT` while CREATE is active, making it clear why their edit controls are unavailable;
- no construction, rotation, movement, physics, O-Ring, axle, or settings behavior was otherwise changed from v0.1.5.

### APK signing
The attached APK is debug-signed for direct sideload/testing. It is not a Play Store production-signed package.
