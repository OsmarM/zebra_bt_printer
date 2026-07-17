import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'src/models/print_result.dart';
import 'src/models/printer_config.dart';
import 'zebra_bt_printer_method_channel.dart';

export 'src/models/print_result.dart';
export 'src/models/printer_config.dart';

abstract class ZebraBtPrinterPlatform extends PlatformInterface {
  ZebraBtPrinterPlatform() : super(token: _token);

  static final Object _token = Object();

  static ZebraBtPrinterPlatform _instance = MethodChannelZebraBtPrinter();

  static ZebraBtPrinterPlatform get instance => _instance;

  static set instance(ZebraBtPrinterPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// Imprime una imagen [imageBase64] en la impresora Bluetooth con dirección [mac].
  /// [copies] indica cuántas copias imprimir dentro de una sola conexión BT.
  Future<PrintResult> printImageBluetooth({
    required String mac,
    required String imageBase64,
    PrinterConfig config = const PrinterConfig(),
    int copies = 1,
  }) {
    throw UnimplementedError('printImageBluetooth() has not been implemented.');
  }

  /// Imprime una imagen [imageBase64] en la impresora IP con dirección [ip].
  Future<PrintResult> printImageIP({
    required String ip,
    required String imageBase64,
    PrinterConfig config = const PrinterConfig(),
  }) {
    throw UnimplementedError('printImageIP() has not been implemented.');
  }

  /// Imprime texto ZPL en la impresora Bluetooth con dirección [mac].
  Future<PrintResult> printLabelBluetooth({
    required String mac,
    required String zplText,
  }) {
    throw UnimplementedError('printLabelBluetooth() has not been implemented.');
  }

  /// Solicita los permisos de Bluetooth en tiempo de ejecución (Android 12+).
  Future<bool> requestPermissions() {
    throw UnimplementedError('requestPermissions() has not been implemented.');
  }

  /// Verifica si el Bluetooth del dispositivo está activo.
  Future<bool> isBluetoothEnabled() {
    throw UnimplementedError('isBluetoothEnabled() has not been implemented.');
  }

  /// Abre y mantiene una conexión Bluetooth persistente con la impresora [mac].
  ///
  /// Llamar a este método antes de imprimir múltiples etiquetas consecutivas
  /// elimina el overhead de open/close (~4-6 s) por impresión.
  /// Cuando termines de imprimir llama a [disconnectBluetooth].
  Future<bool> connectBluetooth({required String mac}) {
    throw UnimplementedError('connectBluetooth() has not been implemented.');
  }

  /// Cierra la conexión Bluetooth persistente con la impresora [mac].
  Future<bool> disconnectBluetooth({required String mac}) {
    throw UnimplementedError('disconnectBluetooth() has not been implemented.');
  }

  /// Calibra el sensor de media de la impresora (comando ZPL `~JC`).
  /// Llamar una vez al cambiar el tipo o tamaño del rollo de etiquetas.
  Future<bool> calibratePrinter({required String mac}) {
    throw UnimplementedError('calibratePrinter() has not been implemented.');
  }
}
