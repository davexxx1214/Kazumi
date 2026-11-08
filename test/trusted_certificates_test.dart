import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/request/core/network_config.dart';
import 'package:kazumi/services/network/trusted_certificates.dart';

void main() {
  _NetworkTestBinding();

  setUpAll(TrustedCertificates.initialize);

  test('packaged root matches the verified official certificate', () async {
    final pem = await rootBundle.loadString(
      TrustedCertificates.sslComRootAsset,
    );
    final der = base64.decode(
      pem
          .replaceAll('-----BEGIN CERTIFICATE-----', '')
          .replaceAll('-----END CERTIFICATE-----', '')
          .replaceAll(RegExp(r'\s'), ''),
    );
    expect(
      sha256.convert(der).toString(),
      '8faf7d2e2cb4709bb8e0b33666bf75a5dd45b5de480f8ea8d4bfe6bebc17f2ed',
    );
  });

  test(
    'initialization reuses an app context without mutating global trust',
    () async {
      final context = TrustedCertificates.context;
      await TrustedCertificates.initialize();
      expect(TrustedCertificates.context, same(context));
      expect(context, isNot(same(SecurityContext.defaultContext)));
    },
  );

  test('Android WebView packages the same root with system trust retained', () {
    final pem = File(
      'android/app/src/main/res/raw/sslcom_tls_root_2022_rsa.pem',
    ).readAsStringSync();
    final der = base64.decode(
      pem
          .replaceAll('-----BEGIN CERTIFICATE-----', '')
          .replaceAll('-----END CERTIFICATE-----', '')
          .replaceAll(RegExp(r'\s'), ''),
    );
    expect(
      sha256.convert(der).toString(),
      '8faf7d2e2cb4709bb8e0b33666bf75a5dd45b5de480f8ea8d4bfe6bebc17f2ed',
    );
    final config = File(
      'android/app/src/main/res/xml/network_security_config.xml',
    ).readAsStringSync();
    expect(config, contains('<certificates src="system" />'));
    expect(
      config,
      contains('<certificates src="@raw/sslcom_tls_root_2022_rsa" />'),
    );
    expect(
      File('android/app/src/main/AndroidManifest.xml').readAsStringSync(),
      contains('android:networkSecurityConfig="@xml/network_security_config"'),
    );
  });

  // Opt in to live endpoint checks; regular tests remain independent of AGE
  // availability. Run with --dart-define=RUN_TLS_NETWORK_TESTS=true.
  const networkTests = bool.fromEnvironment('RUN_TLS_NETWORK_TESTS');
  for (final publicTargetsOnly in [false, true]) {
    final path = publicTargetsOnly ? 'public-target TLS' : 'standard TLS';

    test('$path trusts AGE with the packaged root', () async {
      final client =
          const NetworkConfig(
              enableLog: false,
            ).createHttpClient(publicTargetsOnly: publicTargetsOnly)
            ..connectionTimeout = const Duration(seconds: 15)
            ..findProxy = (_) => 'DIRECT';
      addTearDown(() => client.close(force: true));
      final request = await client.getUrl(
        Uri.https('www.agedm.io', '/search', {'query': '学生会也有洞！'}),
      );
      request.headers.set(HttpHeaders.userAgentHeader, 'Mozilla/5.0');
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      expect(response.statusCode, HttpStatus.ok);
      expect(body, contains('/detail/20260293'));
    }, skip: !networkTests);

    test('$path still rejects an untrusted certificate', () async {
      final client =
          const NetworkConfig(
              enableLog: false,
            ).createHttpClient(publicTargetsOnly: publicTargetsOnly)
            ..connectionTimeout = const Duration(seconds: 15)
            ..findProxy = (_) => 'DIRECT';
      addTearDown(() => client.close(force: true));
      await expectLater(
        client.getUrl(Uri.parse('https://self-signed.badssl.com/')),
        throwsA(isA<HandshakeException>()),
      );
    }, skip: !networkTests);
  }
}

class _NetworkTestBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get overrideHttpClient => false;
}
