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
    expect(result.errorCode, 'PRINT_ERROR');
    expect(result.errorMessage, 'printer offline');
  });

  test('isBluetoothEnabled returns false when the platform throws', () async {
    mockHandler((_) async => throw PlatformException(code: 'UNSUPPORTED'));
    expect(await platform.isBluetoothEnabled(), isFalse);
  });
}
