import 'package:capnotrainer_sdk/capnotrainer_utils.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'dart:async';
import 'package:capnotrainer_sdk/capnotrainer_go_parser.dart';

class CapnoTrainer {

  bool _printLog = false;
  late BluetoothDevice device;
  late Function onDataReceived;
  late BluetoothCharacteristic _readCharacteristic;
  late BluetoothCharacteristic _writeCharacteristic;

  // device identifier
  Guid capnoServiceGuid = Guid("00001000-0000-1000-8000-00805f9b34fb");
  Guid capnoReadCharGuid =  Guid("00001002-0000-1000-8000-00805f9b34fb");
  Guid capnoWriteCharGuid =  Guid("00001001-0000-1000-8000-00805f9b34fb");

  // local state
  bool _deviceBleState = false;
  BluetoothConnectionState _deviceConnectionState = BluetoothConnectionState.disconnected;
  late StreamSubscription _deviceStateSubscription;
  late StreamSubscription _deviceReadSubscription;
  Timer _deviceWriteTimer = Timer(const Duration(hours: 1), () => {},);
  late CapnoTrainerGoParser _parser;

  bool get isConnected => _deviceConnectionState == BluetoothConnectionState.connected;

  Future<void> connect(BluetoothDevice d, Function onData, bool debug) async {
   _printLog = debug;
    device = d;
    onDataReceived = onData;

    if (!isConnected){
      try{
        await device.connect(autoConnect: true);
      } catch(e){
        if (_printLog) print ("[CapnoTrainer SDK] ${e}");
      }
      _deviceStateSubscription = device.connectionState.listen(
          _handleDeviceState,
          onError: (e)=>{ if (_printLog) print("[CapmoTrainer SDK] ${e}")},
          onDone: () => { if (_printLog) print ("[CapnoTrainer SDK] ") }
      );
    }
  }

  Future<void> disconnect() async {
    if (_deviceWriteTimer.isActive) _deviceWriteTimer.cancel();
    await _deviceStateSubscription.cancel();
    await _deviceReadSubscription.cancel();
    await device.disconnect(timeout: 30);
    onDataReceived(<CapnoTrainerDataPoint>[], CapnoTraienrStatusCodes.CODE_DISCONNECTED);
    _deviceConnectionState = BluetoothConnectionState.disconnected;
  }

  _handleDeviceState(BluetoothConnectionState state) async {
    _deviceConnectionState = state;
    _deviceBleState = BluetoothConnectionState.connected == state;
    if (state == BluetoothConnectionState.connected){
      await _handleSetupDevice();
      onDataReceived(<CapnoTrainerDataPoint>[], CapnoTraienrStatusCodes.CODE_CONNECTED);
    }
  }

  Future<void> _handleSetupDevice() async {
    List<BluetoothService> services = await device.discoverServices();
    for (BluetoothService service in services) {
      if (service.uuid == capnoServiceGuid) {
        for (BluetoothCharacteristic characteristic
        in service.characteristics) {
          if (characteristic.uuid == capnoReadCharGuid) {
            _readCharacteristic = characteristic;
          } else if (characteristic.uuid == capnoWriteCharGuid) {
            _writeCharacteristic = characteristic;
          }
        }
      }
    }

    try{
      await _readCharacteristic.setNotifyValue(true);
    } catch(e){
      if (_printLog) print ("[CapnoTrainer SDK] ${e}");
    }

    await Future.delayed(const Duration(milliseconds: 100));

    _deviceReadSubscription = _readCharacteristic.lastValueStream.listen(
      _onDeviceData, onError: _onDeviceError, onDone: _onDeviceDone
    );

    _parser = CapnoTrainerGoParser(_handleDeviceWrite, onDataReceived);

    if (_deviceWriteTimer.isActive) _deviceWriteTimer.cancel();
    _deviceWriteTimer = Timer.periodic(const Duration(milliseconds: 100), _onDeviceWrite );

  }

  _onDeviceData(List<int> data) async {
    await _parser.handlePackagedDataRead(data);
  }

  _onDeviceError(e){
    if (_printLog) print ("[CapnoTrainer SDK] ${e}");
  }

  _onDeviceDone(){

  }

  _onDeviceWrite(Timer timer) async {
    if (!_parser.isReceivedPressure) {
      await _parser.handleBarometricPressureRequest();
    } else if (!_parser.isReceivedTemperature){
      await _parser.handleGasTemperatureRequest();
    } else {
      await _parser.handleBatteryStatusRequest();
      await _parser.handleStartStreamRequest();
      timer.cancel();
    }
  }

  _handleDeviceWrite(List<int> cmd) async {
    try{
      if (_deviceBleState){
        await _writeCharacteristic.write(cmd);
      } else {
        if (_printLog) print ("[CapnoTrainer SDK] Device is not connected. Unable to write to characteristics");
      }
    } catch (e) {
      if (_printLog) print ("[CapnoTrainer SDK] ${e}");
    }
  }

}
