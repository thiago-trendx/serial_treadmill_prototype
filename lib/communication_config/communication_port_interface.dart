import 'dart:typed_data';
import 'package:collection/collection.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_libserialport/flutter_libserialport.dart';
import 'package:serial_to_usb_treadmill_prototype/communication_config/serial_serial_transaction_model.dart';
import 'package:serial_to_usb_treadmill_prototype/communication_config/transaction_mixin.dart';
import 'package:serial_to_usb_treadmill_prototype/communication_config/treadmill_communication.dart';
import 'package:usb_serial_for_android/usb_device.dart';
import 'package:usb_serial_for_android/usb_event.dart';
import 'package:usb_serial_for_android/usb_port.dart';
import 'package:usb_serial_for_android/usb_serial_for_android.dart';

import '../a133/bike_pro_metrics.dart';

part 'serial_to_serial_communication_port.dart';
part 'usb_to_serial_communication_port.dart';

abstract class CommunicationPortInterface {
  Future<void> initializePort();

  Future<void> getPort();

  Future<void> connectToPort();

  Future<List<int>?> sendDataToInverter(List<int> command);

  Future<void> cleanPreviousPort();
}