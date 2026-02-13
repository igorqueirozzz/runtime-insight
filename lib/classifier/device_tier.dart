/// Represents the performance tier of a device.
///
/// Used by [RuntimeInsight] to classify hardware into broad categories
/// that help adjust app behaviour (e.g. animations, parallelism, quality).
enum DeviceTier {
  /// Low-end device — limited CPU/RAM resources.
  low,

  /// Mid-range device — moderate resources.
  mid,

  /// High-end device — plenty of CPU/RAM resources.
  high,
}
