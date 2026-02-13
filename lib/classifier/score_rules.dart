import '../device/device_specs.dart';

int scoreCpu(int cores) {
  if (cores <= 4) return 20;
  if (cores <= 6) return 45;
  if (cores <= 8) return 70;
  return 90; // 10+ cores
}

int scoreRam(int ramMb) {
  if (ramMb <= 3072) return 20; // 3GB
  if (ramMb <= 4096) return 40; // 4GB
  if (ramMb <= 6144) return 65; // 6GB
  if (ramMb <= 8192) return 85; // 8GB
  return 100; // 12GB+
}

int scorePerformanceClass(int? pc) {
  if (pc == null) return 0;

  switch (pc) {
    case 1:
      return 10;
    case 2:
      return 25;
    case 3:
      return 40;
    default:
      return 0;
  }
}

bool isLowRam(int ramMb) => ramMb <= 3072; // <= 3GB

int scoreTotal({
  required DevicePlatform platform,
  required int cpuCores,
  required int ramMb,
  required int? performanceClass,
}) {
  final cpuScore = scoreCpu(cpuCores);
  final ramScore = scoreRam(ramMb);

  if (platform == DevicePlatform.ios) {
    // iOS devices tend to be more CPU bound; weight CPU more than RAM.
    const cpuWeightPercent = 180;
    const ramWeightPercent = 60;
    return (cpuScore * cpuWeightPercent + ramScore * ramWeightPercent) ~/ 100;
  }

  return cpuScore + ramScore + scorePerformanceClass(performanceClass);
}