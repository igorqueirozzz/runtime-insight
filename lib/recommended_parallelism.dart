/// Recommended maximum parallelism limits based on the device tier.
///
/// Use these values to cap the number of concurrent operations in your app
/// so that low-end devices are not overwhelmed.
class RecommendedParallelism {
  /// Maximum concurrent CPU-bound tasks (e.g. image processing, parsing).
  final int cpu;

  /// Maximum concurrent IO-bound tasks (e.g. file reads, database queries).
  final int io;

  /// Maximum concurrent network requests.
  final int network;

  const RecommendedParallelism({
    required this.cpu,
    required this.io,
    required this.network,
  });
}
