part of 'communication_port_interface.dart';

class USBToSerialCommunicationPort with TransactionMixin implements CommunicationPortInterface {

  static final USBToSerialCommunicationPort uSBToSerialCommunicationPort = USBToSerialCommunicationPort._internal();

  factory USBToSerialCommunicationPort() => uSBToSerialCommunicationPort;

  USBToSerialCommunicationPort._internal();

  ValueNotifier<UsbPort?> port = ValueNotifier<UsbPort?>(null);

  @override
  Future<void> initializePort() async {
    A133Metrics.instance.setStatus(TreadmillStatus.idle);

    await cleanPreviousPort();
    await getPort();
  }

  @override
  Future<void> getPort() async {
    final List<UsbDevice> devices = await UsbSerial.listDevices();

    UsbDevice? device;

    device = devices.firstWhereOrNull((device) => device.pid == 29987);

    if (device != null) {
      port.value = await device.create(UsbSerial.CH34x, 0);
      if (await (port.value?.open()) == true) {
        await connectToPort();
      } else {
        await _retryGetPort();
      }
    } else {
      // depois de setar como desconectado, iremos aguardar o listener das
      // portas usb indicarem que um novo dispositivo usb foi conectado
      A133Metrics.instance.setStatus(TreadmillStatus.disconnected);
    }
  }

  Future<void> _retryGetPort() async {
    A133Metrics.instance.setStatus(TreadmillStatus.failedToOpenPort);
    // tentar novamente
    Future.delayed(const Duration(seconds: 2), () async {
      await getPort();
    });
  }

  // configura a porta e estabelece conexão com o inversor da esteira
  @override
  Future<void> connectToPort() async {
    await port.value?.setDTR(true);
    await port.value?.setRTS(true);
    await port.value?.setPortParameters(
      38400,
      UsbPort.DATABITS_8,
      UsbPort.STOPBITS_1,
      UsbPort.PARITY_NONE,
    );

    await port.value?.connect();

    configureTransaction(port.value!, Uint8List.fromList([0xf4]));

    A133Metrics.instance.setStatus(TreadmillStatus.connected);

    await _listenToUsbDeviceConnection();
  }

  // Ouvir quando o cabo USB é conectado ou desconectado
  Future<void> _listenToUsbDeviceConnection() async {
    UsbSerial.usbEventStream!.listen((UsbEvent event) async {
      if (event.device!.pid != 29987) return;

      // tratamento para o nosso device já atribuído:
      if (event.event!.contains('DETACHED')) {
        A133Metrics.instance.setStatus(TreadmillStatus.disconnected);
        return;
      }
      if (event.event!.contains('ATTACHED')) {
        await initializePort();
        return;
      }
    });
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
    await port.value?.close();
    port.value = null;
  }
}