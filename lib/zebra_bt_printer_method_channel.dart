import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'src/models/print_result.dart';
import 'src/models/printer_config.dart';
import 'zebra_bt_printer_platform_interface.dart';

class MethodChannelZebraBtPrinter extends ZebraBtPrinterPlatform {
  @visibleForTesting
  final methodChannel = const MethodChannel('zebra_bt_printer');

  @override
  Future<PrintResult> printImageBluetooth({
    required String mac,
    required String imageBase64,
    PrinterConfig config = const PrinterConfig(),
  }) async {
    try {
      await methodChannel.invokeMethod<void>('printImageBluetooth', {
        'mac': mac,
        'imageBase64': imageBase64,
        ...config.toMap(),
      });
      return const PrintResult.success();
    } on PlatformException catch (e) {
      return PrintResult.failure(
        errorMessage: e.message ?? 'Error desconocido',
        errorCode: e.code,
      );
    }
  }

  @override
  Future<PrintResult> printImageIP({
    required String ip,
    required String imageBase64,
    PrinterConfig config = const PrinterConfig(),
  }) async {
    try {
      await methodChannel.invokeMethod<void>('printImageIP', {
        'ip': ip,
        'imageBase64': imageBase64,
        ...config.toMap(),
      });
      return const PrintResult.success();
    } on PlatformException catch (e) {
      return PrintResult.failure(
        errorMessage: e.message ?? 'Error desconocido',
        errorCode: e.code,
      );
    }
  }

  @override
  Future<PrintResult> printLabelBluetooth({
    required String mac,
    required String zplText,
  }) async {
    try {
      await methodChannel.invokeMethod<void>('printLabelBluetooth', {
        'mac': mac,
        'zplText': zplText,
      });
      return const PrintResult.success();
    } on PlatformException catch (e) {
      return PrintResult.failure(
        errorMessage: e.message ?? 'Error desconocido',
        errorCode: e.code,
      );
    }
  }

  @override
  Future<bool> requestPermissions() async {
    final granted = await methodChannel.invokeMethod<bool>('requestPermissions');
    return granted ?? false;
  }

  @override
  Future<bool> isBluetoothEnabled() async {
    final enabled = await methodChannel.invokeMethod<bool>('isBluetoothEnabled');
    return enabled ?? false;
  }
}
