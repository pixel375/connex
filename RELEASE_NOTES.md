# Connex Lab v0.1.7

Auto-connect reliability update on top of v0.1.6.

### Robust rod-end / socket auto-fusing
- valid rod ends that visually overlap a compatible free connector socket now become real fixed graph connections automatically;
- the capture distance was expanded to match the newer, deeper procedural connector jaws rather than the older simplified connector visuals;
- alignment remains strict, so nearby rods do not attach unless the rod axis and socket direction are physically compatible;
- matching is bidirectional: every free rod end is checked against every free connector socket, regardless of which piece was placed first;
- the closest valid socket wins when more than one candidate is nearby;
- the joint is created from the existing BUILD pose without pulling the model into a preloaded/stressed solver position;
- occupancy metadata for both the rod end and connector socket is updated at the same time.

### Immediate BUILD-time fusion
- auto-fusing now runs before every committed build-state snapshot, not only immediately before SIMULATE;
- placement, connector changes, rod changes, rotations and edit movement can therefore create a real connection as soon as compatible geometry overlaps;
- the same robust matcher runs again immediately before physics as a final safety pass.

### Cross overlap capture
- automatic rod-body cross capture is retained with a slightly more forgiving visual capture distance;
- rod-end/socket matches are always evaluated first so a rod tip beside a connector jaw is not incorrectly treated as a cross connection.

### v0.1.6 UI fixes retained
- CREATE and EDIT remain separate, always-visible top-bar buttons;
- stale selection outlines are rebuilt only from current live piece geometry.

### APK signing
The attached APK is debug-signed for direct sideload/testing. It is not a Play Store production-signed package.
