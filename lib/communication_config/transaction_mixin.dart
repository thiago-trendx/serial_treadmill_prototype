import 'dart:typed_data';
import 'package:usb_serial_for_android/transaction.dart';
import 'package:usb_serial_for_android/types.dart';

mixin TransactionMixin {
  AsyncDataSinkSource? _port;
  Transaction<Uint8List>? _transaction;

  void configureTransaction(AsyncDataSinkSource port, Uint8List terminator) {
    _port = port;
    _transaction = Transaction.terminated(
      _port?.inputStream as Stream<Uint8List>,
      terminator,
    );
  }

  Future<Uint8List?> sendData(List<int> command) async {
    var response = await _transaction?.transaction(
      _port!,
      Uint8List.fromList(command),
      const Duration(seconds: 1),
    );

    return response;
  }

  void clearTransaction() {
    _port = null;
    _transaction?.dispose();
    _transaction = null;
  }
}