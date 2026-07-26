import 'dart:io';

class UnsafeNetworkTargetException implements Exception {
  const UnsafeNetworkTargetException(this.message);

  final String message;

  @override
  String toString() => 'UnsafeNetworkTargetException: $message';
}

/// Rejects rule-controlled requests that could reach the local host or a
/// private/reserved network.
class PublicNetworkPolicy {
  const PublicNetworkPolicy._();

  static Future<void> validate(Uri uri) async {
    await resolve(uri);
  }

  static Future<List<InternetAddress>> resolve(Uri uri) async {
    if ((uri.scheme != 'http' && uri.scheme != 'https') || uri.host.isEmpty) {
      throw UnsafeNetworkTargetException(
        'Only absolute HTTP(S) targets are allowed: $uri',
      );
    }
    if (uri.userInfo.isNotEmpty) {
      throw UnsafeNetworkTargetException(
        'Credentials in rule request URLs are not allowed: $uri',
      );
    }

    final normalizedHost = uri.host.toLowerCase();
    if (normalizedHost == 'localhost' ||
        normalizedHost.endsWith('.localhost')) {
      throw UnsafeNetworkTargetException(
        'Local rule request targets are not allowed: $normalizedHost',
      );
    }

    final literalAddress = InternetAddress.tryParse(normalizedHost);
    final addresses = literalAddress == null
        ? await InternetAddress.lookup(normalizedHost)
        : <InternetAddress>[literalAddress];
    if (addresses.isEmpty || addresses.any((address) => !isPublic(address))) {
      throw UnsafeNetworkTargetException(
        'Private or reserved rule request target is not allowed: '
        '$normalizedHost',
      );
    }
    return addresses;
  }

  static bool isPublic(InternetAddress address) {
    final bytes = address.rawAddress;
    if (address.type == InternetAddressType.IPv4) {
      return _isPublicIpv4(bytes);
    }

    if (bytes.every((byte) => byte == 0)) {
      return false;
    }
    final isLoopback =
        bytes.take(15).every((byte) => byte == 0) && bytes[15] == 1;
    final isUniqueLocal = (bytes[0] & 0xfe) == 0xfc;
    final isLinkLocal = bytes[0] == 0xfe && (bytes[1] & 0xc0) == 0x80;
    final isMulticast = bytes[0] == 0xff;
    final isDocumentation = bytes[0] == 0x20 &&
        bytes[1] == 0x01 &&
        bytes[2] == 0x0d &&
        bytes[3] == 0xb8;
    final isIpv4Mapped = bytes.take(10).every((byte) => byte == 0) &&
        bytes[10] == 0xff &&
        bytes[11] == 0xff;
    if (isIpv4Mapped) {
      return _isPublicIpv4(bytes.sublist(12));
    }
    return !isLoopback &&
        !isUniqueLocal &&
        !isLinkLocal &&
        !isMulticast &&
        !isDocumentation;
  }

  static bool _isPublicIpv4(List<int> bytes) {
    final first = bytes[0];
    final second = bytes[1];
    final third = bytes[2];
    return first != 0 &&
        first != 10 &&
        first != 127 &&
        !(first == 100 && second >= 64 && second <= 127) &&
        !(first == 169 && second == 254) &&
        !(first == 172 && second >= 16 && second <= 31) &&
        !(first == 192 && second == 0) &&
        !(first == 192 && second == 168) &&
        !(first == 192 && second == 0 && third == 2) &&
        !(first == 198 && (second == 18 || second == 19)) &&
        !(first == 198 && second == 51 && third == 100) &&
        !(first == 203 && second == 0 && third == 113) &&
        first < 224;
  }
}
