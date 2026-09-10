# Connex Lab v0.5.16

Follow-up release based on hands-on v0.5.15 testing. This update focuses on O-Ring reliability and construction editing behavior.

### O-Ring selection and axle stops
O-Rings keep their small visual/physical size but now have a much larger screen-space selection target, making them substantially easier to select for MOVE/ROTATE on a phone even when larger parts overlap nearby.

The axle-stop solver is also strengthened for larger constructions. Every AXLE connector in an O-Ring/rod-end segment receives a finite ranked travel range rather than leaving interior hubs unbounded. Multiple hubs retain their original order and stacking space instead of being projected onto one stop coordinate. Connector-side stop correction explicitly cannot traverse into the host axle rod through another fixed path in a complex construction.

O-Rings remain exact rod-relative followers with no collision proxy or independently solved stopper body. AXLE rotation remains free; only longitudinal travel is stopped by O-Rings and physical rod ends.

### Structure Rigidity works across the construction
The Structure Rigidity control now applies bounded angular compliance to all SOCKET/CROSS structure joints during SIMULATE, not only a redundant joint in a closed loop.

- 100% = rigid / 0° angular flex.
- 92% default remains near-rigid at roughly ±1°.
- Lower values progressively allow visible flex for more realistic movement.
- 0% is still bounded (about ±12°), not an uncontrolled free hinge.
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
- three AXLE hubs sharing one O-Ring segment, including previously interior hubs;
- connector-side O-Ring correction in complex graphs;
- enlarged O-Ring touch selection;
- whole-structure rigidity at 0%, 92%, and 100%;
- true side-middle CROSS rod creation;
- second-rod auto-snap after explicit reconnect;
- multi-rod socket re-seat while rods and far-end structures remain fixed;
- all existing editor, camera, closed-loop, O-Ring and Android regression tests.

### Android / update compatibility
- Android versionCode: 40
- Android versionName: `0.5.16`
- package ID: `com.pixel375.connex`
- permanent Connex signing certificate retained for in-place update compatibility.
