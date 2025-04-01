import 'dart:typed_data';
import 'package:flutter_libserialport/flutter_libserialport.dart';
import 'package:usb_serial_for_android/types.dart';

class SerialSerialTransactionModel extends AsyncDataSinkSource {
  final SerialPort port;

  SerialSerialTransactionModel({required this.port});

  @override
  Stream<Uint8List>? get inputStream {
    SerialPortReader reader = SerialPortReader(port);
    return reader.stream;
  }

  @override
  Future<void> write(Uint8List data) async => port.write(data);
}