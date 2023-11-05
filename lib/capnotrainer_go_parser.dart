import 'dart:math';
import 'package:capnotrainer_sdk/capnotrainer_utils.dart';

class CapnoTrainerGoParser{

  final Function _handleSendCmd;
  final Function _onDataReceived;
  final bool _printLog = false;

  final List<CapnoTrainerDataPoint> _dataCo2 = [];
  int _samplesCo2 = 0;
  final int _rateCo2 = 100;

  // basic parsing holder
  List<int> _incomingDataLast = [];

  // write variables
  bool _isReceivedTemperature = false;
  bool _isReceivedPressure = false;
  bool _isReceivedBattery = false;

  void set setDataRawCo2(CapnoTrainerDataPoint point) => _dataCo2.add(point);
  void set setSampleCo2(int samples) => _samplesCo2 = samples;

  bool get isReceivedTemperature => _isReceivedTemperature;
  bool get isReceivedPressure => _isReceivedPressure;
  bool get isReceivedBattery => _isReceivedBattery;
  int get samplesCo2 => _samplesCo2;
  int get rateCo2 => _rateCo2;

  CapnoTrainerGoParser(this._handleSendCmd, this._onDataReceived);

  handlePackagedDataRead(List<int> incoming){

    List<int> data = [..._incomingDataLast, ...incoming];
    _incomingDataLast = [];
    int count = 0;

    for (count = 0; count < data.length; count++) {
      bool isCmdByte = data.elementAt(count) >= 0x80;
      if (isCmdByte) {
        int subDataSize = data.elementAt(1) + 2;
        if (data.length >= count + subDataSize) {
          List<int> subData =
          data.getRange(count, count + subDataSize).toList();
          if (handleCorrectChecksum(subData) && subData.length == subDataSize) {
            handleCmdByteParsing(subData);
          } else {

          }
        } else {
          _incomingDataLast = data.getRange(count, data.length).toList();
        }
      }
    }
  }

  handlePackageDataWrite(List<int> cmd) async {
    cmd = _handleAddChecksum(cmd);
    if (handleCorrectChecksum(cmd)){
      await _handleSendCmd(cmd);
    }
  }

  bool handleCorrectChecksum(List<int> cmd) {
    int sum = 0x00;
    int checksum = 0x00;

    if (cmd.elementAt(0) < 0x80) {
      return false;
    } else {
      int size = cmd.elementAt(1) + 2;
      if (size != cmd.length) {
        return false;
      }
      for (int i = 0; i < size; i++) {
        sum = sum + cmd.elementAt(i);
      }
      checksum = (sum & 0x7F + checksum);
      checksum &= 0x7F;

      if (checksum == 0x00)
        return true;
      else
        return false;
    }
  }


  void handleCmdByteParsing(List<int> data) {
    int cmdByte = data.elementAt(0);
    switch (cmdByte) {
      case 0x80:
        this._handleStartStreamResponse(data);
        break;
      case 0xC9:
        this._handleStopStreamResponse(data);
        break;
      case 0x84:
        int isbType = data.elementAt(2);
        switch (isbType) {
          case 0:
            break;
          case 1:
            _handleBarometricPressureResponse(data);
            break;
          case 4:
            _handleGasTemperatureResponse(data);
            break;
          default:
          // TODO: Add more response for ISB types.
            break;
        }
        break;

      case 0xFB:
        int infoType = data.elementAt(2);
        switch (infoType) {
          case 0x07:
            _handleBatteryStatusResponse(data);
            break;
          default:
          // TODO: Add more response for infor types.
            break;
        }
        break;
      case 0xC8:
        _handleNackErrorCodes(data);
        break;
      default:
      // print ("CapnoTrainer 7.0 - Unknown data type received");
    }
  }

  List<int> _handleAddChecksum(List<int> cmd) {
    int checksum = 0x00;
    int size = cmd.elementAt(1) + 1;
    for (int i = 0; i < size; i++) {
      checksum = checksum + cmd.elementAt(i);
    }
    checksum = (~checksum + 1) & 0x7F;
    cmd[cmd.length - 1] = checksum;

    return cmd;
  }

  String _handleNackErrorCodes(List<int> cmd) {
    int errorCode = cmd.elementAt(2);
    switch (errorCode) {
      case 0x00:
        return "BOOTCODE_WAITE";
        break;
      case 0x01:
        return "INVALID_COMMAND";
        break;
      case 0x02:
        return "CHECKSUM_ERROR";
        break;
      case 0x03:
        return "TIMEOUT_ERROR";
        break;
      case 0x04:
        return "INVALID_BYTE_COUNT";
        break;
      case 0x05:
        return "INVALID_BYTE_DATA";
        break;
      case 0x06:
        return "SYSTEM_FAULTY";
        break;
      default:
        return "";
        break;
    }
  }


  Future<void> _handleStopStreamRequest() async {
    List<int> cmd = [0xC9, 0x01, 0x00];
    await handlePackageDataWrite(cmd);
  }

  void _handleStopStreamResponse(List<int> data) {
    // stop stream
  }

  Future<void> handleStartStreamRequest() async {
    List<int> cmd = [0x80, 0x02, 0x00, 0x00];
    await handlePackageDataWrite(cmd);
  }

  void _handleStartStreamResponse(List<int> data) {

    try{
      int nbf = data.elementAt(1);
      int sync = data.elementAt(2);
      int co2wb1 = data.elementAt(3);
      int co2wb2 = data.elementAt(4);
      double co2 = (((128.0 * co2wb1.toDouble()) + co2wb2.toDouble()) - 1000.0) / 100.0;
      double x = samplesCo2 * 1000 / rateCo2;

      setDataRawCo2 = CapnoTrainerDataPoint(x, co2);
      setSampleCo2 = samplesCo2 + 1;

      if ( _dataCo2.length > 10 ) {
        List<CapnoTrainerDataPoint> co2Data = _dataCo2;
        _onDataReceived(co2Data, CapnoTraienrStatusCodes.CODE_RAW_CO2_DATA);
        _dataCo2.clear();
      }

      // send battery update request every 5 minutes.
      if ( x ~/ 1000 % 300 == 0){
        handleBarometricPressureRequest();
      }

      if ( nbf > 6 ) {
        int dpi = data.elementAt(5);
        if ( dpi == 1 ) {
          int dpb1 = data.elementAt(6);
          int dpb2 = data.elementAt(7);
          int dpb3 = data.elementAt(8);
          int dpb4 = data.elementAt(9);
          int dpb5 = data.elementAt(10);
          if ( dpb1 & 0x10 == 0x10 && dpb4 & 0x04 == 0x04 ){
            _onDataReceived(<CapnoTrainerDataPoint>[], CapnoTraienrStatusCodes.CODE_AIRWAY_BLOCKED);
          }

          bool breathDetected = dpb1 & 0x40 == 0x40;
          bool canNotZero = dpb1 & 0x10 == 0x10;
          // if ( !breathDetected && !canNotZero ){
          //   _onDataReceived([], CapnoTraienrStatusCodes.CODE_READY_TO_ZERO);
          // }

        } else if ( dpi == 2  ){
          int dpb1 = data.elementAt(6);
          int dpb2 = data.elementAt(7);
          double etco2 = (dpb1 * 128 + dpb2).toDouble() / 10.0;
          _onDataReceived(
              [CapnoTrainerDataPoint(samplesCo2*1000/rateCo2, etco2)],
              CapnoTraienrStatusCodes.CODE_ETCO2_DATA
          );
        } else if ( dpi == 3 ){
          int dpb1 = data.elementAt(6);
          int dpb2 = data.elementAt(7);
          double bpm = (dpb1 * 128 + dpb2).toDouble();
          _onDataReceived(
              [CapnoTrainerDataPoint(samplesCo2*1000/rateCo2, bpm)],
              CapnoTraienrStatusCodes.CODE_BPM_DATA
          );
        } else if ( dpi == 4 ){
          int dpb1 = data.elementAt(6);
          int dpb2 = data.elementAt(7);
          double insp = (dpb1 * 128 + dpb2).toDouble() / 10.0;
          _onDataReceived(
              [CapnoTrainerDataPoint(samplesCo2*1000/rateCo2, insp)],
              CapnoTraienrStatusCodes.CODE_INSP_CO2_DATA
          );
        }
      }

    } catch(e){
      if (_printLog) print("[CapnoTrainer SDK] $e}");
    }
  }

  Future<void> handleBarometricPressureRequest() async {
    List<int> cmd = [0x84, 0x02, 0x01, 0x00];
    await handlePackageDataWrite(cmd);
  }

  void _handleBarometricPressureResponse(List<int> data) {
    double _pressure = (data.elementAt(3) * 128 + data.elementAt(4)).toDouble();
    if (_printLog) print ("[CapnoTrainer SDK] CapnoTrainer Go pressure is $_pressure");
    _isReceivedPressure = true;
  }

  Future<void> handleGasTemperatureRequest() async {
    List<int> cmd = [0x84, 0x02, 0x04, 0x00];
    await handlePackageDataWrite(cmd);
  }

  void _handleGasTemperatureResponse(List<int> data) {
    double _temperature =
    ((data.elementAt(3) * 128 + data.elementAt(4)) / 2).toDouble();
    if (_printLog) print ("[CapnoTrainer SDK] CapnoTrainer Go temperature is $_temperature");
    _isReceivedTemperature = true;
  }

  Future<void> handleBatteryStatusRequest() async {
    List<int> cmd = [0xFB, 0x02, 0x07, 0x00];
    await handlePackageDataWrite(cmd);
  }

  void _handleBatteryStatusResponse(List<int> data) {
    double battery = data.elementAt(6).toDouble();
    CapnoTrainerDataPoint batData = CapnoTrainerDataPoint(samplesCo2 * 1000 / rateCo2, battery);
    _onDataReceived([batData], CapnoTraienrStatusCodes.CODE_BATTERY_DATA);
    if (_printLog) print ("[CapnoTrainer SDK] CapnoTrainer GO Battery is $battery %");
    _isReceivedBattery = true;
  }

}