# Connex Lab v0.1.6

Small UI clarity and selection-highlight patch on top of v0.1.5.

### CREATE / EDIT mode selector
- replaced the single mode button whose label changed between CREATE and EDIT;
- CREATE and EDIT are now two separate buttons that are always visible side-by-side;
- the active mode is highlighted with a bright accent and a dot indicator;
- tapping CREATE always enters CREATE directly;
- tapping EDIT always enters EDIT directly;
- the Rotate and Move panel headers explicitly show `EDIT` while CREATE is active, making it clear why their edit controls are unavailable.

### Selection highlight rebuild fix
- changing a selected connector or rod type now rebuilds the cyan outline only from the new live geometry;
- old meshes queued for deletion are ignored when the highlight is regenerated;
- fixes stale outlines such as an 8-way connector highlight remaining around a connector after changing it to 1-way.

No construction, physics, rotation, axle, O-Ring, movement, or persistent-settings behavior is otherwise changed from v0.1.5.

### APK signing
The attached APK is debug-signed for direct sideload/testing. It is not a Play Store production-signed package.
