# runtime_insight

[![pub package](https://img.shields.io/pub/v/runtime_insight.svg)](https://pub.dev/packages/runtime_insight)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

[Leia em Português](doc/README.pt-BR.md)

Flutter plugin that classifies devices into tiers (low/mid/high) based
on runtime hardware characteristics and provides continuous app resource monitoring.

## Features

- Collects CPU cores, total RAM, Android OS version, emulator flag
- Uses Android device performance class when available (Android 12+)
- Provides simple helpers for tier checks and recommended parallelism
- **HTTP request monitoring** with interceptors for `dart:io`, `package:http` and Dio
- Live overlay with metric tabs, stat chips, and scrollable HTTP request list

## Supported platforms

- Android: full support
- iOS: basic support (CPU cores, RAM, OS version, emulator flag)

## Installation

Add the dependency to your `pubspec.yaml`:

```yaml
dependencies:
  runtime_insight: ^1.2.0
```

## Requirements

- Flutter 3.3+
- Android API 24+
- iOS 12+

## Usage

```dart
import 'package:runtime_insight/runtime_insight.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await RuntimeInsight.init(
    monitoredMetrics: const [
      AppMetric.cpu,
      AppMetric.memory,
      AppMetric.fps,
    ],
  );

  final tier = RuntimeInsight.deviceTier;
  final parallel = RuntimeInsight.maxParallelRecommended;

  if (RuntimeInsight.isLowEnd) {
    // adjust heavy tasks
  }
}
```

### Recommended parallelism

```dart
final parallel = RuntimeInsight.maxParallelRecommended;
print('CPU: ${parallel.cpu}');
print('IO: ${parallel.io}');
print('Network: ${parallel.network}');
```

### Overlay (widget)

```dart
Stack(
  children: [
    const MyApp(),
    Align(
      alignment: Alignment.topRight,
      child: RuntimeInsightOverlay(
        persistenceKey: 'runtime_insight_overlay',
        // You can pass localized strings here
        // strings: RuntimeInsightOverlayStrings(...)
      ),
    ),
  ],
)
```

### Controller (static access)

Control the overlay from anywhere — no widget reference needed:

```dart
final ctrl = RuntimeInsightOverlayController.instance;

// Visibility
ctrl.hide();
ctrl.show();

// Minimize / expand
ctrl.minimize();
ctrl.expand();

// Pause / resume data feed
ctrl.pause();
ctrl.resume();

// Change opacity
ctrl.opacity = 0.6;
```

#### Configuration override

Any property set on the controller overrides the widget constructor value:

```dart
ctrl.width = 320;
ctrl.height = 400;
ctrl.showPauseButton = false;
ctrl.showOpacitySlider = false;
ctrl.strings = RuntimeInsightOverlayStrings.english();
ctrl.backgroundColor = Colors.black87;
ctrl.monitoringConfig = const AppResourceMonitoringConfig(
  interval: Duration(milliseconds: 500),
);
```

#### Stream access

Read monitoring data from anywhere without touching the widget:

```dart
// Listen to snapshots in real time
ctrl.snapshotStream.listen((snapshot) {
  print('CPU: ${snapshot.cpuPercent}%');
  print('RAM: ${snapshot.memoryMb} MB');
});

// Read the latest snapshot
final last = ctrl.latestSnapshot;

// Access the full history
final history = ctrl.history;
```

#### Dedicated controller

You can also pass a dedicated controller to a specific overlay:

```dart
final myController = RuntimeInsightOverlayController(minimized: true);

RuntimeInsightOverlay(
  controller: myController,
  persistenceKey: 'my_overlay',
)
```

### HTTP monitoring

Enable automatic HTTP tracking in your `main()`:

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await RuntimeInsight.enableHttpTracking(); // intercepts all dart:io HTTP
  runApp(const MyApp());
}
```

Enable the HTTP tab in the overlay:

```dart
RuntimeInsightOverlay(
  config: const AppResourceMonitoringConfig(
    cpu: true,
    memory: true,
    http: true, // shows the HTTP tab
  ),
)
```

#### Interceptors

**`package:http`:**

```dart
import 'package:runtime_insight/runtime_insight.dart';
import 'package:http/http.dart' as http;

final client = RuntimeInsightHttpClient(http.Client());
final response = await client.get(Uri.parse('https://example.com'));
```

**Dio:**

```dart
import 'package:runtime_insight/runtime_insight.dart';
import 'package:dio/dio.dart';

final dio = Dio();
dio.interceptors.add(RuntimeInsightDioInterceptor());
```

#### Accessing logs

```dart
final tracker = HttpTracker.instance;
// — or via controller —
final tracker = RuntimeInsightOverlayController.instance.httpTracker;

print(tracker.totalCount);
print(tracker.avgResponseTimeMs);

// Export as JSON
final json = tracker.exportLogsAsJson();

// Clear all logs
await tracker.clearLogs();
```

### Migration from 0.x

- `maxParallelJobs` is deprecated → use `maxParallelRecommended`.
- Monitoring now supports dynamic metric lists and pause/resume.

## Monitoring (stream)

```dart
final stream = RuntimeInsight.startMonitoring(
  config: const AppResourceMonitoringConfig(
    interval: Duration(seconds: 1),
    movingAverageWindow: 5,
  ),
);

stream.listen((snapshot) {
  print('CPU: ${snapshot.cpuPercent}%');
  print('CPU avg: ${snapshot.cpuPercentAvg}%');
  print('RX / s: ${snapshot.networkRxBytesPerSec}');
});

// Advanced control
await RuntimeInsight.updateMonitoringConfig(
  const AppResourceMonitoringConfig(
    cpu: true,
    memory: true,
    fps: false,
    network: true,
    disk: false,
    interval: Duration(milliseconds: 500),
  ),
);

await RuntimeInsight.pauseMonitoring();
await RuntimeInsight.resumeMonitoring();

// Helpers
await RuntimeInsight.enableMetric(AppMetric.cpu);
await RuntimeInsight.disableMetric(AppMetric.disk);
await RuntimeInsight.setInterval(const Duration(milliseconds: 500));
await RuntimeInsight.setMovingAverageWindow(10);

// Dynamic list updates
await RuntimeInsight.addMetrics([AppMetric.network]);
await RuntimeInsight.removeMetrics([AppMetric.fps]);
await RuntimeInsight.setMonitoredMetrics([AppMetric.cpu, AppMetric.memory]);
```

## Classification rules (Android)

- Low RAM (<= 3GB) always returns `DeviceTier.low`
- Emulator always returns `DeviceTier.low`
- Otherwise, a score is calculated from:
  - CPU cores
  - RAM size
  - Device performance class (Android 12+ only)

Thresholds:

- `< 80` → low
- `< 140` → mid
- `>= 140` → high

## Classification rules (iOS)

- Low RAM (<= 3GB) always returns `DeviceTier.low`
- Emulator always returns `DeviceTier.low`
- Score uses heavier CPU weighting and lighter RAM weighting

## Notes

- `performanceClass` is only available on Android 12+ (API 31)
- iOS does not provide `performanceClass`
- CPU usage is per-app and normalized to 0–100
- iOS network bytes are device-wide; disk bytes are per-process
- iOS provides only bytes/s for network/disk; raw counters are omitted

## Support

If this plugin helped you, consider supporting the project:

**PayPal:**

[![Donate](https://img.shields.io/badge/Donate-PayPal-blue.svg)](https://www.paypal.com/donate/?hosted_button_id=T98W8VTCJQVA8)

**PIX (Brazil):**

Key: `620b6ef6-574f-447b-aec7-6fac5f3a6be5`

<img src="doc/pix_qrcode.jpg" alt="PIX QR Code" width="200"/>

