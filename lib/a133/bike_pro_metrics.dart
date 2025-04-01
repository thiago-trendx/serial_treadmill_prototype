import 'package:flutter/cupertino.dart';
import 'bike_pro_values_calculation.dart';

class BikeProMetrics {
  static BikeProMetrics instance = BikeProMetrics();

  int? rawResistanceADC;
  ValueNotifier<int?> rotation = ValueNotifier<int?>(null);
  ValueNotifier<int?> resistance = ValueNotifier<int?>(null);
  int? calibrationLimit1;
  int? calibrationLimit2;
  ValueNotifier<int?> power = ValueNotifier<int?>(null);
  ValueNotifier<TreadmillStatus> status = ValueNotifier<TreadmillStatus>(TreadmillStatus.idle);

  void getMetricsFromPacket({required List<int> normalDtaPacket}) {
    rawResistanceADC = (normalDtaPacket[5] << 8) | normalDtaPacket[4];
    rotation.value = (normalDtaPacket[7] << 8) | normalDtaPacket[6];
    calibrationLimit1 = (normalDtaPacket[9] << 8) | normalDtaPacket[8];
    calibrationLimit2 = (normalDtaPacket[11] << 8) | normalDtaPacket[10];

    resistance.value = BikeProValuesCalculation.instance.getResistance(
        limitMin: calibrationLimit1!,
        limitMax: calibrationLimit2!,
        valueADC: rawResistanceADC!
    );

    power.value = BikeProValuesCalculation.instance.getPower(
        resistanceValue: resistance.value,
        rpmValue: rotation.value,
    );
  }

  void setStatus(TreadmillStatus newValue) => status.value = newValue;
}

enum TreadmillStatus {
  idle,
  connected,
  disconnected,
  failedToOpenPort,
}