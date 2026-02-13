import 'device_specs.dart';

abstract class DeviceSpecsCollector {
  Future<DeviceSpecs> collect();
}
