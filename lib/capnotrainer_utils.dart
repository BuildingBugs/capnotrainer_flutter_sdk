
class CapnoTrainerDataPoint{
  CapnoTrainerDataPoint(this.x, this.y);
  final double x ;
  final double y ;
}

enum CapnoTraienrStatusCodes {
  CODE_CONNECTED,
  CODE_DISCONNECTED,
  CODE_READY_TO_ZERO,
  CODE_RAW_CO2_DATA,
  CODE_ETCO2_DATA,
  CODE_BPM_DATA,
  CODE_INSP_CO2_DATA,
  CODE_BATTERY_DATA,
  CODE_AIRWAY_BLOCKED,
}
