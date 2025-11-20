import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'dart:async';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Color Picker',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const ColorPickerPage(),
    );
  }
}

class ColorPickerPage extends StatefulWidget {
  const ColorPickerPage({super.key});

  @override
  State<ColorPickerPage> createState() => _ColorPickerPageState();
}

class _ColorPickerPageState extends State<ColorPickerPage> {
  Color currentColor = Colors.red;
  
  // BLE variables
  BluetoothDevice? connectedDevice;
  BluetoothCharacteristic? targetCharacteristic;
  bool isScanning = false;
  bool isConnected = false;
  List<ScanResult> scanResults = [];
  
  // Optimized queue management for color updates
  Color? _lastSentColor;
  Color? _pendingColor;
  bool _isSending = false;
  
  static const String serviceUuid = "4fafc201-1fb5-459e-8fcc-c5c9c331914b";
  static const String characteristicUuid = "beb5483e-36e1-4688-b7f5-ea07361b26a8";

  @override
  void initState() {
    super.initState();
    _checkBluetoothState();
  }

  @override
  void dispose() {
    connectedDevice?.disconnect();
    super.dispose();
  }

  Future<void> _checkBluetoothState() async {
    if (await FlutterBluePlus.isSupported == false) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bluetooth not supported on this device')),
      );
    }
  }

  Future<void> _startScan() async {
    setState(() {
      scanResults.clear();
      isScanning = true;
    });

    try {
      // Only scan for devices with names (filters out most unknown devices)
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 4),
        withNames: ["ESP32-LED-Controller"], // Only show our device
      );
      
      FlutterBluePlus.scanResults.listen((results) {
        setState(() {
          // Filter out devices without names
          scanResults = results.where((r) => 
            r.device.platformName.isNotEmpty || 
            r.advertisementData.localName.isNotEmpty
          ).toList();
        });
      });

      await Future.delayed(const Duration(seconds: 4));
      await FlutterBluePlus.stopScan();
      setState(() => isScanning = false);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error scanning: $e')),
      );
      setState(() => isScanning = false);
    }
  }

  Future<void> _connectToDevice(BluetoothDevice device) async {
    try {
      await device.connect(license: License.free);
      setState(() {
        connectedDevice = device;
        isConnected = true;
      });

      // Discover services
      List<BluetoothService> services = await device.discoverServices();
      
      for (var service in services) {
        if (service.uuid.toString() == serviceUuid) {
          for (var characteristic in service.characteristics) {
            if (characteristic.uuid.toString() == characteristicUuid) {
              targetCharacteristic = characteristic;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Connected successfully!')),
              );
              return;
            }
          }
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Service/Characteristic not found')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Connection failed: $e')),
      );
      setState(() => isConnected = false);
    }
  }

  Future<void> _disconnect() async {
    await connectedDevice?.disconnect();
    setState(() {
      connectedDevice = null;
      targetCharacteristic = null;
      isConnected = false;
    });
  }

  Future<void> _sendColorToDevice(Color color) async {
    if (targetCharacteristic == null) return;

    _pendingColor = color;
    
    // If already processing, let the current loop handle it
    if (_isSending) return;

    _isSending = true;
    
    try {
      // Keep sending while there are pending colors
      while (_pendingColor != null) {
        final colorToSend = _pendingColor!;
        
        // Skip if same as last sent (optimization)
        if (_lastSentColor != null && 
            _lastSentColor!.red == colorToSend.red &&
            _lastSentColor!.green == colorToSend.green &&
            _lastSentColor!.blue == colorToSend.blue) {
          _pendingColor = null;
          break;
        }
        
        _pendingColor = null;
        String rgbString = "${colorToSend.red},${colorToSend.green},${colorToSend.blue}";
        
        await targetCharacteristic!.write(rgbString.codeUnits);
        
        _lastSentColor = colorToSend;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sending color: $e')),
        );
      }
    } finally {
      _isSending = false;
    }
  }

  void changeColor(Color color) {
    setState(() => currentColor = color);
    _sendColorToDevice(color);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('BLE LED Controller'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.bluetooth),
            onPressed: () => _showBluetoothDialog(),
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Connection status
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isConnected ? Colors.green.shade100 : Colors.red.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
                      color: isConnected ? Colors.green : Colors.red,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isConnected ? 'Connected: ${connectedDevice?.platformName}' : 'Not Connected',
                      style: TextStyle(
                        color: isConnected ? Colors.green.shade900 : Colors.red.shade900,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Color preview box
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: currentColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey, width: 2),
                ),
              ),
              const SizedBox(height: 30),
              
              // Color wheel picker
              ColorPicker(
                pickerColor: currentColor,
                onColorChanged: changeColor,
                pickerAreaHeightPercent: 0.8,
                displayThumbColor: true,
                enableAlpha: false,
                labelTypes: const [],
              ),
              
              const SizedBox(height: 30),
              
              // RGB Sliders
              _buildRGBSliders(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRGBSliders() {
    return Column(
      children: [
        // Red Slider
        Row(
          children: [
            const SizedBox(
              width: 40,
              child: Text('R:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            Expanded(
              child: Slider(
                value: currentColor.red.toDouble(),
                min: 0,
                max: 255,
                divisions: 255,
                activeColor: Colors.red,
                label: currentColor.red.toString(),
                onChanged: (value) {
                  Color newColor = Color.fromARGB(
                    255,
                    value.toInt(),
                    currentColor.green,
                    currentColor.blue,
                  );
                  changeColor(newColor);
                },
              ),
            ),
            SizedBox(
              width: 50,
              child: Text(
                currentColor.red.toString(),
                style: const TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
        
        // Green Slider
        Row(
          children: [
            const SizedBox(
              width: 40,
              child: Text('G:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            Expanded(
              child: Slider(
                value: currentColor.green.toDouble(),
                min: 0,
                max: 255,
                divisions: 255,
                activeColor: Colors.green,
                label: currentColor.green.toString(),
                onChanged: (value) {
                  Color newColor = Color.fromARGB(
                    255,
                    currentColor.red,
                    value.toInt(),
                    currentColor.blue,
                  );
                  changeColor(newColor);
                },
              ),
            ),
            SizedBox(
              width: 50,
              child: Text(
                currentColor.green.toString(),
                style: const TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
        
        // Blue Slider
        Row(
          children: [
            const SizedBox(
              width: 40,
              child: Text('B:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            Expanded(
              child: Slider(
                value: currentColor.blue.toDouble(),
                min: 0,
                max: 255,
                divisions: 255,
                activeColor: Colors.blue,
                label: currentColor.blue.toString(),
                onChanged: (value) {
                  Color newColor = Color.fromARGB(
                    255,
                    currentColor.red,
                    currentColor.green,
                    value.toInt(),
                  );
                  changeColor(newColor);
                },
              ),
            ),
            SizedBox(
              width: 50,
              child: Text(
                currentColor.blue.toString(),
                style: const TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showBluetoothDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Bluetooth Devices'),
              content: SizedBox(
                width: double.maxFinite,
                height: 300,
                child: Column(
                  children: [
                    if (isConnected)
                      ListTile(
                        leading: const Icon(Icons.bluetooth_connected, color: Colors.green),
                        title: Text(connectedDevice?.platformName ?? 'Unknown'),
                        trailing: ElevatedButton(
                          onPressed: () {
                            _disconnect();
                            setDialogState(() {});
                            setState(() {});
                          },
                          child: const Text('Disconnect'),
                        ),
                      )
                    else
                      ElevatedButton.icon(
                        onPressed: isScanning
                            ? null
                            : () async {
                                await _startScan();
                                setDialogState(() {});
                              },
                        icon: isScanning
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.search),
                        label: Text(isScanning ? 'Scanning...' : 'Scan for Devices'),
                      ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: isScanning && scanResults.isEmpty
                          ? const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  CircularProgressIndicator(),
                                  SizedBox(height: 16),
                                  Text('Searching for devices...'),
                                ],
                              ),
                            )
                          : scanResults.isEmpty
                              ? const Center(
                                  child: Text('No devices found.\nMake sure ESP32 is powered on.'),
                                )
                              : ListView.builder(
                                  shrinkWrap: true,
                                  itemCount: scanResults.length,
                                  itemBuilder: (context, index) {
                                    final result = scanResults[index];
                                    final deviceName = result.device.platformName.isNotEmpty
                                        ? result.device.platformName
                                        : result.advertisementData.localName.isNotEmpty
                                            ? result.advertisementData.localName
                                            : 'Unknown Device';
                                    
                                    return ListTile(
                                      leading: Icon(
                                        Icons.bluetooth,
                                        color: deviceName.contains('ESP32') ? Colors.blue : Colors.grey,
                                      ),
                                      title: Text(deviceName),
                                      subtitle: Text(result.device.remoteId.toString()),
                                      trailing: ElevatedButton(
                                        onPressed: () async {
                                          Navigator.of(context).pop();
                                          await _connectToDevice(result.device);
                                        },
                                        child: const Text('Connect'),
                                      ),
                                    );
                                  },
                                ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
