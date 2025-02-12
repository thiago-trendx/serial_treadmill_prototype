import 'package:flutter/cupertino.dart';
import 'a133_values_calculation.dart';

class A133Metrics {
  static A133Metrics instance = A133Metrics();

  int? rawResistanceADC;
  ValueNotifier<int?> rotation = ValueNotifier<int?>(null);
  ValueNotifier<int?> resistance = ValueNotifier<int?>(null);
  int? calibrationLimit1;
  int? calibrationLimit2;
  ValueNotifier<int?> power = ValueNotifier<int?>(null);

  void getMetricsFromPacket({required List<int> normalDtaPacket}) {
    rawResistanceADC = (normalDtaPacket[5] << 8) | normalDtaPacket[4];
    rotation.value = (normalDtaPacket[7] << 8) | normalDtaPacket[6];
    calibrationLimit1 = (normalDtaPacket[9] << 8) | normalDtaPacket[8];
    calibrationLimit2 = (normalDtaPacket[11] << 8) | normalDtaPacket[10];

    resistance.value = A133ValuesCalculation.instance.getResistance(
        limitMin: calibrationLimit1!,
        limitMax: calibrationLimit2!,
        valueADC: rawResistanceADC!
    );

    power.value = A133ValuesCalculation.instance.getPower(
        resistanceValue: resistance.value,
        rpmValue: rotation.value,
    );
  }
}