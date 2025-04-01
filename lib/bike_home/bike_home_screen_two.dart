import 'dart:async';
import 'package:flutter/material.dart';
import '../communication_config/communication_port_interface.dart';
import '../communication_config/communication_port_switcher.dart';
import 'bike_home_metrics.dart';
import 'bike_protocol.dart';
import 'enums.dart';

class BikeHomeScreenTwo extends StatefulWidget {
  const BikeHomeScreenTwo({Key? key}) : super(key: key);

  @override
  State<BikeHomeScreenTwo> createState() => _BikeHomeScreenTwoState();
}

class _BikeHomeScreenTwoState extends State<BikeHomeScreenTwo> {
  late TextEditingController _textController;
  Timer? _bikeDataReadTimer;
  final List<Widget> _serialData = [];
  final List<String> _hexCodeSent = [];
  ValueNotifier<DateTime?> lastBikeDataSent = ValueNotifier<DateTime?>(null);
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
    _bikeDataReadTimer?.cancel();
    _bikeDataReadTimer = null;
  }

  Future<void> _configAndInitialize() async {
    await CommunicationPortSwitcher.instance.initializePort();
    if (GoperHomeMetrics.instance.status.value == TreadmillStatus.connected) {
      _initBikeDataReadTimer();
    }
  }

  Future<void> _initBikeDataReadTimer() async {
    _bikeDataReadTimer?.cancel();
    _bikeDataReadTimer = Timer.periodic(const Duration(milliseconds: 150), (Timer t) async {
      List<int> bikeDataReadCmd = TreadmillProtocol.readCommandToInverter(
          type: CommandType.readBikeData);
      await _sendCommand(bikeDataReadCmd, isBikeDataInfo: true);
    });
  }

  Future<void> _sendCommand(List<int> dataToSend, {required bool isBikeDataInfo}) async {
    var response = await CommunicationPortSwitcher.instance.sendDataToInverter(dataToSend);

    if (isBikeDataInfo) {
      lastBikeDataSent.value = DateTime.now();
      if (response != null) GoperHomeMetrics.instance.getMetricsFromPacket(answerHex: response);
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
                        valueListenable: GoperHomeMetrics.instance.status,
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
                      crossAxisAlignment: CrossAxisAlignment.start,
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
