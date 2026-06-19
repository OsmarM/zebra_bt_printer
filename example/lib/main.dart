import 'package:flutter/material.dart';
import 'package:zebra_bt_printer/zebra_bt_printer.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'zebra_bt_printer example',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo),
      home: const PrinterDemoPage(),
    );
  }
}

class PrinterDemoPage extends StatefulWidget {
  const PrinterDemoPage({super.key});

  @override
  State<PrinterDemoPage> createState() => _PrinterDemoPageState();
}

class _PrinterDemoPageState extends State<PrinterDemoPage> {
  final _macController = TextEditingController(text: '48:A4:93:DB:04:6F');
  final _zplController = TextEditingController(text: 'Hello from Flutter');

  String _status = 'Idle';
  bool _busy = false;

  @override
  void dispose() {
    _macController.dispose();
    _zplController.dispose();
    super.dispose();
  }

  Future<void> _run(String label, Future<PrintResult> Function() action) async {
    setState(() {
      _busy = true;
      _status = '$label…';
    });
    final result = await action();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _status = result.isSuccess
          ? '$label: OK'
          : '$label: ${result.errorCode} – ${result.errorMessage}';
    });
  }

  Future<void> _checkBluetooth() async {
    final granted = await ZebraBtPrinter.requestPermissions();
    final enabled = await ZebraBtPrinter.isBluetoothEnabled();
    if (!mounted) return;
    setState(() {
      _status = 'permissions=$granted, bluetoothEnabled=$enabled';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('zebra_bt_printer example')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _macController,
              decoration: const InputDecoration(
                labelText: 'Printer MAC address',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _zplController,
              decoration: const InputDecoration(
                labelText: 'Label text (ZPL)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: _busy ? null : _checkBluetooth,
              child: const Text('Check permissions & Bluetooth'),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _busy
                  ? null
                  : () => _run(
                        'printLabelBluetooth',
                        () => ZebraBtPrinter.printLabelBluetooth(
                          mac: _macController.text.trim(),
                          zplText: _zplController.text,
                        ),
                      ),
              child: const Text('Print text label (Bluetooth)'),
            ),
            const SizedBox(height: 24),
            if (_busy) const LinearProgressIndicator(),
            const SizedBox(height: 8),
            Text('Status: $_status'),
          ],
        ),
      ),
    );
  }
}
