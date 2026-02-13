import 'dart:io';
import 'dart:async';

import 'package:flutter/scheduler.dart';

export 'monitoring/app_resource_monitoring_config.dart';
export 'monitoring/app_resource_snapshot.dart';
export 'recommended_parallelism.dart';
export 'widgets/runtime_insight_overlay.dart';
export 'widgets/runtime_insight_overlay_controller.dart';
export 'widgets/runtime_insight_overlay_strings.dart';

import 'classifier/device_static_classifier.dart';
import 'classifier/device_tier.dart';
import 'device/device_specs.dart';
import 'monitoring/app_resource_monitoring_config.dart';
import 'monitoring/app_resource_snapshot.dart';
import 'recommended_parallelism.dart';
import 'runtime_insight_platform_interface.dart';

/// Main entry point for the runtime_insight plugin.
///
/// Provides device classification into tiers (low/mid/high) based on runtime
/// hardware characteristics, and continuous app resource monitoring via streams.
///
/// Call [init] before accessing any data. Example:
///
/// ```dart
/// await RuntimeInsight.init();
/// print(RuntimeInsight.deviceTier); // DeviceTier.high
/// ```
class RuntimeInsight {
  static DeviceSpecs? _specs;
  static DeviceTier? _tier;
  static Stream<AppResourceSnapshot>? _monitorStream;
  static StreamSubscription<AppResourceSnapshot>? _monitorSubscription;
  static StreamController<AppResourceSnapshot>? _monitorController;
  static AppResourceMonitoringConfig? _activeConfig;
  static AppResourceMonitoringConfig _defaultMonitoringConfig =
      const AppResourceMonitoringConfig();
  static Timer? _fpsTimer;
  static bool _fpsEnabled = false;
  static int _frameCount = 0;
  static double? _lastFps;
  static bool _fpsCallbackScheduled = false;
  static bool _monitorPaused = false;
  static int? _lastNetworkRxBytes;
  static int? _lastNetworkTxBytes;
  static int? _lastDiskReadBytes;
  static int? _lastDiskWriteBytes;
  static final List<AppResourceSnapshot> _window = [];

  /// Whether [init] has been called successfully.
  static bool get isInitialized => _specs != null;

  /// The collected hardware specifications for the current device.
  ///
  /// Throws [StateError] if [init] has not been called.
  static DeviceSpecs get deviceSpecs {
    _ensureInit();
    return _specs!;
  }

  /// The classified tier (low/mid/high) for the current device.
  ///
  /// Throws [StateError] if [init] has not been called.
  static DeviceTier get deviceTier {
    _ensureInit();
    return _tier!;
  }

  /// Returns `true` if the device is classified as low-end.
  static bool get isLowEnd => deviceTier == DeviceTier.low;

  /// Returns `true` if the device is classified as mid-range.
  static bool get isMidEnd => deviceTier == DeviceTier.mid;

  /// Returns `true` if the device is classified as high-end.
  static bool get isHighEnd => deviceTier == DeviceTier.high;

  /// Recommended parallelism limits based on the device tier.
  ///
  /// Returns separate limits for CPU-bound, IO-bound and network-bound work.
  static RecommendedParallelism get maxParallelRecommended {
    _ensureInit();

    switch (_tier!) {
      case DeviceTier.low:
        return const RecommendedParallelism(cpu: 1, io: 2, network: 2);
      case DeviceTier.mid:
        return const RecommendedParallelism(cpu: 3, io: 6, network: 4);
      case DeviceTier.high:
        return const RecommendedParallelism(cpu: 6, io: 12, network: 8);
    }
  }

  @Deprecated('Use maxParallelRecommended instead.')
  static int get maxParallelJobs => maxParallelRecommended.cpu;

  /// Initialises the plugin by collecting device specs and classifying the tier.
  ///
  /// Must be called once before accessing [deviceSpecs], [deviceTier] or any
  /// monitoring API. Subsequent calls are no-ops.
  ///
  /// Optionally pass [monitoredMetrics] to pre-configure which metrics to
  /// monitor, and/or [monitoringConfig] for fine-grained control.
  ///
  /// Throws [UnsupportedError] on platforms other than Android and iOS.
  static Future<void> init({
    List<AppMetric>? monitoredMetrics,
    AppResourceMonitoringConfig? monitoringConfig,
  }) async {
    if (_specs != null) return;

    if (!Platform.isAndroid && !Platform.isIOS) {
      throw UnsupportedError(
        'RuntimeInsight not supported on this platform yet',
      );
    }

    _specs = await RuntimeInsightPlatform.instance.collectDeviceSpecs();

    _tier = DeviceStaticClassifier.classify(_specs!);

    if (monitoringConfig != null) {
      _validateConfig(monitoringConfig);
      _defaultMonitoringConfig = monitoringConfig;
    }
    if (monitoredMetrics != null) {
      _validateMetrics(monitoredMetrics);
      _defaultMonitoringConfig = _configFromMetrics(
        monitoredMetrics,
        base: _defaultMonitoringConfig,
      );
    }
  }

  /// Starts continuous app resource monitoring and returns a broadcast stream
  /// of [AppResourceSnapshot] events.
  ///
  /// If monitoring is already active, returns the existing stream. Pass
  /// [config] to override the default monitoring configuration.
  static Stream<AppResourceSnapshot> startMonitoring({
    AppResourceMonitoringConfig? config,
  }) {
    final effectiveConfig = config ?? _defaultMonitoringConfig;
    _validateConfig(effectiveConfig);
    if (_monitorController != null) {
      if (_activeConfig != effectiveConfig) {
        updateMonitoringConfig(effectiveConfig);
      }
      return _monitorController!.stream;
    }

    _activeConfig = effectiveConfig;
    _monitorController = StreamController<AppResourceSnapshot>.broadcast(
      onListen: () {
        _startFpsMonitoringIfNeeded(effectiveConfig);
        _resetWindow();
        _monitorStream = RuntimeInsightPlatform.instance
            .appMetricsStream(effectiveConfig)
            .map(_mapSnapshotWithFps);
        _monitorSubscription = _monitorStream!.listen(
          (snapshot) {
            if (!(_monitorController?.isClosed ?? true)) {
              _monitorController?.add(snapshot);
            }
          },
          onError: (error, stack) {
            if (!(_monitorController?.isClosed ?? true)) {
              _monitorController?.addError(error, stack);
            }
          },
        );
      },
      onCancel: () async {
        await stopMonitoring();
      },
    );

    return _monitorController!.stream;
  }

  /// Updates the monitoring configuration while monitoring is active.
  ///
  /// Throws [StateError] if monitoring has not been started.
  static Future<void> updateMonitoringConfig(
    AppResourceMonitoringConfig config,
  ) async {
    if (_monitorController == null) {
      throw StateError('Monitoring is not active.');
    }

    _validateConfig(config);
    if (_activeConfig == config) return;
    _activeConfig = config;
    _defaultMonitoringConfig = config;

    if (config.fps) {
      _startFpsMonitoringIfNeeded(config);
    } else {
      _stopFpsMonitoring();
    }
    _resetWindow();
    await RuntimeInsightPlatform.instance.updateMonitoringConfig(config);
  }

  /// Enables a single [AppMetric] in the current monitoring session.
  static Future<void> enableMetric(AppMetric metric) async {
    await _setMetric(metric, true);
  }

  /// Disables a single [AppMetric] in the current monitoring session.
  static Future<void> disableMetric(AppMetric metric) async {
    await _setMetric(metric, false);
  }

  /// Changes the polling interval for monitoring snapshots.
  static Future<void> setInterval(Duration interval) async {
    await _updateConfigWith(interval: interval);
  }

  /// Sets the number of snapshots used to compute moving averages.
  static Future<void> setMovingAverageWindow(int window) async {
    await _updateConfigWith(movingAverageWindow: window);
  }

  /// Replaces the set of monitored metrics with [metrics].
  static Future<void> setMonitoredMetrics(List<AppMetric> metrics) async {
    _validateMetrics(metrics);
    final current = _activeConfig ?? _defaultMonitoringConfig;
    final next = _configFromMetrics(metrics, base: current);
    await _applyConfig(next);
  }

  /// Adds [metrics] to the current set of monitored metrics.
  static Future<void> addMetrics(List<AppMetric> metrics) async {
    _validateMetrics(metrics);
    final current = _activeConfig ?? _defaultMonitoringConfig;
    final merged = <AppMetric>{
      ..._metricsFromConfig(current),
      ...metrics,
    }.toList();
    final next = _configFromMetrics(merged, base: current);
    await _applyConfig(next);
  }

  /// Removes [metrics] from the current set of monitored metrics.
  static Future<void> removeMetrics(List<AppMetric> metrics) async {
    _validateMetrics(metrics);
    final current = _activeConfig ?? _defaultMonitoringConfig;
    final updated = _metricsFromConfig(current)..removeWhere(metrics.contains);
    _validateMetrics(updated);
    final next = _configFromMetrics(updated, base: current);
    await _applyConfig(next);
  }

  /// Pauses the active monitoring stream without destroying it.
  ///
  /// Throws [StateError] if monitoring has not been started.
  static Future<void> pauseMonitoring() async {
    if (_monitorController == null) {
      throw StateError('Monitoring is not active.');
    }
    if (_monitorPaused) return;
    _monitorPaused = true;
    _stopFpsMonitoring();
    await RuntimeInsightPlatform.instance.pauseMonitoring();
  }

  /// Resumes a previously paused monitoring stream.
  ///
  /// Throws [StateError] if monitoring has not been started.
  static Future<void> resumeMonitoring() async {
    if (_monitorController == null) {
      throw StateError('Monitoring is not active.');
    }
    if (!_monitorPaused) return;
    _monitorPaused = false;
    _startFpsMonitoringIfNeeded(
      _activeConfig ?? const AppResourceMonitoringConfig(),
    );
    await RuntimeInsightPlatform.instance.resumeMonitoring();
  }

  /// Stops monitoring, cancels the stream subscription and releases resources.
  static Future<void> stopMonitoring() async {
    await RuntimeInsightPlatform.instance.stopMonitoring();
    await _monitorSubscription?.cancel();
    await _monitorController?.close();
    _monitorSubscription = null;
    _monitorStream = null;
    _monitorController = null;
    _activeConfig = null;
    _monitorPaused = false;
    _stopFpsMonitoring();
    _resetWindow();
  }

  static void _ensureInit() {
    if (_specs == null) {
      throw StateError(
        'RuntimeInsight.init() must be called before accessing data',
      );
    }
  }

  static AppResourceSnapshot _mapSnapshotWithFps(Map<String, dynamic> event) {
    final timestampMs = event['timestampMs'] as int?;
    final cpuPercentRaw = _toDouble(event['cpuPercent']);
    final cpuPercent =
        cpuPercentRaw ?? ((_activeConfig?.cpu ?? false) ? 0.0 : null);
    final memoryMb = _toDouble(event['memoryMb']);
    final fps = _fpsEnabled ? _lastFps : _toDouble(event['fps']);
    final networkRxBytes = _toInt(event['networkRxBytes']);
    final networkTxBytes = _toInt(event['networkTxBytes']);
    final diskReadBytes = _toInt(event['diskReadBytes']);
    final diskWriteBytes = _toInt(event['diskWriteBytes']);
    final intervalSeconds =
        (_activeConfig?.interval.inMilliseconds ?? 1000) / 1000.0;

    final networkRxDelta = _calcDelta(networkRxBytes, _lastNetworkRxBytes);
    final networkTxDelta = _calcDelta(networkTxBytes, _lastNetworkTxBytes);
    final diskReadDelta = _calcDelta(diskReadBytes, _lastDiskReadBytes);
    final diskWriteDelta = _calcDelta(diskWriteBytes, _lastDiskWriteBytes);

    final snapshot = AppResourceSnapshot(
      timestamp: timestampMs == null
          ? DateTime.now()
          : DateTime.fromMillisecondsSinceEpoch(timestampMs),
      cpuPercent: cpuPercent,
      memoryMb: memoryMb,
      fps: fps,
      networkRxBytes: networkRxBytes,
      networkTxBytes: networkTxBytes,
      diskReadBytes: diskReadBytes,
      diskWriteBytes: diskWriteBytes,
      networkRxDeltaBytes: networkRxDelta,
      networkTxDeltaBytes: networkTxDelta,
      diskReadDeltaBytes: diskReadDelta,
      diskWriteDeltaBytes: diskWriteDelta,
      networkRxBytesPerSec: _calcRate(networkRxDelta, intervalSeconds),
      networkTxBytesPerSec: _calcRate(networkTxDelta, intervalSeconds),
      diskReadBytesPerSec: _calcRate(diskReadDelta, intervalSeconds),
      diskWriteBytesPerSec: _calcRate(diskWriteDelta, intervalSeconds),
      cpuPercentAvg: _calcAverage(cpuPercent, (s) => s.cpuPercent),
      memoryMbAvg: _calcAverage(memoryMb, (s) => s.memoryMb),
      fpsAvg: _calcAverage(fps, (s) => s.fps),
    );

    _lastNetworkRxBytes = networkRxBytes ?? _lastNetworkRxBytes;
    _lastNetworkTxBytes = networkTxBytes ?? _lastNetworkTxBytes;
    _lastDiskReadBytes = diskReadBytes ?? _lastDiskReadBytes;
    _lastDiskWriteBytes = diskWriteBytes ?? _lastDiskWriteBytes;
    if (_specs?.platform == DevicePlatform.ios) {
      final iosSnapshot = snapshot.copyWith(
        networkRxBytes: null,
        networkTxBytes: null,
        diskReadBytes: null,
        diskWriteBytes: null,
      );
      _addToWindow(iosSnapshot);
      return iosSnapshot;
    }
    _addToWindow(snapshot);

    return snapshot;
  }

  static double? _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return null;
  }

  static int? _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return null;
  }

  static int? _calcDelta(int? current, int? previous) {
    if (current == null || previous == null) return null;
    final delta = current - previous;
    return delta >= 0 ? delta : null;
  }

  static double? _calcRate(int? deltaBytes, double intervalSeconds) {
    if (deltaBytes == null || intervalSeconds <= 0) return null;
    return deltaBytes / intervalSeconds;
  }

  static double? _calcAverage(
    double? current,
    double? Function(AppResourceSnapshot snapshot) selector,
  ) {
    if (current == null) return null;
    final config = _activeConfig;
    if (config == null || config.movingAverageWindow <= 1) {
      return current;
    }
    final values = _window
        .map(selector)
        .where((value) => value != null)
        .cast<double>()
        .toList();
    if (values.isEmpty) return current;
    final sum = values.fold<double>(0, (acc, value) => acc + value);
    return sum / values.length;
  }

  static void _addToWindow(AppResourceSnapshot snapshot) {
    final config = _activeConfig;
    if (config == null || config.movingAverageWindow <= 1) return;
    _window.add(snapshot);
    while (_window.length > config.movingAverageWindow) {
      _window.removeAt(0);
    }
  }

  static void _resetWindow() {
    _window.clear();
    _lastNetworkRxBytes = null;
    _lastNetworkTxBytes = null;
    _lastDiskReadBytes = null;
    _lastDiskWriteBytes = null;
  }

  static void _startFpsMonitoringIfNeeded(AppResourceMonitoringConfig config) {
    if (!config.fps) return;
    _fpsEnabled = true;
    _frameCount = 0;
    _lastFps = null;
    _scheduleFrameCallback();
    _fpsTimer?.cancel();
    _fpsTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _lastFps = _frameCount.toDouble();
      _frameCount = 0;
    });
  }

  static void _scheduleFrameCallback() {
    if (!_fpsEnabled || _fpsCallbackScheduled) return;
    _fpsCallbackScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _fpsCallbackScheduled = false;
      if (_fpsEnabled) {
        _frameCount += 1;
        _scheduleFrameCallback();
      }
    });
  }

  static void _stopFpsMonitoring() {
    _fpsEnabled = false;
    _fpsTimer?.cancel();
    _fpsTimer = null;
    _lastFps = null;
    _frameCount = 0;
  }

  static Future<void> _setMetric(AppMetric metric, bool enabled) async {
    switch (metric) {
      case AppMetric.cpu:
        await _updateConfigWith(cpu: enabled);
      case AppMetric.memory:
        await _updateConfigWith(memory: enabled);
      case AppMetric.fps:
        await _updateConfigWith(fps: enabled);
      case AppMetric.network:
        await _updateConfigWith(network: enabled);
      case AppMetric.disk:
        await _updateConfigWith(disk: enabled);
    }
  }

  static Future<void> _updateConfigWith({
    bool? cpu,
    bool? memory,
    bool? fps,
    bool? network,
    bool? disk,
    Duration? interval,
    int? movingAverageWindow,
  }) async {
    final current = _activeConfig ?? const AppResourceMonitoringConfig();
    final next = current.copyWith(
      cpu: cpu,
      memory: memory,
      fps: fps,
      network: network,
      disk: disk,
      interval: interval,
      movingAverageWindow: movingAverageWindow,
    );
    await _applyConfig(next);
  }

  static Future<void> _applyConfig(AppResourceMonitoringConfig next) async {
    _validateConfig(next);
    if (_monitorController != null) {
      await updateMonitoringConfig(next);
    } else {
      _defaultMonitoringConfig = next;
    }
  }

  static List<AppMetric> _metricsFromConfig(
    AppResourceMonitoringConfig config,
  ) {
    final metrics = <AppMetric>[];
    if (config.cpu) metrics.add(AppMetric.cpu);
    if (config.memory) metrics.add(AppMetric.memory);
    if (config.fps) metrics.add(AppMetric.fps);
    if (config.network) metrics.add(AppMetric.network);
    if (config.disk) metrics.add(AppMetric.disk);
    return metrics;
  }

  static AppResourceMonitoringConfig _configFromMetrics(
    List<AppMetric> metrics, {
    required AppResourceMonitoringConfig base,
  }) {
    final set = metrics.toSet();
    return base.copyWith(
      cpu: set.contains(AppMetric.cpu),
      memory: set.contains(AppMetric.memory),
      fps: set.contains(AppMetric.fps),
      network: set.contains(AppMetric.network),
      disk: set.contains(AppMetric.disk),
    );
  }

  static void _validateMetrics(List<AppMetric> metrics) {
    if (metrics.isEmpty) {
      throw ArgumentError('At least one metric must be monitored.');
    }
  }

  static void _validateConfig(AppResourceMonitoringConfig config) {
    if (config.interval < const Duration(milliseconds: 200)) {
      throw ArgumentError('Minimum interval is 200ms.');
    }
    if (config.movingAverageWindow < 1) {
      throw ArgumentError('movingAverageWindow must be >= 1.');
    }
    final hasAnyMetric =
        config.cpu ||
        config.memory ||
        config.fps ||
        config.network ||
        config.disk;
    if (!hasAnyMetric) {
      throw ArgumentError('At least one metric must be enabled.');
    }
  }
}
