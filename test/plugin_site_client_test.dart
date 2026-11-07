import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:kazumi/plugins/api_rule_config.dart';
import 'package:kazumi/request/clients/bangumi_client.dart';
import 'package:kazumi/request/clients/plugin_site_client.dart';
import 'package:kazumi/request/core/dio_factory.dart';
import 'package:kazumi/services/plugin/api_rule_strategy.dart';
import 'package:kazumi/services/storage/storage.dart';
import 'package:logger/logger.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

void main() {
  late Directory directory;
  late PathProviderPlatform originalPaths;
  late _RecordingAdapter adapter;

  setUpAll(() async {
    Logger.level = Level.off;
    directory = await Directory.systemTemp.createTemp('kazumi_rule_http_test_');
    originalPaths = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _TestPaths(directory.path);
    Hive.init(directory.path);
    await GStorage.init();
  });

  setUp(() async {
    DioFactory.reset();
    await GStorage.putSetting(
      SettingsKeys.bangumiAccessToken,
      'app-login-token',
    );
    await GStorage.putSetting(SettingsKeys.bangumiSyncEnable, true);
    await GStorage.putSetting(SettingsKeys.enableBangumiProxy, false);
    adapter = _RecordingAdapter();
    DioFactory.pluginDio.httpClientAdapter = adapter;
  });

  tearDown(() {
    DioFactory.pluginDio.close(force: true);
    DioFactory.apiDio.close(force: true);
    DioFactory.reset();
  });

  tearDownAll(() async {
    await Hive.close();
    PathProviderPlatform.instance = originalPaths;
    expect(
      directory.absolute.path.startsWith(Directory.systemTemp.absolute.path),
      isTrue,
    );
    expect(
      directory.uri.pathSegments.where((part) => part.isNotEmpty).last,
      startsWith('kazumi_rule_http_test_'),
    );
    await directory.delete(recursive: true);
  });

  test('application login credentials never enter rule requests', () async {
    final appAdapter = _RecordingAdapter();
    DioFactory.apiDio.httpClientAdapter = appAdapter;
    await BangumiClient.instance.get('https://api.bgm.tv/v0/me');
    expect(
      _header(appAdapter.requests.single, 'authorization'),
      'Bearer app-login-token',
    );
    expect(identical(DioFactory.apiDio, DioFactory.pluginDio), isFalse);

    await PluginSiteClient.instance.requestText(
      'https://rules.example/search',
      method: 'GET',
      headers: {'Authorization': 'Bearer rule-token'},
    );
    await PluginSiteClient.instance.requestText(
      'https://other.example/search',
      method: 'GET',
    );
    expect(_header(adapter.requests[0], 'authorization'), 'Bearer rule-token');
    expect(_header(adapter.requests[1], 'authorization'), isNull);
    expect(_header(adapter.requests[1], 'cookie'), isNull);
    expect(
      adapter.requests.expand((r) => r.headers.values),
      isNot(contains('Bearer app-login-token')),
    );
  });

  test(
    'bundled xfdmnext search and chapter credentials reach their target',
    () async {
      final rule =
          jsonDecode(await File('assets/plugins/xfdmnext.json').readAsString())
              as Map<String, dynamic>;
      for (final field in ['searchApiConfig', 'chapterApiConfig']) {
        final config = ApiRequestConfig.fromJson(rule[field]['request']);
        final prepared = const ApiRuleStrategy().prepareRequest(config, {
          'keyword': 'test',
          'source': '123',
        });
        await PluginSiteClient.instance.requestText(
          prepared.url,
          method: prepared.method,
          headers: prepared.headers,
          queryParameters: prepared.query,
          data: prepared.body,
        );
        final sent = adapter.requests.last;
        expect(sent.uri.host, 'api.xifanacg.com');
        expect(sent.method, 'POST');
        expect(_header(sent, 'authorization'), config.headers['Authorization']);
        expect(_header(sent, 'apikey'), config.headers['apikey']);
      }
    },
  );

  for (final status in [301, 302, 303, 307, 308]) {
    test('same-origin $status redirect retains explicit credentials', () async {
      adapter.locations = ['https://RULES.example:443/next'];
      adapter.redirectStatus = status;
      await PluginSiteClient.instance.requestText(
        'https://rules.example/start',
        method: 'POST',
        headers: {'Authorization': 'Bearer rule-token'},
        data: 'payload',
      );
      final redirected = adapter.requests.last;
      expect(_header(redirected, 'authorization'), 'Bearer rule-token');
      expect(
        redirected.method,
        status == 307 || status == 308 ? 'POST' : 'GET',
      );
      expect(
        redirected.data,
        status == 307 || status == 308 ? 'payload' : null,
      );
      expect(adapter.requests.every((r) => !r.followRedirects), isTrue);
    });
  }

  for (final target in [
    'https://other.example/next',
    'https://sub.rules.example/next',
    'https://rules.example:8443/next',
    'http://rules.example/next',
  ]) {
    test(
      'credentials are removed on redirect to $target and stay removed',
      () async {
        adapter.locations = [target, 'https://rules.example/return'];
        final validated = <Uri>[];
        await PluginSiteClient.instance.requestText(
          'https://rules.example/start',
          method: 'GET',
          headers: {
            'aUtHoRiZaTiOn': 'Bearer rule-token',
            'ApiKey': 'rule-key',
            'Cookie': 'clearance=rule-cookie',
            'X-Rule-Header': 'keep',
          },
          validateTarget: (uri) async => validated.add(uri),
        );
        expect(adapter.requests, hasLength(3));
        expect(validated, adapter.requests.map((r) => r.uri).toList());
        expect(
          _header(adapter.requests.first, 'authorization'),
          'Bearer rule-token',
        );
        for (final redirected in adapter.requests.skip(1)) {
          expect(_header(redirected, 'authorization'), isNull);
          expect(_header(redirected, 'apikey'), isNull);
          expect(_header(redirected, 'cookie'), isNull);
          expect(_header(redirected, 'x-rule-header'), 'keep');
        }
      },
    );
  }

  test('redirect targets are validated before sending a request', () async {
    adapter.locations = ['https://blocked.example/next'];
    await expectLater(
      PluginSiteClient.instance.requestText(
        'https://rules.example/start',
        method: 'GET',
        headers: {'Authorization': 'Bearer rule-token'},
        validateTarget: (uri) async {
          if (uri.host == 'blocked.example') throw StateError('blocked');
        },
      ),
      throwsStateError,
    );
    expect(adapter.requests, hasLength(1));
  });
}

Object? _header(RequestOptions request, String name) {
  for (final entry in request.headers.entries) {
    if (entry.key.toLowerCase() == name) return entry.value;
  }
  return null;
}

class _RecordingAdapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  List<String> locations = [];
  int redirectStatus = 302;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final index = requests.length - 1;
    if (index < locations.length) {
      return ResponseBody.fromString(
        '',
        redirectStatus,
        headers: {
          'location': [locations[index]],
        },
      );
    }
    return ResponseBody.fromString(
      '{}',
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _TestPaths extends PathProviderPlatform {
  _TestPaths(this.path);
  final String path;

  @override
  Future<String?> getApplicationSupportPath() async => path;
}
