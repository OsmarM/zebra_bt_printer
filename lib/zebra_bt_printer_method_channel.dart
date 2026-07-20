import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'src/models/print_error_code.dart';
import 'src/models/print_result.dart';
import 'src/models/printer_config.dart';
import 'zebra_bt_printer_platform_interface.dart';

class MethodChannelZebraBtPrinter extends ZebraBtPrinterPlatform {
  @visibleForTesting
  final methodChannel = const MethodChannel('zebra_bt_printer');

  PrintResult _failureFrom(PlatformException e) {
    return PrintResult.failure(
      errorCode: PrintErrorCode.fromNative(e.code),
      errorMessage: e.message ?? 'Error desconocido',
      rawErrorCode: e.code,
    );
  }

  @override
  Future<PrintResult> printImageBluetooth({
    required String mac,
    required String imageBase64,
    PrinterConfig config = const PrinterConfig(),
    int copies = 1,
  }) async {
    try {
      await methodChannel.invokeMethod<void>('printImageBluetooth', {
        'mac': mac,
        'imageBase64': imageBase64,
        'copies': copies.clamp(1, 999),
        ...config.toMap(),
      });
      return const PrintResult.success();
    } on PlatformException catch (e) {
      return _failureFrom(e);
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
      return _failureFrom(e);
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
      return _failureFrom(e);
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

  @override
  Future<bool> connectBluetooth({required String mac}) async {
    final ok = await methodChannel.invokeMethod<bool>('connectBluetooth', {'mac': mac});
    return ok ?? false;
  }

  @override
  Future<bool> disconnectBluetooth({required String mac}) async {
    final ok = await methodChannel.invokeMethod<bool>('disconnectBluetooth', {'mac': mac});
    return ok ?? false;
  }

  @override
  Future<bool> calibratePrinter({required String mac}) async {
    final ok = await methodChannel.invokeMethod<bool>('calibratePrinter', {'mac': mac});
    return ok ?? false;
  }
}
