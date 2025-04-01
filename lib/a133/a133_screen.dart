import 'dart:async';
import 'package:flutter/material.dart';
import '../communication_config/communication_port_interface.dart';
import '../communication_config/communication_port_switcher.dart';
import 'a133_command_enums.dart';
import 'a133_metrics.dart';
import 'a133_protocol.dart';

class A133Screen extends StatefulWidget {
  const A133Screen({super.key});

  @override
  State<A133Screen> createState() => _A133ScreenState();
}

class _A133ScreenState extends State<A133Screen> {
  final List<Widget> _serialData = [];
  final List<Widget> _normalDataAnswer = [];
  final List<String> _hexCodeSent = [];
  late TextEditingController _speedTextController;
  late TextEditingController _inclinationTextController;
  Timer? _normalPacketTimer;
  ValueNotifier<DateTime?> lastNormalPacketSent = ValueNotifier<DateTime?>(null);
  ValueNotifier<bool> loadingRetry = ValueNotifier<bool>(false);
  
  @override
  void initState() {
    super.initState();
    _speedTextController = TextEditingController();
    _inclinationTextController = TextEditingController();
    _configAndInitialize();
  }

  @override
  void dispose() {
    super.dispose();
    _speedTextController.dispose();
    _inclinationTextController.dispose();
    _normalPacketTimer?.cancel();
    _normalPacketTimer = null;
  }

  Future<void> _configAndInitialize() async {
    await CommunicationPortSwitcher.instance.initializePort();
    if (A133Metrics.instance.status.value == TreadmillStatus.connected) {
      _initNormalPacketTimer();
    }
  }
  
  
  Future<void> _initNormalPacketTimer() async {
    _normalPacketTimer?.cancel();
    _normalPacketTimer = Timer.periodic(const Duration(milliseconds: 1000), (Timer t) async {
      List<int> normalDataPacket = [0xff, 0x41, 0x01, 0x8f, 0xbe, 0xfe];
      await _sendCommand(normalDataPacket, isNormalPacket: true);
    });
  }

  Future<void> _sendCommand(List<int>? dataToSend, {required bool isNormalPacket}) async {
    var response = await CommunicationPortSwitcher.instance.sendDataToInverter(dataToSend!);

    if (isNormalPacket) {
      lastNormalPacketSent.value = DateTime.now();

      List<String> hexResponse = [];
      if (response != null) {
        for (var num in response) {
          hexResponse.add(num.toRadixString(16));
        }
      }
      setState(() {
        if (response != null) {
          if (response[4] != 0 || response[5] != 0) {
            _normalDataAnswer.insert(0,
                Text('$hexResponse\n', style: const TextStyle(color: Colors.red)));
          } else {
            _normalDataAnswer.insert(0, Text('$hexResponse\n'));
          }
        } else {
          _normalDataAnswer.insert(0, Text('${response.toString()}\n'));
        }
      });
      return;
    }

    _dealWithHexSent(dataToSend);

    List<String> hexResponse = [];
    if (response != null) {
      for (var num in response) {
        hexResponse.add(num.toRadixString(16));
      }
    }
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
                        valueListenable: A133Metrics.instance.status,
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
                    Text(
                        'Quick Commands:',
                        style: Theme.of(context).textTheme.headline6),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _controlCommandButton(title: 'Start Operation',
                              commandType: A133CommandTypes.writeControlCommand,
                              instructionType: A133InstructionTypes.startTreadmill
                          ),
                          _controlCommandButton(title: 'Stop Operation',
                              commandType: A133CommandTypes.writeControlCommand,
                              instructionType: A133InstructionTypes.stopTreadmill
                          ),
                          _controlCommandButton(title: 'Emergency Stop',
                              commandType: A133CommandTypes.writeControlCommand,
                              instructionType: A133InstructionTypes.emergencyStop
                          ),
                          _oneParamButton(title: 'Read Set Speed',
                              commandType: A133CommandTypes.readOneParam,
                              parameterIndex: A133ParameterIndexTypes.setSpeed
                          ),
                          _oneParamButton(title: 'Read Actual Speed',
                              commandType: A133CommandTypes.readOneParam,
                              parameterIndex: A133ParameterIndexTypes.actualSpeed
                          ),
                          _oneParamButton(title: 'Read Data Packet',
                              commandType: A133CommandTypes.readMultipleParams,
                              parameterIndex: A133ParameterIndexTypes.dataPacket
                          ),
                          _oneParamButton(title: 'Calibrate Lift Segments to 15',
                              commandType: A133CommandTypes.writeControlCommand,
                              parameterIndex: A133ParameterIndexTypes.liftSegments,
                              value: 15
                          ),
                          _oneParamButton(title: 'Save Calibration Parameters',
                              commandType: A133CommandTypes.writeOneParam,
                              parameterIndex: A133ParameterIndexTypes.saveSettingParameters,
                              value: 1
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Column(
                          children: [
                            Text(
                                'Choose speed command in km/h:',
                                style: Theme.of(context).textTheme.headline6),
                            SizedBox(
                              width: 300,
                              child: ListTile(
                                title: TextField(
                                  controller: _speedTextController,
                                  decoration: const InputDecoration(
                                    border: OutlineInputBorder(),
                                    labelText: 'type speed',
                                  ),
                                ),
                                trailing: ElevatedButton(
                                  onPressed: () async {
                                    int data = int.parse(_speedTextController.text);
                                    List<int>? dataToSend =
                                    A133Protocol.formatOneParameterCmd(value: data,
                                        commandType: A133CommandTypes.writeOneParam,
                                        parameterIndex: A133ParameterIndexTypes.setSpeed);
                                    await _sendCommand(dataToSend, isNormalPacket: false);
                                  },
                                  child: const Text("Send"),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 40),
                        Column(
                          children: [
                            Text(
                                'Choose inclination command:',
                                style: Theme.of(context).textTheme.headline6),
                            SizedBox(
                              width: 300,
                              child: ListTile(
                                title: TextField(
                                  controller: _inclinationTextController,
                                  decoration: const InputDecoration(
                                    border: OutlineInputBorder(),
                                    labelText: 'type inclination',
                                  ),
                                ),
                                trailing: ElevatedButton(
                                  onPressed: () async {
                                    int data = int.parse(_inclinationTextController.text);
                                    List<int>? dataToSend =
                                    A133Protocol.formatOneParameterCmd(value: data,
                                        commandType: A133CommandTypes.writeOneParam,
                                        parameterIndex: A133ParameterIndexTypes.setInclination);
                                    await _sendCommand(dataToSend, isNormalPacket: false);
                                  },
                                  child: const Text("Send"),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 40),
                        Column(
                          children: [
                            ElevatedButton(
                              onPressed: () {
                                _normalPacketTimer?.cancel();
                              },
                              child: const Text("Stop Normal Data Packet"),
                            ),
                            const SizedBox(height: 20),
                            ElevatedButton(
                              onPressed: () {
                                _initNormalPacketTimer();
                              },
                              child: const Text("Restart Normal Data Packet"),
                            ),
                          ],
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
                            const Text('Periodic Normal Data Packet call'),
                            ValueListenableBuilder(
                                valueListenable: lastNormalPacketSent,
                                builder: (BuildContext context, DateTime? lastCmdSent, Widget? child) {
                                  return Text(
                                      'Last call: ${lastCmdSent ?? ''}'
                                  );
                                }),
                            const Text("Answer for sent command"),
                            ..._normalDataAnswer,
                          ],
                        ),
                        const SizedBox(width: 40),
                        Column(
                          children: [
                            Text('Command sent to treadmill: $_hexCodeSent'),
                            const Text("Answer for sent command"),
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

  Widget _controlCommandButton({
    required String title,
    required A133CommandTypes commandType,
    required A133InstructionTypes instructionType,
  }) {
    List<int> command = A133Protocol.formatControlCmd(
        commandType: commandType,
        instructionType: instructionType,
    );
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
      child: ElevatedButton(
        child: Text(title),
        onPressed: () async {
          await _sendCommand(command, isNormalPacket: false);
        },
      ),
    );
  }

  Widget _oneParamButton({
    required String title,
    required A133CommandTypes commandType,
    required A133ParameterIndexTypes parameterIndex,
    num? value,
    }) {
    List<int> command = A133Protocol.formatOneParameterCmd(
        commandType: commandType,
        parameterIndex: parameterIndex,
        value: value
    );
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
      child: ElevatedButton(
        child: Text(title),
        onPressed: () async {
          await _sendCommand(command, isNormalPacket: false);
        },
      ),
    );
  }

  void _dealWithHexSent(final List<int> command) {
    _hexCodeSent.clear();
    for (var num in command) {
      _hexCodeSent.add(num.toRadixString(16));
    }
    setState(() {});
  }
}