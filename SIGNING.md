# Android signing and updates

Connex Lab uses package ID `com.pixel375.connex`.

Starting with v0.2.1, release APKs are intended to be signed by one permanent release key. The public certificate SHA-256 fingerprint is:

`24:A4:0D:73:4E:EC:AF:5B:E2:75:CF:C1:4C:71:7C:B0:F7:51:D7:E7:C1:DF:99:E8:89:5E:F6:27:12:A2:A4:55`

The private keystore and passwords must never be committed to this repository.

## Required GitHub Actions Secrets

Add these repository Actions secrets before publishing v0.2.1 or any later release:

- `CONNEX_KEYSTORE_B64` — complete base64 text of the permanent keystore
- `CONNEX_KEYSTORE_PASSWORD` — keystore password
- `CONNEX_KEY_ALIAS` — key alias
- `CONNEX_KEY_PASSWORD` — key password

Godot currently requires the keystore and key password to be the same. The workflow checks this and also verifies the certificate fingerprint before it creates a Release.

## Migration from v0.2.0

Releases through v0.2.0 were debug-signed with a newly generated CI key on each workflow run. Android therefore cannot accept v0.2.1 as an in-place update over an installed v0.2.0 because the signatures differ.

Install procedure for v0.2.1:

1. uninstall the old Connex Lab build once;
2. install the permanent-signed v0.2.1 APK;
3. future permanent-signed releases with the same package ID and versionCode greater than the installed build can update in place.

Keep multiple offline backups of the permanent key. Losing it prevents future APKs from updating installations signed with it.

## In-app update source

While this repository is public, the game checks:

`https://api.github.com/repos/pixel375/connex/releases/latest`

No GitHub credential is embedded in the APK.

If source development later moves to a private repository, keep update metadata/APKs in a separate public release repository or public update manifest. Do not embed a private GitHub token in the Android app.
