/// The platform the device is running on.
enum DevicePlatform {
  /// Android device.
  android,

  /// iOS device.
  ios,
}

/// Hardware specifications collected at runtime from the device.
///
/// Contains the number of CPU cores, total RAM, OS version, whether the
/// device is an emulator, and an optional Android performance class.
class DeviceSpecs {
  /// The platform (Android or iOS).
  final DevicePlatform platform;

  /// Number of available CPU cores, or `null` if unavailable.
  final int? cpuCores;

  /// Total device RAM in megabytes, or `null` if unavailable.
  final int? ramMb;

  /// OS version number (e.g. Android API level or iOS major version).
  final int? osVersion;

  /// Android 12+ media performance class, or `null` on older devices / iOS.
  final int? performanceClass;

  /// Whether the device is an emulator/simulator.
  final bool isEmulator;

  DeviceSpecs({
    required this.platform,
    required this.cpuCores,
    required this.ramMb,
    required this.osVersion,
    this.performanceClass,
    this.isEmulator = false,
  });
}
