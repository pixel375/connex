# Connex Lab v0.3.6

Interaction and connection-geometry stabilization release.

### Attachment selection reliability
- selected attachment points now remain live references to their piece instead of stale world-space coordinates;
- rod-body points are recomputed from their saved axial position whenever the rod moves;
- discrete point hit radius is increased and supplemented by a physical raycast fallback when rods/connectors overlap on screen;
- a selected source stays selected until a valid compatible target succeeds or the user explicitly deselects it;
- reconnecting a connector preserves/rebuilds its primary mount record so later rotation still knows which real connection is the pivot.

### Rotation gizmo stabilization
- the selected-piece gizmo remains fixed to WORLD X/Y/Z axes;
- drag tracking no longer integrates a screen tangent that can flip after assemblies are moved/rotated;
- the drag follows the actual projected ring parameter continuously and unwraps its angle;
- the resulting transform still snaps to exact 45° world-axis states and still validates the connection graph before committing;
- invalid rotation directions remain disabled/greyed.

### Rotate / Move accordion
- Rotate and Move are now a strict one-open-at-a-time accordion;
- entering ROTATE automatically opens Rotate and closes Move;
- manually opening either utility always collapses the other;
- panel bounds are recalculated from the viewport and clipped so their contents cannot draw through each other.

### Reset Placement Rotation fixed
- reset no longer relies on the connector's stale absolute world-space creation basis;
- socket reset reconstructs the default orientation from the connector's current mounted rod/socket;
- axle reset reconstructs orientation from the current axle axis while preserving axial slide position;
- cross reset reconstructs orientation from the current cross rod and socket;
- previous 45° Roll steps are therefore actually removed while the current mount stays attached.

### True CROSS geometry
- CROSS is corrected to match the intended physical connection: the rod is perpendicular to the connector's flat face, parallel to the connector's axle axis, but passes through a side clamp rather than the center hub;
- creation, explicit attachment, validation and automatic cross-fusion all use this same rule;
- the old in-plane cross rule is removed.

### Signing / update compatibility
- Android versionCode is 17;
- package ID remains `com.pixel375.connex`;
- v0.3.6 uses the same permanent signing certificate as v0.2.1+;
- it updates in place over permanently signed earlier builds and preserves app data/settings;
- GitHub Actions verifies the signing certificate before publishing.
