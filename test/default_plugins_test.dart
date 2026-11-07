import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/plugins/plugins.dart';

void main() {
  // Predidit/KazumiRules index.json at 2967d7babafffa92dbf35fbcb69d0fd964139e63.
  test('bundled default plugins match the upstream rule catalog', () async {
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
        'AGE',
        '7sefun',
        'aafun',
        'akianime',
        'DM84',
        'LMM',
        'MXdm',
        'baimao',
        'dalvdm',
        'ezdmw',
        'giriGiriLove',
        'mgnacg',
        'moonci',
        'mutefun',
        'sorani',
        'TvTFun',
        'xfdmneo',
        'xfdmnext',
      ]),
    );

    for (final file in pluginFiles) {
      final pluginJson = jsonDecode(await file.readAsString());
      expect(
        () => Plugin.fromJson(Map<String, dynamic>.from(pluginJson)),
        returnsNormally,
        reason: '${file.path} should remain a valid bundled plugin rule',
      );
      expect(
        Plugin.fromJson(Map<String, dynamic>.from(pluginJson))
            .requiresNewerClient,
        isFalse,
        reason: '${file.path} must be supported by this client',
      );
    }
  });
}
