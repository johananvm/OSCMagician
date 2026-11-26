# osc_magician

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.

## Android builds and releases

Each branch or tag push builds a signed APK. Download the `osc-magician-apk`
artifact from the workflow run in GitHub Actions (GitHub requires you to sign
in, and artifacts expire according to repository retention settings).

Push a `v*` tag (for example, `v1.0.0`) to also publish the APK as a GitHub
Release. Branch builds use the version name in `pubspec.yaml`; release tags use
the tag without the `v`. The APK filename includes that version, for example
`OSCMagician1.0.2.apk`. Both use the workflow run number as Android's version
code, so an older build cannot normally be installed over a newer one.

Configure these repository Actions secrets before pushing:

- `ANDROID_KEYSTORE_BASE64`: base64-encoded upload keystore
- `ANDROID_KEYSTORE_PASSWORD`: keystore password
- `ANDROID_KEY_ALIAS`: signing key alias
- `ANDROID_KEY_PASSWORD`: signing key password

Create and back up a long-lived keystore securely; do not commit it. On macOS,
encode it for the `ANDROID_KEYSTORE_BASE64` secret with:

```sh
base64 -i android/upload-keystore.jks | tr -d '\n'
```

Keep using the same keystore and key for all builds so they can be installed as
updates. An APK signed with the local debug key must be uninstalled before
installing one signed with this release key.
