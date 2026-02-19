import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'http_request_log.dart';

/// Asynchronous NDJSON file storage for HTTP request logs.
///
/// Writes are batched and flushed periodically to avoid blocking the main
/// thread. The file is stored in the system temp directory under
/// `runtime_insight/http_logs.ndjson`.
class HttpLogStorage {
  final int maxLogs;
  final List<HttpRequestLog> _pendingWrites = [];
  Timer? _flushTimer;
  bool _loading = false;

  late final Directory _dir;
  late final File _file;

  HttpLogStorage({this.maxLogs = 500}) {
    _dir = Directory('${Directory.systemTemp.path}/runtime_insight');
    _file = File('${_dir.path}/http_logs.ndjson');
  }

  /// Loads persisted logs from the NDJSON file.
  Future<List<HttpRequestLog>> loadLogs() async {
    _loading = true;
    try {
      if (!await _file.exists()) return [];
      final content = await _file.readAsString();
      if (content.trim().isEmpty) return [];
      final lines = const LineSplitter().convert(content);
      final logs = <HttpRequestLog>[];
      for (final line in lines) {
        if (line.trim().isEmpty) continue;
        try {
          logs.add(HttpRequestLog.fromJson(
            json.decode(line) as Map<String, dynamic>,
          ));
        } catch (_) {
          // Skip malformed lines.
        }
      }
      // Keep only the most recent entries.
      if (logs.length > maxLogs) {
        return logs.sublist(logs.length - maxLogs);
      }
      return logs;
    } catch (_) {
      return [];
    } finally {
      _loading = false;
    }
  }

  /// Enqueues a log for async writing. Starts a flush timer if not running.
  void enqueue(HttpRequestLog log) {
    if (_loading) return;
    _pendingWrites.add(log);
    if (_pendingWrites.length >= 50) {
      flush();
    } else {
      _flushTimer ??= Timer(const Duration(seconds: 5), flush);
    }
  }

  /// Writes all pending logs to the NDJSON file.
  Future<void> flush() async {
    _flushTimer?.cancel();
    _flushTimer = null;
    if (_pendingWrites.isEmpty) return;
    final batch = List<HttpRequestLog>.from(_pendingWrites);
    _pendingWrites.clear();
    try {
      if (!await _dir.exists()) {
        await _dir.create(recursive: true);
      }
      final buffer = StringBuffer();
      for (final log in batch) {
        buffer.writeln(json.encode(log.toJson()));
      }
      await _file.writeAsString(
        buffer.toString(),
        mode: FileMode.append,
        flush: true,
      );
      await _trimIfNeeded();
    } catch (_) {
      // Silently ignore write errors to avoid impacting app performance.
    }
  }

  /// Rewrites the file keeping only the last [maxLogs] entries.
  Future<void> _trimIfNeeded() async {
    try {
      if (!await _file.exists()) return;
      final lines = await _file.readAsLines();
      if (lines.length <= maxLogs) return;
      final trimmed = lines.sublist(lines.length - maxLogs);
      await _file.writeAsString('${trimmed.join('\n')}\n');
    } catch (_) {
      // Ignore trim errors.
    }
  }

  /// Deletes the log file.
  Future<void> clear() async {
    _pendingWrites.clear();
    _flushTimer?.cancel();
    _flushTimer = null;
    try {
      if (await _file.exists()) {
        await _file.delete();
      }
    } catch (_) {
      // Ignore delete errors.
    }
  }

  /// Copies the log file to [path].
  Future<void> export(String path) async {
    await flush();
    try {
      if (await _file.exists()) {
        await _file.copy(path);
      }
    } catch (_) {
      // Ignore copy errors.
    }
  }

  /// Cancels any pending flush timer.
  void dispose() {
    _flushTimer?.cancel();
    _flushTimer = null;
  }
}
