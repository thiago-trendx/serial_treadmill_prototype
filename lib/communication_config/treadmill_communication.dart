import 'dart:typed_data';

import 'package:flutter_libserialport/flutter_libserialport.dart';
import 'package:serial_to_usb_treadmill_prototype/communication_config/treadmill_communication_enum.dart';
import 'package:usb_serial_for_android/usb_device.dart';
import 'package:usb_serial_for_android/usb_serial_for_android.dart';

import 'communication_port_switcher.dart';

class TreadmillCommunication {
  static TreadmillCommunication instance = TreadmillCommunication();

  bool get isUndefined =>
      treadmillCommunicationEnum == TreadmillCommunicationEnum.undefined;

  bool get isSerial =>
      treadmillCommunicationEnum == TreadmillCommunicationEnum.usbToSerial ||
          treadmillCommunicationEnum == TreadmillCommunicationEnum.serialToSerial;

  bool get isSerialToSerial =>
      treadmillCommunicationEnum == TreadmillCommunicationEnum.serialToSerial;

  TreadmillCommunicationEnum treadmillCommunicationEnum =
      TreadmillCommunicationEnum.undefined;

  Future<void> getTreadmillCommunication() async {
    print('aqui communication 01');
    if (await _checkUSBPortAvailable()) {
      print('aqui communication 02');
      treadmillCommunicationEnum = TreadmillCommunicationEnum.usbToSerial;
      return;
    }
    if (await _checkSerialPortAvailable()) {
      print('aqui communication 03');
      treadmillCommunicationEnum = TreadmillCommunicationEnum.serialToSerial;
      return;
    }
  }

  Future<void> clearPreviousTreadmillRoutines() async {
    // Caso a comunicação atual seja indefinida não precisamos limpar a sujeira das portas antigas
    if (!isSerial) return;
    treadmillCommunicationEnum = TreadmillCommunicationEnum.undefined;
    CommunicationPortSwitcher.instance.cleanPreviousPort();
  }

  Future<bool> _checkSerialPortAvailable() async {
    return await getSerialPort() != null;
  }

  Future<SerialPort?> getSerialPort() async {
    print('aqui get serial port 01');
    final List<String> availablePorts = ['/dev/ttyS4', '/dev/ttyS3'];

    for (var port in availablePorts) {
      final SerialPort serialPort = SerialPort(port);

      try {
        print('aqui get serial port 02');
        serialPort.openReadWrite();

        serialPort.config = SerialPortConfig()
          ..baudRate = 9600
          ..bits = 8
          ..stopBits = 1
          ..parity = SerialPortParity.none
          ..setFlowControl(SerialPortFlowControl.none);

        //serialPort.write(Uint8List.fromList(healthCheck));

        await Future.delayed(const Duration(milliseconds: 250));

        final Uint8List response = serialPort.read(7);

        if (response.isNotEmpty && response[0] == 0xf1) {
          print('aqui get serial port 02');
          serialPort.close();
          return serialPort;
        }
      } catch (e) {
        print('aqui get serial port 03: $e');
        serialPort.close();
        continue;
      }
    }

    return null;
  }

  // verifica se existe adaptador usb-serial conectado
  Future<bool> _checkUSBPortAvailable() async {
    List<UsbDevice> foundDevices = await UsbSerial.listDevices();

    for (UsbDevice device in foundDevices) {
      if (device.pid == 29987) {
        return true;
      }
    }

    print('aqui usb não disponível');
    return false;
  }
}