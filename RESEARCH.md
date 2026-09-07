# Connex mechanical research notes

This document records the engineering assumptions behind Connex Lab v0.1.0. The goal is to model the mechanics of classic K'NEX-style construction without copying proprietary artwork or relying on unofficial 3D model packs.

## Fundamental connection mechanics

### End rod to connector socket

The original construction-system patent describes a connector socket that receives a rod end by lateral snap-in. The rod end and socket axis become aligned, and the socket geometry constrains axial and lateral separation. The end includes cylindrical grip, annular groove and flange features.

**v0.1 mapping:** a normal socket connection becomes a rigid six-degree-of-freedom joint after placement.

Primary source: https://patents.google.com/patent/US5350331

### Intermediate rod body to connector socket

The same patent describes the elongated rod body being laterally received by a socket with the rod at right angles to the socket axis and non-rotatably gripped.

**v0.1 mapping:** CROSS mode places a connector socket radially on a rod at 90 degrees, then creates a rigid joint.

### Rod through connector hub

Classic connectors have a central cylindrical opening. Patent text describes slight clearance around the rod envelope so a rod can pass through with free rotational and longitudinal motion.

**v0.1 mapping:** AXLE mode uses a 6DOF joint whose hub axis is local Y. X/Z translation and X/Z tilt are locked; Y translation and Y rotation remain free.

## Angular geometry

Classic sockets are arranged radially at 45-degree increments or multiples. v0.1 uses the following planar topology:

| Connector | Socket directions |
|---|---|
| Gray 1-way | 0° |
| Orange straight | 0°, 180° |
| Light gray 2-way | 0°, 45° |
| Red 3-way | 0°, 45°, 90° |
| Green 4-way | 0°, 45°, 90°, 135° |
| Yellow 5-way | 0°, 45°, 90°, 135°, 180° |
| White 8-way | every 45° around 360° |

The MIT legacy K'NEX overview also catalogs the purple 4-way and blue 7-way special 3D connectors that interlock perpendicular to one another. Those are intentionally deferred beyond v0.1.

References:
- https://patents.google.com/patent/US5350331
- https://web.mit.edu/~naha/Public/knex/about/Basic/knex.html

## Rod lengths and grid spacing

The rod family is designed around connector-center spacing and a square-root-of-two progression, enabling exact 45/45/90 structures. v0.1 uses these measured physical lengths:

- green: 17.5 mm
- white: 33 mm
- blue: 55 mm
- yellow: 86 mm
- red: 130 mm
- gray: 192 mm

The connector center-to-socket-end distance is modeled as about 10.1 mm. A normal connector-center distance therefore becomes approximately `rod physical length + 2 × 10.1 mm`.

## Visual form

The patent drawings/text establish the simulation-relevant features: a ribbed/non-circular rod body, cylindrical grip sections near each end, annular groove and terminal flange, plate-like radial connectors, socket jaws, and a central cylindrical hole.

v0.1 renders those cues procedurally with crossed rod ribs, cylindrical end grips/flanges, groove rings, a connector hub ring and radial jaws. These are recognizable engineering approximations rather than scans or copied official meshes.

References:
- https://patents.google.com/patent/US5350331
- https://patents.google.com/patent/US20060276100A1/en
- https://patents.google.com/patent/US20190160390A1/en

## Physics fidelity

Later patent material describes standard connectors molded from Celcon acetal copolymer. Public sources do not provide a complete calibrated dataset for every part's flexural stiffness, pull-out force, wear, clearances or dynamic friction.

v0.1 therefore models what can be grounded confidently:

- Earth-normal gravity (9.81 m/s²);
- rigid-body pieces with lightweight relative masses;
- fully constrained end and cross-snap joints;
- documented free axial translation and rotation through a hub;
- a fixed seed connector so structures have an anchor during testing.

Rod bending, snap deformation, joint breakaway and detailed friction/tolerance are deferred until they can be measured instead of invented.

## Why Godot 4.6.3

Godot was selected over a custom Android/OpenGL engine and libGDX/Bullet for the first release because it provides native Android export, headless CI operation, built-in 3D rigid bodies, a Generic6DOFJoint3D that directly maps to the required constraints, and procedural mesh APIs. GDScript also keeps the public repository small and makes mechanical dimensions easy to tune.

Godot 4.6 Android export documentation recommends OpenJDK 17 and Android SDK Platform-Tools 35+, Build-Tools 35.0.1 and Platform 35. The workflow installs those baseline versions.

Reference: https://docs.godotengine.org/en/4.6/tutorials/export/exporting_for_android.html

## Mobile control design

A phone is poorly suited to CAD-style six-axis gizmos. Connex instead uses the construction geometry itself as the interaction constraint:

- choose a rod and next connector;
- select SOCKET, AXLE or CROSS mode;
- tap the existing piece at the connection location;
- let the app calculate the mechanically valid pose;
- use Twist to rotate a new connector plane around an incoming rod in 45-degree steps;
- drag to orbit and pinch to zoom;
- keep authored geometry frozen in Build mode and release it in Simulate mode.

This makes building fast with one hand while preserving discrete connection geometry.

## Next fidelity targets

1. Purple/blue perpendicular 3D interlocking connector pair.
2. Ghost placement preview and socket highlighting.
3. Wheels, tires, spacers, clips and axle stops.
4. Gears, chain and motors.
5. Flexible rods and calibrated elastic bending.
6. Breakaway snap force and joint-stress visualization.
7. Save/load and shareable construction files.
8. Larger part library and inventory/challenge modes.
