import 'dart:async';
import 'dart:math';
import 'package:capnotrainer_sdk/capnotrainer_utils.dart';

class CapnoTrainerSimulation { 
  final _printLog = false ;
  late Function onDataReceived ;

  bool _isConnected = false; 
  late Timer _deviceTimer; 

  final int _rateCo2 = 20; 
  int _samplesCo2 = 0; 
  final List<CapnoTrainerDataPoint> _dataCo2 = [];

  bool get isConnected => _isConnected;

  String get title => "CapnoTrainer";
  String get subtitle => "Simulation";
  int get samplesCo2 => _samplesCo2;
  int get rateCo2 => _rateCo2;
  void set setDataRawCo2(CapnoTrainerDataPoint point) => _dataCo2.add(point);
  void set setSampleCo2(int samples) => _samplesCo2 = samples;

  Future<void> connect(Function onData) async {
    if (!isConnected){
      onDataReceived = onData;
      _deviceTimer = Timer.periodic(const Duration(milliseconds: 100), _handleDataGeneration);
      _isConnected = true; 
      onDataReceived(<CapnoTrainerDataPoint>[], CapnoTraienrStatusCodes.CODE_CONNECTED);
    }
  }

  Future<void> disconnect() async { 
    if (isConnected){
      _deviceTimer.cancel();
      _isConnected = false;
      onDataReceived(<CapnoTrainerDataPoint>[], CapnoTraienrStatusCodes.CODE_DISCONNECTED);
      setSampleCo2 = 0; 
      _dataCo2.clear();

    }
  }

  void _handleDataGeneration(Timer t) { 

    double amplitude = 20.0; 
    double frequency = 0.2;

    for (int i = 0; i < 2; i++ ){
      double x = samplesCo2 * 1000 / rateCo2; 
      double co2 = amplitude * sin( 2 * pi * x * frequency / 1000) + amplitude;
      setDataRawCo2 = CapnoTrainerDataPoint(x, co2); 
      setSampleCo2 = samplesCo2 + 1; 
 
      if ( _dataCo2.length >= 10 ) { 
        List<CapnoTrainerDataPoint> co2Data = _dataCo2; 
        onDataReceived(co2Data, CapnoTraienrStatusCodes.CODE_RAW_CO2_DATA);
        _dataCo2.clear();
      }

      if ( x ~/ 1000 % 300 == 0){
        double battery = 95.0 + Random().nextDouble();
        CapnoTrainerDataPoint batData = CapnoTrainerDataPoint(samplesCo2 * 1000 / rateCo2, battery);
        onDataReceived([batData], CapnoTraienrStatusCodes.CODE_BATTERY_DATA);
      }

      if ( x ~/ 1000 % 60 == 0){
        double etco2 = amplitude+ Random().nextDouble();
        CapnoTrainerDataPoint batData = CapnoTrainerDataPoint(samplesCo2 * 1000 / rateCo2, etco2);
        onDataReceived([batData], CapnoTraienrStatusCodes.CODE_ETCO2_DATA);
      }

      if ( x ~/ 1000 % 60 == 0){
        double bpm = frequency * 60+ Random().nextDouble();
        CapnoTrainerDataPoint batData = CapnoTrainerDataPoint(samplesCo2 * 1000 / rateCo2, bpm);
        onDataReceived([batData], CapnoTraienrStatusCodes.CODE_BPM_DATA);
      }
 
    }

  }

}