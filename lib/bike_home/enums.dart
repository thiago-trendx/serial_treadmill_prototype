enum CommandType {
  readBikeData,
  readPower,
  readCadence,
  readResistance,
  readID,
  readBikeName,
  readMagneticSysPosition,
  writeNewID,
  writeCalibrationRef,
}

extension CommandTypeToINS on CommandType {
  int toINS() {
    switch(this) {
      case CommandType.readBikeData:
        return 0x10;
      case CommandType.readPower:
        return 0x11;
      case CommandType.readCadence:
        return 0x12;
      case CommandType.readResistance:
        return 0x01;
      case CommandType.readID:
        return 0x02;
      case CommandType.readBikeName:
        return 0x50;
      case CommandType.readMagneticSysPosition:
        return 0x03;
      case CommandType.writeNewID:
        return 0x90;
      case CommandType.writeCalibrationRef:
        return 0x91;
    }
  }
}