import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/plugins/plugins.dart';

void main() {
  test('bundled default plugins stay in sync with curated defaults', () async {
    final pluginDirectory = Directory('assets/plugins');
    final pluginFiles = pluginDirectory
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.json'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));

    final pluginNames = pluginFiles
        .map((file) => file.uri.pathSegments.last.replaceFirst('.json', ''))
        .toList();

    expect(
      pluginNames,
      unorderedEquals([
        '7sefun',
        'AGE',
        'DM84',
        'LMM',
        'MXdm',
        'aafun',
        'baimao',
        'enlie',
        'giriGiriLove',
        'gpjda',
        'gugu3',
        'mwcy',
        'omofun03',
        'xfdm',
        'xfdmneo',
        'yishijie',
      ]),
    );

    for (final file in pluginFiles) {
      final pluginJson = jsonDecode(await file.readAsString());
      expect(
        () => Plugin.fromJson(Map<String, dynamic>.from(pluginJson)),
        returnsNormally,
        reason: '${file.path} should remain a valid bundled plugin rule',
      );
    }
  });
}
