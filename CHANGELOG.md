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
