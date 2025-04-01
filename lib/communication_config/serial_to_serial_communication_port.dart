part of 'communication_port_interface.dart';

class SerialToSerialCommunicationPort with TransactionMixin implements CommunicationPortInterface {

  static final SerialToSerialCommunicationPort serialToSerialCommunicationPort = SerialToSerialCommunicationPort._internal();

  factory SerialToSerialCommunicationPort() => serialToSerialCommunicationPort;

  SerialToSerialCommunicationPort._internal();

  ValueNotifier<SerialPort?> port = ValueNotifier<SerialPort?>(null);

  @override
  Future<void> initializePort() async {
    BikeProMetrics.instance.setStatus(TreadmillStatus.idle);

    await cleanPreviousPort();
    await getPort();
  }

  @override
  Future<void> getPort() async {
    port.value = await TreadmillCommunication.instance.getSerialPort();

    if (port.value != null) {
      try {
        await connectToPort();
      } catch (_) {
        await _retryGetPort();
      }
    } else {
      BikeProMetrics.instance.setStatus(TreadmillStatus.disconnected);
    }
  }

  Future<void> _retryGetPort() async {
    BikeProMetrics.instance.setStatus(TreadmillStatus.failedToOpenPort);
    // tentar novamente
    Future.delayed(const Duration(seconds: 2), () async {
      await getPort();
    });
  }

// configura a porta e estabelece conexão com o inversor da esteira
  @override
  Future<void> connectToPort() async {
    if (port.value?.isOpen == true) return;

    port.value?.openReadWrite();

    port.value?.config = SerialPortConfig()
      ..baudRate = 38400
      ..bits = 8
      ..stopBits = 1
      ..parity = SerialPortParity.none
      ..setFlowControl(SerialPortFlowControl.none);

    final SerialSerialTransactionModel serialSerialTransaction =
    SerialSerialTransactionModel(port: port.value!);

    configureTransaction(serialSerialTransaction, Uint8List.fromList([0xf4]));

    BikeProMetrics.instance.setStatus(TreadmillStatus.connected);
  }

// envia comando para o inversor e retorna resposta
  @override
  Future<List<int>?> sendDataToInverter(List<int> command) async {
    // verificar se a porta está íntegra antes de enviar comando:
    if (port.value == null) {
      await initializePort().then((_) async {
        // depois de reiniciar a porta, reenviamos o valor interrompido
        await Future.delayed(const Duration(milliseconds: 200));
        sendDataToInverter(command);
        return;
      });
    }

    var response = await sendData(command);

    return response;
  }

  @override
  Future<void> cleanPreviousPort() async {
    clearTransaction();
    port.value?.close();
    port.value = null;
  }
}
