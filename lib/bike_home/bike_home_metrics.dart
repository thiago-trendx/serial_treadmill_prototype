import 'package:flutter/cupertino.dart';

class GoperHomeMetrics {
  static GoperHomeMetrics instance = GoperHomeMetrics();

  ValueNotifier<TreadmillStatus> status = ValueNotifier<TreadmillStatus>(TreadmillStatus.idle);
  ValueNotifier<int?> power = ValueNotifier<int?>(null);
  ValueNotifier<int?> rotation = ValueNotifier<int?>(null);
  ValueNotifier<int?> resistance = ValueNotifier<int?>(null);

  void getMetricsFromPacket({required List<int> answerHex}) {
    power.value = (answerHex[2] << 8) | answerHex[3];
    rotation.value = (answerHex[4]/2).round(); // a cadência deve ser dividida por 2
    resistance.value = answerHex[5];
  }

  void setStatus(TreadmillStatus newValue) => status.value = newValue;

}

enum TreadmillStatus {
  idle,
  connected,
  disconnected,
  failedToOpenPort,
}