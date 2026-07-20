# zebra_bt_printer

Flutter plugin for printing to **Zebra** label printers over **Bluetooth** or
**TCP/IP**, built on the Zebra Link-OS Android SDK.

> **Platform support: Android only.** iOS is a graceful stub — print calls return
> a failure (`UNSUPPORTED_PLATFORM`) and `requestPermissions()` /
> `isBluetoothEnabled()` return `false` instead of throwing, so cross-platform
> apps keep compiling and running.

| | |
| --- | --- |
| Supported printers | Zebra Link-OS (e.g. ZQ series, ZD series) |
| Connectivity | Bluetooth Classic (SPP) and TCP/IP |
| Android `minSdk` | 24 |
| iOS | Not supported (stubbed) |

➡️ **Integrating from another app/team? Read [`doc/INTEGRATION.md`](doc/INTEGRATION.md)** for a step-by-step guide.

## Features

- Print a base64 image (JPG/PNG) over Bluetooth or TCP/IP — auto-scaled and
  centered to the configured label size.
- Print a plain-text label wrapped in basic ZPL over Bluetooth.
- Runtime Bluetooth permission handling (Android 12+ and legacy).
- Typed results (`PrintResult`) — no exceptions to catch in the normal flow.

## Quick start

```dart
import 'package:zebra_bt_printer/zebra_bt_printer.dart';

// 1. Request permissions (Android 12+ shows the system dialog).
if (!await ZebraBtPrinter.requestPermissions()) return;

// 2. Make sure Bluetooth is on.
if (!await ZebraBtPrinter.isBluetoothEnabled()) return;

// 3. Print.
final result = await ZebraBtPrinter.printImageBluetooth(
  mac: '48:A4:93:DB:04:6F',
  imageBase64: myBase64Image,
  config: const PrinterConfig(labelWidthDots: 600, labelHeightDots: 250),
);

if (result.isSuccess) {
  print('Printed!');
} else {
  // userMessage: texto estable para UI
  print(result.userMessage);
  // errorMessage / rawErrorCode: detalle técnico para logs
  print('log: [${result.rawErrorCode}] ${result.errorMessage}');
}
```

## Installation

Add the dependency to the consuming app's `pubspec.yaml` (use the form that
matches how you distribute it):

```yaml
dependencies:
  # From a Git repository
  zebra_bt_printer:
    git:
      url: https://github.com/<org>/zebra_bt_printer.git
      ref: v1.0.0

  # …or from a local path (monorepo / vendored)
  # zebra_bt_printer:
  #   path: ../packages/zebra_bt_printer
```

Then `flutter pub get`. See [`doc/INTEGRATION.md`](doc/INTEGRATION.md) for the
required Android setup.

## API

| Method | Returns | Notes |
| --- | --- | --- |
| `printImageBluetooth({mac, imageBase64, config})` | `Future<PrintResult>` | Image over Bluetooth |
| `printImageIP({ip, imageBase64, config})` | `Future<PrintResult>` | Image over TCP/IP |
| `printLabelBluetooth({mac, zplText})` | `Future<PrintResult>` | Plain-text label over Bluetooth |
| `requestPermissions()` | `Future<bool>` | `true` if all BT permissions granted |
| `isBluetoothEnabled()` | `Future<bool>` | Whether the adapter is on |

### `PrinterConfig`

| Field | Default | Description |
| --- | --- | --- |
| `labelWidthDots` | `600` | Label width in dots (3 in @ 200 DPI ≈ 600). |
| `labelHeightDots` | `240` | Label height in dots. |
| `useSmoothScaling` | `true` | Anti-aliased resize when fitting the image. |

### `PrintResult`

| Member | Type | Description |
| --- | --- | --- |
| `isSuccess` | `bool` | `true` when the job was sent successfully. |
| `errorCode` | `PrintErrorCode?` | Typed error code (see below). |
| `userMessage` | `String?` | Stable message for UI (`errorCode.userMessage`). |
| `errorMessage` | `String?` | Technical detail from the native layer (logs). |
| `rawErrorCode` | `String?` | Original native string code. |

## Error codes (`PrintErrorCode`)

| Enum | Native code | User message (ES) |
| --- | --- | --- |
| `invalidArgs` | `INVALID_ARGS` | Revisa los datos enviados a la impresora. |
| `permissionDenied` | `PERMISSION_DENIED` | Se requieren permisos de Bluetooth… |
| `printError` | `PRINT_ERROR` | No se pudo imprimir. Verifica que la impresora… |
| `connectError` | `CONNECT_ERROR` | No se pudo conectar con la impresora… |
| `calibrateError` | `CALIBRATE_ERROR` | No se pudo calibrar la impresora… |
| `disconnectError` | `DISCONNECT_ERROR` | No se pudo cerrar la conexión… |
| `noActivity` | `NO_ACTIVITY` | No hay una pantalla activa… |
| `permissionRequestInProgress` | `PERMISSION_REQUEST_IN_PROGRESS` | Ya hay una solicitud de permisos… |
| `unsupportedPlatform` | `UNSUPPORTED_PLATFORM` | La impresión solo está disponible en Android. |
| `unknown` | `UNKNOWN` | Ocurrió un error al imprimir… |

Unknown native codes map to `PrintErrorCode.unknown`; the original string is kept in `rawErrorCode`.

## Example

A runnable demo lives in [`example/`](example/lib/main.dart) (MAC input,
permission check, and a print button).

## License

See [LICENSE](LICENSE).
