import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'device/device_specs.dart';
import 'monitoring/app_resource_monitoring_config.dart';
import 'runtime_insight_platform_interface.dart';

class MethodChannelRuntimeInsight extends RuntimeInsightPlatform {
  @visibleForTesting
  final methodChannel = const MethodChannel('runtime_insight/device_specs');

  @visibleForTesting
  final metricsMethodChannel = const MethodChannel(
    'runtime_insight/app_metrics',
  );

  @visibleForTesting
  final metricsEventChannel = const EventChannel(
    'runtime_insight/app_metrics_stream',
  );

  @override
  Future<DeviceSpecs> collectDeviceSpecs() async {
    final Map<dynamic, dynamic> deviceSpecs = await methodChannel.invokeMethod(
      'collect',
    );

    final platform = Platform.isIOS
        ? DevicePlatform.ios
        : DevicePlatform.android;
    final dynamic osVersionValue = deviceSpecs['osVersion'];
    final int? osVersion = osVersionValue is int
        ? osVersionValue
        : osVersionValue is String
        ? int.tryParse(osVersionValue)
        : null;

    return DeviceSpecs(
      platform: platform,
      cpuCores: deviceSpecs['cpuCores'],
      ramMb: deviceSpecs['ramMb'],
      osVersion: osVersion,
      isEmulator: deviceSpecs['isEmulator'] ?? false,
      performanceClass: deviceSpecs['performanceClass'],
    );
  }

  @override
  Stream<Map<String, dynamic>> appMetricsStream(
    AppResourceMonitoringConfig config,
  ) async* {
    await metricsMethodChannel.invokeMethod('startMonitoring', config.toMap());

    yield* metricsEventChannel.receiveBroadcastStream().map(
      (event) => Map<String, dynamic>.from(event as Map),
    );
  }

  @override
  Future<void> updateMonitoringConfig(
    AppResourceMonitoringConfig config,
  ) async {
    await metricsMethodChannel.invokeMethod('updateMonitoring', config.toMap());
  }

  @override
  Future<void> pauseMonitoring() async {
    await metricsMethodChannel.invokeMethod('pauseMonitoring');
  }

  @override
  Future<void> resumeMonitoring() async {
    await metricsMethodChannel.invokeMethod('resumeMonitoring');
  }

  @override
  Future<void> stopMonitoring() async {
    await metricsMethodChannel.invokeMethod('stopMonitoring');
  }
}
