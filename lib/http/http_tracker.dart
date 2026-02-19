import 'dart:async';
import 'dart:convert';

import 'http_log_storage.dart';
import 'http_request_log.dart';

/// Singleton that collects, aggregates and persists HTTP request logs.
///
/// Use the interceptors ([RuntimeInsightHttpOverrides],
/// [RuntimeInsightHttpClient], [RuntimeInsightDioInterceptor]) or the manual
/// API ([startRequest] / [endRequest]) to feed data.
///
/// ```dart
/// final id = HttpTracker.instance.startRequest('GET', 'https://api.example.com/users');
/// // ... perform request ...
/// HttpTracker.instance.endRequest(id, statusCode: 200, responseBytes: 1024);
/// ```
class HttpTracker {
  /// Global shared instance.
  static final HttpTracker instance = HttpTracker();

  final List<HttpRequestLog> _logs = [];
  final Map<String, HttpRequestLog> _active = {};
  late HttpLogStorage _storage;
  int _maxLogs;
  bool _initialized = false;
  int _idCounter = 0;

  final StreamController<void> _changeController =
      StreamController<void>.broadcast();

  HttpTracker({int maxLogs = 500}) : _maxLogs = maxLogs {
    _storage = HttpLogStorage(maxLogs: maxLogs);
  }

  // ---------------------------------------------------------------------------
  // Configuration
  // ---------------------------------------------------------------------------

  /// Whether HTTP tracking is active. When `false`, [startRequest] and
  /// [endRequest] are no-ops.
  bool enabled = false;

  /// Maximum number of log entries kept in the ring buffer and on disk.
  int get maxLogs => _maxLogs;

  set maxLogs(int value) {
    _maxLogs = value;
    _storage = HttpLogStorage(maxLogs: value);
    _trimBuffer();
  }

  // ---------------------------------------------------------------------------
  // Initialization
  // ---------------------------------------------------------------------------

  /// Loads persisted logs from disk. Called once by
  /// [RuntimeInsight.enableHttpTracking].
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    final persisted = await _storage.loadLogs();
    _logs.addAll(persisted);
    _trimBuffer();
    _notify();
  }

  // ---------------------------------------------------------------------------
  // Tracking API
  // ---------------------------------------------------------------------------

  /// Begins tracking a new HTTP request. Returns a unique [id] that must be
  /// passed to [endRequest] when the response arrives.
  String startRequest(
    String method,
    String url, {
    int? requestBytes,
  }) {
    if (!enabled) return '';
    final id = '_ri_${_idCounter++}';
    final log = HttpRequestLog(
      id: id,
      method: method.toUpperCase(),
      url: url,
      startTime: DateTime.now(),
      requestBytes: requestBytes,
    );
    _active[id] = log;
    _logs.add(log);
    _trimBuffer();
    _notify();
    return id;
  }

  /// Completes a previously started request.
  void endRequest(
    String id, {
    int? statusCode,
    int? responseBytes,
    String? error,
  }) {
    if (!enabled || id.isEmpty) return;
    final log = _active.remove(id);
    if (log == null) return;
    log.endTime = DateTime.now();
    log.statusCode = statusCode;
    log.responseBytes = responseBytes;
    log.error = error;
    log.status = (error != null || (statusCode != null && statusCode >= 400))
        ? HttpRequestStatus.failed
        : HttpRequestStatus.completed;
    _storage.enqueue(log);
    _notify();
  }

  // ---------------------------------------------------------------------------
  // Stats
  // ---------------------------------------------------------------------------

  /// Number of in-flight requests.
  int get activeCount => _active.length;

  /// Total number of logged requests (active + completed + failed).
  int get totalCount => _logs.length;

  /// Number of completed requests (status 1xx–3xx).
  int get completedCount =>
      _logs.where((l) => l.status == HttpRequestStatus.completed).length;

  /// Number of failed requests (4xx, 5xx, or exception).
  int get failedCount =>
      _logs.where((l) => l.status == HttpRequestStatus.failed).length;

  /// Average response time in milliseconds for completed requests.
  double get avgResponseTimeMs {
    final finished =
        _logs.where((l) => l.status != HttpRequestStatus.pending).toList();
    if (finished.isEmpty) return 0;
    final total =
        finished.fold<int>(0, (sum, l) => sum + (l.durationMs ?? 0));
    return total / finished.length;
  }

  /// Error rate as a fraction (0.0 – 1.0).
  double get errorRate {
    final finished =
        _logs.where((l) => l.status != HttpRequestStatus.pending).length;
    if (finished == 0) return 0;
    return failedCount / finished;
  }

  // ---------------------------------------------------------------------------
  // Logs access
  // ---------------------------------------------------------------------------

  /// A broadcast stream that fires whenever logs change (new request,
  /// completion, clear, etc.). Useful for rebuilding UI.
  Stream<void> get onChange => _changeController.stream;

  /// All logged requests, most recent first.
  List<HttpRequestLog> get logs => _logs.reversed.toList();

  /// Exports all logs as a pretty-printed JSON string.
  String exportLogsAsJson() {
    final list = _logs.map((l) => l.toJson()).toList();
    return const JsonEncoder.withIndent('  ').convert(list);
  }

  /// Clears all in-memory logs and the persisted file.
  Future<void> clearLogs() async {
    _logs.clear();
    _active.clear();
    _idCounter = 0;
    await _storage.clear();
    _notify();
  }

  /// Flushes pending writes to disk.
  Future<void> flush() => _storage.flush();

  /// Exports the NDJSON log file to [path].
  Future<void> exportFile(String path) => _storage.export(path);

  // ---------------------------------------------------------------------------
  // Internals
  // ---------------------------------------------------------------------------

  void _trimBuffer() {
    while (_logs.length > _maxLogs) {
      final removed = _logs.removeAt(0);
      _active.remove(removed.id);
    }
  }

  void _notify() {
    if (!_changeController.isClosed) {
      _changeController.add(null);
    }
  }

  /// Releases resources.
  void dispose() {
    _storage.dispose();
    _changeController.close();
  }
}
