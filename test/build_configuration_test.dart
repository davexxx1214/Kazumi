import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android build follows the Flutter SDK toolchain versions', () {
    final androidBuild = File('android/app/build.gradle').readAsStringSync();
    final tvWorkflow =
        File('.github/workflows/build_tv_apk.yml').readAsStringSync();

    expect(androidBuild, contains('ndkVersion flutter.ndkVersion'));
    expect(tvWorkflow, contains('flutter-version-file: pubspec.yaml'));
  });
}
