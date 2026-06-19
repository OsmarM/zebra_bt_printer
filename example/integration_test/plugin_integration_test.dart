// Basic Flutter integration test.
//
// Since integration tests run in a full Flutter application, they can interact
// with the host side of the plugin implementation, unlike Dart unit tests.
//
// For more information, see https://flutter.dev/to/integration-testing

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:zebra_bt_printer/zebra_bt_printer.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('isBluetoothEnabled returns a boolean from the host',
      (WidgetTester tester) async {
    // We can't guarantee Bluetooth state on a CI device, but the call must
    // complete with a real boolean instead of throwing or hanging.
    final bool enabled = await ZebraBtPrinter.isBluetoothEnabled();
    expect(enabled, isA<bool>());
  });
}
