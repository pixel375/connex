# Connex Lab v0.1.1

Interaction and construction-flow update based on first-device testing.

### Fixed
- Android touchscreen taps now activate the bottom UI buttons correctly;
- rod and connector selectors are functional on-device;
- connector rotation control is functional on newly attached connectors.

### Changed construction flow
- tapping a free connector socket now creates **only a rod**;
- a connector is created only after tapping the free end of that rod in normal SOCKET mode;
- tapping a rod body selects that rod for editing;
- Rod ◀/▶ changes the selected rod length while one end remains free;
- tapping a connector hub selects that connector for editing;
- Conn ◀/▶ changes the selected connector type while preserving occupied socket directions;
- Rotate turns a newly attached connector around its incoming rod in 45° steps;
- once a rod is locked between two connectors, its length cannot be changed without undoing an end;
- once a connector has extra rods attached, its rotation is locked so existing geometry is not silently broken.

### Still included
- AXLE mode with free axial slide and rotation;
- explicit CROSS mode for the special 90° connector-to-rod snap;
- orbit, pinch zoom, Undo, Reset, and Build/Simulate physics.

### APK signing
The attached APK is debug-signed for direct sideload/testing. It is not a Play Store production-signed package.
