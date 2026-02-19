import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../runtime_insight.dart';

/// Which statistics to display in each metric tab's chip row.
///
/// Defaults to [current] and [average]. Developers can pick any combination:
///
/// ```dart
/// RuntimeInsightOverlay(
///   displayStats: {OverlayDisplayStat.current, OverlayDisplayStat.min, OverlayDisplayStat.max},
/// )
/// ```
enum OverlayDisplayStat {
  /// The most recent value.
  current,

  /// Moving average over the configured window.
  average,

  /// Minimum value in the current history buffer.
  min,

  /// Maximum value in the current history buffer.
  max,

  /// Secondary value (e.g. write rate for disk, TX for network).
  secondary,
}

/// The default set of display stats shown in the overlay.
const Set<OverlayDisplayStat> kDefaultDisplayStats = {
  OverlayDisplayStat.current,
  OverlayDisplayStat.average,
};

/// A draggable overlay widget that displays real-time app resource charts.
///
/// Place it in a [Stack] to visualise CPU, RAM, disk and network metrics.
/// The overlay supports drag, pause/resume, opacity control and position
/// persistence via [SharedPreferences].
///
/// If no [stream] is provided, the widget automatically calls
/// [RuntimeInsight.startMonitoring] and manages its lifecycle.
///
/// Use [controller] (or the static [RuntimeInsightOverlayController.instance])
/// to change any configuration or read streams from anywhere:
///
/// ```dart
/// final ctrl = RuntimeInsightOverlayController.instance;
/// ctrl.hide();
/// ctrl.minimize();
/// ctrl.opacity = 0.6;
/// ctrl.width = 320;
/// ctrl.showPauseButton = false;
///
/// ctrl.snapshotStream.listen((s) => print(s.cpuPercent));
/// ```
class RuntimeInsightOverlay extends StatefulWidget {
  /// An external monitoring stream. If `null`, the overlay creates its own.
  final Stream<AppResourceSnapshot>? stream;

  /// Monitoring configuration used when the overlay creates its own stream.
  final AppResourceMonitoringConfig? config;

  /// Maximum number of data points shown in the charts.
  final int maxPoints;

  /// Widget width.
  final double width;

  /// Widget height.
  final double height;

  /// Whether to show the close button.
  final bool showCloseButton;

  /// Whether to show the pause/resume button.
  final bool showPauseButton;

  /// Whether to show the opacity slider.
  final bool showOpacitySlider;

  /// Whether the overlay can be dragged.
  final bool allowDrag;

  /// Key used for persisting position and opacity in [SharedPreferences].
  final String? persistenceKey;

  /// Whether to persist the overlay position across sessions.
  final bool persistPosition;

  /// Whether to persist the overlay opacity across sessions.
  final bool persistOpacity;

  /// Localised strings for the overlay UI.
  final RuntimeInsightOverlayStrings? strings;

  /// Called when the close button is tapped.
  final VoidCallback? onClose;

  /// Margin around the overlay.
  final EdgeInsets margin;

  /// Background colour override for the overlay panel.
  final Color? backgroundColor;

  /// Whether to show the minimize button in the header.
  final bool showMinimizeButton;

  /// Diameter of the minimized circle bubble.
  final double minimizedSize;

  /// Whether the overlay starts in minimized mode.
  final bool initiallyMinimized;

  /// Which statistics to show in each metric tab (current, average, min, max,
  /// secondary). Defaults to [kDefaultDisplayStats] (current + average).
  final Set<OverlayDisplayStat> displayStats;

  /// Optional controller for programmatic state and configuration changes.
  ///
  /// If `null`, the global [RuntimeInsightOverlayController.instance] is used.
  final RuntimeInsightOverlayController? controller;

  const RuntimeInsightOverlay({
    super.key,
    this.stream,
    this.config,
    this.maxPoints = 60,
    this.width = 280,
    this.height = 300,
    this.showCloseButton = true,
    this.showPauseButton = true,
    this.showOpacitySlider = true,
    this.allowDrag = true,
    this.persistenceKey,
    this.persistPosition = true,
    this.persistOpacity = true,
    this.strings,
    this.onClose,
    this.margin = const EdgeInsets.all(12),
    this.backgroundColor,
    this.showMinimizeButton = true,
    this.minimizedSize = 56,
    this.initiallyMinimized = false,
    this.displayStats = kDefaultDisplayStats,
    this.controller,
  });

  @override
  State<RuntimeInsightOverlay> createState() => _RuntimeInsightOverlayState();
}

class _RuntimeInsightOverlayState extends State<RuntimeInsightOverlay> {
  Stream<AppResourceSnapshot>? _stream;
  StreamSubscription<AppResourceSnapshot>? _subscription;
  StreamSubscription<void>? _httpSubscription;
  bool _ownsMonitoring = false;
  Offset _dragOffset = Offset.zero;
  Timer? _persistTimer;

  RuntimeInsightOverlayController get _ctrl =>
      widget.controller ?? RuntimeInsightOverlayController.instance;

  // ---------------------------------------------------------------------------
  // Resolved config helpers — controller value ?? widget value
  // ---------------------------------------------------------------------------

  double get _width => _ctrl.width ?? widget.width;
  double get _height => _ctrl.height ?? widget.height;
  int get _maxPoints => _ctrl.maxPoints ?? widget.maxPoints;
  double get _minimizedSize => _ctrl.minimizedSize ?? widget.minimizedSize;
  EdgeInsets get _margin => _ctrl.margin ?? widget.margin;
  Color? get _backgroundColor => _ctrl.backgroundColor ?? widget.backgroundColor;
  bool get _showCloseButton => _ctrl.showCloseButton ?? widget.showCloseButton;
  bool get _showPauseButton => _ctrl.showPauseButton ?? widget.showPauseButton;
  bool get _showOpacitySlider =>
      _ctrl.showOpacitySlider ?? widget.showOpacitySlider;
  bool get _showMinimizeButton =>
      _ctrl.showMinimizeButton ?? widget.showMinimizeButton;
  bool get _allowDrag => _ctrl.allowDrag ?? widget.allowDrag;
  RuntimeInsightOverlayStrings get _strings =>
      _ctrl.strings ?? widget.strings ?? RuntimeInsightOverlayStrings.english();
  VoidCallback? get _onClose => _ctrl.onClose ?? widget.onClose;
  AppResourceMonitoringConfig? get _monitoringConfig =>
      _ctrl.monitoringConfig ?? widget.config;
  Set<OverlayDisplayStat> get _displayStats =>
      _ctrl.displayStats ?? widget.displayStats;

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    if (widget.initiallyMinimized) {
      _ctrl.minimized = true;
    }
    _ctrl.addListener(_onControllerChanged);
    _restorePrefs();
    _start();
  }

  @override
  void didUpdateWidget(RuntimeInsightOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);

    final oldCtrl =
        oldWidget.controller ?? RuntimeInsightOverlayController.instance;
    if (oldCtrl != _ctrl) {
      oldCtrl.removeListener(_onControllerChanged);
      _ctrl.addListener(_onControllerChanged);
    }

    if (oldWidget.stream != widget.stream ||
        oldWidget.config != widget.config) {
      _restart();
    }
  }

  AppResourceMonitoringConfig? _lastAppliedConfig;

  /// Called whenever the [RuntimeInsightOverlayController] notifies.
  void _onControllerChanged() {
    if (!mounted) return;

    // Sync pause / resume with monitoring engine.
    if (_ctrl.paused && !_isPausedInternally) {
      _pauseInternal();
    } else if (!_ctrl.paused && _isPausedInternally) {
      _resumeInternal();
    }

    // If the monitoring config was changed via the controller, restart.
    final newConfig = _monitoringConfig;
    if (newConfig != _lastAppliedConfig && _ownsMonitoring) {
      _lastAppliedConfig = newConfig;
      _restart();
    }

    setState(() {}); // Rebuild with new controller values.
    _schedulePersist();
  }

  // ---------------------------------------------------------------------------
  // Preferences persistence
  // ---------------------------------------------------------------------------

  Future<void> _restorePrefs() async {
    final key = widget.persistenceKey;
    if (key == null) return;
    final prefs = await SharedPreferences.getInstance();
    final dx = prefs.getDouble('${key}_dx');
    final dy = prefs.getDouble('${key}_dy');
    final opacity = prefs.getDouble('${key}_opacity');
    final minimized = prefs.getBool('${key}_minimized');
    if (!mounted) return;
    setState(() {
      if (dx != null && dy != null) {
        _dragOffset = Offset(dx, dy);
      }
      if (opacity != null) {
        _ctrl.opacity = opacity.clamp(0.4, 1.0);
      }
      if (minimized != null) {
        _ctrl.minimized = minimized;
      }
    });
  }

  void _schedulePersist() {
    final key = widget.persistenceKey;
    if (key == null) return;
    _persistTimer?.cancel();
    _persistTimer = Timer(const Duration(milliseconds: 300), () async {
      final prefs = await SharedPreferences.getInstance();
      if (widget.persistPosition) {
        await prefs.setDouble('${key}_dx', _dragOffset.dx);
        await prefs.setDouble('${key}_dy', _dragOffset.dy);
      }
      if (widget.persistOpacity) {
        await prefs.setDouble('${key}_opacity', _ctrl.opacity);
      }
      await prefs.setBool('${key}_minimized', _ctrl.minimized);
    });
  }

  // ---------------------------------------------------------------------------
  // Monitoring start / stop
  // ---------------------------------------------------------------------------

  Future<void> _start() async {
    if (widget.stream != null) {
      _stream = widget.stream;
      _ownsMonitoring = false;
    } else {
      _lastAppliedConfig = _monitoringConfig;
      _stream = RuntimeInsight.startMonitoring(config: _monitoringConfig);
      _ownsMonitoring = true;
    }
    _subscribe();
  }

  void _subscribe() {
    _subscription = _stream?.listen((snapshot) {
      if (_ctrl.paused) return;
      _ctrl.addSnapshot(snapshot, maxPoints: _maxPoints);
      setState(() {});
    });
    _httpSubscription?.cancel();
    if (HttpTracker.instance.enabled) {
      _httpSubscription = HttpTracker.instance.onChange.listen((_) {
        if (mounted) setState(() {});
      });
    }
  }

  Future<void> _restart() async {
    await _subscription?.cancel();
    if (_ownsMonitoring) {
      await RuntimeInsight.stopMonitoring();
    }
    _ctrl.clearHistory();
    await _start();
  }

  @override
  void dispose() {
    _ctrl.removeListener(_onControllerChanged);
    _persistTimer?.cancel();
    _subscription?.cancel();
    _httpSubscription?.cancel();
    if (_ownsMonitoring) {
      RuntimeInsight.stopMonitoring();
    }
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Pause helpers
  // ---------------------------------------------------------------------------

  bool _isPausedInternally = false;

  Future<void> _togglePause() async {
    _ctrl.togglePause();
  }

  Future<void> _pauseInternal() async {
    if (_isPausedInternally) return;
    _isPausedInternally = true;
    if (_ownsMonitoring) {
      await RuntimeInsight.pauseMonitoring();
    } else {
      await _subscription?.cancel();
    }
  }

  Future<void> _resumeInternal() async {
    if (!_isPausedInternally) return;
    _isPausedInternally = false;
    if (_ownsMonitoring) {
      await RuntimeInsight.resumeMonitoring();
    } else {
      _subscription?.cancel();
      _subscribe();
    }
  }

  void _toggleMinimized() {
    _ctrl.toggleMinimized();
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (!_ctrl.visible) return const SizedBox.shrink();

    final history = _ctrl.history;
    final snapshot = _ctrl.latestSnapshot;
    final theme = Theme.of(context);

    if (_ctrl.minimized) {
      return _buildMinimized(context, snapshot, theme);
    }
    return _buildExpanded(context, snapshot, history, theme);
  }

  Widget _buildMinimized(
    BuildContext context,
    AppResourceSnapshot? snapshot,
    ThemeData theme,
  ) {
    final cpuRaw = snapshot?.cpuPercent ?? snapshot?.cpuPercentAvg ?? 0;
    final cpuInt = cpuRaw.round().clamp(0, 100);
    final fraction = cpuInt / 100;

    final bgColor =
        _backgroundColor ?? theme.colorScheme.surface.withOpacity(_ctrl.opacity);

    final bubble = GestureDetector(
      onTap: _toggleMinimized,
      child: Container(
        margin: _margin,
        width: _minimizedSize,
        height: _minimizedSize,
        child: Material(
          elevation: 6,
          shape: const CircleBorder(),
          color: bgColor,
          child: CustomPaint(
            painter: _CpuArcPainter(
              fraction: fraction,
              arcColor: _cpuArcColor(fraction),
              trackColor: theme.colorScheme.outlineVariant.withOpacity(0.3),
              strokeWidth: 3.5,
            ),
            child: Center(
              child: Text(
                '$cpuInt%',
                style: TextStyle(
                  fontSize: _minimizedSize * 0.26,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    if (!_allowDrag) return bubble;

    return Transform.translate(
      offset: _dragOffset,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            _dragOffset += details.delta;
          });
          _schedulePersist();
        },
        child: bubble,
      ),
    );
  }

  Widget _buildExpanded(
    BuildContext context,
    AppResourceSnapshot? snapshot,
    List<AppResourceSnapshot> history,
    ThemeData theme,
  ) {
    final bgColor =
        _backgroundColor ?? theme.colorScheme.surface.withOpacity(_ctrl.opacity);
    final strings = _strings;
    final config = _monitoringConfig ?? const AppResourceMonitoringConfig();

    // Build only tabs for monitored metrics.
    final tabs = <Tab>[];
    final tabViews = <Widget>[];

    if (config.cpu) {
      tabs.add(Tab(text: strings.tabCpu));
      tabViews.add(_metricTab(
        title: strings.cpuTitle,
        icon: Icons.memory,
        history: history,
        primarySelector: (s) => s.cpuPercent,
        avgSelector: (s) => s.cpuPercentAvg,
        format: _formatDouble,
        series: [_series(history, (s) => s.cpuPercent)],
        colors: [Colors.orange],
      ));
    }

    if (config.memory) {
      tabs.add(Tab(text: strings.tabRam));
      tabViews.add(_metricTab(
        title: strings.ramTitle,
        icon: Icons.storage,
        history: history,
        primarySelector: (s) => s.memoryMb,
        avgSelector: (s) => s.memoryMbAvg,
        format: _formatDouble,
        series: [_series(history, (s) => s.memoryMb)],
        colors: [Colors.blue],
      ));
    }

    if (config.disk) {
      tabs.add(Tab(text: strings.tabDisk));
      tabViews.add(_metricTab(
        title: strings.diskTitle,
        icon: Icons.disc_full_outlined,
        history: history,
        primarySelector: (s) => s.diskReadBytesPerSec,
        avgSelector: null,
        secondarySelector: (s) => s.diskWriteBytesPerSec,
        format: _formatRate,
        series: [
          _series(history, (s) => s.diskReadBytesPerSec),
          _series(history, (s) => s.diskWriteBytesPerSec),
        ],
        colors: [Colors.green, Colors.redAccent],
        legend: [strings.legendRead, strings.legendWrite],
      ));
    }

    if (config.network) {
      tabs.add(Tab(text: strings.tabNetwork));
      tabViews.add(_metricTab(
        title: strings.networkTitle,
        icon: Icons.wifi,
        history: history,
        primarySelector: (s) => s.networkRxBytesPerSec,
        avgSelector: null,
        secondarySelector: (s) => s.networkTxBytesPerSec,
        format: _formatRate,
        series: [
          _series(history, (s) => s.networkRxBytesPerSec),
          _series(history, (s) => s.networkTxBytesPerSec),
        ],
        colors: [Colors.teal, Colors.purple],
        legend: [strings.legendRx, strings.legendTx],
      ));
    }

    if (config.http) {
      tabs.add(Tab(text: strings.tabHttp));
      tabViews.add(_httpTab(strings));
    }

    final hasTabs = tabs.isNotEmpty;

    final content = Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(12),
      color: bgColor,
      child: hasTabs
          ? DefaultTabController(
              length: tabs.length,
              child: Column(
                children: [
                  _header(theme, strings),
                  if (_showOpacitySlider) _opacityControl(),
                  const Divider(height: 1),
                  TabBar(tabs: tabs),
                  const SizedBox(height: 8),
                  Expanded(child: TabBarView(children: tabViews)),
                ],
              ),
            )
          : Column(
              children: [
                _header(theme, strings),
                if (_showOpacitySlider) _opacityControl(),
              ],
            ),
    );

    final overlay = Container(
      margin: _margin,
      width: _width,
      height: _height,
      child: content,
    );

    if (!_allowDrag) return overlay;

    return Transform.translate(
      offset: _dragOffset,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            _dragOffset += details.delta;
          });
          _schedulePersist();
        },
        child: overlay,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Sub-widgets
  // ---------------------------------------------------------------------------

  static Color _cpuArcColor(double fraction) {
    if (fraction < 0.5) return Colors.green;
    if (fraction < 0.8) return Colors.orange;
    return Colors.red;
  }

  Widget _header(ThemeData theme, RuntimeInsightOverlayStrings strings) {
    final iconColor = theme.colorScheme.onSurface;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          Icon(Icons.monitor, size: 18, color: iconColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              strings.title,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: iconColor,
              ),
            ),
          ),
          if (_showPauseButton)
            IconButton(
              icon: Icon(
                _ctrl.paused ? Icons.play_arrow : Icons.pause,
                size: 18,
                color: iconColor,
              ),
              onPressed: _togglePause,
              tooltip: _ctrl.paused ? strings.resume : strings.pause,
            ),
          if (_showMinimizeButton)
            IconButton(
              icon: Icon(
                Icons.remove_circle_outline,
                size: 18,
                color: iconColor,
              ),
              onPressed: _toggleMinimized,
              tooltip: strings.minimize,
            ),
          if (_showCloseButton)
            IconButton(
              icon: Icon(Icons.close, size: 18, color: iconColor),
              onPressed: _onClose,
              tooltip: strings.close,
            ),
        ],
      ),
    );
  }

  Widget _opacityControl() {
    final iconColor = Theme.of(context).colorScheme.onSurface;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Icon(Icons.opacity, size: 16, color: iconColor),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 2,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              ),
              child: Slider(
                value: _ctrl.opacity.clamp(0.4, 1.0),
                min: 0.4,
                max: 1.0,
                onChanged: (value) {
                  _ctrl.opacity = value;
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _metricTab({
    required String title,
    required IconData icon,
    required List<AppResourceSnapshot> history,
    required double? Function(AppResourceSnapshot) primarySelector,
    double? Function(AppResourceSnapshot)? avgSelector,
    double? Function(AppResourceSnapshot)? secondarySelector,
    required String Function(double?) format,
    required List<List<double?>> series,
    required List<Color> colors,
    List<String>? legend,
  }) {
    final strings = _strings;
    final stats = _displayStats;
    final iconColor = Theme.of(context).colorScheme.onSurface;

    final snapshot = history.isEmpty ? null : history.last;
    final primaryValues =
        history.map(primarySelector).whereType<double>().toList();

    final chips = <Widget>[];

    if (stats.contains(OverlayDisplayStat.current)) {
      double? currentValue;
      if (snapshot != null) {
        if (avgSelector != null) {
          currentValue = primarySelector(snapshot);
        } else {
          // For rate-based metrics (disk, network) smooth the displayed value
          // over the last few samples to avoid flickering.
          final recent = primaryValues.length <= 3
              ? primaryValues
              : primaryValues.sublist(primaryValues.length - 3);
          currentValue = recent.isEmpty
              ? primarySelector(snapshot)
              : recent.fold<double>(0, (a, b) => a + b) / recent.length;
        }
      }
      chips.add(_valueChip(strings.labelCurrent, format(currentValue)));
    }
    if (stats.contains(OverlayDisplayStat.average)) {
      double? avg;
      if (avgSelector != null && snapshot != null) {
        avg = avgSelector(snapshot);
      } else if (primaryValues.isNotEmpty) {
        avg = primaryValues.fold<double>(0, (a, b) => a + b) /
            primaryValues.length;
      }
      chips.add(_valueChip(strings.labelAverage, format(avg)));
    }
    if (stats.contains(OverlayDisplayStat.min) && primaryValues.isNotEmpty) {
      chips.add(_valueChip(
        strings.labelMin,
        format(primaryValues.reduce(min)),
      ));
    }
    if (stats.contains(OverlayDisplayStat.max) && primaryValues.isNotEmpty) {
      chips.add(_valueChip(
        strings.labelMax,
        format(primaryValues.reduce(max)),
      ));
    }
    if (stats.contains(OverlayDisplayStat.secondary) &&
        secondarySelector != null) {
      chips.add(_valueChip(
        strings.labelSecondary,
        format(snapshot == null ? null : secondarySelector(snapshot)),
      ));
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: iconColor),
              const SizedBox(width: 6),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 52),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: chips,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: SimpleLineChart(series: series, colors: colors),
          ),
          if (legend != null) _legendRow(legend, colors),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _httpTab(RuntimeInsightOverlayStrings strings) {
    final tracker = HttpTracker.instance;
    final iconColor = Theme.of(context).colorScheme.onSurface;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.http, size: 16, color: iconColor),
              const SizedBox(width: 6),
              Text(strings.httpTitle,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 52),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  _valueChip(strings.httpActive, '${tracker.activeCount}'),
                  _valueChip(strings.httpTotal, '${tracker.totalCount}'),
                  _valueChip(strings.httpAvgTime,
                      '${tracker.avgResponseTimeMs.toStringAsFixed(0)} ms'),
                  _valueChip(strings.httpErrors,
                      '${(tracker.errorRate * 100).toStringAsFixed(0)}%'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: tracker.logs.isEmpty
                ? Center(
                    child: Text(
                      'No requests yet',
                      style: TextStyle(
                        color: iconColor.withOpacity(0.5),
                        fontSize: 12,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.zero,
                    reverse: true,
                    itemCount: tracker.logs.length,
                    itemExtent: 36,
                    itemBuilder: (context, index) {
                      final log = tracker.logs[index];
                      return _httpRequestRow(log);
                    },
                  ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _httpRequestRow(HttpRequestLog log) {
    return Row(
      children: [
        _httpMethodChip(log.method),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            log.url,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            style: const TextStyle(fontSize: 11),
          ),
        ),
        const SizedBox(width: 6),
        _httpStatusIndicator(log),
      ],
    );
  }

  Widget _httpMethodChip(String method) {
    final color = _httpMethodColor(method);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.4), width: 0.5),
      ),
      child: Text(
        method,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  static Color _httpMethodColor(String method) {
    switch (method.toUpperCase()) {
      case 'GET':
        return Colors.green;
      case 'POST':
        return Colors.blue;
      case 'PUT':
        return Colors.orange;
      case 'PATCH':
        return Colors.deepOrange;
      case 'DELETE':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Widget _httpStatusIndicator(HttpRequestLog log) {
    switch (log.status) {
      case HttpRequestStatus.pending:
        return const SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(strokeWidth: 1.5),
        );
      case HttpRequestStatus.completed:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (log.durationMs != null)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Text(
                  '${log.durationMs}ms',
                  style: TextStyle(
                    fontSize: 9,
                    color: Colors.green.shade700,
                  ),
                ),
              ),
            Icon(Icons.check_circle, size: 14, color: Colors.green.shade600),
          ],
        );
      case HttpRequestStatus.failed:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (log.statusCode != null)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Text(
                  '${log.statusCode}',
                  style: TextStyle(
                    fontSize: 9,
                    color: Colors.red.shade700,
                  ),
                ),
              ),
            Icon(Icons.cancel, size: 14, color: Colors.red.shade600),
          ],
        );
    }
  }

  Widget _legendRow(List<String> labels, List<Color> colors) {
    return Wrap(
      spacing: 12,
      children: List.generate(labels.length, (index) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: colors[index],
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(labels[index]),
          ],
        );
      }),
    );
  }

  Widget _valueChip(String label, String value) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.06),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text('$label: $value'),
    );
  }
}

// =============================================================================
// Charts
// =============================================================================

/// A lightweight line chart widget used internally by [RuntimeInsightOverlay].
///
/// Renders one or more data series using [CustomPaint].
class SimpleLineChart extends StatelessWidget {
  final List<List<double?>> series;
  final List<Color> colors;
  final int gridLines;
  final Color gridColor;

  const SimpleLineChart({
    super.key,
    required this.series,
    required this.colors,
    this.gridLines = 4,
    this.gridColor = const Color(0x22000000),
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _LineChartPainter(
        series,
        colors,
        gridLines: gridLines,
        gridColor: gridColor,
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _LineChartPainter extends CustomPainter {
  final List<List<double?>> series;
  final List<Color> colors;
  final int gridLines;
  final Color gridColor;

  _LineChartPainter(
    this.series,
    this.colors, {
    required this.gridLines,
    required this.gridColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    _drawGrid(canvas, rect);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final maxValue = _maxValue(series);
    if (maxValue <= 0) return;

    for (var s = 0; s < series.length; s++) {
      final data = series[s];
      if (data.isEmpty) continue;
      paint.color = colors[s % colors.length];

      final path = Path();
      bool started = false;
      for (var i = 0; i < data.length; i++) {
        final value = data[i];
        if (value == null) {
          started = false;
          continue;
        }
        final x = rect.left + (i / max(1, data.length - 1)) * rect.width;
        final y = rect.bottom - (value / maxValue) * rect.height;
        if (!started) {
          path.moveTo(x, y);
          started = true;
        } else {
          path.lineTo(x, y);
        }
      }
      canvas.drawPath(path, paint);
    }
  }

  void _drawGrid(Canvas canvas, Rect rect) {
    if (gridLines <= 0) return;
    final gridPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = gridColor;
    for (var i = 1; i <= gridLines; i++) {
      final dy = rect.top + (rect.height * i / (gridLines + 1));
      canvas.drawLine(
          Offset(rect.left, dy), Offset(rect.right, dy), gridPaint);
    }
  }

  double _maxValue(List<List<double?>> series) {
    double maxValue = 0;
    for (final data in series) {
      for (final value in data) {
        if (value != null) {
          maxValue = max(maxValue, value);
        }
      }
    }
    return maxValue;
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) {
    return oldDelegate.series != series ||
        oldDelegate.colors != colors ||
        oldDelegate.gridLines != gridLines ||
        oldDelegate.gridColor != gridColor;
  }
}

class _CpuArcPainter extends CustomPainter {
  final double fraction;
  final Color arcColor;
  final Color trackColor;
  final double strokeWidth;

  _CpuArcPainter({
    required this.fraction,
    required this.arcColor,
    required this.trackColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (min(size.width, size.height) / 2) - strokeWidth;
    const startAngle = -pi / 2;
    final sweepAngle = 2 * pi * fraction.clamp(0.0, 1.0);

    // Track (background circle).
    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = trackColor
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, trackPaint);

    // Arc (CPU usage).
    if (sweepAngle > 0) {
      final arcPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..color = arcColor
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        arcPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CpuArcPainter oldDelegate) {
    return oldDelegate.fraction != fraction ||
        oldDelegate.arcColor != arcColor ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}

// =============================================================================
// Helpers
// =============================================================================

List<double?> _series(
  List<AppResourceSnapshot> history,
  double? Function(AppResourceSnapshot snapshot) selector,
) {
  return history.map(selector).toList();
}

String _formatDouble(double? value) {
  if (value == null) return 'n/a';
  return value.toStringAsFixed(1);
}

String _formatRate(double? bytesPerSec) {
  if (bytesPerSec == null) return 'n/a';
  return '${_formatBytes(bytesPerSec.round())}/s';
}

String _formatBytes(int? bytes) {
  if (bytes == null) return 'n/a';
  const kb = 1024;
  const mb = 1024 * 1024;
  if (bytes >= mb) {
    return '${(bytes / mb).toStringAsFixed(1)} MB';
  }
  if (bytes >= kb) {
    return '${(bytes / kb).toStringAsFixed(1)} KB';
  }
  return '$bytes B';
}
