## 1.5.0

* Breaking: `PrintResult.errorCode` is now a typed `PrintErrorCode` enum
  instead of a raw `String?`.
* Added stable `userMessage` for UI and kept `errorMessage` / `rawErrorCode`
  for technical logging.
* Unknown native codes map to `PrintErrorCode.unknown`.

## 1.0.0

* Print base64 images to Zebra printers over Bluetooth and TCP/IP (auto-scaled
  and centered).
* Print plain-text labels as basic ZPL over Bluetooth.
* Runtime Bluetooth permission handling for Android 12+ and legacy devices.
* Typed `PrintResult` return values and a `PrinterConfig` for label sizing.
* Graceful iOS stub: unsupported operations fail or return `false` instead of
  throwing.
* Integration guide for consuming teams (`doc/INTEGRATION.md`).
