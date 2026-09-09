# Connex Lab v0.5.10

Correction release for the v0.5.9 device regressions where a rod could auto-connect across a visible gap and pressing SIMULATE could reshape the construction before physics began.

### Auto-connect is now overlap-only
- a free rod end is considered for automatic SOCKET attachment only when it is already directly inside the intended socket area;
- capture distance is reduced to 0.38 world units, lateral miss to 0.22, with strong 0.98 directional alignment;
- a nearby rod that is merely pointing toward a socket stays free;
- automatic attachment no longer translates, rotates, bends, relaxes, or otherwise moves an existing component to manufacture a connection;
- v0.5.7's immediate far-end attachment remains, but only when the newly created rod already physically reaches the second socket.

### SIMULATE no longer edits the build
The visible warp was caused by two inherited editor operations being run as part of simulation preflight: v0.5.5 re-projected all recorded attachment geometry and v0.5.6 performed a last automatic dock/connection pass. Both are disabled at simulation start in v0.5.10.

- pressing SIMULATE does not auto-orient connectors;
- it does not search for new nearby SOCKET attachments;
- it does not normalize or relax body positions/rotations;
- preflight snapshots the complete build pose and has a hard safeguard that preserves those transforms while the solver graph is prepared.

### Physics protections retained
- the permanent v0.5.8 rule remains: every real closed-loop SOCKET stays physically connected in simulation;
- v0.5.9's redundant cycle angular-lock softening remains active to avoid the delayed over-constraint instability;
- duplicate axle suppression and connected-component collision handling remain active;
- camera behavior is intentionally unchanged in this release.

### Regression coverage
- a 1.0-unit visible rod/socket gap must remain unconnected and unchanged;
- a 0.10-unit true overlap must attach without moving either connector or the rod assembly;
- simulation preflight must preserve every build transform exactly;
- old v0.5.4/v0.5.5 tests that required wide proximity snapping were explicitly reversed because that behavior is now considered a bug;
- the v0.5.8 closed-loop SOCKET regression and v0.5.9 long physics stability test continue to pass.

### Signing / update compatibility
- Android versionCode is 34;
- Android versionName is `0.5.10`;
- package ID remains `com.pixel375.connex`;
- the existing permanent Connex signing certificate is retained for an in-place update over v0.5.9.
