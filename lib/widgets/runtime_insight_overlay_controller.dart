import 'dart:async';

import 'package:flutter/material.dart';

import '../monitoring/app_resource_monitoring_config.dart';
import '../monitoring/app_resource_snapshot.dart';
import 'runtime_insight_overlay_strings.dart';

/// A controller for [RuntimeInsightOverlay] that allows changing its state
/// and configuration programmatically from anywhere in the app.
///
/// Use the static [instance] for global access, or create a dedicated instance
/// and pass it to the overlay via the `controller` parameter.
///
/// ### State control
///
/// ```dart
/// final ctrl = RuntimeInsightOverlayController.instance;
/// ctrl.hide();
/// ctrl.minimize();
/// ctrl.pause();
/// ctrl.opacity = 0.6;
/// ```
///
/// ### Configuration override
///
/// Any property set on the controller overrides the corresponding widget
/// constructor value. Leaving it `null` keeps the widget default.
///
/// ```dart
/// ctrl.width = 320;
/// ctrl.showPauseButton = false;
/// ctrl.strings = RuntimeInsightOverlayStrings.english();
/// ```
///
/// ### Stream access
///
/// ```dart
/// ctrl.snapshotStream.listen((snapshot) {
///   print('CPU: ${snapshot.cpuPercent}%');
/// });
///
/// final last = ctrl.latestSnapshot;
/// final all  = ctrl.history;
/// ```
class RuntimeInsightOverlayController extends ChangeNotifier {
  /// Global shared instance for convenient static access.
  static final RuntimeInsightOverlayController instance =
      RuntimeInsightOverlayController();

  // ---------------------------------------------------------------------------
  // Constructor
  // ---------------------------------------------------------------------------

  /// Creates a controller with the given initial values.
  ///
  /// All configuration properties default to `null`, meaning the overlay
  /// widget's own constructor values are used.
  RuntimeInsightOverlayController({
    bool visible = true,
    bool minimized = false,
    bool paused = false,
    double opacity = 0.95,
    double? width,
    double? height,
    int? maxPoints,
    double? minimizedSize,
    EdgeInsets? margin,
    Color? backgroundColor,
    bool? showCloseButton,
    bool? showPauseButton,
    bool? showOpacitySlider,
    bool? showMinimizeButton,
    bool? allowDrag,
    RuntimeInsightOverlayStrings? strings,
    VoidCallback? onClose,
    AppResourceMonitoringConfig? monitoringConfig,
  })  : _visible = visible,
        _minimized = minimized,
        _paused = paused,
        _opacity = opacity.clamp(0.0, 1.0),
        _width = width,
        _height = height,
        _maxPoints = maxPoints,
        _minimizedSize = minimizedSize,
        _margin = margin,
        _backgroundColor = backgroundColor,
        _showCloseButton = showCloseButton,
        _showPauseButton = showPauseButton,
        _showOpacitySlider = showOpacitySlider,
        _showMinimizeButton = showMinimizeButton,
        _allowDrag = allowDrag,
        _strings = strings,
        _onClose = onClose,
        _monitoringConfig = monitoringConfig;

  // ===========================================================================
  //  STATE
  // ===========================================================================

  // ---------------------------------------------------------------------------
  // Visibility
  // ---------------------------------------------------------------------------

  bool _visible;

  /// Whether the overlay is visible.
  bool get visible => _visible;

  set visible(bool value) {
    if (_visible == value) return;
    _visible = value;
    notifyListeners();
  }

  /// Shows the overlay.
  void show() => visible = true;

  /// Hides the overlay.
  void hide() => visible = false;

  /// Toggles overlay visibility.
  void toggleVisibility() => visible = !_visible;

  // ---------------------------------------------------------------------------
  // Minimized
  // ---------------------------------------------------------------------------

  bool _minimized;

  /// Whether the overlay is in minimized (bubble) mode.
  bool get minimized => _minimized;

  set minimized(bool value) {
    if (_minimized == value) return;
    _minimized = value;
    notifyListeners();
  }

  /// Minimizes the overlay to the CPU bubble.
  void minimize() => minimized = true;

  /// Expands the overlay to the full panel.
  void expand() => minimized = false;

  /// Toggles between minimized and expanded.
  void toggleMinimized() => minimized = !_minimized;

  // ---------------------------------------------------------------------------
  // Paused
  // ---------------------------------------------------------------------------

  bool _paused;

  /// Whether the monitoring data feed is paused.
  bool get paused => _paused;

  set paused(bool value) {
    if (_paused == value) return;
    _paused = value;
    notifyListeners();
  }

  /// Pauses the data feed.
  void pause() => paused = true;

  /// Resumes the data feed.
  void resume() => paused = false;

  /// Toggles between paused and running.
  void togglePause() => paused = !_paused;

  // ---------------------------------------------------------------------------
  // Opacity
  // ---------------------------------------------------------------------------

  double _opacity;

  /// The overlay background opacity (clamped between 0.0 and 1.0).
  double get opacity => _opacity;

  set opacity(double value) {
    final clamped = value.clamp(0.0, 1.0);
    if (_opacity == clamped) return;
    _opacity = clamped;
    notifyListeners();
  }

  // ===========================================================================
  //  CONFIGURATION (nullable = use widget default)
  // ===========================================================================

  // ---------------------------------------------------------------------------
  // Dimensions
  // ---------------------------------------------------------------------------

  double? _width;

  /// Overlay panel width. `null` keeps the widget default (280).
  double? get width => _width;

  set width(double? value) {
    if (_width == value) return;
    _width = value;
    notifyListeners();
  }

  double? _height;

  /// Overlay panel height. `null` keeps the widget default (300).
  double? get height => _height;

  set height(double? value) {
    if (_height == value) return;
    _height = value;
    notifyListeners();
  }

  int? _maxPoints;

  /// Maximum data-points shown in the charts. `null` keeps the widget default (60).
  int? get maxPoints => _maxPoints;

  set maxPoints(int? value) {
    if (_maxPoints == value) return;
    _maxPoints = value;
    notifyListeners();
  }

  double? _minimizedSize;

  /// Diameter of the minimized circle bubble. `null` keeps the widget default (56).
  double? get minimizedSize => _minimizedSize;

  set minimizedSize(double? value) {
    if (_minimizedSize == value) return;
    _minimizedSize = value;
    notifyListeners();
  }

  EdgeInsets? _margin;

  /// Margin around the overlay. `null` keeps the widget default (12 all).
  EdgeInsets? get margin => _margin;

  set margin(EdgeInsets? value) {
    if (_margin == value) return;
    _margin = value;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Appearance
  // ---------------------------------------------------------------------------

  Color? _backgroundColor;

  /// Background colour override for the overlay panel.
  Color? get backgroundColor => _backgroundColor;

  set backgroundColor(Color? value) {
    if (_backgroundColor == value) return;
    _backgroundColor = value;
    notifyListeners();
  }

  RuntimeInsightOverlayStrings? _strings;

  /// Localised strings for the overlay UI.
  RuntimeInsightOverlayStrings? get strings => _strings;

  set strings(RuntimeInsightOverlayStrings? value) {
    if (_strings == value) return;
    _strings = value;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Feature toggles
  // ---------------------------------------------------------------------------

  bool? _showCloseButton;

  /// Whether to show the close button. `null` keeps the widget default (true).
  bool? get showCloseButton => _showCloseButton;

  set showCloseButton(bool? value) {
    if (_showCloseButton == value) return;
    _showCloseButton = value;
    notifyListeners();
  }

  bool? _showPauseButton;

  /// Whether to show the pause/resume button. `null` keeps the widget default (true).
  bool? get showPauseButton => _showPauseButton;

  set showPauseButton(bool? value) {
    if (_showPauseButton == value) return;
    _showPauseButton = value;
    notifyListeners();
  }

  bool? _showOpacitySlider;

  /// Whether to show the opacity slider. `null` keeps the widget default (true).
  bool? get showOpacitySlider => _showOpacitySlider;

  set showOpacitySlider(bool? value) {
    if (_showOpacitySlider == value) return;
    _showOpacitySlider = value;
    notifyListeners();
  }

  bool? _showMinimizeButton;

  /// Whether to show the minimize button. `null` keeps the widget default (true).
  bool? get showMinimizeButton => _showMinimizeButton;

  set showMinimizeButton(bool? value) {
    if (_showMinimizeButton == value) return;
    _showMinimizeButton = value;
    notifyListeners();
  }

  bool? _allowDrag;

  /// Whether the overlay can be dragged. `null` keeps the widget default (true).
  bool? get allowDrag => _allowDrag;

  set allowDrag(bool? value) {
    if (_allowDrag == value) return;
    _allowDrag = value;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Callbacks
  // ---------------------------------------------------------------------------

  VoidCallback? _onClose;

  /// Called when the close button is tapped. Overrides the widget callback.
  VoidCallback? get onClose => _onClose;

  set onClose(VoidCallback? value) {
    if (_onClose == value) return;
    _onClose = value;
    notifyListeners();
  }

  // ===========================================================================
  //  MONITORING CONFIGURATION
  // ===========================================================================

  AppResourceMonitoringConfig? _monitoringConfig;

  /// Monitoring configuration override. When set, the overlay restarts
  /// monitoring with this config.
  AppResourceMonitoringConfig? get monitoringConfig => _monitoringConfig;

  set monitoringConfig(AppResourceMonitoringConfig? value) {
    if (_monitoringConfig == value) return;
    _monitoringConfig = value;
    notifyListeners();
  }

  // ===========================================================================
  //  STREAM / SNAPSHOT ACCESS
  // ===========================================================================

  final StreamController<AppResourceSnapshot> _snapshotController =
      StreamController<AppResourceSnapshot>.broadcast();

  final List<AppResourceSnapshot> _history = [];
  AppResourceSnapshot? _latestSnapshot;

  /// A broadcast stream of [AppResourceSnapshot] events, fed by the overlay.
  ///
  /// Listen to this from anywhere to react to new monitoring data:
  /// ```dart
  /// RuntimeInsightOverlayController.instance.snapshotStream.listen((s) {
  ///   print('CPU: ${s.cpuPercent}');
  /// });
  /// ```
  Stream<AppResourceSnapshot> get snapshotStream => _snapshotController.stream;

  /// The most recent [AppResourceSnapshot], or `null` if none arrived yet.
  AppResourceSnapshot? get latestSnapshot => _latestSnapshot;

  /// An unmodifiable copy of the snapshot history currently held by the overlay.
  List<AppResourceSnapshot> get history => List.unmodifiable(_history);

  /// Pushes a new snapshot into the controller.
  ///
  /// Called internally by the overlay widget — you normally don't need this.
  void addSnapshot(AppResourceSnapshot snapshot, {required int maxPoints}) {
    _latestSnapshot = snapshot;
    _history.add(snapshot);
    while (_history.length > maxPoints) {
      _history.removeAt(0);
    }
    if (!_snapshotController.isClosed) {
      _snapshotController.add(snapshot);
    }
  }

  /// Clears the snapshot history. Called internally when the overlay restarts
  /// monitoring.
  void clearHistory() {
    _history.clear();
    _latestSnapshot = null;
  }

  // ---------------------------------------------------------------------------
  // Dispose
  // ---------------------------------------------------------------------------

  @override
  void dispose() {
    _snapshotController.close();
    super.dispose();
  }
}
