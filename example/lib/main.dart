import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';

import 'package:flutter/material.dart';
import 'l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:runtime_insight/device/device_specs.dart';
import 'package:runtime_insight/runtime_insight.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await RuntimeInsight.enableHttpTracking();
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
  static const _monitorConfig = AppResourceMonitoringConfig(
    cpu: true,
    memory: true,
    fps: false,
    network: false,
    disk: false,
    http: true,
    interval: Duration(seconds: 1),
    movingAverageWindow: 5,
  );
  bool _cpuStressRunning = false;
  bool _httpDemoRunning = false;
  Timer? _autoHttpTimer;
  bool _autoHttpRunning = false;

  @override
  void initState() {
    super.initState();
    _initPlatformState();
  }

  @override
  void dispose() {
    _autoHttpTimer?.cancel();
    _monitorSubscription?.cancel();
    RuntimeInsight.stopMonitoring();
    super.dispose();
  }

  Future<void> _fireHttpDemo() async {
    if (_httpDemoRunning) return;
    setState(() => _httpDemoRunning = true);
    try {
      final client = HttpClient();

      // GET requests
      await _doRequest(client, 'GET', 'https://jsonplaceholder.typicode.com/posts/1');
      await _doRequest(client, 'GET', 'https://jsonplaceholder.typicode.com/users');

      // POST
      await _doRequest(client, 'POST', 'https://jsonplaceholder.typicode.com/posts',
          body: '{"title":"test","body":"hello","userId":1}');

      // PUT
      await _doRequest(client, 'PUT', 'https://jsonplaceholder.typicode.com/posts/1',
          body: '{"id":1,"title":"updated","body":"world","userId":1}');

      // PATCH
      await _doRequest(client, 'PATCH', 'https://jsonplaceholder.typicode.com/posts/1',
          body: '{"title":"patched"}');

      // DELETE
      await _doRequest(client, 'DELETE', 'https://jsonplaceholder.typicode.com/posts/1');

      // 404 error
      await _doRequest(client, 'GET', 'https://httpstat.us/404');

      // 500 error
      await _doRequest(client, 'GET', 'https://httpstat.us/500');

      client.close();
    } finally {
      if (mounted) setState(() => _httpDemoRunning = false);
    }
  }

  Future<void> _doRequest(HttpClient client, String method, String url,
      {String? body}) async {
    try {
      final uri = Uri.parse(url);
      final HttpClientRequest request;
      switch (method) {
        case 'POST':
          request = await client.postUrl(uri);
          break;
        case 'PUT':
          request = await client.putUrl(uri);
          break;
        case 'PATCH':
          request = await client.patchUrl(uri);
          break;
        case 'DELETE':
          request = await client.deleteUrl(uri);
          break;
        default:
          request = await client.getUrl(uri);
      }
      request.headers.set('Content-Type', 'application/json');
      if (body != null) request.write(body);
      final response = await request.close();
      await response.drain<void>();
    } catch (_) {}
  }

  void _toggleAutoHttp() {
    if (_autoHttpRunning) {
      _autoHttpTimer?.cancel();
      _autoHttpTimer = null;
      setState(() => _autoHttpRunning = false);
    } else {
      setState(() => _autoHttpRunning = true);
      _autoHttpTick();
      _autoHttpTimer = Timer.periodic(const Duration(seconds: 3), (_) {
        _autoHttpTick();
      });
    }
  }

  Future<void> _autoHttpTick() async {
    final client = HttpClient();
    final endpoints = [
      'https://jsonplaceholder.typicode.com/posts/${Random().nextInt(100) + 1}',
      'https://jsonplaceholder.typicode.com/comments/${Random().nextInt(500) + 1}',
      'https://jsonplaceholder.typicode.com/todos/${Random().nextInt(200) + 1}',
    ];
    final url = endpoints[Random().nextInt(endpoints.length)];
    try {
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close();
      await response.drain<void>();
    } catch (_) {}
    client.close();
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
    _monitorStream = RuntimeInsight.startMonitoring(config: _monitorConfig);
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
                                ListTile(
                                  title: const Text('HTTP Demo'),
                                  subtitle: Text(
                                    _httpDemoRunning
                                        ? 'Firing 8 requests (GET, POST, PUT, PATCH, DELETE, 404, 500)...'
                                        : 'Fire 8 varied HTTP requests',
                                  ),
                                  trailing: ElevatedButton.icon(
                                    onPressed: _httpDemoRunning
                                        ? null
                                        : _fireHttpDemo,
                                    icon: const Icon(Icons.send, size: 16),
                                    label: const Text('Fire'),
                                  ),
                                ),
                                ListTile(
                                  title: const Text('Auto HTTP'),
                                  subtitle: Text(
                                    _autoHttpRunning
                                        ? 'Sending a random GET every 3s...'
                                        : 'Periodically send random requests',
                                  ),
                                  trailing: ElevatedButton.icon(
                                    onPressed: _toggleAutoHttp,
                                    icon: Icon(
                                      _autoHttpRunning ? Icons.stop : Icons.play_arrow,
                                      size: 16,
                                    ),
                                    label: Text(_autoHttpRunning ? 'Stop' : 'Start'),
                                    style: _autoHttpRunning
                                        ? ElevatedButton.styleFrom(
                                            backgroundColor: Colors.red.shade100,
                                            foregroundColor: Colors.red.shade800,
                                          )
                                        : null,
                                  ),
                                ),
                                ListTile(
                                  title: const Text('HTTP Logs'),
                                  subtitle: Text(
                                    '${HttpTracker.instance.totalCount} total, '
                                    '${HttpTracker.instance.activeCount} active',
                                  ),
                                  trailing: TextButton.icon(
                                    onPressed: () async {
                                      await HttpTracker.instance.clearLogs();
                                      if (mounted) setState(() {});
                                    },
                                    icon: const Icon(Icons.delete_outline, size: 16),
                                    label: const Text('Clear'),
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
                          config: _monitorConfig,
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
                            labelMin: l10n.labelMin,
                            labelMax: l10n.labelMax,
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
                            tabHttp: l10n.tabHttp,
                            httpTitle: l10n.httpTitle,
                            httpActive: l10n.httpActive,
                            httpTotal: l10n.httpTotal,
                            httpAvgTime: l10n.httpAvgTime,
                            httpErrors: l10n.httpErrors,
                            httpPending: l10n.httpPending,
                            httpCompleted: l10n.httpCompleted,
                            httpFailed: l10n.httpFailed,
                          ),
                          onClose: () {},
                          displayStats: {OverlayDisplayStat.current, OverlayDisplayStat.average, OverlayDisplayStat.min, OverlayDisplayStat.max, OverlayDisplayStat.secondary},
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
