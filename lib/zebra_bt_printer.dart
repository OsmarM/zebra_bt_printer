library zebra_bt_printer;

export 'src/models/print_result.dart';
export 'src/models/printer_config.dart';
export 'zebra_bt_printer_platform_interface.dart'
    show ZebraBtPrinterPlatform;

import 'src/models/print_result.dart';
import 'src/models/printer_config.dart';
import 'zebra_bt_printer_platform_interface.dart';

/// Punto de entrada principal del plugin.
///
/// Ejemplo de uso:
/// ```dart
/// final result = await ZebraBtPrinter.printImageBluetooth(
///   mac: '48:A4:93:DB:04:6F',
///   imageBase64: myBase64String,
/// );
/// if (result.isSuccess) { ... }
/// ```
class ZebraBtPrinter {
  ZebraBtPrinter._();

  /// Imprime una imagen base64 en una impresora Bluetooth.
  ///
  /// [mac] : Dirección MAC de la impresora (ej. `48:A4:93:DB:04:6F`).
  /// [imageBase64] : Imagen en formato base64 (JPG o PNG).
  /// [config] : Configuración de etiqueta. Por defecto 600×240 dots, Zebra.
  /// [copies] : Número de copias a imprimir en una sola conexión BT (default 1).
  ///
  /// Pasar [copies] > 1 es mucho más eficiente que llamar este método
  /// varias veces, ya que la conexión Bluetooth se abre y cierra una sola vez.
  static Future<PrintResult> printImageBluetooth({
    required String mac,
    required String imageBase64,
    PrinterConfig config = const PrinterConfig(),
    int copies = 1,
  }) {
    return ZebraBtPrinterPlatform.instance.printImageBluetooth(
      mac: mac,
      imageBase64: imageBase64,
      config: config,
      copies: copies,
    );
  }

  /// Imprime una imagen base64 en una impresora conectada por TCP/IP.
  ///
  /// [ip] : Dirección IP de la impresora.
  /// [imageBase64] : Imagen en formato base64.
  /// [config] : Configuración de etiqueta.
  static Future<PrintResult> printImageIP({
    required String ip,
    required String imageBase64,
    PrinterConfig config = const PrinterConfig(),
  }) {
    return ZebraBtPrinterPlatform.instance.printImageIP(
      ip: ip,
      imageBase64: imageBase64,
      config: config,
    );
  }

  /// Imprime texto en formato ZPL en una impresora Bluetooth.
  ///
  /// [mac] : Dirección MAC de la impresora.
  /// [zplText] : Texto plano a imprimir (se envuelve en comandos ZPL básicos).
  static Future<PrintResult> printLabelBluetooth({
    required String mac,
    required String zplText,
  }) {
    return ZebraBtPrinterPlatform.instance.printLabelBluetooth(
      mac: mac,
      zplText: zplText,
    );
  }

  /// Solicita permisos de Bluetooth en tiempo de ejecución (Android 12+).
  /// Devuelve `true` si todos los permisos fueron concedidos.
  static Future<bool> requestPermissions() {
    return ZebraBtPrinterPlatform.instance.requestPermissions();
  }

  /// Verifica si el Bluetooth del dispositivo está activo.
  static Future<bool> isBluetoothEnabled() {
    return ZebraBtPrinterPlatform.instance.isBluetoothEnabled();
  }

  /// Abre una conexión Bluetooth persistente con la impresora [mac].
  ///
  /// Úsalo antes de imprimir múltiples etiquetas seguidas para eliminar el
  /// overhead de conexión (~4-6 s) en cada llamada a [printImageBluetooth].
  ///
  /// ```dart
  /// await ZebraBtPrinter.connectBluetooth(mac: '48:A4:93:DB:04:6F');
  /// for (final label in labels) {
  ///   await ZebraBtPrinter.printImageBluetooth(mac: '48:A4:93:DB:04:6F', ...);
  /// }
  /// await ZebraBtPrinter.disconnectBluetooth(mac: '48:A4:93:DB:04:6F');
  /// ```
  static Future<bool> connectBluetooth({required String mac}) {
    return ZebraBtPrinterPlatform.instance.connectBluetooth(mac: mac);
  }

  /// Cierra la conexión Bluetooth persistente con la impresora [mac].
  /// Llámalo siempre al terminar la sesión de impresión.
  static Future<bool> disconnectBluetooth({required String mac}) {
    return ZebraBtPrinterPlatform.instance.disconnectBluetooth(mac: mac);
  }
}
