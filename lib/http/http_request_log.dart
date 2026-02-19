/// Status of an HTTP request being tracked.
enum HttpRequestStatus {
  /// Request is in-flight.
  pending,

  /// Request completed successfully (any 1xx–3xx status code).
  completed,

  /// Request failed (4xx, 5xx, or exception).
  failed,
}

/// A single HTTP request/response log entry.
class HttpRequestLog {
  /// Unique identifier for this request.
  final String id;

  /// HTTP method (GET, POST, PUT, DELETE, etc.).
  final String method;

  /// Full request URL.
  final String url;

  /// HTTP status code of the response, or `null` while pending.
  int? statusCode;

  /// Current status of this request.
  HttpRequestStatus status;

  /// When the request was initiated.
  final DateTime startTime;

  /// When the response was received, or `null` while pending.
  DateTime? endTime;

  /// Size of the request body in bytes, if known.
  final int? requestBytes;

  /// Size of the response body in bytes, if known.
  int? responseBytes;

  /// Error message if the request failed.
  String? error;

  HttpRequestLog({
    required this.id,
    required this.method,
    required this.url,
    this.statusCode,
    this.status = HttpRequestStatus.pending,
    required this.startTime,
    this.endTime,
    this.requestBytes,
    this.responseBytes,
    this.error,
  });

  /// Elapsed duration, or `null` if still pending.
  Duration? get duration => endTime?.difference(startTime);

  /// Elapsed milliseconds, or `null` if still pending.
  int? get durationMs => duration?.inMilliseconds;

  Map<String, dynamic> toJson() => {
        'id': id,
        'method': method,
        'url': url,
        if (statusCode != null) 'statusCode': statusCode,
        'status': status.name,
        'startTime': startTime.millisecondsSinceEpoch,
        if (endTime != null) 'endTime': endTime!.millisecondsSinceEpoch,
        if (requestBytes != null) 'requestBytes': requestBytes,
        if (responseBytes != null) 'responseBytes': responseBytes,
        if (error != null) 'error': error,
      };

  factory HttpRequestLog.fromJson(Map<String, dynamic> json) {
    return HttpRequestLog(
      id: json['id'] as String,
      method: json['method'] as String,
      url: json['url'] as String,
      statusCode: json['statusCode'] as int?,
      status: HttpRequestStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => HttpRequestStatus.pending,
      ),
      startTime:
          DateTime.fromMillisecondsSinceEpoch(json['startTime'] as int),
      endTime: json['endTime'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['endTime'] as int)
          : null,
      requestBytes: json['requestBytes'] as int?,
      responseBytes: json['responseBytes'] as int?,
      error: json['error'] as String?,
    );
  }
}
