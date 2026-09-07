# Connex Lab v0.2.1

Permanent Android signing and in-app update infrastructure.

### Permanent app signing
- package ID remains `com.pixel375.connex`;
- release APKs now use one permanent signing certificate instead of a freshly generated CI debug key;
- release CI verifies the expected certificate SHA-256 fingerprint before publishing;
- signing material is supplied only through GitHub Actions Secrets and is never committed to the repository;
- the workflow refuses to publish a `[release]` build if any required signing secret is missing or the certificate does not match.

Because all releases up through v0.2.0 used ephemeral debug signing keys, Android cannot update an already-installed v0.2.0 directly to this new permanent key. v0.2.1 therefore requires one final uninstall/reinstall. Once v0.2.1 is installed, future APKs signed by this same key can update it in place while retaining the same package ID and app data.

### In-app updater
- Options now contains an App Updates section;
- the app can automatically check the public `pixel375/connex` GitHub Releases feed at launch;
- automatic checking can be enabled/disabled and the preference persists between launches;
- `Check for Updates` compares the installed semantic version with the latest GitHub release;
- when a newer APK is available, the button changes to `Update to vX.Y.Z`;
- on Android, the APK is downloaded through Android DownloadManager and the system package installer is opened automatically when the download completes;
- Android 8+ unknown-source permission is handled by opening the per-app `Install unknown apps` settings page when required, then continuing installation after the user returns;
- Android still requires the normal package-install confirmation. Ordinary apps cannot silently replace themselves;
- on non-Android platforms, the updater falls back to opening the release/download URL.

### Update source
For now, update metadata and APKs come directly from the public `pixel375/connex` GitHub Releases API. No GitHub token is embedded in the application. When development moves to a private source repository, the updater should continue using a separate public release/update repository or public update manifest rather than embedding private-repository credentials in the APK.

### Security
Private signing files are ignored by `.gitignore`. Required GitHub Actions Secret names are:
- `CONNEX_KEYSTORE_B64`
- `CONNEX_KEYSTORE_PASSWORD`
- `CONNEX_KEY_ALIAS`
- `CONNEX_KEY_PASSWORD`

Godot currently requires the Android keystore password and key password to match.

### v0.3.0 editor TODO
The planned transform-gizmo and explicit detach/re-attach connection editor is tracked separately and is intentionally not included in this updater/signing release.
