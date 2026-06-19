# Integration guide — `zebra_bt_printer`

This guide is for teams adding `zebra_bt_printer` to an **existing Flutter app**.
It covers installation, Android configuration, runtime permissions, every API
call with copy-paste examples, and troubleshooting.

> **TL;DR**
> 1. Add the dependency. 2. Set Android `minSdk` to 24+. 3. Call
> `requestPermissions()` then `isBluetoothEnabled()`. 4. Call a `print…` method
> and check `result.isSuccess`. iOS compiles but always fails gracefully.

---

## 1. Requirements

| Requirement | Value |
| --- | --- |
| Flutter SDK | `>=3.3.0` |
| Dart SDK | `>=3.0.0 <4.0.0` |
| Android `minSdk` | **24** or higher |
| Android `compileSdk` | 34+ (35/36 recommended) |
| Java / Kotlin JVM target | 17 |
| Target devices | Android only (Bluetooth Classic capable) |

The Zebra Link-OS SDK has **no iOS counterpart in this plugin**. On iOS the
plugin is a stub: print calls return `PrintResult.failure` with code
`UNSUPPORTED_PLATFORM`, and `requestPermissions()` / `isBluetoothEnabled()`
return `false`. Your code does not need iOS-specific branching — just check
`isSuccess`.

---

## 2. Add the dependency

In your app's `pubspec.yaml`:

```yaml
dependencies:
  zebra_bt_printer:
    git:
      url: https://github.com/<org>/zebra_bt_printer.git
      ref: v1.0.0        # pin to a tag/commit for reproducible builds
```

Local / monorepo alternative:

```yaml
dependencies:
  zebra_bt_printer:
    path: ../packages/zebra_bt_printer
```

Then:

```bash
flutter pub get
```

The Zebra SDK `.jar` files ship **inside the plugin** (`android/libs`) and are
wired up by the plugin's own Gradle file. You do **not** need to download or add
any Zebra SDK manually.

---

## 3. Android configuration

### 3.1 `minSdk`

In `android/app/build.gradle` (or `build.gradle.kts`):

```groovy
android {
    defaultConfig {
        minSdk = 24   // or higher
    }
}
```

### 3.2 Permissions

The plugin **already declares** the Bluetooth permissions in its own manifest,
and they are merged into your app automatically:

```xml
<uses-permission android:name="android.permission.BLUETOOTH" />            <!-- < Android 12 -->
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN" />      <!-- < Android 12 -->
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />    <!-- Android 12+ -->
<uses-permission android:name="android.permission.BLUETOOTH_SCAN" />       <!-- Android 12+ -->
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
```

You normally don't need to add anything. If your app targets Android 12+ and you
want to declare that location is **not** used to derive physical location, you
can add `android:usesPermissionFlags="neverForLocation"` to `BLUETOOTH_SCAN` in
your app manifest.

### 3.3 Packaging (only if you hit a merge error)

The Zebra SDK bundles Apache Commons jars that contain duplicate `META-INF`
entries. The plugin handles this internally, but if your app build fails with a
*"More than one file was found with OS independent path…"* error, mirror the
plugin's `packaging` block in `android/app/build.gradle`:

```groovy
android {
    packaging {
        resources {
            excludes += [
                'META-INF/DEPENDENCIES', 'META-INF/LICENSE', 'META-INF/LICENSE.txt',
                'META-INF/NOTICE', 'META-INF/NOTICE.txt',
                'META-INF/*.RSA', 'META-INF/*.SF', 'META-INF/*.DSA',
            ]
            pickFirsts += ['org/apache/commons/**', 'org/apache/**']
        }
    }
}
```

---

## 4. Runtime permissions (Android 12+)

On Android 12+ the Bluetooth permissions are **runtime** permissions. Always
request them before connecting, and verify Bluetooth is on:

```dart
Future<bool> _ensureReady() async {
  final granted = await ZebraBtPrinter.requestPermissions();
  if (!granted) return false;               // user denied the dialog
  return ZebraBtPrinter.isBluetoothEnabled(); // adapter must be on
}
```

- `requestPermissions()` shows the system dialog and resolves to `true` only
  when **all** required permissions are granted.
- If the user denies, returns `false` — surface a message asking them to enable
  Bluetooth permissions in system settings.
- Calling it again while a previous request is still pending returns a failure
  with code `PERMISSION_REQUEST_IN_PROGRESS` (the underlying `Future` still
  resolves once the first dialog is answered).

---

## 5. Printing

All print methods return a `PrintResult`. They never throw in normal use —
inspect `result.isSuccess`.

### 5.1 Print an image over Bluetooth

```dart
final result = await ZebraBtPrinter.printImageBluetooth(
  mac: '48:A4:93:DB:04:6F',          // printer MAC address
  imageBase64: base64Image,          // JPG or PNG, base64-encoded (no data: prefix)
  config: const PrinterConfig(
    labelWidthDots: 600,             // 3in @ 200 DPI
    labelHeightDots: 250,
    useSmoothScaling: true,
  ),
);
```

The image is decoded, scaled to fit within `labelWidthDots × labelHeightDots`
(never upscaled), and centered on the label.

### 5.2 Print an image over TCP/IP

```dart
final result = await ZebraBtPrinter.printImageIP(
  ip: '192.168.0.50',                // printer IP, default ZPL port (9100)
  imageBase64: base64Image,
);
```

### 5.3 Print a plain-text label over Bluetooth

```dart
final result = await ZebraBtPrinter.printLabelBluetooth(
  mac: '48:A4:93:DB:04:6F',
  zplText: 'Order #12345',
);
```

The text is wrapped in a minimal ZPL template. For full control over layout,
generate your own label as an image and use `printImageBluetooth`.

---

## 6. Producing the base64 image

`imageBase64` is a base64-encoded JPG/PNG **without** a `data:` URI prefix.

### From an asset

```dart
import 'package:flutter/services.dart';
import 'dart:convert';

final bytes = await rootBundle.load('assets/label.png');
final base64Image = base64Encode(bytes.buffer.asUint8List());
```

### From a file

```dart
import 'dart:io';
import 'dart:convert';

final base64Image = base64Encode(await File(path).readAsBytes());
```

### From a rendered Flutter widget

Use a `RepaintBoundary` + `RenderRepaintBoundary.toImage()` to rasterize a
widget, encode it to PNG bytes, then `base64Encode`. This is the recommended way
to print rich, dynamic labels (logos, barcodes, formatted text).

---

## 7. Choosing label dimensions

Dots = inches × DPI. Most Zebra portable printers are **203 DPI** (often called
"200 DPI").

| Label width | 203 DPI | 300 DPI |
| --- | --- | --- |
| 2 in | 406 dots | 600 dots |
| 3 in | 609 dots | 900 dots |
| 4 in | 812 dots | 1200 dots |

Set `labelWidthDots` / `labelHeightDots` to your physical label size in dots.
The default `600 × 250` suits a ~3 in wide receipt-style label at 203 DPI.

---

## 8. Recommended usage pattern (verified)

This is the flow tested across multiple Android versions. The key on Android 12+
is to **always `await requestPermissions()` and only print once it returns
`true`** — printing before `BLUETOOTH_SCAN`/`BLUETOOTH_CONNECT` are granted is
what triggers the `cancelDiscovery` SecurityException.

```dart
Future<void> printLabel(String mac, String base64Image) async {
  // 1. Request permissions and WAIT for the user's answer.
  //    On Android 12+ this shows the "Nearby devices" dialog.
  final granted = await ZebraBtPrinter.requestPermissions();
  if (!granted) {
    _showError('Bluetooth permissions are required. Enable them in Settings.');
    return;
  }

  // 2. Make sure the Bluetooth adapter is on.
  if (!await ZebraBtPrinter.isBluetoothEnabled()) {
    _showError('Please turn on Bluetooth.');
    return;
  }

  // 3. Print (the plugin opens the connection, prints, and closes it).
  final result = await ZebraBtPrinter.printImageBluetooth(
    mac: mac,
    imageBase64: base64Image,
  );

  // 4. Handle the typed result.
  if (result.isSuccess) {
    _showSuccess('Printed.');
  } else {
    switch (result.errorCode) {
      case 'PERMISSION_DENIED':
        // Permissions were revoked between step 1 and printing.
        _showError('Grant Bluetooth permissions, then try again.');
        break;
      case 'UNSUPPORTED_PLATFORM':
        _showError('Printing is only available on Android.');
        break;
      case 'PRINT_ERROR':
        // Printer off, out of range, or busy with another phone.
        _showError('Could not reach the printer: ${result.errorMessage}');
        break;
      default:
        _showError('Print failed: ${result.errorMessage}');
    }
  }
}
```

> ⚠️ **Don't print before `requestPermissions()` resolves.** On Android 12+ the
> Zebra SDK calls `cancelDiscovery()` while opening the Bluetooth connection,
> which needs `BLUETOOTH_SCAN`. If you print first, you get the error
> *"Need android.permission.BLUETOOTH_SCAN permission … AdapterService
> cancelDiscovery"*.

---

## 9. Error reference

| `errorCode` | When it happens | Suggested handling |
| --- | --- | --- |
| `INVALID_ARGS` | A required argument (mac/ip/image/text) was null or empty. | Validate inputs before calling. |
| `PERMISSION_DENIED` | A Bluetooth print was attempted without `BLUETOOTH_CONNECT`/`BLUETOOTH_SCAN` granted (Android 12+). | Call `requestPermissions()` and have the user accept, then retry. |
| `PRINT_ERROR` | Printer unreachable, off, out of range, or busy with another phone. | Retry, check power/pairing/range. |
| `NO_ACTIVITY` | `requestPermissions()` called with no foreground Activity. | Call from a live screen. |
| `PERMISSION_REQUEST_IN_PROGRESS` | A second permission request overlapped the first. | Await the first call before retrying. |
| `UNSUPPORTED_PLATFORM` | Any call on iOS. | Gate the feature to Android. |

---

## 10. Troubleshooting

**Build fails with "More than one file was found with OS independent path
META-INF/…"** → Add the `packaging` block from [§3.3](#33-packaging-only-if-you-hit-a-merge-error).

**`Need android.permission.BLUETOOTH_SCAN permission … AdapterService
cancelDiscovery`** → You printed before `BLUETOOTH_SCAN` was granted. Make sure
you `await ZebraBtPrinter.requestPermissions()` and it returns `true` *before*
calling any `printImageBluetooth`/`printLabelBluetooth`. This is most common on
Android 12+ (it doesn't happen on Android 11 and below). See [§8](#8-recommended-usage-pattern-verified).

**`requestPermissions()` returns `false` even after granting** → On some OEM
ROMs the user must also grant "Nearby devices". Send the user to App Settings.

**`PRINT_ERROR` immediately** → Verify the printer is powered, paired in Android
Bluetooth settings, and within range. For Bluetooth, the MAC must be the
printer's (format `AA:BB:CC:DD:EE:FF`). For TCP/IP, confirm the device and
printer are on the same network and port 9100 is reachable.

**Image prints too small / off-center** → Match `labelWidthDots` /
`labelHeightDots` to your physical label at the printer's DPI (see [§7](#7-choosing-label-dimensions)).

**Nothing prints but `isSuccess` is true** → The job was sent successfully; check
the printer's media/calibration and that the label format matches the loaded
stock.

---

## 11. FAQ

**Does it discover/scan for nearby printers?** No. You supply the MAC address (or
IP). Use the OS Bluetooth settings or a separate discovery package to obtain it.

**Is iOS supported?** No. Calls fail gracefully so cross-platform apps still
build and run.

**Which printers are supported?** Zebra Link-OS Bluetooth/network printers (ZQ,
ZD, and similar families).

**Can I print raw ZPL?** `printLabelBluetooth` sends a basic text label. For full
ZPL control, render your label to an image and use `printImageBluetooth`.

---

## 12. Connection lifecycle & disconnecting a device

### The plugin disconnects automatically

There is **no persistent connection** to manage and **no `disconnect()` call is
needed**. Every print method follows the same short-lived cycle:

```
open() ─► (cancelDiscovery) ─► write/printImage ─► close()
```

The connection is **always closed** when the job finishes — success or failure
(via an internal `safeClose`). So after each print, your phone is already
disconnected from the printer. This is intentional: Bluetooth Classic (SPP)
printers accept **only one connection at a time**, so holding the connection
open would block every other phone.

### Releasing a printer that's "busy" with another phone

If you get `PRINT_ERROR` because another phone is currently connected, you have
three options:

1. **Wait and retry** — the plugin already retries a few times with a short
   delay. The moment the other phone's job finishes (and its connection closes),
   yours succeeds.
2. **Have the other phone finish its print** — since each job auto-closes, the
   lock is released within seconds.
3. **Power-cycle the printer** — turn it off and on to drop any stuck session
   (last resort, e.g. an app that crashed mid-print).

### Fully unpairing a printer from the phone

"Disconnecting" at the OS level (removing the pairing/bond) is a **system
action**, not something this plugin does. Direct the user to:

**Android Settings → Connected devices / Bluetooth → tap the printer →
Forget / Unpair.**

After unpairing, the next Bluetooth print to that MAC will re-establish the pair
(the system may prompt). There is no app-level API to force-unpair a bonded
device on modern Android without privileged permissions.

### Prefer TCP/IP for shared printers

If several phones must print to the **same** printer frequently, use a
**network-attached** printer and `printImageIP`. The printer queues jobs and
serves multiple clients, so there's no single-connection Bluetooth lock to fight
over.
