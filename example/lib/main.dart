import 'dart:async';
import 'dart:isolate';
import 'dart:math';

import 'package:flutter/material.dart';
import 'l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:runtime_insight/device/device_specs.dart';
import 'package:runtime_insight/runtime_insight.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  DeviceSpecs? _specs;
  String? _tierName;
  RecommendedParallelism? _parallelism;
  bool _loading = false;
  AppResourceSnapshot? _snapshot;
  StreamSubscription<AppResourceSnapshot>? _monitorSubscription;
  Stream<AppResourceSnapshot>? _monitorStream;
  bool _cpuStressRunning = false;

  @override
  void initState() {
    super.initState();
    _initPlatformState();
  }

  @override
  void dispose() {
    _monitorSubscription?.cancel();
    RuntimeInsight.stopMonitoring();
    super.dispose();
  }

  Future<void> _startCpuStress() async {
    if (_cpuStressRunning) return;
    final parallel = _parallelism?.cpu ?? 2;
    final isolatesCount = max(1, min(4, parallel));
    setState(() {
      _cpuStressRunning = true;
    });

    const duration = Duration(seconds: 5);
    final futures = List.generate(isolatesCount, (_) async {
      await Isolate.spawn(_cpuStressEntry, duration.inMilliseconds);
    });

    await Future.wait(futures);
    await Future.delayed(duration);

    if (!mounted) return;
    setState(() {
      _cpuStressRunning = false;
    });
  }

  Future<void> _initPlatformState() async {
    setState(() {
      _loading = true;
      _specs = null;
      _snapshot = null;
    });

    await RuntimeInsight.init(
      monitoredMetrics: const [
        AppMetric.cpu,
        AppMetric.memory,
        AppMetric.fps,
        AppMetric.network,
        AppMetric.disk,
      ],
    );

    final specs = RuntimeInsight.deviceSpecs;
    final tier = RuntimeInsight.deviceTier;
    final parallelism = RuntimeInsight.maxParallelRecommended;

    if (!mounted) return;

    setState(() {
      _specs = specs;
      _tierName = tier.name;
      _parallelism = parallelism;
      _loading = false;
    });

    _monitorSubscription?.cancel();
    _monitorStream = RuntimeInsight.startMonitoring(
      config: const AppResourceMonitoringConfig(
        cpu: true,
        memory: true,
        fps: true,
        network: true,
        disk: true,
        interval: Duration(seconds: 1),
        movingAverageWindow: 5,
      ),
    );
    _monitorSubscription = _monitorStream!.listen((snapshot) {
      if (!mounted) return;
      setState(() {
        _snapshot = snapshot;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final specs = _specs;
    final snapshot = _snapshot;
    final cpuValue = snapshot?.cpuPercent ?? snapshot?.cpuPercentAvg;
    return MaterialApp(
      themeMode: ThemeMode.system,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.tealAccent,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en'), Locale('pt')],
      home: Builder(
        builder: (context) {
          final l10n = AppLocalizations.of(context)!;
          return Scaffold(
            appBar: AppBar(
              title: Text(l10n.appTitle),
              actions: [
                IconButton(
                  onPressed: _loading ? null : _initPlatformState,
                  icon: const Icon(Icons.refresh),
                  tooltip: l10n.refresh,
                ),
              ],
            ),
            body: specs == null
                ? const Center(child: CircularProgressIndicator())
                : Stack(
                    children: [
                      ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          Card(
                            child: ListTile(
                              leading: Icon(
                                _tierIcon(_tierName),
                                color: _tierColor(_tierName),
                              ),
                              title: Text(l10n.summary),
                              subtitle: Text(
                                '${l10n.cpuLabel}: ${_parallelism?.cpu}  '
                                '${l10n.ioLabel}: ${_parallelism?.io}  '
                                '${l10n.networkLabel}: ${_parallelism?.network}',
                              ),
                              trailing: Chip(
                                label: Text(_tierName ?? 'n/a'),
                                backgroundColor: _tierColor(
                                  _tierName,
                                ).withValues(alpha: 0.15),
                                labelStyle: TextStyle(
                                  color: _tierColor(_tierName),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Card(
                            child: Column(
                              children: [
                                ListTile(
                                  title: Text(l10n.specs),
                                  trailing: Chip(
                                    label: Text(
                                      _platformLabel(specs.platform),
                                    ),
                                    avatar: Icon(
                                      _platformIcon(specs.platform),
                                      size: 18,
                                    ),
                                  ),
                                ),
                                _infoTile(
                                  l10n.platform,
                                  specs.platform.name,
                                  icon: Icons.devices,
                                ),
                                _infoTile(
                                  l10n.cpuCores,
                                  '${specs.cpuCores}',
                                  icon: Icons.memory,
                                ),
                                _infoTile(
                                  l10n.ramMb,
                                  '${specs.ramMb}',
                                  icon: Icons.storage,
                                ),
                                _infoTile(
                                  l10n.osVersion,
                                  '${specs.osVersion}',
                                  icon: Icons.system_update,
                                ),
                                _infoTile(
                                  l10n.performanceClass,
                                  specs.performanceClass?.toString() ?? 'n/a',
                                  icon: Icons.speed,
                                ),
                                _infoTile(
                                  l10n.emulator,
                                  specs.isEmulator.toString(),
                                  icon: Icons.phone_android,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Card(
                            child: Column(
                              children: [
                                ListTile(title: Text(l10n.helpers)),
                                _infoTile(
                                  'isLowEnd',
                                  RuntimeInsight.isLowEnd.toString(),
                                  icon: Icons.arrow_downward,
                                ),
                                _infoTile(
                                  'isMidEnd',
                                  RuntimeInsight.isMidEnd.toString(),
                                  icon: Icons.remove,
                                ),
                                _infoTile(
                                  'isHighEnd',
                                  RuntimeInsight.isHighEnd.toString(),
                                  icon: Icons.arrow_upward,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Card(
                            child: Column(
                              children: [
                                ListTile(title: Text(l10n.monitoring)),
                                ListTile(
                                  title: Text(l10n.cpuStressTitle),
                                  subtitle: Text(
                                    _cpuStressRunning
                                        ? l10n.cpuStressRunning
                                        : l10n.cpuStressHint,
                                  ),
                                  trailing: ElevatedButton(
                                    onPressed: _cpuStressRunning
                                        ? null
                                        : _startCpuStress,
                                    child: Text(l10n.cpuStressButton),
                                  ),
                                ),
                                _infoTile(
                                  l10n.cpuPercent,
                                  cpuValue?.toStringAsFixed(1) ?? 'n/a',
                                  icon: Icons.memory,
                                ),
                                _infoTile(
                                  l10n.cpuAvg,
                                  snapshot?.cpuPercentAvg?.toStringAsFixed(1) ??
                                      'n/a',
                                  icon: Icons.show_chart,
                                ),
                                _infoTile(
                                  l10n.ramMb,
                                  snapshot?.memoryMb?.toStringAsFixed(1) ??
                                      'n/a',
                                  icon: Icons.storage,
                                ),
                                _infoTile(
                                  l10n.ramAvg,
                                  snapshot?.memoryMbAvg?.toStringAsFixed(1) ??
                                      'n/a',
                                  icon: Icons.auto_graph,
                                ),
                                _infoTile(
                                  'FPS',
                                  snapshot?.fps?.toStringAsFixed(1) ?? 'n/a',
                                  icon: Icons.speed,
                                ),
                                _infoTile(
                                  l10n.fpsAvg,
                                  snapshot?.fpsAvg?.toStringAsFixed(1) ?? 'n/a',
                                  icon: Icons.speed,
                                ),
                                _infoTile(
                                  l10n.networkRx,
                                  _formatBytes(snapshot?.networkRxBytes),
                                  icon: Icons.download,
                                ),
                                _infoTile(
                                  l10n.networkRxRate,
                                  _formatRate(snapshot?.networkRxBytesPerSec),
                                  icon: Icons.trending_up,
                                ),
                                _infoTile(
                                  l10n.networkTx,
                                  _formatBytes(snapshot?.networkTxBytes),
                                  icon: Icons.upload,
                                ),
                                _infoTile(
                                  l10n.networkTxRate,
                                  _formatRate(snapshot?.networkTxBytesPerSec),
                                  icon: Icons.trending_up,
                                ),
                                _infoTile(
                                  l10n.diskRead,
                                  _formatBytes(snapshot?.diskReadBytes),
                                  icon: Icons.file_open,
                                ),
                                _infoTile(
                                  l10n.diskReadRate,
                                  _formatRate(snapshot?.diskReadBytesPerSec),
                                  icon: Icons.trending_up,
                                ),
                                _infoTile(
                                  l10n.diskWrite,
                                  _formatBytes(snapshot?.diskWriteBytes),
                                  icon: Icons.save,
                                ),
                                _infoTile(
                                  l10n.diskWriteRate,
                                  _formatRate(snapshot?.diskWriteBytesPerSec),
                                  icon: Icons.trending_up,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      Align(
                        alignment: Alignment.topRight,
                        child: RuntimeInsightOverlay(
                          stream: _monitorStream,
                          persistenceKey: 'runtime_insight_overlay',
                          strings: RuntimeInsightOverlayStrings(
                            title: l10n.overlayTitle,
                            tabCpu: l10n.tabCpu,
                            tabRam: l10n.tabRam,
                            tabDisk: l10n.tabDisk,
                            tabNetwork: l10n.tabNetwork,
                            cpuTitle: l10n.cpuPercent,
                            ramTitle: l10n.ramMb,
                            diskTitle: l10n.diskReadRate,
                            networkTitle: l10n.networkRxRate,
                            labelCurrent: l10n.labelCurrent,
                            labelAverage: l10n.labelAverage,
                            labelSecondary: l10n.labelSecondary,
                            legendRead: l10n.legendRead,
                            legendWrite: l10n.legendWrite,
                            legendRx: l10n.legendRx,
                            legendTx: l10n.legendTx,
                            pause: l10n.pause,
                            resume: l10n.resume,
                            close: l10n.close,
                            minimize: l10n.minimize,
                            expand: l10n.expand,
                          ),
                          onClose: () {},
                        ),
                      ),
                    ],
                  ),
          );
        },
      ),
    );
  }
}

void _cpuStressEntry(int durationMs) {
  final stopwatch = Stopwatch()..start();
  var value = 0.0;
  while (stopwatch.elapsedMilliseconds < durationMs) {
    value = sqrt(value + 1.0001);
    if (value > 1e6) value = 0.0;
  }
}

Widget _infoTile(String label, String value, {IconData? icon}) {
  return ListTile(
    dense: true,
    leading: icon == null ? null : Icon(icon, size: 20),
    title: Text(label),
    trailing: Text(value),
  );
}

Color _tierColor(String? tierName) {
  switch (tierName) {
    case 'low':
      return Colors.red;
    case 'mid':
      return Colors.orange;
    case 'high':
      return Colors.green;
    default:
      return Colors.blueGrey;
  }
}

IconData _tierIcon(String? tierName) {
  switch (tierName) {
    case 'low':
      return Icons.battery_1_bar;
    case 'mid':
      return Icons.battery_5_bar;
    case 'high':
      return Icons.battery_full;
    default:
      return Icons.help_outline;
  }
}

String _formatBytes(int? bytes) {
  if (bytes == null) return 'n/a';
  const kb = 1024;
  const mb = 1024 * 1024;
  if (bytes >= mb) {
    return '${(bytes / mb).toStringAsFixed(2)} MB';
  }
  if (bytes >= kb) {
    return '${(bytes / kb).toStringAsFixed(1)} KB';
  }
  return '$bytes B';
}

String _formatRate(double? bytesPerSec) {
  if (bytesPerSec == null) return 'n/a';
  return '${_formatBytes(bytesPerSec.round())}/s';
}

String _platformLabel(DevicePlatform platform) {
  switch (platform) {
    case DevicePlatform.android:
      return 'Android';
    case DevicePlatform.ios:
      return 'iOS';
  }
}

IconData _platformIcon(DevicePlatform platform) {
  switch (platform) {
    case DevicePlatform.android:
      return Icons.android;
    case DevicePlatform.ios:
      return Icons.apple;
  }
}
