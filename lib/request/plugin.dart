import 'dart:convert';
import 'package:kazumi/utils/logger.dart';
import 'package:kazumi/request/api.dart';
import 'package:kazumi/request/request.dart';
import 'package:kazumi/plugins/plugins.dart';
import 'package:kazumi/modules/plugin/plugin_http_module.dart';
import 'package:kazumi/utils/storage.dart';

class PluginSourceRepository {
  const PluginSourceRepository({
    required this.indexUrl,
    required this.pluginBaseUrl,
  });

  final String indexUrl;
  final String pluginBaseUrl;
}

class PluginHTTP {
  static PluginSourceRepository? _cachedRepository;
  static String? _cachedConfiguredIndexUrl;

  static String _normalizeIndexUrl(String source) {
    final trimmed = source.trim();
    if (trimmed.endsWith('index.json')) {
      return trimmed;
    }
    if (trimmed.endsWith('/')) {
      return '${trimmed}index.json';
    }
    return '$trimmed/index.json';
  }

  static String _pluginBaseUrlFromIndexUrl(String indexUrl) {
    return indexUrl.replaceFirst(RegExp(r'index\.json$'), '');
  }

  static bool _isLegacyIndexItem(dynamic item) {
    return item is Map &&
        item['name'] != null &&
        item['version'] != null &&
        item.containsKey('useNativePlayer') &&
        item.containsKey('author');
  }

  static List<dynamic> _decodeJsonList(dynamic data) {
    final decoded = data is String ? json.decode(data) : data;
    if (decoded is List) {
      return decoded;
    }
    throw const FormatException('Plugin source index is not a JSON list');
  }

  static String _configuredIndexUrl() {
    final configured = GStorage.setting.get(
      SettingBoxKey.pluginSourceIndexUrl,
      defaultValue: Api.defaultPluginSourceIndex,
    );
    if (configured is String && configured.trim().isNotEmpty) {
      return _normalizeIndexUrl(configured);
    }
    return _normalizeIndexUrl(Api.defaultPluginSourceIndex);
  }

  static Future<PluginSourceRepository?> _resolveRepository({
    bool forceRefresh = false,
  }) async {
    final configuredIndexUrl = _configuredIndexUrl();
    if (!forceRefresh &&
        _cachedRepository != null &&
        _cachedConfiguredIndexUrl == configuredIndexUrl) {
      return _cachedRepository;
    }

    final candidates = <String>{
      configuredIndexUrl,
      _normalizeIndexUrl(Api.pluginShop),
    };

    for (final indexUrl in candidates) {
      try {
        final res = await Request().get(indexUrl);
        final jsonData = _decodeJsonList(res.data);
        if (jsonData.isEmpty) {
          continue;
        }
        if (_isLegacyIndexItem(jsonData.first)) {
          final repository = PluginSourceRepository(
            indexUrl: indexUrl,
            pluginBaseUrl: _pluginBaseUrlFromIndexUrl(indexUrl),
          );
          _cachedConfiguredIndexUrl = configuredIndexUrl;
          _cachedRepository = repository;
          return repository;
        }
        KazumiLogger().w(
          'Plugin: unsupported plugin source format at $indexUrl, fallback to legacy source',
        );
      } catch (e) {
        KazumiLogger().w(
          'Plugin: failed to resolve plugin source $indexUrl',
          error: e,
        );
      }
    }

    _cachedConfiguredIndexUrl = configuredIndexUrl;
    _cachedRepository = null;
    return null;
  }

  static Future<List<PluginHTTPItem>> getPluginList() async {
    List<PluginHTTPItem> pluginHTTPItemList = [];
    try {
      final repository = await _resolveRepository(forceRefresh: true);
      if (repository == null) {
        return pluginHTTPItemList;
      }
      var res = await Request().get(repository.indexUrl);
      final jsonData = _decodeJsonList(res.data);
      for (dynamic pluginJsonItem in jsonData) {
        try {
          PluginHTTPItem pluginHTTPItem = PluginHTTPItem.fromJson(
              Map<String, dynamic>.from(pluginJsonItem));
          pluginHTTPItemList.add(pluginHTTPItem);
        } catch (_) {}
      }
    } catch (e) {
      KazumiLogger().e('Plugin: getPluginList error: ${e.toString()}');
    }
    return pluginHTTPItemList;
  }

  static Future<Plugin?> getPlugin(String name) async {
    Plugin? plugin;
    try {
      final repository = await _resolveRepository();
      if (repository == null) {
        return null;
      }
      var res = await Request().get('${repository.pluginBaseUrl}$name.json');
      final jsonData = json.decode(res.data);
      plugin = Plugin.fromJson(jsonData);
    } catch (e) {
      KazumiLogger().e('Plugin: getPlugin error: ${e.toString()}');
    }
    return plugin;
  }
}
