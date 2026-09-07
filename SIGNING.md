# Android signing and updates

Connex Lab uses package ID `com.pixel375.connex`.

Starting with v0.2.1, release APKs are signed by one permanent release key. The authoritative public certificate SHA-256 fingerprint is:

`BF:CD:2B:59:70:91:E4:AA:FE:4F:27:93:FD:14:A7:9A:2A:D4:94:0D:D1:06:9D:18:74:9C:E7:A9:99:50:D4:22`

This fingerprint was independently re-verified from the published v0.3.7 APK with Android `apksigner`. The release workflow verifies the decoded release keystore against the same fingerprint before export and verifies the finished APK again after signing. CI also checks that this documented fingerprint stays synchronized with the workflow value.

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
