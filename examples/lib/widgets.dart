import 'dart:io';
import 'package:intl/intl.dart';
import 'package:capnotrainer_sdk/capnotrainer_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:capnotrainer_sdk/capnotrainer_sdk.dart';

class BLEScreen extends StatefulWidget {
  BLEScreen() : super();
  final List<BleCapnos> capnoDevices = <BleCapnos>[];
  final List<BluetoothDevice> bleDevices = <BluetoothDevice>[];
  String bleStatusMsg = "Status: None";
  String btnText = "Connect";

  List<CapnoTrainerDataPoint> co2 = [];
  double etco2 = 0;
  double battery = 0;
  double bpm = 0;
  double insp_co2 = 0;
  bool airwayBlocked = false;

  @override
  _BLEScreenState createState() => _BLEScreenState();
}

class _BLEScreenState extends State<BLEScreen> {
  CapnoTrainer capnoTrainer = CapnoTrainer();

  _addDeviceTolist(final BluetoothDevice device) async {

    if (!widget.bleDevices.contains(device)){
      setState(() {
        widget.bleDevices.add(device);
        widget.capnoDevices.add( BleCapnos(device) );
      });
    }

  }

  void handleCheckBluetoothAndLocationPermissions() async {
    Permission locationPermission = Permission.locationWhenInUse;
    Permission bluetoothPermission = Permission.bluetoothScan;

    PermissionStatus locationStatus = await  locationPermission.status;
    PermissionStatus bluetoothStatus = await  bluetoothPermission.status;

    if ( locationStatus != PermissionStatus.granted ) {
      await locationPermission.request();
    }
    if (Platform.isAndroid){
      if ( bluetoothStatus != PermissionStatus.granted ) {
        await bluetoothPermission.request();
      }
    }
  }

  Future<bool> _checkDeviceLocationIsOn() async {
    return await Permission.locationWhenInUse.serviceStatus.isEnabled;
  }

  Future<bool> _checkDeviceBluetoothIsOn() async {
    return await FlutterBluePlus.adapterState.first == BluetoothAdapterState.on;
  }

  void handleBluetoothScans() async {

    bool isLocation = await _checkDeviceLocationIsOn();
    bool isBle = await _checkDeviceBluetoothIsOn();

    if (!isLocation){ setState( () =>   widget.bleStatusMsg = "Status: Turn on mobile location");}
    if (!isBle){ setState(() => widget.bleStatusMsg = "Status: Turn on mobile bluetooth adapter");}
    if ( !isBle || !isLocation) { return ; }
    setState(() =>   widget.bleStatusMsg = "Status: Scanning..." );
    setState(() =>  widget.capnoDevices.length = 0);
    setState(() =>  widget.bleDevices.length = 0);

    Guid goGoServiceGuid = Guid("00001000-0000-1000-8000-00805f9b34fb");
    List<Guid> scanServices = [goGoServiceGuid];

    try {
      FlutterBluePlus.isSupported.then((isSupported) {
        if (isSupported) FlutterBluePlus.setLogLevel(LogLevel.info);
      });

      FlutterBluePlus.adapterState.listen((event) {
        setState(() {});
      });

      FlutterBluePlus.connectedDevices.forEach((element) {
        _addDeviceTolist(element);
      });

      FlutterBluePlus.scanResults.listen((List<ScanResult> results) {
        for (ScanResult result in results) {
          _addDeviceTolist(result.device);
        }
      });

      FlutterBluePlus.startScan(withServices: scanServices);
      // FlutterBluePlus.startScan();
    } catch (e) {
      print(e.toString());
    }
  }

  void onDataReceived(List<CapnoTrainerDataPoint> data, CapnoTraienrStatusCodes code){

    switch(code){
      case CapnoTraienrStatusCodes.CODE_CONNECTED:
        {
          setState(() => widget.bleStatusMsg = "Status: Connected to ${capnoTrainer.device.advName}");
          setState(() => widget.btnText = "Disconnect");
        } break;
      case CapnoTraienrStatusCodes.CODE_DISCONNECTED:
        {
          setState(() {
            widget.btnText = "Connect";
            widget.battery = 0;
            widget.etco2 = 0;
            widget.bpm = 0;
          });
          handleBluetoothScans();
        } break;
      case CapnoTraienrStatusCodes.CODE_RAW_CO2_DATA:
        {
          setState(() {
            widget.co2.addAll(data);
            if (widget.co2.length > 10){
             widget.co2.removeRange(0, widget.co2.length - 10);
            }
          });
        } break;
      case CapnoTraienrStatusCodes.CODE_BATTERY_DATA:
        {
          setState(() => widget.battery = data.last.y );
        } break;
      case CapnoTraienrStatusCodes.CODE_ETCO2_DATA:
        {
          setState(() => widget.etco2 = data.last.y );
        } break;
      case CapnoTraienrStatusCodes.CODE_BPM_DATA:
        {
          setState(() => widget.bpm = data.last.y );
        } break;
      case CapnoTraienrStatusCodes.CODE_INSP_CO2_DATA:
        {
          setState(() => widget.insp_co2 = data.last.y );
        } break;
      case CapnoTraienrStatusCodes.CODE_AIRWAY_BLOCKED:
        {
          setState(() => widget.airwayBlocked = true );
        } break;
      default: {

      }
    }
  }

  void handleButton(int index) async{
    if (!capnoTrainer.isConnected){
      setState(() => widget.bleStatusMsg = "Status: Connecting to ${widget.bleDevices.elementAt(index).advName}");
      await FlutterBluePlus.stopScan();
      await capnoTrainer.connect(widget.bleDevices.elementAt(index), onDataReceived);
    } else {
      await capnoTrainer.disconnect();
    }
    print (capnoTrainer.isConnected);
  }

  @override
  void initState() {
    super.initState();
    handleCheckBluetoothAndLocationPermissions();
    handleBluetoothScans();
  }

  @override
  void dispose() {
    FlutterBluePlus.stopScan();
    // TODO: implement dispose
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _bleScreenView();

  Widget _bleScreenView() {
    return Container(
      height: MediaQuery.of(context).size.height,
      width: MediaQuery.of(context).size.width,
      padding: const EdgeInsets.only(left: 20, right: 20),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.bleStatusMsg),
            const Divider(
              thickness: 1,
            ),
            _buildDeviceView()
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceView() {
    return Column(
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * .75,
          child: ListView.builder(
            itemCount: widget.capnoDevices.length,
            itemBuilder: (context, index) => Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.fromLTRB(5, 5, 5, 5),
                  minLeadingWidth: 0,
                  horizontalTitleGap: 4,
                  leading: const Icon(
                    Icons.bluetooth,
                    size: 36,
                  ),
                  title: Text(
                    widget.capnoDevices.elementAt(index).title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  subtitle: Text(
                    widget.capnoDevices.elementAt(index).subtitle,
                    style: const TextStyle(
                        fontWeight: FontWeight.w300, fontSize: 13),
                  ),
                  trailing: OutlinedButton(
                    onPressed: () async {handleButton(index);},
                    child: Text(widget.btnText),
                  )),
                  
                const Divider(thickness: 2,),
                Text("Battery: ${widget.battery}%  |  Airway Blocked: ${widget.airwayBlocked ? 'Yes' : 'No'}"),
                const Divider(thickness: 2,),
                Text("InspCO2: ${widget.insp_co2} mmHg  | "
                    " BPM:  ${widget.bpm} | "
                    " ETCO2: ${widget.etco2} mmHg"
                ),

                const Divider(thickness: 2,),
                const Text("Raw CO2 Data"),
                SizedBox(height: 5,),
                SizedBox(
                  height: MediaQuery.of(context).size.height*0.3,
                  width: MediaQuery.of(context).size.width,
                  child: _tableView(context),
                )
              ],
            ))),
      ],
    );
  }

  Widget _tableView(BuildContext context) {
    return ListView.builder(
      itemCount: widget.co2.length,
      itemBuilder: (context, index) {
        return Row(
          children: <Widget>[
            Expanded(
              child: Container(
                padding: EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                ),
                child: Text(
                  DateFormat("mm:ss")
                      .format(
                        DateTime.fromMillisecondsSinceEpoch(
                            widget.co2[index].x.toInt()
                        )
                  ).toString()
                ),
              ),
            ),
            Expanded(
              child: Container(
                padding: EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                ),
                child: Text("${widget.co2[index].y.toString()} mmHg"),
              ),
            ),
          ],
        );
      },
    );
  }

}

class BleCapnos {
  BluetoothDevice capno;
  String title = "";
  String subtitle = "";
  BleCapnos(this.capno){
    this.title = this.capno.advName;
    this.subtitle = "CapnoTrainer GO";
  }
}
