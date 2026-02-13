import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:runtime_insight/device/device_specs.dart';
import 'package:runtime_insight/monitoring/app_resource_monitoring_config.dart';
import 'package:runtime_insight/runtime_insight_method_channel.dart';
import 'package:runtime_insight/runtime_insight_platform_interface.dart';

class MockRuntimeInsightPlatform
    with MockPlatformInterfaceMixin
    implements RuntimeInsightPlatform {
  @override
  Future<DeviceSpecs> collectDeviceSpecs() async {
    return DeviceSpecs(
      platform: DevicePlatform.android,
      cpuCores: 4,
      ramMb: 4096,
      osVersion: 34,
    );
  }

  @override
  Stream<Map<String, dynamic>> appMetricsStream(
    AppResourceMonitoringConfig config,
  ) {
    return const Stream.empty();
  }

  @override
  Future<void> updateMonitoringConfig(
    AppResourceMonitoringConfig config,
  ) async {}

  @override
  Future<void> pauseMonitoring() async {}

  @override
  Future<void> resumeMonitoring() async {}

  @override
  Future<void> stopMonitoring() async {}
}

void main() {
  test('$MethodChannelRuntimeInsight is the default instance', () {
    final RuntimeInsightPlatform initialPlatform =
        RuntimeInsightPlatform.instance;
    expect(initialPlatform, isInstanceOf<MethodChannelRuntimeInsight>());
  });

  test('RuntimeInsightPlatform instance can be replaced', () async {
    final fakePlatform = MockRuntimeInsightPlatform();
    RuntimeInsightPlatform.instance = fakePlatform;

    final specs = await RuntimeInsightPlatform.instance.collectDeviceSpecs();
    expect(specs.cpuCores, 4);
    expect(specs.ramMb, 4096);
    expect(specs.osVersion, 34);
  });
}
