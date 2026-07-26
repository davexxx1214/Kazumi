import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/request/config/api_endpoints.dart';
import 'package:kazumi/request/core/network_config.dart';
import 'package:kazumi/services/network/public_network_policy.dart';

void main() {
  test('allows public IP addresses', () {
    expect(
      PublicNetworkPolicy.isPublic(InternetAddress('8.8.8.8')),
      isTrue,
    );
    expect(
      PublicNetworkPolicy.isPublic(
        InternetAddress('2606:4700:4700::1111'),
      ),
      isTrue,
    );
  });

  test('rejects local, private, link-local, and mapped private addresses', () {
    for (final value in <String>[
      '0.0.0.0',
      '10.0.0.1',
      '100.64.0.1',
      '127.0.0.1',
      '169.254.169.254',
      '172.16.0.1',
      '192.168.1.1',
      '::',
      '::1',
      'fc00::1',
      'fe80::1',
      '::ffff:192.168.1.1',
    ]) {
      expect(
        PublicNetworkPolicy.isPublic(InternetAddress(value)),
        isFalse,
        reason: value,
      );
    }
  });

  test('rejects non-HTTP targets and localhost names', () async {
    await expectLater(
      PublicNetworkPolicy.validate(Uri.parse('file:///etc/passwd')),
      throwsA(isA<UnsafeNetworkTargetException>()),
    );
    await expectLater(
      PublicNetworkPolicy.validate(Uri.parse('http://localhost/admin')),
      throwsA(isA<UnsafeNetworkTargetException>()),
    );
  });

  test('public target adapter negotiates TLS for HTTPS requests', () async {
    final adapter = const NetworkConfig(enableLog: false).createAdapter(
      publicTargetsOnly: true,
    );
    final client = adapter.createHttpClient!()..findProxy = (_) => 'DIRECT';
    addTearDown(() {
      client.close(force: true);
      adapter.close(force: true);
    });

    final request = await client.getUrl(
      Uri.parse('${ApiEndpoints.pluginShop}index.json'),
    );
    final response = await request.close();
    await response.drain<void>();

    expect(response.statusCode, HttpStatus.ok);
  });
}
