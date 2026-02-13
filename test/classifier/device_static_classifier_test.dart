import 'package:flutter_test/flutter_test.dart';
import 'package:runtime_insight/device/device_specs.dart';
import 'package:runtime_insight/classifier/device_static_classifier.dart';
import 'package:runtime_insight/classifier/device_tier.dart';

void main() {
  group('DeviceClassifier – LOW tier', () {
    test('low-end device: 4 cores, 3GB RAM', () {
      final specs = DeviceSpecs(
        platform: DevicePlatform.android,
        cpuCores: 4,
        ramMb: 3072,
        osVersion: 29,
      );

      expect(DeviceStaticClassifier.classify(specs), DeviceTier.low);
    });

    test('low-end device: good CPU but low RAM', () {
      final specs = DeviceSpecs(
        platform: DevicePlatform.android,
        cpuCores: 8,
        ramMb: 2048,
        osVersion: 31,
      );

      expect(DeviceStaticClassifier.classify(specs), DeviceTier.low);
    });

    test('low-end device: emulator is always LOW', () {
      final specs = DeviceSpecs(
        platform: DevicePlatform.android,
        cpuCores: 16,
        ramMb: 16384,
        osVersion: 34,
        isEmulator: true,
      );

      expect(DeviceStaticClassifier.classify(specs), DeviceTier.low);
    });
  });

  group('DeviceClassifier – MID tier', () {
    test('mid device: 6 cores, 4GB RAM', () {
      final specs = DeviceSpecs(
        platform: DevicePlatform.android,
        cpuCores: 6,
        ramMb: 4096,
        osVersion: 30,
      );

      expect(DeviceStaticClassifier.classify(specs), DeviceTier.mid);
    });

    test('mid device: 8 cores, 6GB RAM', () {
      final specs = DeviceSpecs(
        platform: DevicePlatform.android,
        cpuCores: 8,
        ramMb: 6144,
        osVersion: 31,
      );

      expect(DeviceStaticClassifier.classify(specs), DeviceTier.mid);
    });

    test('mid device: good CPU, medium RAM', () {
      final specs = DeviceSpecs(
        platform: DevicePlatform.android,
        cpuCores: 8,
        ramMb: 5120,
        osVersion: 32,
      );

      expect(DeviceStaticClassifier.classify(specs), DeviceTier.mid);
    });
  });

  group('DeviceClassifier – HIGH tier', () {
    test('high-end device: 8 cores, 8GB RAM', () {
      final specs = DeviceSpecs(
        platform: DevicePlatform.android,
        cpuCores: 8,
        ramMb: 8192,
        osVersion: 33,
      );

      expect(DeviceStaticClassifier.classify(specs), DeviceTier.high);
    });

    test('high-end device: 12 cores, 12GB RAM', () {
      final specs = DeviceSpecs(
        platform: DevicePlatform.android,
        cpuCores: 12,
        ramMb: 12288,
        osVersion: 34,
      );

      expect(DeviceStaticClassifier.classify(specs), DeviceTier.high);
    });
  });

  group('DeviceClassifier – Performance Class (Android)', () {
    test('performanceClass boosts tier to MID', () {
      final specs = DeviceSpecs(
        platform: DevicePlatform.android,
        cpuCores: 4,
        ramMb: 4096,
        osVersion: 31,
        performanceClass: 2, // Android PC
      );

      expect(DeviceStaticClassifier.classify(specs), DeviceTier.mid);
    });

    test('performanceClass boosts tier to HIGH', () {
      final specs = DeviceSpecs(
        platform: DevicePlatform.android,
        cpuCores: 6,
        ramMb: 6144,
        osVersion: 33,
        performanceClass: 3,
      );

      expect(DeviceStaticClassifier.classify(specs), DeviceTier.high);
    });
  });

  group('DeviceClassifier – iOS weighting', () {
    test('iOS favors CPU over RAM', () {
      final androidSpecs = DeviceSpecs(
        platform: DevicePlatform.android,
        cpuCores: 8,
        ramMb: 6144,
        osVersion: 34,
      );

      final iosSpecs = DeviceSpecs(
        platform: DevicePlatform.ios,
        cpuCores: 8,
        ramMb: 6144,
        osVersion: 17,
      );

      expect(DeviceStaticClassifier.classify(androidSpecs), DeviceTier.mid);
      expect(DeviceStaticClassifier.classify(iosSpecs), DeviceTier.high);
    });
  });

  group('DeviceClassifier – Threshold boundaries', () {
    test('score exactly at low threshold', () {
      final specs = DeviceSpecs(
        platform: DevicePlatform.android,
        cpuCores: 4,
        ramMb: 4096,
        osVersion: 30,
      );

      final tier = DeviceStaticClassifier.classify(specs);
      expect(tier, anyOf(DeviceTier.low, DeviceTier.mid));
    });

    test('score exactly at mid threshold', () {
      final specs = DeviceSpecs(
        platform: DevicePlatform.android,
        cpuCores: 6,
        ramMb: 6144,
        osVersion: 31,
      );

      final tier = DeviceStaticClassifier.classify(specs);
      expect(tier, anyOf(DeviceTier.mid, DeviceTier.high));
    });
  });

  group('DeviceClassifier – Determinism', () {
    test('same specs always return same tier', () {
      final specs = DeviceSpecs(
        platform: DevicePlatform.android,
        cpuCores: 8,
        ramMb: 6144,
        osVersion: 32,
      );

      final tier1 = DeviceStaticClassifier.classify(specs);
      final tier2 = DeviceStaticClassifier.classify(specs);

      expect(tier1, equals(tier2));
    });
  });
}
