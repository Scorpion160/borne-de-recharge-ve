import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vescope_supervisor/core/network/mobile_session.dart';

void main() {
  tearDown(MobileSession.clear);
  test('successful login sends Basic auth without following redirects', () async {
    final expected = 'Basic ${base64Encode(utf8.encode('test:p:a:ss'))}';
    await MobileSession.login('test', 'p:a:ss', client: MockClient((request) async {
      expect(request.url.scheme, 'https');
      expect(request.followRedirects, isFalse);
      expect(request.headers['Authorization'], expected);
      return http.Response('{"service":"vescope-hub","ok":true}', 200);
    }));
    expect(MobileSession.headers['Authorization'], expected);
    MobileSession.clear();
    expect(MobileSession.headers, isEmpty);
  });
  for (final code in [401, 403, 302, 500]) {
    test('HTTP $code never installs credentials', () async {
      await expectLater(MobileSession.login('test', 'bad',
        client: MockClient((_) async => http.Response('refused', code))),
        throwsFormatException);
      expect(MobileSession.headers, isEmpty);
    });
  }
  test('HTML fallback is rejected', () async {
    await expectLater(MobileSession.login('test', 'password',
      client: MockClient((_) async => http.Response('<html></html>', 200))),
      throwsFormatException);
    expect(MobileSession.headers, isEmpty);
  });
  test('colon is rejected in username', () {
    expect(() => MobileSession.encodeCredentials('user:other', 'password'),
      throwsFormatException);
  });
}
