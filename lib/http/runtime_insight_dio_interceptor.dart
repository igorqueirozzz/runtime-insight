import 'package:dio/dio.dart';

import 'http_tracker.dart';

/// A [Dio] interceptor that reports every request to [HttpTracker].
///
/// ```dart
/// final dio = Dio();
/// dio.interceptors.add(RuntimeInsightDioInterceptor());
/// ```
class RuntimeInsightDioInterceptor extends Interceptor {
  /// Extra key used to pass the tracking id between callbacks.
  static const _extraKey = '_ri_track_id';

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final id = HttpTracker.instance.startRequest(
      options.method,
      options.uri.toString(),
      requestBytes: options.data is List<int>
          ? (options.data as List<int>).length
          : null,
    );
    options.extra[_extraKey] = id;
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    final id = response.requestOptions.extra[_extraKey] as String?;
    if (id != null && id.isNotEmpty) {
      final bytes = response.data is List<int>
          ? (response.data as List<int>).length
          : null;
      HttpTracker.instance.endRequest(
        id,
        statusCode: response.statusCode,
        responseBytes: bytes,
      );
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final id = err.requestOptions.extra[_extraKey] as String?;
    if (id != null && id.isNotEmpty) {
      HttpTracker.instance.endRequest(
        id,
        statusCode: err.response?.statusCode,
        error: err.message ?? err.type.name,
      );
    }
    handler.next(err);
  }
}
