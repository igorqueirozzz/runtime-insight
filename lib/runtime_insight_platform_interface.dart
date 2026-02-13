import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'device/device_specs.dart';
import 'monitoring/app_resource_monitoring_config.dart';
import 'runtime_insight_method_channel.dart';

abstract class RuntimeInsightPlatform extends PlatformInterface {
  RuntimeInsightPlatform() : super(token: _token);

  static final Object _token = Object();

  static RuntimeInsightPlatform _instance = MethodChannelRuntimeInsight();

  static RuntimeInsightPlatform get instance => _instance;

  static set instance(RuntimeInsightPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<DeviceSpecs> collectDeviceSpecs() {
    throw UnimplementedError('collectDeviceSpecs() has not been implemented.');
  }

  Stream<Map<String, dynamic>> appMetricsStream(
    AppResourceMonitoringConfig config,
  ) {
    throw UnimplementedError('appMetricsStream() has not been implemented.');
  }

  Future<void> updateMonitoringConfig(AppResourceMonitoringConfig config) {
    throw UnimplementedError(
      'updateMonitoringConfig() has not been implemented.',
    );
  }

  Future<void> pauseMonitoring() {
    throw UnimplementedError('pauseMonitoring() has not been implemented.');
  }

  Future<void> resumeMonitoring() {
    throw UnimplementedError('resumeMonitoring() has not been implemented.');
  }

  Future<void> stopMonitoring() {
    throw UnimplementedError('stopMonitoring() has not been implemented.');
  }
}
