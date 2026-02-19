import 'package:http/http.dart' as http;

import 'http_tracker.dart';

/// A wrapper around [http.BaseClient] that reports every request to
/// [HttpTracker].
///
/// ```dart
/// final client = RuntimeInsightHttpClient(http.Client());
/// final response = await client.get(Uri.parse('https://example.com'));
/// ```
class RuntimeInsightHttpClient extends http.BaseClient {
  final http.Client _inner;

  /// Creates a tracked HTTP client wrapping [inner].
  RuntimeInsightHttpClient(this._inner);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final tracker = HttpTracker.instance;
    final id = tracker.startRequest(
      request.method,
      request.url.toString(),
      requestBytes: request.contentLength,
    );
    try {
      final response = await _inner.send(request);
      tracker.endRequest(
        id,
        statusCode: response.statusCode,
        responseBytes:
            response.contentLength != null && response.contentLength! >= 0
                ? response.contentLength
                : null,
      );
      return response;
    } catch (e) {
      tracker.endRequest(id, error: e.toString());
      rethrow;
    }
  }

  @override
  void close() {
    _inner.close();
    super.close();
  }
}
