/// Available app resource metrics that can be monitored.
enum AppMetric {
  /// CPU usage percentage (per-app, 0–100).
  cpu,

  /// Memory (RAM) usage in megabytes.
  memory,

  /// Frames per second rendered by the Flutter engine.
  fps,

  /// Network receive/transmit bytes.
  network,

  /// Disk read/write bytes.
  disk,
}

/// Configuration for [RuntimeInsight.startMonitoring].
///
/// Controls which metrics are collected, the polling interval, and the
/// window size for moving-average calculations.
class AppResourceMonitoringConfig {
  /// Whether to collect CPU usage.
  final bool cpu;

  /// Whether to collect memory usage.
  final bool memory;

  /// Whether to collect FPS.
  final bool fps;

  /// Whether to collect network bytes.
  final bool network;

  /// Whether to collect disk bytes.
  final bool disk;

  /// How often a snapshot is emitted.
  final Duration interval;

  /// Number of recent snapshots used for moving-average calculations.
  final int movingAverageWindow;

  const AppResourceMonitoringConfig({
    this.cpu = true,
    this.memory = true,
    this.fps = true,
    this.network = true,
    this.disk = true,
    this.interval = const Duration(seconds: 1),
    this.movingAverageWindow = 5,
  });

  AppResourceMonitoringConfig copyWith({
    bool? cpu,
    bool? memory,
    bool? fps,
    bool? network,
    bool? disk,
    Duration? interval,
    int? movingAverageWindow,
  }) {
    return AppResourceMonitoringConfig(
      cpu: cpu ?? this.cpu,
      memory: memory ?? this.memory,
      fps: fps ?? this.fps,
      network: network ?? this.network,
      disk: disk ?? this.disk,
      interval: interval ?? this.interval,
      movingAverageWindow: movingAverageWindow ?? this.movingAverageWindow,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'cpu': cpu,
      'memory': memory,
      'fps': fps,
      'network': network,
      'disk': disk,
      'intervalMs': interval.inMilliseconds,
    };
  }

  @override
  bool operator ==(Object other) {
    return other is AppResourceMonitoringConfig &&
        other.cpu == cpu &&
        other.memory == memory &&
        other.fps == fps &&
        other.network == network &&
        other.disk == disk &&
        other.interval == interval &&
        other.movingAverageWindow == movingAverageWindow;
  }

  @override
  int get hashCode => Object.hash(
    cpu,
    memory,
    fps,
    network,
    disk,
    interval,
    movingAverageWindow,
  );
}
