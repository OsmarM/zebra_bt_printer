import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zebra_bt_printer/zebra_bt_printer.dart';
import 'package:zebra_bt_printer/zebra_bt_printer_method_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final MethodChannelZebraBtPrinter platform = MethodChannelZebraBtPrinter();
  const MethodChannel channel = MethodChannel('zebra_bt_printer');

  final List<MethodCall> log = <MethodCall>[];

  void mockHandler(Future<Object?>? Function(MethodCall) handler) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) {
      log.add(call);
      return handler(call);
    });
  }

  setUp(log.clear);

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('printImageBluetooth marshals mac, image and config', () async {
    mockHandler((_) async => true);

    final result = await platform.printImageBluetooth(
      mac: 'AA:BB:CC:DD:EE:FF',
      imageBase64: 'AAAA',
      config: const PrinterConfig(labelWidthDots: 800, labelHeightDots: 400),
    );

    expect(result.isSuccess, isTrue);
    expect(log.single.method, 'printImageBluetooth');
    final args = log.single.arguments as Map;
    expect(args['mac'], 'AA:BB:CC:DD:EE:FF');
    expect(args['imageBase64'], 'AAAA');
    expect(args['labelWidthDots'], 800);
    expect(args['labelHeightDots'], 400);
  });

  test('PlatformException is mapped to PrintResult.failure', () async {
    mockHandler((_) async => throw PlatformException(
          code: 'PRINT_ERROR',
          message: 'printer offline',
        ));

    final result = await platform.printImageBluetooth(
      mac: 'AA:BB:CC:DD:EE:FF',
      imageBase64: 'AAAA',
    );

    expect(result.isSuccess, isFalse);
    expect(result.errorCode, PrintErrorCode.printError);
    expect(result.errorMessage, 'printer offline');
    expect(result.userMessage, PrintErrorCode.printError.userMessage);
    expect(result.rawErrorCode, 'PRINT_ERROR');
  });

  test('unknown PlatformException code maps to PrintErrorCode.unknown', () async {
    mockHandler((_) async => throw PlatformException(
          code: 'SOMETHING_NEW',
          message: 'future native error',
        ));

    final result = await platform.printImageBluetooth(
      mac: 'AA:BB:CC:DD:EE:FF',
      imageBase64: 'AAAA',
    );

    expect(result.isSuccess, isFalse);
    expect(result.errorCode, PrintErrorCode.unknown);
    expect(result.rawErrorCode, 'SOMETHING_NEW');
    expect(result.userMessage, PrintErrorCode.unknown.userMessage);
  });

  test('PAPER_OUT PlatformException maps to PrintErrorCode.paperOut', () async {
    mockHandler((_) async => throw PlatformException(
          code: 'PAPER_OUT',
          message: 'La impresora reporta sin papel (isPaperOut)',
        ));

    final result = await platform.printImageBluetooth(
      mac: 'AA:BB:CC:DD:EE:FF',
      imageBase64: 'AAAA',
    );

    expect(result.isSuccess, isFalse);
    expect(result.errorCode, PrintErrorCode.paperOut);
    expect(result.rawErrorCode, 'PAPER_OUT');
    expect(result.userMessage, PrintErrorCode.paperOut.userMessage);
  });

  test('PRINT_TIMEOUT PlatformException maps to PrintErrorCode.printTimeout',
      () async {
    mockHandler((_) async => throw PlatformException(
          code: 'PRINT_TIMEOUT',
          message: 'Timeout esperando fin de lote',
        ));

    final result = await platform.printImageBluetooth(
      mac: 'AA:BB:CC:DD:EE:FF',
      imageBase64: 'AAAA',
    );

    expect(result.isSuccess, isFalse);
    expect(result.errorCode, PrintErrorCode.printTimeout);
    expect(result.rawErrorCode, 'PRINT_TIMEOUT');
    expect(result.userMessage, PrintErrorCode.printTimeout.userMessage);
  });

  test('isBluetoothEnabled returns false when the platform throws', () async {
    mockHandler((_) async => throw PlatformException(code: 'UNSUPPORTED'));
    expect(await platform.isBluetoothEnabled(), isFalse);
  });
}
