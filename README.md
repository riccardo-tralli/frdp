# frdp

[![dart version](https://img.shields.io/badge/dart-%3E%3D3.10.4-0175C2)](https://dart.dev)
[![flutter version](https://img.shields.io/badge/flutter-%3E%3D3.3.0-02569B)](https://flutter.dev)

[![macOS support](https://img.shields.io/badge/macOS-supported-2EA44F)](https://github.com/riccardo-tralli/frdp)
[![Linux support](https://img.shields.io/badge/Linux-not%20supported%20yet-BD561D)](https://github.com/riccardo-tralli/frdp)
[![Windows support](https://img.shields.io/badge/Windows-not%20supported%20yet-BD561D)](https://github.com/riccardo-tralli/frdp)

A Flutter plugin for Remote Desktop Protocol (RDP) connections.

`frdp` provides:

- A Dart API to open and manage RDP sessions.
- A native macOS platform view to render the remote desktop in Flutter (widget).
- Input forwarding for keyboard and mouse events.

![demo](docs/assets/demo.gif)

## ‼️ Development status (Early Stage) ‼️

This project is **early-stage / experimental**.

- API changes can be breaking, even in minor updates.
- Method-channel contract details may evolve while the plugin matures.
- Current production readiness should be evaluated carefully per use case.

If you adopt `frdp` now, pin a specific commit or version and test upgrades before rollout.

## Platform support

- macOS: supported ✅
- Windows: planned 🗓️
- Linux: planned 🗓️
- iOS: not planned ❌
- Android: not planned ❌
- Web: not planned ❌

## Installation

Add the dependency to your `pubspec.yaml`.

### From GitHub

```yaml
dependencies:
    frdp:
        git:
            url: https://github.com/riccardo-tralli/frdp.git
            ref: main
```

### From local

```yaml
dependencies:
    frdp:
        path: ../frdp
```

Then run:

```bash
flutter pub get
```

## Quick start

Import the package:

```dart
import "package:frdp/frdp.dart";
```

Create a plugin instance and connect:

```dart
final frdp = const Frdp();

final session = await frdp.connect(
  const FrdpConnectionConfig(
    host: "192.168.1.1",
    port: 3389, // optional, default 3389
    username: "rdp-user",
    password: "rdp-password",
    domain: "WORKGROUP", // optional
    ignoreCertificate: true, // optional, default false
    performanceProfile: FrdpPerformanceProfile.medium, // optional, default medium
    connectTimeoutMs: 15000, // optional
  ),
);
```

Render the remote desktop in your widget tree:

```dart
FrdpView(sessionId: session.id)
```

Disconnect when done:

```dart
await frdp.disconnect(sessionId: session.id);
```

## FreeRDP requirement (macOS)

FreeRDP is required. Install with Homebrew:

```bash
brew install freerdp
```

By default, the plugin looks in:

```text
/opt/homebrew/opt/freerdp
```

You can override this path with `FREERDP_PREFIX`:

```bash
export FREERDP_PREFIX="$(brew --prefix freerdp)"
```

If your local FreeRDP build has only one architecture slice, you can force excluded archs:

```bash
export FREERDP_EXCLUDED_ARCHS="x86_64"
# or
export FREERDP_EXCLUDED_ARCHS="arm64"
```

For distribution to other devices, ensure FreeRDP is also available on target machines, or bundle the required dylibs and configure runtime paths accordingly.

## Public API overview

Main exports:

- `Frdp`: API client (`connect`, `disconnect`, state checks, input forwarding)
- `FrdpConnectionConfig`: connection settings and validation
- `FrdpSession`: session identifier and current state
- `FrdpConnectionState`: `disconnected`, `connecting`, `connected`, `error`
- `FrdpPerformanceProfile`: preset profile for connection quality/performance trade-offs
- `FrdpView`: RDP rendering widget

## Input forwarding

`frdp` forwards:

- Pointer events (`x`, `y`, `buttons` bitmask)
- Key events (`keyCode`, `isDown`)

The pointer `buttons` bitmask follows Flutter conventions:

- `1`: left button
- `2`: right button
- `4`: middle button
- `8`: back button
- `16`: forward button

## Method-Channel Contract Tool

The plugin uses a generated channel contract to keep Dart and native implementations aligned.

- Source of truth: `tool/channel_contract.json`
- Generated Dart file: `lib/src/channel/frdp_channel_contract.dart`
- Generated macOS file: `macos/Classes/plugin/FrdpChannelContract.swift`
- Generator: `tool/generate_channel_contracts.dart`

### Maintenance

Do not edit files manually. Update `tool/channel_contract.json` and regenerate contract files:

```bash
dart tool/generate_channel_contracts.dart
```

## Example app

A working example app is available in [example](example).

Run it with:

```bash
cd example
flutter pub get
flutter run -d macos
```

## License

`frdp` is distributed under the MIT License. See [LICENSE](LICENSE).
