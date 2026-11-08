import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/plugins/plugins_controller.dart';
import 'package:logger/logger.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late PathProviderPlatform originalPaths;

  setUp(() async {
    Logger.level = Level.off;
    directory = await Directory.systemTemp.createTemp('kazumi_plugin_startup_');
    originalPaths = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _TestPaths(directory.path);
  });

  tearDown(() async {
    PathProviderPlatform.instance = originalPaths;
    expect(
      directory.absolute.path.startsWith(Directory.systemTemp.absolute.path),
      isTrue,
    );
    expect(
      directory.uri.pathSegments.where((part) => part.isNotEmpty).last,
      startsWith('kazumi_plugin_startup_'),
    );
    await directory.delete(recursive: true);
  });

  for (final savedEmpty in [false, true]) {
    test(
      'startup installs bundled rules with savedEmpty=$savedEmpty',
      () async {
        final saved = File('${directory.path}/plugins/v2/plugins.json');
        if (savedEmpty) {
          await saved.parent.create(recursive: true);
          await saved.writeAsString('[]');
        }
        final controller = PluginsController();
        await controller.init();

        final bundledNames = Directory('assets/plugins')
            .listSync()
            .whereType<File>()
            .where((file) => file.path.endsWith('.json'))
            .map((file) => jsonDecode(file.readAsStringSync())['name'])
            .toList();
        expect(
          controller.pluginList.map((rule) => rule.name),
          unorderedEquals(bundledNames),
        );
        final persisted = jsonDecode(await saved.readAsString()) as List;
        expect(
          persisted.map((rule) => rule['name']),
          unorderedEquals(bundledNames),
        );

        await controller.init();
        expect(
          controller.pluginList.map((rule) => rule.name),
          unorderedEquals(bundledNames),
        );
      },
    );
  }

  test('startup preserves previously installed or customized rules', () async {
    final saved = File('${directory.path}/plugins/v2/plugins.json');
    await saved.parent.create(recursive: true);
    final original = jsonEncode([
      {
        'name': 'custom-rule',
        'version': '1.0',
        'baseURL': 'https://custom.example',
      },
    ]);
    await saved.writeAsString(original);
    final controller = PluginsController();
    await controller.init();

    expect(controller.pluginList.single.name, 'custom-rule');
    expect(controller.pluginList.single.baseUrl, 'https://custom.example');
    expect(await saved.readAsString(), original);
  });
}

class _TestPaths extends PathProviderPlatform {
  _TestPaths(this.path);
  final String path;

  @override
  Future<String?> getApplicationSupportPath() async => path;
}
