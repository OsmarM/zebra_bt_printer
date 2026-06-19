import Flutter
import UIKit

/// Stub de iOS: el SDK de Zebra y Honeywell no está disponible para iOS.
/// Todos los métodos devuelven un error UNSUPPORTED_PLATFORM.
public class ZebraBtPrinterPlugin: NSObject, FlutterPlugin {
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "zebra_bt_printer",
            binaryMessenger: registrar.messenger()
        )
        let instance = ZebraBtPrinterPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        result(FlutterError(
            code: "UNSUPPORTED_PLATFORM",
            message: "Zebra/Honeywell Bluetooth printing is not supported on iOS.",
            details: nil
        ))
    }
}
