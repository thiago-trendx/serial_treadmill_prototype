import 'package:serial_to_usb_treadmill_prototype/communication_config/treadmill_communication.dart';

import 'communication_port_interface.dart';

class CommunicationPortSwitcher implements CommunicationPortInterface {
  static CommunicationPortSwitcher instance = CommunicationPortSwitcher();

  late CommunicationPortInterface communicationPort;

  @override
  Future<void> initializePort() async {
    communicationPort = await _getCommunicationPort();
    await communicationPort.initializePort();
  }

  @override
  Future<void> getPort() async => communicationPort.getPort();

  @override
  Future<void> connectToPort() async => communicationPort.connectToPort();

  @override
  Future<List<int>?> sendDataToInverter(List<int> command) async =>
      communicationPort.sendDataToInverter(command);

  @override
  Future<void> cleanPreviousPort() async => communicationPort.cleanPreviousPort();

  Future<CommunicationPortInterface> _getCommunicationPort() async {
    print('aqui communication port 01');
    if (TreadmillCommunication.instance.isUndefined) {
      print('aqui communication port 02');
      await TreadmillCommunication.instance.getTreadmillCommunication();
    }

    if (TreadmillCommunication.instance.isSerialToSerial) {
      print('aqui communication port 03');
      return SerialToSerialCommunicationPort();
    } else {
      print('aqui communication port 04');
      return USBToSerialCommunicationPort();
    }
  }
}
