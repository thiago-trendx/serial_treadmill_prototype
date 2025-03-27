import 'enums.dart';

abstract class TreadmillProtocol {

  static List<int> writeDataToInverter(
      {required int value, required CommandType type}) {
    List<int> mainCommand = [0xf6, type.toINS(), value];
    List<int> checkSum = [_getCheckSum(mainCommand)];
    List<int> end = [0xf4];

    List<int> finalData = mainCommand + checkSum + end;
    return finalData;
  }

  static List<int> readCommandToInverter({required CommandType type}) {
    List<int> mainCommand = [0xf6, type.toINS()];
    List<int> checkSum = [_getCheckSum(mainCommand)];
    List<int> end = [0xf4];

    List<int> finalData = mainCommand + checkSum + end;
    return finalData;
  }

  static int _getCheckSum(List<int> hexNumbers) {
    int sum = hexNumbers.fold(0, (acumulator, num) => acumulator + num);
    int lsb8Bits = sum & 0xff;
    return lsb8Bits;
  }
}