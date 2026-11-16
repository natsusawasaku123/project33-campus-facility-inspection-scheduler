import 'dart:convert';

import 'package:campus_facility_inspection_scheduler/secure_api_client.dart';
import 'package:campus_facility_inspection_scheduler/sign_in_dialog.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('insecure or credential-bearing service addresses are rejected', () {
    for (final value in [
      'http://example.test/api',
      'http://localhost:8000/api',
      'https://name:password@example.test/api',
      'https://example.test/api?token=value',
    ]) {
      expect(() => validateApiBaseUrl(value), throwsFormatException);
    }
    expect(validateApiBaseUrl('https://localhost:8443/api').scheme, 'https');
    expect(
      validateApiBaseUrl(
        'http://127.0.0.1:8000/api',
        allowInsecureLoopback: true,
      ).scheme,
      'http',
    );
    expect(
      () => validateApiBaseUrl(
        'http://example.test/api',
        allowInsecureLoopback: true,
      ),
      throwsFormatException,
    );
  });

  test(
    'cross-origin or non-API requests are stopped before sending credentials',
    () async {
      var sent = 0;
      final inner = MockClient((request) async {
        sent++;
        return http.Response('{}', 200);
      });
      addTearDown(inner.close);
      final client = SecureApiClient(
        baseUrl: 'https://localhost:8443/api',
        inner: inner,
      );
      for (final address in [
        'https://untrusted.example/api/user',
        'https://localhost:8443/other',
      ]) {
        await expectLater(
          client.get(
            Uri.parse(address),
            headers: {'Authorization': 'Bearer test-only'},
          ),
          throwsA(isA<http.ClientException>()),
        );
      }
      expect(sent, 0);
    },
  );

  test(
    'expired authenticated requests notify the app and never follow redirects',
    () async {
      var expired = 0;
      final inner = MockClient((request) async {
        expect(request.followRedirects, isFalse);
        return http.Response('{}', 401);
      });
      addTearDown(inner.close);
      final client = SecureApiClient(
        baseUrl: 'https://localhost:8443/api',
        inner: inner,
        onUnauthorized: () => expired++,
      );
      await client.post(Uri.parse('https://localhost:8443/api/auth/login'));
      expect(expired, 0);
      await client.get(
        Uri.parse('https://localhost:8443/api/user'),
        headers: {'Authorization': 'Bearer test-only'},
      );
      expect(expired, 1);
    },
  );

  test('sign-in response needs an approved role and future expiry', () {
    String response(String role, DateTime expiry) => jsonEncode({
      'token': 'test-only',
      'expires_at': expiry.toIso8601String(),
      'user': {'name': 'Demo Inspector', 'role': role},
    });
    expect(
      DemoSession.fromResponse(
        response('inspector', DateTime.now().add(const Duration(hours: 1))),
      ).role,
      'inspector',
    );
    expect(
      () => DemoSession.fromResponse(
        response('administrator', DateTime.now().add(const Duration(hours: 1))),
      ),
      throwsFormatException,
    );
    expect(
      () => DemoSession.fromResponse(
        response(
          'inspector',
          DateTime.now().subtract(const Duration(seconds: 1)),
        ),
      ),
      throwsFormatException,
    );
  });
}
