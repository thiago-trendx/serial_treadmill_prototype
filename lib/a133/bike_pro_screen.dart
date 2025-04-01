import 'dart:async';
import 'package:flutter/material.dart';
import '../communication_config/communication_port_interface.dart';
import '../communication_config/communication_port_switcher.dart';
import 'bike_pro_metrics.dart';

class BikeProScreen extends StatefulWidget {
  const BikeProScreen({Key? key}) : super(key: key);

  @override
  State<BikeProScreen> createState() => _BikeProScreenState();
}

class _BikeProScreenState extends State<BikeProScreen> {
  late TextEditingController _textController;
  Timer? _normalDataPacketTimer;
  final List<Widget> _serialData = [];
  final List<String> _hexCodeSent = [];
  ValueNotifier<DateTime?> lastNormalPacketDataSent = ValueNotifier<DateTime?>(null);
  ValueNotifier<bool> loadingRetry = ValueNotifier<bool>(false);

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController();
    _configAndInitialize();
  }

  @override
  void dispose() {
    super.dispose();
    _textController.dispose();
    _normalDataPacketTimer?.cancel();
    _normalDataPacketTimer = null;
  }

  Future<void> _configAndInitialize() async {
    await CommunicationPortSwitcher.instance.initializePort();
    if (BikeProMetrics.instance.status.value == TreadmillStatus.connected) {
      _initBikeDataReadTimer();
    }
  }

  Future<void> _initBikeDataReadTimer() async {
    _normalDataPacketTimer?.cancel();
    _normalDataPacketTimer = Timer.periodic(const Duration(milliseconds: 150), (Timer t) async {
      await _sendCommand([0xff, 0x41, 0x01, 0x8f, 0xbe, 0xfe], isBikeDataInfo: true);
    });
  }

  Future<void> _sendCommand(List<int> dataToSend, {required bool isBikeDataInfo}) async {
    var response = await CommunicationPortSwitcher.instance.sendDataToInverter(dataToSend);

    if (isBikeDataInfo) {
      lastNormalPacketDataSent.value = DateTime.now();
      if (response != null) BikeProMetrics.instance.getMetricsFromPacket(normalDtaPacket: response);
      //return;
    }

    _dealWithHexSent(dataToSend);

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
                    ValueListenableBuilder(
                        valueListenable: BikeProMetrics.instance.status,
                        builder: (BuildContext context, TreadmillStatus value, Widget? child) {
                          if (value == TreadmillStatus.failedToOpenPort) {
                            return Text(
                                "Fail to communicate with equipment",
                                style: Theme.of(context).textTheme.headline6);
                          }
                          if (value == TreadmillStatus.disconnected) {
                            return Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                    "Status: Disconnected",
                                    style: Theme.of(context).textTheme.headline6),
                                const SizedBox(width: 40),
                                ValueListenableBuilder(
                                    valueListenable: loadingRetry,
                                    builder: (BuildContext context, bool loading, Widget? child) {
                                      if (loading) {
                                        return const CircularProgressIndicator();
                                      }
                                      return ElevatedButton(
                                        onPressed: () async {
                                          loadingRetry.value = true;
                                          await Future.delayed(const Duration(seconds: 1));
                                          _configAndInitialize();
                                          loadingRetry.value = false;
                                        },
                                        child: const Text("Retry connection"),
                                      );
                                    }),
                              ],
                            );
                          }
                          if (value == TreadmillStatus.connected) {
                            SerialToSerialCommunicationPort serialToSerial = SerialToSerialCommunicationPort
                                .serialToSerialCommunicationPort;
                            USBToSerialCommunicationPort uSBToSerialCommunicationPort = USBToSerialCommunicationPort
                                .uSBToSerialCommunicationPort;
                            return Column(
                              children: [
                                Text("Status: Connected",
                                    style: Theme.of(context).textTheme.headline6),
                                const SizedBox(height: 20),
                                CommunicationPortSwitcher.instance
                                    .communicationPort is SerialToSerialCommunicationPort
                                    ? const Text('Connection type: Serial cable')
                                    : const Text('Connection type: USB adapter'),
                                const SizedBox(height: 20),
                                CommunicationPortSwitcher.instance
                                    .communicationPort is SerialToSerialCommunicationPort
                                    ? Text(
                                    'Details: ${serialToSerial.port.toString()}\n')
                                    : Text(
                                    'Details: ${uSBToSerialCommunicationPort.port.toString()}\n')
                              ],
                            );
                          }
                          return Text(
                              "Idle... trying to connect",
                              style: Theme.of(context).textTheme.headline6);
                        }),
                    const SizedBox(height: 40),
                    const SizedBox(height: 40),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton(
                          onPressed: () {
                            _normalDataPacketTimer?.cancel();
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
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          children: [
                            const Text('Periodic Bike Data Reading'),
                            ValueListenableBuilder(
                                valueListenable: lastNormalPacketDataSent,
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
                                valueListenable: BikeProMetrics.instance.resistance,
                                builder: (BuildContext context, int? value, Widget? child) {
                                  return Text(
                                    'RESISTÊNCIA: $value',
                                    style: const TextStyle(fontSize: 20),
                                  );
                                }),
                            const SizedBox(height: 15),
                            ValueListenableBuilder(
                                valueListenable: BikeProMetrics.instance.rotation,
                                builder: (BuildContext context, int? value, Widget? child) {
                                  return Text(
                                    'ROTAÇÃO: $value',
                                    style: const TextStyle(fontSize: 20),
                                  );
                                }),
                            const SizedBox(height: 15),
                            ValueListenableBuilder(
                                valueListenable: BikeProMetrics.instance.power,
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