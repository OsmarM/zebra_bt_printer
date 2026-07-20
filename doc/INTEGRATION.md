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
plugin is a stub: print calls return `PrintResult.failure` with
`PrintErrorCode.unsupportedPlatform`, and `requestPermissions()` / `isBluetoothEnabled()`
return `false`. Your code does not need iOS-specific branching — just check
`isSuccess`.

---

## 2. Add the dependency

In your app's `pubspec.yaml`:

```yaml
dependencies:
  zebra_bt_printer:
    git:
      url: https://github.com/OsmarM/zebra_bt_printer.git
      ref: v1.4.0        # pin to a tag/commit for reproducible builds
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
  if (!granted) return false;
  return ZebraBtPrinter.isBluetoothEnabled();
}
```

- `requestPermissions()` shows the system dialog and resolves to `true` only
  when **all** required permissions are granted.
- If the user denies, returns `false` — surface a message asking them to enable
  Bluetooth permissions in system settings.

---

## 5. Label configuration (`PrinterConfig`)

All print methods accept an optional `PrinterConfig`:

```dart
const PrinterConfig({
  int    labelWidthDots   = 600,                 // label width in dots
  int    labelHeightDots  = 240,                 // label height in dots
  bool   useSmoothScaling = true,                // anti-aliasing when scaling
  PrinterType    printerType = PrinterType.zebra,
  LabelMediaType mediaType   = LabelMediaType.gap,
  bool   allowUpscale        = false,
  int?   maxLabelLengthDots,                     // ^ML (default: labelHeightDots × 2)
  int    labelTopOffset      = 0,                // ^LT vertical offset in dots
})
```

### 5.1 Dimensions (dots)

`dots = inches × DPI`. Most Zebra portable printers are **203 DPI** (often called
"200 DPI").

| Label size | Width | Height | Width dots | Height dots |
| --- | --- | --- | --- | --- |
| 3" × 1.2" | 3 in | 1.2 in | 600 | 240 |
| 3" × 3" | 3 in | 3 in | 600 | 600 |
| 4" × 6" | 4 in | 6 in | 812 | 1218 |

### 5.2 Media type (`LabelMediaType`)

Controls how the printer detects the end of each label:

| Value | ZPL command | When to use |
| --- | --- | --- |
| `LabelMediaType.gap` | `^MNA` | Die-cut labels with a physical gap between them (**default**) |
| `LabelMediaType.mark` | `^MNB` | Labels with a black mark printed on the back of the roll |
| `LabelMediaType.none` | `^MNN` | No physical sensing; length controlled only by `^LL` |

> **Important when using `mark`:** every time you load a roll of a different
> size you must call `calibratePrinter()` so the printer measures the new mark
> spacing. See [§8](#8-roll-change--calibration).

### 5.3 Advanced parameters

| Parameter | Description |
| --- | --- |
| `allowUpscale` | Allow the image to be scaled up if it is smaller than the label area. Default `false`. |
| `maxLabelLengthDots` | Maximum distance the printer travels looking for the next mark/gap (`^ML`). Default: `labelHeightDots × 2`. |
| `labelTopOffset` | Vertical offset of the print area relative to the mark (`^LT`, in dots). Positive = image lower; negative = image higher. |

---

## 6. Printing

All print methods return a `PrintResult`. They never throw in normal use —
inspect `result.isSuccess`.

### 6.1 Print an image over Bluetooth

```dart
final result = await ZebraBtPrinter.printImageBluetooth(
  mac: '48:A4:93:DB:04:6F',
  imageBase64: base64Image,
  config: const PrinterConfig(
    labelWidthDots:  600,
    labelHeightDots: 240,
    mediaType: LabelMediaType.gap,
  ),
  copies: 1,  // number of copies in a single BT connection
);
```

The `copies` parameter prints N copies **within the same Bluetooth connection**,
which is far more efficient than calling the method N times (see [§9](#9-performance--batch-printing)).

### 6.2 Print an image over TCP/IP

```dart
final result = await ZebraBtPrinter.printImageIP(
  ip: '192.168.0.50',
  imageBase64: base64Image,
  config: const PrinterConfig(
    labelWidthDots:  600,
    labelHeightDots: 240,
  ),
);
```

### 6.3 Print a plain-text label over Bluetooth

```dart
final result = await ZebraBtPrinter.printLabelBluetooth(
  mac: '48:A4:93:DB:04:6F',
  zplText: 'Order #12345',
);
```

---

## 7. Producing the base64 image

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

> **Resolution tip:** generate the image at exactly `labelWidthDots × labelHeightDots`
> pixels. For example, a 3×3" label at 200 DPI needs a 600×600 px canvas.
> This avoids any scaling and maximizes print quality.

---

## 8. Roll change & calibration

When the operator loads a **different roll size or media type**, the printer must
be calibrated once so it learns the new label spacing.

```dart
// Configs for each roll type
const configSmall = PrinterConfig(
  labelWidthDots:  600,
  labelHeightDots: 240,
  mediaType: LabelMediaType.gap,   // standard die-cut label
);

const configLarge = PrinterConfig(
  labelWidthDots:  600,
  labelHeightDots: 600,
  mediaType: LabelMediaType.mark,  // roll with black marks on the back
);

/// Call ONCE when loading a new roll.
/// The printer feeds 1-2 labels to measure the mark spacing (~3 s).
Future<void> calibratePrinter(String mac) async {
  final ok = await ZebraBtPrinter.calibratePrinter(mac: mac);
  if (!ok) throw Exception('Could not calibrate the printer');
}

/// Full flow when switching to the large black-mark roll.
Future<void> switchToLargeLabel(String mac, String base64Image) async {
  await calibratePrinter(mac);     // ← only once per roll change
  final result = await ZebraBtPrinter.printImageBluetooth(
    mac: mac,
    imageBase64: base64Image,
    config: configLarge,
  );
  if (!result.isSuccess) throw Exception(result.errorMessage);
}

/// Full flow when switching to the small gap roll (no calibration needed).
Future<void> switchToSmallLabel(String mac, String base64Image) async {
  final result = await ZebraBtPrinter.printImageBluetooth(
    mac: mac,
    imageBase64: base64Image,
    config: configSmall,
  );
  if (!result.isSuccess) throw Exception(result.errorMessage);
}
```

> Calibration is **stored in the printer**. It does not need to be repeated on
> every print — only when a different roll is loaded.

---

## 9. Performance — batch printing

Opening and closing a Bluetooth connection takes ~4-6 seconds. For multiple
labels use `copies` or a persistent connection:

### Option A — `copies` (same design, N copies)

```dart
await ZebraBtPrinter.printImageBluetooth(
  mac: mac,
  imageBase64: base64Image,
  config: configSmall,
  copies: 5,  // 5 copies, 1 BT connection
);
```

### Option B — persistent connection (different designs)

```dart
await ZebraBtPrinter.connectBluetooth(mac: mac);
try {
  for (final label in batch) {
    await ZebraBtPrinter.printImageBluetooth(
      mac: mac,
      imageBase64: label.base64,
      config: configSmall,
    );
  }
} finally {
  await ZebraBtPrinter.disconnectBluetooth(mac: mac);
}
```

| Scenario | Approx. time |
| --- | --- |
| 1 label (no prior connection) | ~6-8 s |
| 5 labels with `copies: 5` | ~9-11 s |
| 5 labels with persistent connection | ~11-13 s |
| 5 labels without optimization (5 calls) | ~30-40 s |

---

## 10. Recommended usage pattern (verified)

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

  // 3. Print.
  final result = await ZebraBtPrinter.printImageBluetooth(
    mac: mac,
    imageBase64: base64Image,
    config: const PrinterConfig(
      labelWidthDots:  600,
      labelHeightDots: 240,
      mediaType: LabelMediaType.gap,
    ),
  );

  // 4. Handle the typed result.
  if (result.isSuccess) {
    _showSuccess('Printed.');
  } else {
    // userMessage: stable text for UI
    _showError(result.userMessage!);
    // errorMessage / rawErrorCode: technical detail for logs
    debugPrint('[${result.rawErrorCode}] ${result.errorMessage}');

    // Optional: branch on the typed code
    switch (result.errorCode) {
      case PrintErrorCode.permissionDenied:
        // open Settings, etc.
        break;
      case PrintErrorCode.printError:
        // retry, etc.
        break;
      default:
        break;
    }
  }
}
```

---

## 11. Error reference

Print methods map the native code to a typed [PrintErrorCode].
Use `result.userMessage` in the UI and `result.errorMessage` in logs.

| `PrintErrorCode` | Native code | When it happens | Suggested handling |
| --- | --- | --- | --- |
| `invalidArgs` | `INVALID_ARGS` | A required argument (mac/ip/image/text) was null or empty. | Validate inputs before calling. |
| `permissionDenied` | `PERMISSION_DENIED` | A Bluetooth print was attempted without `BLUETOOTH_CONNECT`/`BLUETOOTH_SCAN` granted. | Call `requestPermissions()` and retry. |
| `printError` | `PRINT_ERROR` | Printer unreachable, off, out of range, or busy. | Retry, check power/pairing/range. |
| `connectError` | `CONNECT_ERROR` | `connectBluetooth()` could not open the persistent connection. | Verify the printer is on and in range. |
| `calibrateError` | `CALIBRATE_ERROR` | `calibratePrinter()` failed to send `~JC`. | Check connection and retry. |
| `disconnectError` | `DISCONNECT_ERROR` | Failed to close the persistent connection. | Retry disconnect; ignore if already closed. |
| `noActivity` | `NO_ACTIVITY` | `requestPermissions()` called with no foreground Activity. | Call from a live screen. |
| `permissionRequestInProgress` | `PERMISSION_REQUEST_IN_PROGRESS` | A second permission request overlapped the first. | Await the first call before retrying. |
| `unsupportedPlatform` | `UNSUPPORTED_PLATFORM` | Any call on iOS. | Gate the feature to Android. |
| `unknown` | *(unrecognized code)* | New or unexpected native code. | Show `userMessage`; log `rawErrorCode`. |

---

## 12. Troubleshooting

**Build fails with "More than one file was found with OS independent path META-INF/…"**
→ Add the `packaging` block from [§3.3](#33-packaging-only-if-you-hit-a-merge-error).

**`Need android.permission.BLUETOOTH_SCAN permission … cancelDiscovery`**
→ You printed before `BLUETOOTH_SCAN` was granted. Make sure you
`await ZebraBtPrinter.requestPermissions()` and it returns `true` *before*
printing. See [§10](#10-recommended-usage-pattern-verified).

**`PRINT_ERROR` immediately**
→ Verify the printer is powered, paired in Android Bluetooth settings, and within range.

**Label cuts too early with `LabelMediaType.mark`**
→ The printer has the previous roll's calibration stored. Call
`calibratePrinter()` with the new roll loaded. See [§8](#8-roll-change--calibration).

**Image prints complete but spans across two labels**
→ Use `LabelMediaType.mark` (with prior calibration) or `LabelMediaType.gap`
instead of `none`. Also verify `labelHeightDots` matches the physical roll size.

**Image prints small / centered with blank space**
→ The base64 image has fewer pixels than the label's dot dimensions. Generate
the image at exactly `labelWidthDots × labelHeightDots` pixels, or enable
`allowUpscale: true`.

**Nothing prints but `isSuccess` is true**
→ The job was sent successfully; check the printer's media/calibration and that
the label format matches the loaded stock.

---

## 13. FAQ

**Does it discover/scan for nearby printers?** No. You supply the MAC address (or
IP). Use the OS Bluetooth settings or a separate discovery package to obtain it.

**Is iOS supported?** No. Calls fail gracefully so cross-platform apps still
build and run.

**Which printers are supported?** Zebra Link-OS Bluetooth/network printers (ZQ,
ZD, and similar families).

**Can I print raw ZPL?** `printLabelBluetooth` sends a basic text label. For full
ZPL control, render your label to an image and use `printImageBluetooth`.

**What DPI is my printer?** Zebra ZQ and ZD portable printers are typically
203 DPI. You can confirm by printing the configuration label (hold the feed button
while powering on).

---

## 14. Connection lifecycle

### Auto connection (default)

Without calling `connectBluetooth`, each print follows the short-lived cycle:

```
open() ─► cancelDiscovery ─► write ZPL ─► close()
```

### Persistent connection

With `connectBluetooth` / `disconnectBluetooth` the connection stays open
between prints. See [§9](#9-performance--batch-printing).

### Releasing a busy printer

If you get `PRINT_ERROR` because another phone is connected:

1. **Wait and retry** — the plugin already retries automatically.
2. **Have the other phone finish** — the connection closes itself when the job ends.
3. **Power-cycle the printer** — last resort for stuck sessions.
