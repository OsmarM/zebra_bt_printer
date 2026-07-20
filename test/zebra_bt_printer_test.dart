import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:zebra_bt_printer/zebra_bt_printer.dart';
import 'package:zebra_bt_printer/zebra_bt_printer_method_channel.dart';

/// Plataforma falsa que registra las llamadas recibidas para poder verificarlas.
class MockZebraBtPrinterPlatform
    with MockPlatformInterfaceMixin
    implements ZebraBtPrinterPlatform {
  String? lastMethod;
  Map<String, dynamic> lastArgs = {};

  @override
  Future<PrintResult> printImageBluetooth({
    required String mac,
    required String imageBase64,
    PrinterConfig config = const PrinterConfig(),
    int copies = 1,
  }) async {
    lastMethod = 'printImageBluetooth';
    lastArgs = {
      'mac': mac,
      'imageBase64': imageBase64,
      'config': config,
      'copies': copies,
    };
    return const PrintResult.success();
  }

  @override
  Future<PrintResult> printImageIP({
    required String ip,
    required String imageBase64,
    PrinterConfig config = const PrinterConfig(),
  }) async {
    lastMethod = 'printImageIP';
    lastArgs = {'ip': ip, 'imageBase64': imageBase64, 'config': config};
    return const PrintResult.failure(
      errorCode: PrintErrorCode.printError,
      errorMessage: 'boom',
      rawErrorCode: 'PRINT_ERROR',
    );
  }

  @override
  Future<PrintResult> printLabelBluetooth({
    required String mac,
    required String zplText,
  }) async {
    lastMethod = 'printLabelBluetooth';
    lastArgs = {'mac': mac, 'zplText': zplText};
    return const PrintResult.success();
  }

  @override
  Future<bool> requestPermissions() async => true;

  @override
  Future<bool> isBluetoothEnabled() async => true;

  @override
  Future<bool> connectBluetooth({required String mac}) async => true;

  @override
  Future<bool> disconnectBluetooth({required String mac}) async => true;

  @override
  Future<bool> calibratePrinter({required String mac}) async => true;
}

void main() {
  final ZebraBtPrinterPlatform initialPlatform =
      ZebraBtPrinterPlatform.instance;

  test('MethodChannelZebraBtPrinter is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelZebraBtPrinter>());
  });

  group('ZebraBtPrinter facade delegates to the platform', () {
    late MockZebraBtPrinterPlatform fake;

    setUp(() {
      fake = MockZebraBtPrinterPlatform();
      ZebraBtPrinterPlatform.instance = fake;
    });

    test('printImageBluetooth forwards args and returns success', () async {
      final result = await ZebraBtPrinter.printImageBluetooth(
        mac: '48:A4:93:DB:04:6F',
        imageBase64: 'AAAA',
      );

      expect(result.isSuccess, isTrue);
      expect(fake.lastMethod, 'printImageBluetooth');
      expect(fake.lastArgs['mac'], '48:A4:93:DB:04:6F');
    });

    test('printImageIP surfaces failures', () async {
      final result = await ZebraBtPrinter.printImageIP(
        ip: '192.168.0.10',
        imageBase64: 'AAAA',
      );

      expect(result.isSuccess, isFalse);
      expect(result.errorCode, PrintErrorCode.printError);
      expect(result.errorMessage, 'boom');
      expect(result.userMessage, PrintErrorCode.printError.userMessage);
      expect(result.rawErrorCode, 'PRINT_ERROR');
    });

    test('requestPermissions / isBluetoothEnabled delegate', () async {
      expect(await ZebraBtPrinter.requestPermissions(), isTrue);
      expect(await ZebraBtPrinter.isBluetoothEnabled(), isTrue);
    });
  });

  group('PrintErrorCode', () {
    test('fromNative maps known codes', () {
      expect(
        PrintErrorCode.fromNative('PRINT_ERROR'),
        PrintErrorCode.printError,
      );
      expect(
        PrintErrorCode.fromNative('PERMISSION_DENIED'),
        PrintErrorCode.permissionDenied,
      );
    });

    test('fromNative maps unknown / null to unknown', () {
      expect(PrintErrorCode.fromNative(null), PrintErrorCode.unknown);
      expect(PrintErrorCode.fromNative(''), PrintErrorCode.unknown);
      expect(PrintErrorCode.fromNative('FOO'), PrintErrorCode.unknown);
    });

    test('userMessage is stable and non-empty', () {
      for (final code in PrintErrorCode.values) {
        expect(code.userMessage, isNotEmpty);
        expect(code.nativeCode, isNotEmpty);
      }
    });
  });

  group('PrinterConfig', () {
    test('defaults serialize to a map', () {
      const config = PrinterConfig();
      final map = config.toMap();

      expect(map['labelWidthDots'], 600);
      expect(map['labelHeightDots'], 240);
      expect(map['useSmoothScaling'], true);
    });

    test('custom values serialize', () {
      const config = PrinterConfig(
        labelWidthDots: 800,
        labelHeightDots: 400,
        useSmoothScaling: false,
      );
      final map = config.toMap();

      expect(map['labelWidthDots'], 800);
      expect(map['labelHeightDots'], 400);
      expect(map['useSmoothScaling'], false);
    });
  });
}
