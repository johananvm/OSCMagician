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

## Android releases

Push a `v*` tag (for example, `v1.0.0`) to build a signed APK and publish it as a
GitHub Release. The APK is attached to the release, including the latest release.

Configure these repository Actions secrets before pushing a release tag:

- `ANDROID_KEYSTORE_BASE64`: base64-encoded upload keystore
- `ANDROID_KEYSTORE_PASSWORD`: keystore password
- `ANDROID_KEY_ALIAS`: signing key alias
- `ANDROID_KEY_PASSWORD`: signing key password

Create and back up a long-lived keystore securely; do not commit it. On macOS,
encode it for the `ANDROID_KEYSTORE_BASE64` secret with:

```sh
base64 -i android/upload-keystore.jks | tr -d '\n'
```
