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
