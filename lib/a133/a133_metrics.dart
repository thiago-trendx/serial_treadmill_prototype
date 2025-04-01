import 'package:flutter/cupertino.dart';

class A133Metrics {
  static A133Metrics instance = A133Metrics();

  ValueNotifier<TreadmillStatus> status = ValueNotifier<TreadmillStatus>(TreadmillStatus.idle);

  void setStatus(TreadmillStatus newValue) => status.value = newValue;
}

enum TreadmillStatus {
  idle,
  connected,
  disconnected,
  failedToOpenPort,
}