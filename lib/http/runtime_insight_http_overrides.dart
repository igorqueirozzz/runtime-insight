import 'dart:convert';
import 'dart:io';

import 'http_tracker.dart';

/// [HttpOverrides] that automatically tracks every HTTP request made by the
/// application through `dart:io`'s [HttpClient].
///
/// Activate via [RuntimeInsight.enableHttpTracking] or manually:
///
/// ```dart
/// HttpOverrides.global = RuntimeInsightHttpOverrides(HttpOverrides.current);
/// ```
///
/// Both `package:http` and `dio` use [HttpClient] under the hood, so this
/// interceptor captures traffic from most Flutter HTTP libraries.
class RuntimeInsightHttpOverrides extends HttpOverrides {
  final HttpOverrides? _previous;

  RuntimeInsightHttpOverrides([this._previous]);

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final inner = _previous?.createHttpClient(context) ??
        super.createHttpClient(context);
    return _TrackedHttpClient(inner);
  }

  @override
  String findProxyFromEnvironment(Uri url, Map<String, String>? environment) {
    return _previous?.findProxyFromEnvironment(url, environment) ??
        super.findProxyFromEnvironment(url, environment);
  }
}

/// Wrapper around [HttpClient] that reports requests to [HttpTracker].
class _TrackedHttpClient implements HttpClient {
  final HttpClient _inner;

  _TrackedHttpClient(this._inner);

  // Intercept open() which is the single entry point for all requests.
  @override
  Future<HttpClientRequest> open(
    String method,
    String host,
    int port,
    String path,
  ) async {
    final uri = Uri(scheme: 'http', host: host, port: port, path: path);
    final request = await _inner.open(method, host, port, path);
    return _TrackedRequest(request, method, uri.toString());
  }

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    final request = await _inner.openUrl(method, url);
    return _TrackedRequest(request, method, url.toString());
  }

  @override
  Future<HttpClientRequest> get(String host, int port, String path) =>
      open('GET', host, port, path);

  @override
  Future<HttpClientRequest> getUrl(Uri url) => openUrl('GET', url);

  @override
  Future<HttpClientRequest> post(String host, int port, String path) =>
      open('POST', host, port, path);

  @override
  Future<HttpClientRequest> postUrl(Uri url) => openUrl('POST', url);

  @override
  Future<HttpClientRequest> put(String host, int port, String path) =>
      open('PUT', host, port, path);

  @override
  Future<HttpClientRequest> putUrl(Uri url) => openUrl('PUT', url);

  @override
  Future<HttpClientRequest> delete(String host, int port, String path) =>
      open('DELETE', host, port, path);

  @override
  Future<HttpClientRequest> deleteUrl(Uri url) => openUrl('DELETE', url);

  @override
  Future<HttpClientRequest> patch(String host, int port, String path) =>
      open('PATCH', host, port, path);

  @override
  Future<HttpClientRequest> patchUrl(Uri url) => openUrl('PATCH', url);

  @override
  Future<HttpClientRequest> head(String host, int port, String path) =>
      open('HEAD', host, port, path);

  @override
  Future<HttpClientRequest> headUrl(Uri url) => openUrl('HEAD', url);

  // --- Delegate all other members ---

  @override
  set autoUncompress(bool value) => _inner.autoUncompress = value;

  @override
  bool get autoUncompress => _inner.autoUncompress;

  @override
  set connectionTimeout(Duration? value) => _inner.connectionTimeout = value;

  @override
  Duration? get connectionTimeout => _inner.connectionTimeout;

  @override
  set idleTimeout(Duration value) => _inner.idleTimeout = value;

  @override
  Duration get idleTimeout => _inner.idleTimeout;

  @override
  set maxConnectionsPerHost(int? value) =>
      _inner.maxConnectionsPerHost = value;

  @override
  int? get maxConnectionsPerHost => _inner.maxConnectionsPerHost;

  @override
  set userAgent(String? value) => _inner.userAgent = value;

  @override
  String? get userAgent => _inner.userAgent;

  @override
  set authenticate(
    Future<bool> Function(Uri url, String scheme, String? realm)? f,
  ) =>
      _inner.authenticate = f;

  @override
  set authenticateProxy(
    Future<bool> Function(
            String host, int port, String scheme, String? realm)?
        f,
  ) =>
      _inner.authenticateProxy = f;

  @override
  set badCertificateCallback(
    bool Function(X509Certificate cert, String host, int port)? callback,
  ) =>
      _inner.badCertificateCallback = callback;

  @override
  set connectionFactory(
    Future<ConnectionTask<Socket>> Function(
            Uri url, String? proxyHost, int? proxyPort)?
        f,
  ) =>
      _inner.connectionFactory = f;

  @override
  set findProxy(String Function(Uri url)? f) => _inner.findProxy = f;

  @override
  set keyLog(Function(String line)? callback) => _inner.keyLog = callback;

  @override
  void addCredentials(
    Uri url,
    String realm,
    HttpClientCredentials credentials,
  ) =>
      _inner.addCredentials(url, realm, credentials);

  @override
  void addProxyCredentials(
    String host,
    int port,
    String realm,
    HttpClientCredentials credentials,
  ) =>
      _inner.addProxyCredentials(host, port, realm, credentials);

  @override
  void close({bool force = false}) => _inner.close(force: force);
}

/// Wrapper around [HttpClientRequest] that tracks the response.
class _TrackedRequest implements HttpClientRequest {
  final HttpClientRequest _inner;
  final String _trackId;

  _TrackedRequest(this._inner, String method, String url)
      : _trackId = HttpTracker.instance.startRequest(method, url);

  @override
  Future<HttpClientResponse> close() async {
    try {
      final response = await _inner.close();
      HttpTracker.instance.endRequest(
        _trackId,
        statusCode: response.statusCode,
        responseBytes: response.contentLength >= 0
            ? response.contentLength
            : null,
      );
      return response;
    } catch (e) {
      HttpTracker.instance.endRequest(_trackId, error: e.toString());
      rethrow;
    }
  }

  // --- Delegate all other members ---

  @override
  bool get bufferOutput => _inner.bufferOutput;

  @override
  set bufferOutput(bool value) => _inner.bufferOutput = value;

  @override
  int get contentLength => _inner.contentLength;

  @override
  set contentLength(int value) => _inner.contentLength = value;

  @override
  Encoding get encoding => _inner.encoding;

  @override
  set encoding(Encoding value) => _inner.encoding = value;

  @override
  bool get followRedirects => _inner.followRedirects;

  @override
  set followRedirects(bool value) => _inner.followRedirects = value;

  @override
  int get maxRedirects => _inner.maxRedirects;

  @override
  set maxRedirects(int value) => _inner.maxRedirects = value;

  @override
  bool get persistentConnection => _inner.persistentConnection;

  @override
  set persistentConnection(bool value) =>
      _inner.persistentConnection = value;

  @override
  HttpHeaders get headers => _inner.headers;

  @override
  HttpConnectionInfo? get connectionInfo => _inner.connectionInfo;

  @override
  List<Cookie> get cookies => _inner.cookies;

  @override
  Future<HttpClientResponse> get done => _inner.done;

  @override
  String get method => _inner.method;

  @override
  Uri get uri => _inner.uri;

  @override
  void abort([Object? exception, StackTrace? stackTrace]) =>
      _inner.abort(exception, stackTrace);

  @override
  void add(List<int> data) => _inner.add(data);

  @override
  void addError(Object error, [StackTrace? stackTrace]) =>
      _inner.addError(error, stackTrace);

  @override
  Future<dynamic> addStream(Stream<List<int>> stream) =>
      _inner.addStream(stream);

  @override
  Future<dynamic> flush() => _inner.flush();

  @override
  void write(Object? object) => _inner.write(object);

  @override
  void writeAll(Iterable<dynamic> objects, [String separator = '']) =>
      _inner.writeAll(objects, separator);

  @override
  void writeCharCode(int charCode) => _inner.writeCharCode(charCode);

  @override
  void writeln([Object? object = '']) => _inner.writeln(object);
}
