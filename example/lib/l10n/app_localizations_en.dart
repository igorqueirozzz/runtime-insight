// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Runtime Insight Example';

  @override
  String get refresh => 'Refresh';

  @override
  String get summary => 'Summary';

  @override
  String get cpuLabel => 'CPU';

  @override
  String get ioLabel => 'IO';

  @override
  String get networkLabel => 'Network';

  @override
  String get specs => 'Specs';

  @override
  String get platform => 'Platform';

  @override
  String get cpuCores => 'CPU cores';

  @override
  String get ramMb => 'RAM (MB)';

  @override
  String get osVersion => 'OS version';

  @override
  String get performanceClass => 'Performance class';

  @override
  String get emulator => 'Emulator';

  @override
  String get helpers => 'Helpers';

  @override
  String get monitoring => 'Monitoring';

  @override
  String get cpuPercent => 'CPU (%)';

  @override
  String get cpuAvg => 'CPU avg (%)';

  @override
  String get ramAvg => 'RAM avg (MB)';

  @override
  String get fpsAvg => 'FPS avg';

  @override
  String get networkRx => 'Network RX';

  @override
  String get networkRxRate => 'Network RX / s';

  @override
  String get networkTx => 'Network TX';

  @override
  String get networkTxRate => 'Network TX / s';

  @override
  String get diskRead => 'Disk read';

  @override
  String get diskReadRate => 'Disk read / s';

  @override
  String get diskWrite => 'Disk write';

  @override
  String get diskWriteRate => 'Disk write / s';

  @override
  String get cpuStressTitle => 'CPU stress test';

  @override
  String get cpuStressRunning => 'Running...';

  @override
  String get cpuStressHint => 'Press to stress for 5s';

  @override
  String get cpuStressButton => 'Stress';

  @override
  String get overlayTitle => 'Runtime Insight';

  @override
  String get tabCpu => 'CPU';

  @override
  String get tabRam => 'RAM';

  @override
  String get tabDisk => 'Disk';

  @override
  String get tabNetwork => 'Network';

  @override
  String get labelCurrent => 'Current';

  @override
  String get labelAverage => 'Avg';

  @override
  String get labelSecondary => 'Alt';

  @override
  String get legendRead => 'Read';

  @override
  String get legendWrite => 'Write';

  @override
  String get legendRx => 'RX';

  @override
  String get legendTx => 'TX';

  @override
  String get pause => 'Pause';

  @override
  String get resume => 'Resume';

  @override
  String get close => 'Close';

  @override
  String get minimize => 'Minimize';

  @override
  String get expand => 'Expand';
}
