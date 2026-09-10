# Connex Lab v0.5.16

Follow-up release based on hands-on v0.5.15 testing. This update focuses on O-Ring reliability and construction editing behavior.

### O-Ring selection and axle stops
O-Rings keep their small visual/physical size but now have a much larger screen-space selection target, making them substantially easier to select for MOVE/ROTATE on a phone even when larger parts overlap nearby.

The axle-stop model keeps the stable v0.5.15 nearest-hub behavior: only the lowest/highest AXLE hub in each O-Ring segment owns that segment's physical O-Ring/rod-end boundary, while interior hubs continue to stack through normal connector collision. A separate post-step topology guard now catches the rare case where two axle hubs genuinely tunnel through one another in a physics step and restores their original order before an interior hub can bypass the O-Ring. The guard does not pre-empt normal Jolt contact or continuously force hidden spacing between hubs.

Connector-side stop correction explicitly cannot traverse into the host axle rod through another fixed path in a complex construction. O-Rings remain exact rod-relative followers with no collision proxy or independently solved stopper body. AXLE rotation remains free; only longitudinal travel is stopped by O-Rings and physical rod ends.

### Structure Rigidity works across the construction
The Structure Rigidity control now applies bounded angular compliance to SOCKET/CROSS structure joints during SIMULATE instead of affecting only one redundant closed-loop edge.

- 92–100% keeps ordinary SOCKET/CROSS joints exactly rigid for stable normal builds.
- Redundant closed-loop edges retain only a tiny solver-relief allowance at high rigidity so Jolt is not numerically over-constrained.
- 50% gives about ±2.9° of visible bounded flex.
- Lower values progressively allow more movement.
- 0% is still bounded at about ±12°, not an uncontrolled free hinge.
- Linear socket positions remain locked at every setting.

Rigidity changes made while simulation is running continue to take effect on the next SIMULATE run, preserving deterministic setup.

### Correct CROSS rod creation
CREATE + CROSS now creates the selected rod through the **side/middle** of the tapped connector socket. The rod is perpendicular to the socket direction and centered at the socket mouth, leaving both rod ends free. This is intentionally different from SOCKET mode, where a rod end is inserted into the socket.

Existing behavior for placing a CROSS connector onto the body of an existing rod remains available.

### Reconnect auto-snap
After **Disconnect Selected**, explicitly reconnecting one socket now re-enables other previously detached rods from that same connector only when they are still geometrically aligned with a free socket. Those aligned rods automatically snap back instead of remaining artificially blocked by the disconnect safeguard.

Unrelated intentionally detached pairs remain blocked and will not silently reconnect.

### Multi-rod socket re-seat
Socket changing now supports connectors whose rods are attached to structures at their other ends. Re-seat keeps the rods and their remote structures fixed, rotates only the connector, and atomically remaps all existing connector mounts onto the sockets that now occupy the same valid positions.

This supports operations such as rotating a multi-socket connector one socket left/right while two or more connected rods stay in place. The change is rejected without modifying the construction if any existing rod, CROSS mount, or AXLE cannot remain geometrically valid.

### Retained v0.5.15 improvements
- 11-point and 14-point socket picking remains fixed.
- New Rod / New Connector free placement remains available.
- O-Ring closed-frame/device-video stability coverage remains active.

### Validation
v0.5.16 adds regression coverage for:
- three AXLE hubs sharing one O-Ring segment;
- actual hub-order tunnelling recovery without pre-empting ordinary hub collision;
- connector-side O-Ring correction in complex graphs;
- enlarged O-Ring touch selection;
- whole-structure rigidity at 0%, 50%, 92%, and 100%, including closed-loop solver relief;
- true side-middle CROSS rod creation;
- second-rod auto-snap after explicit reconnect;
- multi-rod socket re-seat while rods and far-end structures remain fixed;
- all existing editor, camera, closed-loop, O-Ring and Android regression tests.

### Android / update compatibility
- Android versionCode: 40
- Android versionName: `0.5.16`
- package ID: `com.pixel375.connex`
- permanent Connex signing certificate retained for in-place update compatibility.
