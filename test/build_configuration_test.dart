import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android build uses the NDK required by native plugins', () {
    final androidBuild = File('android/app/build.gradle').readAsStringSync();
    final tvWorkflow =
        File('.github/workflows/build_tv_apk.yml').readAsStringSync();

    expect(androidBuild, contains('ndkVersion "28.2.13676358"'));
    expect(tvWorkflow, contains('flutter-version-file: pubspec.yaml'));
  });
}
