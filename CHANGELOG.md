## 1.2.1

* Fixed disk and network chip values flickering by smoothing with a 3-sample
  moving average for the "Current" chip.
* Fixed "Avg" chip showing `n/a` for disk and network — now computed from
  the full history buffer.

## 1.2.0

* **HTTP request monitoring** — Track every HTTP request automatically with
  interceptors for `dart:io`, `package:http` and Dio.
* New `RuntimeInsight.enableHttpTracking()` installs global `HttpOverrides`
  with a single call.
* `HttpTracker` singleton provides stats (active, total, avg response time,
  error rate), a real-time `onChange` stream, and log management (export JSON,
  clear, NDJSON file persistence).
* `RuntimeInsightHttpClient` wraps `package:http` clients.
* `RuntimeInsightDioInterceptor` plugs into any Dio instance.
* New **HTTP tab** in the overlay shows stats chips and a live scrollable list
  of requests with method badge, URL and status indicator.
* `AppMetric.http` and `AppResourceMonitoringConfig.http` to opt in.
* Overlay now hides tabs for metrics that are not being monitored.
* Added `OverlayDisplayStat` enum — developers choose which chips to display
  (current, average, min, max, secondary).
* Icons added next to metric tab titles (CPU, RAM, Disk, Network, HTTP).
* Added `RuntimeInsightOverlayStrings.portugueseBr()` and `.spanish()` factories.
* Controller exposes `httpTracker` getter for external log access.

## 1.0.4

* Controller now supports all overlay configuration properties (width, height,
  showPauseButton, showCloseButton, strings, backgroundColor, margin, etc.).
* Controller exposes `snapshotStream`, `latestSnapshot` and `history` for
  reading monitoring data from anywhere.
* Controller supports `monitoringConfig` override — changing it restarts
  monitoring automatically.

## 1.0.3

* Added `RuntimeInsightOverlayController` for static/global overlay control.
* Overlay visibility, minimized state, pause and opacity can now be changed from anywhere.
* Fixed icon contrast on white backgrounds (icons now use `onSurface` color).

## 1.0.2

* Lowered minimum SDK to Dart 3.0.0 / Flutter 3.7.0 for wider compatibility.
* Lowered shared_preferences dependency to ^2.2.0.

## 1.0.1

* Fixed package description length for pub.dev scoring.
* Fixed repository URL in pubspec.yaml.
* Added minimize/expand mode to RuntimeInsightOverlay widget.
* Fixed example app structure and l10n setup.

## 1.0.0

* Stable API for device classification and monitoring.
* Added monitoring overlay widget with charts and persistence.
* Added advanced monitoring controls and metric list management.
* Added recommended parallelism per CPU/IO/network.
* Added example localization (EN/PT) and overlay string customization.

## 0.0.1

* Initial release with Android device classification.
* Added runtime hardware collection (CPU, RAM, OS version, emulator flag).
* Added performance class support on Android 12+.
* Added tier classification rules and helpers.
* Added iOS collection for CPU, RAM, OS version, emulator flag.
* Added platform interface for specs collection.
* Adjusted iOS classification weights (CPU weighted higher than RAM).
* Added continuous app monitoring via stream (CPU, RAM, FPS, network, disk).
* Added moving averages and per-interval deltas for monitoring.
* Added iOS network and disk byte collection (with platform limits).
* Added bytes/s rates for network and disk; iOS exposes only rates.
* Added recommended parallelism per CPU/IO/network.
