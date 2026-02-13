import 'dart:io';

import 'package:runtime_insight/device/device_specs.dart';
import 'package:runtime_insight/device/device_specs_collector.dart';
import 'package:runtime_insight/runtime_insight_platform_interface.dart';

final class DeviceSpecsCollectorAndroid extends DeviceSpecsCollector {
  @override
  Future<DeviceSpecs> collect() async {
    if (!Platform.isAndroid) {
      throw UnsupportedError(
        'DeviceSpecsCollectorAndroid can only be used on Android',
      );
    }

    return RuntimeInsightPlatform.instance.collectDeviceSpecs();
  }
}
