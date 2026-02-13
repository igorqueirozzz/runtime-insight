/// A point-in-time snapshot of app resource usage.
///
/// Fields are `null` when the corresponding metric is not being monitored.
/// Moving-average fields (e.g. [cpuPercentAvg]) are computed over the
/// configured [AppResourceMonitoringConfig.movingAverageWindow].
class AppResourceSnapshot {
  /// When this snapshot was taken.
  final DateTime timestamp;

  /// Current CPU usage percentage (0–100), per-app.
  final double? cpuPercent;

  /// Current memory usage in megabytes.
  final double? memoryMb;

  /// Current frames per second.
  final double? fps;

  /// Moving average of CPU usage.
  final double? cpuPercentAvg;

  /// Moving average of memory usage.
  final double? memoryMbAvg;

  /// Moving average of FPS.
  final double? fpsAvg;

  /// Cumulative network bytes received.
  final int? networkRxBytes;

  /// Cumulative network bytes transmitted.
  final int? networkTxBytes;

  /// Network bytes received since the previous snapshot.
  final int? networkRxDeltaBytes;

  /// Network bytes transmitted since the previous snapshot.
  final int? networkTxDeltaBytes;

  /// Network receive rate in bytes per second.
  final double? networkRxBytesPerSec;

  /// Network transmit rate in bytes per second.
  final double? networkTxBytesPerSec;

  /// Cumulative disk bytes read.
  final int? diskReadBytes;

  /// Cumulative disk bytes written.
  final int? diskWriteBytes;

  /// Disk bytes read since the previous snapshot.
  final int? diskReadDeltaBytes;

  /// Disk bytes written since the previous snapshot.
  final int? diskWriteDeltaBytes;

  /// Disk read rate in bytes per second.
  final double? diskReadBytesPerSec;

  /// Disk write rate in bytes per second.
  final double? diskWriteBytesPerSec;

  const AppResourceSnapshot({
    required this.timestamp,
    this.cpuPercent,
    this.memoryMb,
    this.fps,
    this.cpuPercentAvg,
    this.memoryMbAvg,
    this.fpsAvg,
    this.networkRxBytes,
    this.networkTxBytes,
    this.networkRxDeltaBytes,
    this.networkTxDeltaBytes,
    this.networkRxBytesPerSec,
    this.networkTxBytesPerSec,
    this.diskReadBytes,
    this.diskWriteBytes,
    this.diskReadDeltaBytes,
    this.diskWriteDeltaBytes,
    this.diskReadBytesPerSec,
    this.diskWriteBytesPerSec,
  });

  AppResourceSnapshot copyWith({
    DateTime? timestamp,
    double? cpuPercent,
    double? memoryMb,
    double? fps,
    double? cpuPercentAvg,
    double? memoryMbAvg,
    double? fpsAvg,
    int? networkRxBytes,
    int? networkTxBytes,
    int? networkRxDeltaBytes,
    int? networkTxDeltaBytes,
    double? networkRxBytesPerSec,
    double? networkTxBytesPerSec,
    int? diskReadBytes,
    int? diskWriteBytes,
    int? diskReadDeltaBytes,
    int? diskWriteDeltaBytes,
    double? diskReadBytesPerSec,
    double? diskWriteBytesPerSec,
  }) {
    return AppResourceSnapshot(
      timestamp: timestamp ?? this.timestamp,
      cpuPercent: cpuPercent ?? this.cpuPercent,
      memoryMb: memoryMb ?? this.memoryMb,
      fps: fps ?? this.fps,
      cpuPercentAvg: cpuPercentAvg ?? this.cpuPercentAvg,
      memoryMbAvg: memoryMbAvg ?? this.memoryMbAvg,
      fpsAvg: fpsAvg ?? this.fpsAvg,
      networkRxBytes: networkRxBytes ?? this.networkRxBytes,
      networkTxBytes: networkTxBytes ?? this.networkTxBytes,
      networkRxDeltaBytes: networkRxDeltaBytes ?? this.networkRxDeltaBytes,
      networkTxDeltaBytes: networkTxDeltaBytes ?? this.networkTxDeltaBytes,
      networkRxBytesPerSec: networkRxBytesPerSec ?? this.networkRxBytesPerSec,
      networkTxBytesPerSec: networkTxBytesPerSec ?? this.networkTxBytesPerSec,
      diskReadBytes: diskReadBytes ?? this.diskReadBytes,
      diskWriteBytes: diskWriteBytes ?? this.diskWriteBytes,
      diskReadDeltaBytes: diskReadDeltaBytes ?? this.diskReadDeltaBytes,
      diskWriteDeltaBytes: diskWriteDeltaBytes ?? this.diskWriteDeltaBytes,
      diskReadBytesPerSec: diskReadBytesPerSec ?? this.diskReadBytesPerSec,
      diskWriteBytesPerSec: diskWriteBytesPerSec ?? this.diskWriteBytesPerSec,
    );
  }
}
