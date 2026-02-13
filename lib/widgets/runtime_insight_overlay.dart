import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../runtime_insight.dart';

/// A draggable overlay widget that displays real-time app resource charts.
///
/// Place it in a [Stack] to visualise CPU, RAM, disk and network metrics.
/// The overlay supports drag, pause/resume, opacity control and position
/// persistence via [SharedPreferences].
///
/// If no [stream] is provided, the widget automatically calls
/// [RuntimeInsight.startMonitoring] and manages its lifecycle.
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
  });

  @override
  State<RuntimeInsightOverlay> createState() => _RuntimeInsightOverlayState();
}

class _RuntimeInsightOverlayState extends State<RuntimeInsightOverlay> {
  final List<AppResourceSnapshot> _history = [];
  Stream<AppResourceSnapshot>? _stream;
  StreamSubscription<AppResourceSnapshot>? _subscription;
  bool _ownsMonitoring = false;
  bool _paused = false;
  bool _minimized = false;
  Offset _dragOffset = Offset.zero;
  double _opacity = 0.95;
  Timer? _persistTimer;

  @override
  void initState() {
    super.initState();
    _minimized = widget.initiallyMinimized;
    _restorePrefs();
    _start();
  }

  @override
  void didUpdateWidget(RuntimeInsightOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.stream != widget.stream ||
        oldWidget.config != widget.config) {
      _restart();
    }
  }

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
        _opacity = opacity.clamp(0.4, 1.0);
      }
      if (minimized != null) {
        _minimized = minimized;
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
        await prefs.setDouble('${key}_opacity', _opacity);
      }
      await prefs.setBool('${key}_minimized', _minimized);
    });
  }

  void _toggleMinimized() {
    setState(() {
      _minimized = !_minimized;
    });
    _schedulePersist();
  }

  Future<void> _start() async {
    if (widget.stream != null) {
      _stream = widget.stream;
      _ownsMonitoring = false;
    } else {
      _stream = RuntimeInsight.startMonitoring(config: widget.config);
      _ownsMonitoring = true;
    }
    _subscribe();
  }

  void _subscribe() {
    _subscription = _stream?.listen((snapshot) {
      if (_paused) return;
      setState(() {
        _history.add(snapshot);
        if (_history.length > widget.maxPoints) {
          _history.removeAt(0);
        }
      });
    });
  }

  Future<void> _restart() async {
    await _subscription?.cancel();
    if (_ownsMonitoring) {
      await RuntimeInsight.stopMonitoring();
    }
    _history.clear();
    await _start();
  }

  @override
  void dispose() {
    _persistTimer?.cancel();
    _subscription?.cancel();
    if (_ownsMonitoring) {
      RuntimeInsight.stopMonitoring();
    }
    super.dispose();
  }

  Future<void> _togglePause() async {
    if (_paused) {
      await _resume();
    } else {
      await _pause();
    }
  }

  Future<void> _pause() async {
    if (_paused) return;
    if (_ownsMonitoring) {
      await RuntimeInsight.pauseMonitoring();
    } else {
      await _subscription?.cancel();
    }
    setState(() {
      _paused = true;
    });
  }

  Future<void> _resume() async {
    if (!_paused) return;
    if (_ownsMonitoring) {
      await RuntimeInsight.resumeMonitoring();
    } else {
      _subscription?.cancel();
      _subscribe();
    }
    setState(() {
      _paused = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final strings = widget.strings ?? RuntimeInsightOverlayStrings.english();
    final snapshot = _history.isEmpty ? null : _history.last;
    final theme = Theme.of(context);

    if (_minimized) {
      return _buildMinimized(context, snapshot, strings, theme);
    }
    return _buildExpanded(context, snapshot, strings, theme);
  }

  Widget _buildMinimized(
    BuildContext context,
    AppResourceSnapshot? snapshot,
    RuntimeInsightOverlayStrings strings,
    ThemeData theme,
  ) {
    final cpuRaw = snapshot?.cpuPercent ?? snapshot?.cpuPercentAvg ?? 0;
    final cpuInt = cpuRaw.round().clamp(0, 100);
    final fraction = cpuInt / 100;

    final bgColor =
        widget.backgroundColor ??
        theme.colorScheme.surface.withValues(alpha: _opacity);

    final bubble = GestureDetector(
      onTap: _toggleMinimized,
      child: Container(
        margin: widget.margin,
        width: widget.minimizedSize,
        height: widget.minimizedSize,
        child: Material(
          elevation: 6,
          shape: const CircleBorder(),
          color: bgColor,
          child: CustomPaint(
            painter: _CpuArcPainter(
              fraction: fraction,
              arcColor: _cpuArcColor(fraction),
              trackColor: theme.colorScheme.outlineVariant.withValues(
                alpha: 0.3,
              ),
              strokeWidth: 3.5,
            ),
            child: Center(
              child: Text(
                '$cpuInt%',
                style: TextStyle(
                  fontSize: widget.minimizedSize * 0.26,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    if (!widget.allowDrag) return bubble;

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
    RuntimeInsightOverlayStrings strings,
    ThemeData theme,
  ) {
    final cpuValue = _formatDouble(
      snapshot?.cpuPercent ?? snapshot?.cpuPercentAvg,
    );
    final bgColor =
        widget.backgroundColor ??
        theme.colorScheme.surface.withValues(alpha: _opacity);
    final content = Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(12),
      color: bgColor,
      child: DefaultTabController(
        length: 4,
        child: Column(
          children: [
            _header(theme, strings),
            if (widget.showOpacitySlider) _opacityControl(),
            const Divider(height: 1),
            TabBar(
              tabs: [
                Tab(text: strings.tabCpu),
                Tab(text: strings.tabRam),
                Tab(text: strings.tabDisk),
                Tab(text: strings.tabNetwork),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: TabBarView(
                children: [
                  _metricTab(
                    title: strings.cpuTitle,
                    value: cpuValue,
                    avgValue: _formatDouble(snapshot?.cpuPercentAvg),
                    series: [_series(_history, (s) => s.cpuPercent)],
                    colors: [Colors.orange],
                  ),
                  _metricTab(
                    title: strings.ramTitle,
                    value: _formatDouble(snapshot?.memoryMb),
                    avgValue: _formatDouble(snapshot?.memoryMbAvg),
                    series: [_series(_history, (s) => s.memoryMb)],
                    colors: [Colors.blue],
                  ),
                  _metricTab(
                    title: strings.diskTitle,
                    value: _formatRate(snapshot?.diskReadBytesPerSec),
                    secondaryValue: _formatRate(snapshot?.diskWriteBytesPerSec),
                    series: [
                      _series(_history, (s) => s.diskReadBytesPerSec),
                      _series(_history, (s) => s.diskWriteBytesPerSec),
                    ],
                    colors: [Colors.green, Colors.redAccent],
                    legend: [strings.legendRead, strings.legendWrite],
                  ),
                  _metricTab(
                    title: strings.networkTitle,
                    value: _formatRate(snapshot?.networkRxBytesPerSec),
                    secondaryValue: _formatRate(snapshot?.networkTxBytesPerSec),
                    series: [
                      _series(_history, (s) => s.networkRxBytesPerSec),
                      _series(_history, (s) => s.networkTxBytesPerSec),
                    ],
                    colors: [Colors.teal, Colors.purple],
                    legend: [strings.legendRx, strings.legendTx],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    final overlay = Container(
      margin: widget.margin,
      width: widget.width,
      height: widget.height,
      child: content,
    );

    if (!widget.allowDrag) return overlay;

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

  static Color _cpuArcColor(double fraction) {
    if (fraction < 0.5) return Colors.green;
    if (fraction < 0.8) return Colors.orange;
    return Colors.red;
  }

  Widget _header(ThemeData theme, RuntimeInsightOverlayStrings strings) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.monitor, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              strings.title,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          if (widget.showPauseButton)
            IconButton(
              icon: Icon(_paused ? Icons.play_arrow : Icons.pause, size: 18),
              onPressed: _togglePause,
              tooltip: _paused ? strings.resume : strings.pause,
            ),
          if (widget.showMinimizeButton)
            IconButton(
              icon: const Icon(Icons.remove_circle_outline, size: 18),
              onPressed: _toggleMinimized,
              tooltip: strings.minimize,
            ),
          if (widget.showCloseButton)
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              onPressed: widget.onClose,
              tooltip: strings.close,
            ),
        ],
      ),
    );
  }

  Widget _opacityControl() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          const Icon(Icons.opacity, size: 16),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 2,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              ),
              child: Slider(
                value: _opacity.clamp(0.4, 1.0),
                min: 0.4,
                max: 1.0,
                onChanged: (value) {
                  setState(() {
                    _opacity = value;
                  });
                  _schedulePersist();
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
    required String value,
    String? secondaryValue,
    String? avgValue,
    required List<List<double?>> series,
    required List<Color> colors,
    List<String>? legend,
  }) {
    final strings = widget.strings ?? RuntimeInsightOverlayStrings.english();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Row(
            children: [
              _valueChip(strings.labelCurrent, value),
              if (avgValue != null) _valueChip(strings.labelAverage, avgValue),
              if (secondaryValue != null)
                _valueChip(strings.labelSecondary, secondaryValue),
            ],
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
        color: Colors.black.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text('$label: $value'),
    );
  }
}

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
      canvas.drawLine(Offset(rect.left, dy), Offset(rect.right, dy), gridPaint);
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
