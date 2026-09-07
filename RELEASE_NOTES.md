# Connex Lab v0.3.1

Updater reliability hotfix on top of the v0.3.0 gizmo/topology editor release.

### Android updater fix
- fixes the updater remaining on `Downloading…` forever when Android DownloadManager has actually failed;
- polls the real DownloadManager job status instead of treating a missing completed-file URI as proof that the transfer is still active;
- shows queued, running, paused, completed, and failed states;
- running downloads show percentage and transferred MB when Android reports a total size;
- paused downloads explain whether Android is waiting to retry, waiting for a network, or waiting for Wi-Fi;
- failed downloads surface a readable failure reason and restore a `Retry Download` button instead of becoming permanently stuck;
- JavaClassWrapper/DownloadManager query failures have a grace period and then recover the UI instead of hanging indefinitely;
- update APKs now download to Connex's app-specific external Downloads directory using a unique temporary filename, avoiding stale/shared Downloads filename collisions under scoped storage;
- updater requests explicitly send a Connex User-Agent and APK Accept header;
- the normal browser fallback is retained when Android updater APIs are unavailable;
- successful downloads still continue into Android's normal unknown-source permission/install-confirmation flow.

### Version handling
- updater comparisons now use the installed v0.3.1 version, so v0.3.1 will not offer itself as an update;
- Android versionCode is 12;
- package ID remains `com.pixel375.connex`.

### Signing / install compatibility
- v0.3.1 uses the same permanent signing certificate introduced in v0.2.1;
- it installs in place over v0.2.1 and v0.3.0 and preserves app data/settings;
- GitHub Actions verifies the permanent certificate before publishing.

### Existing v0.3 systems retained
- world-axis X/Y/Z 45-degree rotation gizmo;
- real-mount Roll;
- connector Re-seat;
- explicit Detach / Attach topology editor;
- authoritative connection graph and automatic overlap fusion;
- SOCKET / AXLE / CROSS construction modes and O-Ring Stop;
- simulation stabilization and persistent options.
