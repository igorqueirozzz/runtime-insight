/// Localisable strings used by [RuntimeInsightOverlay].
///
/// Use the [RuntimeInsightOverlayStrings.english] factory for sensible defaults,
/// or create a custom instance for other languages.
class RuntimeInsightOverlayStrings {
  final String title;
  final String tabCpu;
  final String tabRam;
  final String tabDisk;
  final String tabNetwork;
  final String cpuTitle;
  final String ramTitle;
  final String diskTitle;
  final String networkTitle;
  final String labelCurrent;
  final String labelAverage;
  final String labelSecondary;
  final String legendRead;
  final String legendWrite;
  final String legendRx;
  final String legendTx;
  final String pause;
  final String resume;
  final String close;
  final String minimize;
  final String expand;

  const RuntimeInsightOverlayStrings({
    required this.title,
    required this.tabCpu,
    required this.tabRam,
    required this.tabDisk,
    required this.tabNetwork,
    required this.cpuTitle,
    required this.ramTitle,
    required this.diskTitle,
    required this.networkTitle,
    required this.labelCurrent,
    required this.labelAverage,
    required this.labelSecondary,
    required this.legendRead,
    required this.legendWrite,
    required this.legendRx,
    required this.legendTx,
    required this.pause,
    required this.resume,
    required this.close,
    required this.minimize,
    required this.expand,
  });

  factory RuntimeInsightOverlayStrings.english() {
    return const RuntimeInsightOverlayStrings(
      title: 'Runtime Insight',
      tabCpu: 'CPU',
      tabRam: 'RAM',
      tabDisk: 'Disk',
      tabNetwork: 'Network',
      cpuTitle: 'CPU (%)',
      ramTitle: 'RAM (MB)',
      diskTitle: 'Disk (bytes/s)',
      networkTitle: 'Network (bytes/s)',
      labelCurrent: 'Current',
      labelAverage: 'Avg',
      labelSecondary: 'Alt',
      legendRead: 'Read',
      legendWrite: 'Write',
      legendRx: 'RX',
      legendTx: 'TX',
      pause: 'Pause',
      resume: 'Resume',
      close: 'Close',
      minimize: 'Minimize',
      expand: 'Expand',
    );
  }
}
