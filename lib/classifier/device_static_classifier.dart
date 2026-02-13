import 'package:runtime_insight/classifier/score_rules.dart';
import '../device/device_specs.dart';
import 'device_tier.dart';

final class DeviceStaticClassifier {
  static DeviceTier classify(DeviceSpecs specs) {
    if (isLowRam(specs.ramMb ?? 0)) {
      return DeviceTier.low;
    }

    if (specs.isEmulator) {
      return DeviceTier.low;
    }

    final score = scoreTotal(
      platform: specs.platform,
      cpuCores: specs.cpuCores ?? 0,
      ramMb: specs.ramMb ?? 0,
      performanceClass: specs.performanceClass,
    );

    if (score < 80) return DeviceTier.low;
    if (score < 140) return DeviceTier.mid;
    return DeviceTier.high;
  }
}
