import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:usb_serial_for_android/transaction.dart';
import 'package:usb_serial_for_android/usb_device.dart';
import 'package:usb_serial_for_android/usb_event.dart';
import 'package:usb_serial_for_android/usb_port.dart';
import 'package:usb_serial_for_android/usb_serial_for_android.dart';
import 'bike_protocol.dart';
import 'bike_home_metrics.dart';
import 'enums.dart';

class BikeHomeScreen extends StatefulWidget {
  const BikeHomeScreen({super.key});

  @override
  State<BikeHomeScreen> createState() => _BikeHomeScreenState();
}

class _BikeHomeScreenState extends State<BikeHomeScreen> {
  UsbPort? _port;
  String _status = "Idle";
  List<Widget> _ports = [];
  final List<Widget> _serialData = [];
  Transaction<Uint8List>? _transaction;
  UsbDevice? _device;

  final List<String> _hexCodeSent = [];
  late TextEditingController _textController;
  Timer? _bikeDataReadTimer;
  ValueNotifier<DateTime?> lastBikeDataSent = ValueNotifier<DateTime?>(null);


  Future<bool> _connectTo(UsbDevice? device) async {
    _serialData.clear();
    if (_transaction != null) {
      _transaction!.dispose();
      _transaction = null;
    }
    if (_port != null) {
      _port!.close();
      _port = null;
    }
    if (device == null) {
      _device = null;
      setState(() {
        _status = "Disconnected";
      });
      return true;
    }

    //_port = await device.create();
    // You can customize your driver and the port number
    _port = await device.create(UsbSerial.CH34x, 0);
    if (await (_port!.open()) != true) {
      setState(() {
        _status = "Failed to open port";
      });
      return false;
    }
    _device = device;

    await _port!.setDTR(true);
    await _port!.setRTS(true);
    await _port!.setPortParameters(
        9600, UsbPort.DATABITS_8, UsbPort.STOPBITS_1, UsbPort.PARITY_NONE);

    await _port!.connect();

    _transaction = Transaction.terminated(
        _port?.inputStream as Stream<Uint8List>, Uint8List.fromList([0xf4]));

    setState(() {
      _status = "Connected";
    });
    await _initBikeDataReadTimer();
    return true;
  }

  Future<void> _initBikeDataReadTimer() async {
    _bikeDataReadTimer?.cancel();
    _bikeDataReadTimer = Timer.periodic(const Duration(milliseconds: 150), (Timer t) async {
      List<int> bikeDataReadCmd = TreadmillProtocol.readCommandToInverter(
          type: CommandType.readBikeData);
      await _sendCommand(bikeDataReadCmd, isBikeDataInfo: true);
    });
  }

  Future<void> _sendCommand(List<int>? dataToSend, {required bool isBikeDataInfo}) async {
    var response = await _transaction?.transaction(_port!, Uint8List
        .fromList(dataToSend!), const Duration(seconds: 1));

    if (isBikeDataInfo) {
      lastBikeDataSent.value = DateTime.now();
      GoperHomeMetrics.instance.getMetricsFromPacket(answerHex: response!);
      //return;
    }

    _dealWithHexSent(dataToSend!);

    List<String> hexResponse = [];
    if (response != null) {
      for (var num in response) {
        hexResponse.add(num.toRadixString(16));
      }
    }
    print(hexResponse);
    setState(() {
      if (response != null) {
        _serialData.insert(0, Text('$hexResponse\n'));
      } else {
        _serialData.insert(0, Text('${response.toString()}\n'));
      }
    });
  }

  void _getPorts() async {
    _ports = [];
    List<UsbDevice> devices = await UsbSerial.listDevices();
    if (!devices.contains(_device)) {
      _connectTo(null);
    }

    for (var device in devices) {
      _ports.add(ListTile(
          leading: const Icon(Icons.usb),
          title: Text(device.productName ?? 'no ProductName specified'),
          subtitle: Text(device.manufacturerName ?? 'no ManufactureName specified'),
          trailing: ElevatedButton(
            child: Text(_device == device ? "Disconnect" : "Connect"),
            onPressed: () {
              _connectTo(_device == device ? null : device).then((res) {
                _getPorts();
              });
            },
          )));
    }
  }

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController();
    UsbSerial.usbEventStream!.listen((UsbEvent event) {
      _getPorts();
    });

    _getPorts();
  }

  @override
  void dispose() {
    super.dispose();
    _textController.dispose();
    _bikeDataReadTimer?.cancel();
    _bikeDataReadTimer = null;
    _connectTo(null);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        home: Scaffold(
          appBar: AppBar(
            title: const Text('USB-Serial Communication Prototype'),
          ),
          body: Center(
            child: SingleChildScrollView(
              child: Column(
                  children: <Widget>[
                    Text(
                        _ports.isNotEmpty
                            ? "Available Serial Ports"
                            : "No serial devices available",
                        style: Theme.of(context).textTheme.headline6),
                    ..._ports,
                    const SizedBox(height: 40),
                    Text(
                      'Connection Info:',
                       style: Theme.of(context).textTheme.headline6),
                    Text('Status: $_status\n'),
                    Text('Details: ${_port.toString()}\n'),
                    const SizedBox(height: 40),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton(
                          onPressed: () {
                            _bikeDataReadTimer?.cancel();
                          },
                          child: const Text("STOP Bike Data Reading"),
                        ),
                        const SizedBox(width: 20),
                        ElevatedButton(
                          onPressed: () {
                            _initBikeDataReadTimer();
                          },
                          child: const Text("RESTART Bike Data Reading"),
                        ),
                      ],
                    ),
                    const SizedBox(height: 40),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Column(
                          children: [
                            const Text('Periodic Bike Data Reading'),
                            ValueListenableBuilder(
                                valueListenable: lastBikeDataSent,
                                builder: (BuildContext context, DateTime? lastCmdSent, Widget? child) {
                                  return Text(
                                      'Last call: ${lastCmdSent ?? ''}'
                                  );
                                }),
                          ],
                        ),
                        const SizedBox(width: 40),
                        Column(
                          children: [
                            ValueListenableBuilder(
                                valueListenable: GoperHomeMetrics.instance.resistance,
                                builder: (BuildContext context, int? value, Widget? child) {
                                  return Text(
                                    'RESISTÊNCIA: $value',
                                    style: const TextStyle(fontSize: 20),
                                  );
                                }),
                            const SizedBox(height: 15),
                            ValueListenableBuilder(
                                valueListenable: GoperHomeMetrics.instance.rotation,
                                builder: (BuildContext context, int? value, Widget? child) {
                                  return Text(
                                      'ROTAÇÃO: $value',
                                    style: const TextStyle(fontSize: 20),
                                  );
                                }),
                            const SizedBox(height: 15),
                            ValueListenableBuilder(
                                valueListenable: GoperHomeMetrics.instance.power,
                                builder: (BuildContext context, int? value, Widget? child) {
                                  return Text(
                                    'POTÊNCIA: $value',
                                    style: const TextStyle(fontSize: 20),
                                  );
                                }),
                            Text('Command sent to treadmill: $_hexCodeSent'),
                            const Text("Result Data"),
                            ..._serialData,
                          ],
                        ),
                      ],
                    ),
                  ]),
            ),
          ),
        ));
  }

  void _dealWithHexSent(final List<int> command) {
    _hexCodeSent.clear();
    for (var num in command) {
      _hexCodeSent.add(num.toRadixString(16));
    }
    setState(() {});
  }
}