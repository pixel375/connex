# Connex Lab v0.5.15

This release fixes the O-Ring axle-stop regression and adds the requested construction/editor workflow improvements.

### O-Ring axle stops
O-Rings now use simple rod-relative stop semantics during SIMULATE. The visible O-Ring follows its host rod exactly and does not participate as an independent collision body or host-rod proxy.

AXLE connectors retain their normal free slide and free rotation around the axle. The runtime constrains only longitudinal travel: an O-Ring becomes a stop coordinate on the rod, and the physical rod ends are also travel limits. This works from relative motion, so it prevents both a connector falling/sliding off the rod and a moving/falling rod passing through the connector beyond an O-Ring.

When several axle connectors share the same segment, only the connector nearest each O-Ring or rod end owns that boundary. Other axle connectors remain freely sliding and can stack through ordinary connector contact. Predictive relative-velocity limiting prevents crossings without turning the O-Ring into a high-energy physics contact, and any residual boundary correction is applied only to the connector-side rigid assembly. The host rod is never teleported by an O-Ring stop.

The original v0.5.13 host-rod proxy collision system is disabled. No moving proxy body or replacement AXLE joint is used.

### CROSS creation
In CREATE + CROSS mode, a connector socket can now be tapped to grow a rod directly from that socket. Tapping a rod body still performs normal CROSS connector placement.

### New free parts
CREATE mode now includes **New Rod** and **New Connector** actions. Arm one, then tap empty workspace to create the currently selected rod or connector as a free/unattached part.

### 11-point / 14-point socket selection
All sockets on the 11-point and 14-point 3D connectors are now selectable, including the eight surrounding planar sockets. Socket picking uses the visible jaw instead of relying on one tiny projected mouth point, and overlapping front/back jaws are disambiguated by camera depth.

### Change an existing connector socket
ATTACH now supports re-seating an existing socket connection. Select the connector socket you want to use, then select the rod that is already attached to that connector. If the change is geometrically valid, Connex rotates/re-seats the connector-side structure onto that socket while keeping the target rod in place. Invalid changes are rejected without altering the construction.

### Validation
The complete regression suite includes all retained editor/physics tests plus dedicated v0.5.15 coverage for:
- mixed multi-hub O-Ring axle behavior;
- the reported closed-frame + axle + O-Ring device-video topology;
- 11-point and 14-point socket picking;
- CROSS socket-to-rod creation;
- free rod and connector creation;
- validated socket-to-existing-rod re-seat without moving the target rod.

### Android / update compatibility
- Android versionCode: 39
- Android versionName: `0.5.15`
- package ID: `com.pixel375.connex`
- permanent Connex signing certificate retained for in-place update compatibility.
