# Connex Lab v0.5.0

Second editor-UX modernization chunk, focused on part selection, persistence, recovery, physics controls and scalability.

### Parts browser
- the bottom bar now has one clear **PARTS** button instead of four part-cycling arrows;
- Rods and Connectors are shown as color-coded cards in a scrollable browser;
- each card shows the part name and useful size/connection information;
- choosing a card changes the **next** part only and never silently converts the currently selected construction piece;
- O-Ring Stop, 11-point 3D and 14-point 3D remain available in the connector browser.

### Named Save / Load
- Options now contains **Open Saves & Recovery**;
- builds can be saved under user-defined names and loaded later;
- save files preserve the complete construction snapshot, connection topology, O-Rings, spatial connectors, selected part palette, camera position and SOCKET / AXLE / CROSS mode;
- loading establishes a fresh Undo root without auto-fusing intentionally detached-but-overlapping pieces.

### Crash autosave and recovery
- every committed build change schedules a debounced local autosave;
- the app tracks whether the previous non-headless session closed cleanly;
- after an unclean Android/app exit, the next launch automatically opens the recovery panel;
- **Restore Autosave** returns to the latest committed construction;
- dismissing recovery archives the old autosave into the named Saves folder before normal autosaving resumes, so the recovery point is not silently destroyed;
- app pause/close flushes pending autosave data.

### Physics controls
Options now exposes runtime simulation tuning for:
- gravity;
- surface friction;
- bounce;
- linear damping;
- angular damping;
- one-button reset to Connex defaults.

The values persist between launches and are applied to existing and newly created rods, connectors and O-Rings.

### Performance / scalability
- repeated procedural BoxMesh and CylinderMesh geometry now uses a shared primitive-mesh cache;
- ATTACH now maintains per-body and world-cell target indexes rather than requiring every ordinary tap to search the entire construction;
- physical-piece taps use the indexed compatible points first, with the proven global picker retained as a fallback for marker taps outside collision geometry;
- ATTACH overlay rebuilding is dirty-driven, so repeated UI refreshes no longer recreate all marker geometry when topology, mode and selection have not changed;
- index/overlay invalidation is tied to commits, restores, mode changes and selection changes.

### UI cleanup
- part-selection arrows are removed from the normal bottom workflow;
- Parts, Saves and Physics are grouped behind dedicated surfaces instead of adding more permanent editor buttons;
- the existing CREATE / ROTATE / MOVE / ATTACH editor stays intact.

### Regression coverage
- every v0.3.8 through v0.4.0 behavioral smoke remains active;
- new `editor_chunk2_smoke_v050.gd` verifies the Parts browser, Variant save round-trip, build restore, physics propagation, mesh-resource reuse, ATTACH spatial indexing and dirty-overlay behavior.

### Signing / update compatibility
- Android versionCode is 24;
- package ID remains `com.pixel375.connex`;
- v0.5.0 uses the same permanent signing certificate and updates in place over v0.2.1+ permanently signed builds.
