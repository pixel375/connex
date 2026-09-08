# Connex Lab v0.3.11

Adds two new fully functional 3D connector pieces.

### New 11-point 3D connector
- based on the existing 8-way flat connector;
- adds a three-socket arc over the top;
- the top arc ports point 45° upward, straight upward, and 45° upward on the opposite side;
- all 11 ports are real SOCKET endpoints with normal occupancy, attachment, history, rotation, and physics behavior.

### New 14-point 3D connector
- includes the full 11-point geometry;
- adds the mirrored three-socket arc underneath;
- total: 8 flat-plane sockets + 3 upper-arc sockets + 3 lower-arc sockets;
- all 14 ports are functional, not decorative.

### Spatial connector support
- connector socket IDs now support reserved out-of-plane directions while retaining the existing integer socket bookkeeping;
- existing connection records, Undo/Redo, occupancy maps, re-seat/reset logic and ATTACH can therefore continue to address every socket consistently;
- the new arc sockets receive matching visual jaw assemblies and collision volumes;
- changing a spatial connector back to a normal planar connector clears its nested arc geometry correctly.

### Regression coverage
- adds `spatial_connectors_smoke_v041.gd`;
- verifies the exact 11/14 socket counts and 3D directions;
- verifies top and bottom arc ports create rods in the correct world direction;
- verifies ATTACH exposes every new socket;
- verifies spatial geometry is removed when converting back to a planar connector;
- all v0.3.8, v0.3.9 and v0.3.10 behavioral tests remain active.

### Signing / update compatibility
- Android versionCode is 22;
- package ID remains `com.pixel375.connex`;
- v0.3.11 uses the same permanent signing certificate and updates in place over v0.2.1+ permanently signed builds.
