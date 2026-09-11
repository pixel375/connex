# Connex Lab v0.5.22

This release is a touch-control and interface pass on top of v0.5.21. The existing SOCKET, AXLE, CROSS, O-Ring, save/load and simulation mechanics are retained.

### Camera controls
- The movement joystick and UP/DOWN elevation controls now own separate touch IDs, so horizontal movement and elevation work at the same time with two fingers.
- The joystick is slightly larger and moved farther right so it no longer crowds the left editor toolbar.
- UP/DOWN are enlarged to roughly 2.4× their previous width/height for easier phone use.
- Touch pinch zoom and two-finger camera pan are disabled. One-finger viewport orbit remains the camera touch gesture.
- Desktop mouse camera controls remain available for testing.

### Transform controls
- The right TRANSFORM card is smaller and no longer collapses.
- Its TRANSFORM header, long ITEM/WORLD description, MOUNT ROLL title and duplicate Axle Slide row are removed.
- The compact ITEM/WORLD toggle remains available, followed directly by Roll − / Roll + and Reset Rotation.
- The card has an X close button and reopens when TRANSFORM is pressed again.
- Move arrows are 65% larger than the rotation rings, including their hit area, so moving and rotating are visually distinct.

### Left and top toolbars
- Left utility actions are now simply **Disconnect** and **Deselect**; the redundant Deselect Point control is removed because Deselect already clears an ATTACH point.
- Delete moved from the left toolbar to the top bar.
- The status strip was removed from the top bar and the bar was enlarged.
- Exact top layout: **Select, Center | Undo, Redo | Simulate, Restore | Restart, Delete | Options**.
- The top actions use square icon-style buttons; Select and Simulate highlight only while active.
- Restart and Delete now show confirmation dialogs with Cancel.
- Help moved from the top-level `?` into Options.

### Options and menus
- The first three Options entries are now **Physics / Save & Load / Help**.
- Structure Rigidity moved from general Options to the top of Physics without creating a duplicate setting.
- Reset Physics continues to reset Structure Rigidity to its Connex default (92%) together with the other physics controls.
- Options, Help, Parts, Save & Load, Physics and the compact Transform card all have an X close button.

### Bottom parts bar
- The Parts/Mode title is removed and the bottom bar is slightly larger.
- Parts is represented by a tool icon.
- Rod and connector previous/next controls are plain left/right arrows.
- The selected rod and connector are shown as live procedural 3D renderings instead of text names, using the same geometry path as the Parts browser.
- SOCKET / AXLE / CROSS remain centered text inside the connection-mode control for clarity.

### Android / update compatibility
- Android versionCode: 46
- Android versionName: `0.5.22`
- package ID: `com.pixel375.connex`
- permanent Connex signing certificate retained for in-place update compatibility.
