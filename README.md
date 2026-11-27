# OSC Magician

An Android app for building your own OSC (Open Sound Control) control surfaces.
Lay out sliders, buttons, knobs and meters on a grid, then use them to control
mixers, DAWs, lighting software or anything else that speaks OSC over UDP.

## Download

Get the latest APK from the
[Releases page](https://github.com/johananvm/OSCMagician/releases/latest) and
open it on your Android device. You may need to allow installing apps from
unknown sources.

## Website

The static single-page website is in [website/](website/). Open
[`index.html`](website/index.html) in a browser to preview it. Its example
screenshots show a custom surface rendered by the app.

## Features

- **Controls**: horizontal and vertical sliders, push, hold and toggle buttons,
  and turnable knobs. Each sends its value as a float to its own OSC address,
  scaled to the min/max you choose.
- **Meters**: horizontal and vertical level meters (green to red) that show
  values received on their OSC address.
- **Labels and shapes**: text and bordered boxes to annotate and group controls.
- **Two-way sync**: incoming OSC messages on a control's address update that
  control, so the surface follows changes made elsewhere.
- **Multiple pages**, each in portrait or landscape. Landscape pages can be
  edited with the phone held upright for easier typing.
- **Fullscreen play mode** to hide the bars while performing.
- **Import and export** all pages and settings as a JSON file.

## Usage

1. Open **⋮ → Settings** and enter the IP address and port of the device that
   should receive OSC. Set the listen port for incoming messages; the device's
   own IP address is shown there too.
2. Tap the **pencil** to enter edit mode, then **+** to add a control.
3. Drag controls to move them, and tap one to change its name, OSC address,
   value range, color, position and size.
4. Tap **play** to use the surface. Use the bar at the bottom to switch or add
   pages, and **⋮ (page options)** in edit mode to rename a page, delete it or
   switch its orientation.

## Building from source

Requires Flutter 3.41.9 (the version used by CI).

```sh
flutter pub get
flutter test
flutter run            # on a connected device or emulator
flutter build apk --release
```

Without `android/key.properties`, release builds are signed with the debug key.

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.
