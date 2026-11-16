import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

Uri validateApiBaseUrl(String value, {bool allowInsecureLoopback = false}) {
  final uri = Uri.tryParse(value);
  if (uri == null ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      uri.hasQuery ||
      uri.hasFragment ||
      !uri.path.endsWith('/api')) {
    throw const FormatException(
      'The service address is not configured correctly.',
    );
  }
  final localDevelopment =
      !kReleaseMode &&
      allowInsecureLoopback &&
      uri.scheme == 'http' &&
      const ['localhost', '127.0.0.1', '::1'].contains(uri.host);
  if (uri.scheme != 'https' && !localDevelopment) {
    throw const FormatException('A secure HTTPS service address is required.');
  }
  return uri;
}

class SecureApiClient extends http.BaseClient {
  SecureApiClient({
    required String baseUrl,
    http.Client? inner,
    this.onUnauthorized,
    bool allowInsecureLoopback = false,
  }) : baseUri = validateApiBaseUrl(
         baseUrl,
         allowInsecureLoopback: allowInsecureLoopback,
       ),
       _inner = inner ?? http.Client(),
       _ownsInner = inner == null;

  final Uri baseUri;
  final http.Client _inner;
  final bool _ownsInner;
  final VoidCallback? onUnauthorized;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (request.url.origin != baseUri.origin ||
        !request.url.path.startsWith('${baseUri.path}/')) {
      throw http.ClientException(
        'The request uses an unexpected service address.',
      );
    }
    request.followRedirects = false;
    final response = await _inner.send(request);
    if (response.statusCode == 401 &&
        request.headers.keys.any(
          (key) => key.toLowerCase() == 'authorization',
        )) {
      onUnauthorized?.call();
    }
    return response;
  }

  @override
  void close() {
    if (_ownsInner) _inner.close();
    super.close();
  }
}
