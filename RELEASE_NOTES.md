# Connex Lab v0.5.23

This is a focused UI and ATTACH-selection correction pass on top of v0.5.22. SOCKET, AXLE, CROSS, O-Ring, save/load and simulation mechanics are unchanged.

### Menu close buttons
- Options, Help, Parts, Save & Load and Physics now use compact square X controls fixed to the upper-right corner of the menu frame.
- The X controls live outside scrollable menu content, so they no longer move when the menu is scrolled.
- The old long blue inline X rows are retired.

### Top toolbar cleanup
- The obsolete status text remains hidden and its leftover frame/background is removed.
- Select and Simulate now use the same neutral grey button style as the rest of the toolbar while inactive.
- Select turns blue only while one-shot Select is armed.
- Simulate turns blue only while simulation is active.
- Delete remains neutral grey and never uses the active blue state.
- Top toolbar glyphs are slightly larger for easier touch use.

### Transform panel
- The compact right Transform card no longer has an X button.
- It cannot be hidden while Transform mode is active.
- ITEM/WORLD, Roll − / Roll + and Reset Rotation remain available.

### Deselect / ATTACH behavior
- The left utility area remains only **Disconnect** and **Deselect**.
- The inherited **Deselect Point** button is force-retired so it cannot reappear during attachment-marker refreshes.
- **Deselect** is now context-aware: when an ATTACH point is selected it clears that point first; otherwise it clears the selected piece.
- Deselect stays enabled for an active ATTACH point even when no piece is currently selected.
- Tapping empty background while an ATTACH point is selected now clears that point without clearing the piece selection.

### Camera / icon polish
- The movement joystick is shifted farther right again to provide more clearance from the left editor menu.
- Bottom Parts and previous/next icon glyphs are slightly larger.

### Android / update compatibility
- Android versionCode: 47
- Android versionName: `0.5.23`
- package ID: `com.pixel375.connex`
- permanent Connex signing certificate retained for in-place update compatibility.