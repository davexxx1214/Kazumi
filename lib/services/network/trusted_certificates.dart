import 'dart:io';

import 'package:flutter/services.dart';

/// Supplements platform trust stores that predate SSL.com's 2022 RSA root.
/// This context is scoped to the app's network clients, not the global store.
class TrustedCertificates {
  TrustedCertificates._();

  static const sslComRootAsset =
      'assets/certificates/SSLcom-TLS-Root-2022-RSA.pem';

  static SecurityContext? _context;

  static SecurityContext get context =>
      _context ?? SecurityContext.defaultContext;

  /// Call before creating network clients. Keep all platform roots and normal
  /// certificate-chain, hostname, and validity checks enabled.
  static Future<void> initialize() async {
    if (_context != null) return;
    final certificate = await rootBundle.load(sslComRootAsset);
    final context = SecurityContext(withTrustedRoots: true);
    context.setTrustedCertificatesBytes(
      certificate.buffer.asUint8List(
        certificate.offsetInBytes,
        certificate.lengthInBytes,
      ),
    );
    _context = context;
  }
}
