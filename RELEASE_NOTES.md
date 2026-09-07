# Connex Lab v0.3.3

Updater and phone-layout reliability release.

### Android updater rebuilt
- removes the failing JavaClassWrapper / Android `DownloadManager.Request` construction path used by v0.3.1/v0.3.2;
- downloads update APKs directly with Godot `HTTPRequest` into Connex's private `user://` storage;
- shows live bytes/percentage while downloading;
- validates successful HTTP completion and rejects missing or implausibly small files;
- reads the SHA-256 digest published on the GitHub Release asset and verifies the downloaded APK before installation;
- hands the verified local APK to Android through Godot `OS.shell_open()`, which uses Godot's built-in Android FileProvider integration;
- keeps a verified APK available so **Install** can be tapped again if Android first asks the user to allow installs from Connex Lab;
- failed transfers clean up the partial APK and restore **Retry Download** instead of getting stuck.

### Top toolbar no longer gets squeezed by status text
- runtime/version/status messages have been moved out of the toolbar HBox;
- a dedicated status strip now sits directly below the top toolbar;
- toolbar buttons retain their own horizontal space even when a status message is long;
- the left editor-mode panel and right Move/Rotate accordion are shifted below the new status strip.

### Existing editor retained
- CREATE / ROTATE / ATTACH editor modes from v0.3.2;
- point-based attachment/reconnection workflow;
- fixed-world XYZ 45-degree gizmo and real-mount Roll;
- explicit connection graph, automatic overlap fusion, O-Ring Stop and simulation stabilization;
- persistent camera/options settings.

### Signing / update compatibility
- Android versionCode is 14;
- package ID remains `com.pixel375.connex`;
- v0.3.3 uses the same permanent signing certificate introduced in v0.2.1;
- it installs in place over permanently signed earlier builds and preserves app data/settings;
- GitHub Actions verifies the permanent certificate before publishing.

**Important for v0.3.1/v0.3.2 users affected by the broken downloader:** the updater bug is in the already-installed old APK, so that old copy cannot repair its own download routine. Install v0.3.3 manually once from this Release. Future releases then use the rebuilt updater.
