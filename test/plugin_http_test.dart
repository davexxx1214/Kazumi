import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:kazumi/request/api.dart';
import 'package:kazumi/request/plugin.dart';
import 'package:kazumi/request/request.dart';
import 'package:kazumi/utils/storage.dart';

void main() {
  late Directory hiveDir;

  setUpAll(() async {
    hiveDir = await Directory.systemTemp.createTemp(
      'kazumi_plugin_source_test',
    );
    Hive.init(hiveDir.path);
    GStorage.setting = await Hive.openBox<dynamic>('setting');
    await GStorage.setting.put(
      SettingBoxKey.pluginSourceIndexUrl,
      Api.defaultPluginSourceIndex,
    );
    Request();
    await Request.setCookie();
  });

  tearDownAll(() async {
    await GStorage.setting.close();
    await Hive.close();
    if (await hiveDir.exists()) {
      await hiveDir.delete(recursive: true);
    }
  });

  test('falls back to legacy source when default index is incompatible',
      () async {
    final pluginList = await PluginHTTP.getPluginList();

    expect(pluginList, isNotEmpty);
    expect(pluginList.first.name, isNotEmpty);

    final plugin = await PluginHTTP.getPlugin(pluginList.first.name);
    expect(plugin, isNotNull);
    expect(plugin!.api, isNotEmpty);
  });
}
