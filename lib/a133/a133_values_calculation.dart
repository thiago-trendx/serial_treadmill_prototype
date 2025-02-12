
class A133ValuesCalculation {
  static A133ValuesCalculation instance = A133ValuesCalculation();

  int getResistance({required int limitMin,
    required int limitMax,required int valueADC,}) {
    if (limitMin >= limitMax) {
      throw ArgumentError("O valor para CalibrationMin não pode ser"
          " maior ou igual ao valor de CalibrationMax.");
    }
    // Normalizar o valor de input numa range 0-1 baseada nos limites de calibração
    double normalizedValue = (valueADC - limitMin) / (limitMax - limitMin);

    // Mapear o valor normalizado para a uma range de 1 até 32 e arredondar
    int scaledValue = (normalizedValue * (32 - 1) + 1).round();

    // Garantir que o valor fique dentro da range esperada (1 até 32)
    return scaledValue.clamp(1, 32);
  }

  int getPower({required resistanceValue, required rpmValue}) {
    try {
      double result = _getInterpolatedValue(resistanceValue, rpmValue);
      return result.round();
    } catch (e) {
      print(e);
      return 0;
    }
  }

  // Construindo uma tabela 2D com List of Lists
  // Os fornecedores da China que nos passaram essa tabela
  List<List<double>> resistanceTable = [
    [1, 1, 1.5, 3, 5, 9, 10, 11, 12, 14, 15.5],
    [2, 1.5, 2, 6, 9, 15, 17, 24, 28, 32, 36],
    [3, 2, 3, 9, 13, 24, 31, 41, 45, 47, 54],
    [4, 2.5, 4, 11, 17.5, 31.5, 41, 52, 56, 62, 69],
    [5, 3, 5, 13, 20.5, 35, 46, 60, 63, 71, 85],
    [6, 3, 6, 15, 25, 40, 50, 65, 75, 87, 96],
    [7, 3.5, 7, 18, 28, 44.5, 62, 72, 82, 95, 116],
    [8, 3.5, 8, 20, 31, 51.5, 73, 86, 91, 105, 122],
    [9, 4, 11, 22.5, 36, 55.5, 82, 105, 110, 115, 129],
    [10, 4, 12, 30.5, 43, 65, 90, 117, 122, 136, 147],
    [11, 4.5, 14, 35, 50, 70, 105, 121, 140, 152, 190],
    [12, 4.5, 15, 38.5, 57, 87, 117, 152, 189, 184, 223],
    [13, 5, 17.5, 44.5, 63.5, 97, 139, 175, 212, 221, 258],
    [14, 5.7, 19, 49.5, 72, 116, 165, 202, 241, 256, 307],
    [15, 6.3, 22, 56.5, 83, 132, 190, 250, 272, 289, 341],
    [16, 7.4, 25, 62.5, 97, 143, 205, 274, 320, 327, 385],
    [17, 8, 28.5, 70, 104, 157, 225, 296, 334, 356, 399],
    [18, 8.7, 31, 78, 122, 172, 242, 322, 352, 385, 423],
    [19, 9.3, 35, 85, 131, 192, 253, 360, 387, 415, 455],
    [20, 10.6, 37.5, 90, 140, 212, 300, 395, 412, 438, 475],
    [21, 11.5, 42, 100, 152, 240, 332, 425, 453, 472, 525],
    [22, 12.7, 45.5, 110, 168, 255, 354, 443, 479, 508, 560],
    [23, 13.5, 49, 115, 180, 275, 385, 485, 516, 540, 613],
    [24, 14.5, 52.5, 125, 197, 302, 410, 520, 542, 562, 645],
    [25, 15.5, 59.5, 132, 215, 322, 440, 561, 583, 605.5, 678],
    [26, 16, 63.5, 145, 228, 340, 462, 600, 614, 645, 717],
    [27, 17.2, 65.5, 152, 242, 356, 497, 642, 662, 685, 745],
    [28, 18, 71, 160, 254, 378, 515, 678, 699, 720, 752],
    [29, 19.5, 74, 178, 266, 400, 538, 705, 735, 759.5, 789],
    [30, 28, 82, 187, 293, 436, 578, 747, 762, 800, 826],
    [31, 35, 97, 200, 325, 460, 602, 782, 810, 832, 865],
    [32, 50, 130, 210, 350, 483, 615, 820, 845, 862, 900]
  ];

  // Definindo os headers da coluna de RPM também de acordo com a tabela do fornecedor
  List<int> rpmHeaders = [10, 20, 30, 40, 50, 60, 70, 80, 90, 100];

  // Função para procurar o valor na tabela baseado na resistência e no RPM
  double _getInterpolatedValue(double resistance, int rpm) {
    // Encontrar o index da resistência na tabela
    int resistanceIndex = resistance.toInt() - 1;

    // Encontrar o index do RPM na lista de headers
    int rpmIndex = rpmHeaders.indexOf(rpm);

    if (resistanceIndex >= 0 && resistanceIndex < resistanceTable.length) {
      // Se o número exato do RPM existir na tabela, apenas retornar o valor
      if (rpmIndex >= 0 && rpmIndex < rpmHeaders.length) {
        return resistanceTable[resistanceIndex][rpmIndex + 1]; // +1 because the first column is resistance
      } else {
        // Se o valor de RPM não estiver na tabela, encontrar o RPM mais próximo
        // dentro os valores adjacentes
        int lowerRPMIndex = rpmHeaders.indexWhere((rpmValue) => rpmValue > rpm) - 1;
        int upperRPMIndex = lowerRPMIndex + 1;

        // Se o valor não estiver fora dos limites da tabela, tratá-lo
        if (lowerRPMIndex < 0 || upperRPMIndex >= rpmHeaders.length) {
          throw ArgumentError('RPM is out of the valid range');
        }

        // Obter os valores da tabela dos RMPs adjacentes
        double lowerValue = resistanceTable[resistanceIndex][lowerRPMIndex + 1];
        double upperValue = resistanceTable[resistanceIndex][upperRPMIndex + 1];

        // Realizar uma interpolação linear
        double lowerRPM = rpmHeaders[lowerRPMIndex].toDouble();
        double upperRPM = rpmHeaders[upperRPMIndex].toDouble();

        double interpolatedValue = lowerValue + (upperValue - lowerValue) * (rpm - lowerRPM) / (upperRPM - lowerRPM);
        return interpolatedValue;
      }
    } else {
      throw ArgumentError('Invalid resistance value');
    }
  }
}