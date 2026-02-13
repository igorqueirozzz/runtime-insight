import 'package:flutter/foundation.dart';

/// A controller for [RuntimeInsightOverlay] that allows changing its state
/// programmatically from anywhere in the app.
///
/// Use the static [instance] for global access, or create a dedicated instance
/// and pass it to the overlay via the `controller` parameter.
///
/// ```dart
/// // Hide the overlay from any screen:
/// RuntimeInsightOverlayController.instance.hide();
///
/// // Minimize from a settings page:
/// RuntimeInsightOverlayController.instance.minimize();
///
/// // Change opacity at runtime:
/// RuntimeInsightOverlayController.instance.opacity = 0.6;
/// ```
class RuntimeInsightOverlayController extends ChangeNotifier {
  /// Global shared instance for convenient static access.
  static final RuntimeInsightOverlayController instance =
      RuntimeInsightOverlayController();

  bool _visible;
  bool _minimized;
  bool _paused;
  double _opacity;

  /// Creates a controller with the given initial values.
  RuntimeInsightOverlayController({
    bool visible = true,
    bool minimized = false,
    bool paused = false,
    double opacity = 0.95,
  })  : _visible = visible,
        _minimized = minimized,
        _paused = paused,
        _opacity = opacity.clamp(0.0, 1.0);

  // ---------------------------------------------------------------------------
  // Visibility
  // ---------------------------------------------------------------------------

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

  /// The overlay background opacity (clamped between 0.0 and 1.0).
  double get opacity => _opacity;

  set opacity(double value) {
    final clamped = value.clamp(0.0, 1.0);
    if (_opacity == clamped) return;
    _opacity = clamped;
    notifyListeners();
  }
}
