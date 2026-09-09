# v0.5.12 focused regression

Device report after v0.5.11:

1. A vertical AXLE rod could remain stationary instead of sliding under gravity when the surrounding structure was supported.
2. Moving Structure Rigidity while SIMULATE was already running could cause the assembly to stop moving.

Root cause/fix direction:
- Structure Rigidity is no longer injected into active Generic6DOF joint limits. A value changed during SIMULATE is saved and applied only on the next SIMULATE run.
- AXLE rods are kept awake (`can_sleep = false`) while simulation is active so the deliberately free slide axis continues resolving under gravity/support changes.
- Camera behavior is intentionally untouched.
