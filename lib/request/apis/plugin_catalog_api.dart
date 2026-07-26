import 'dart:convert';
import 'package:kazumi/services/logging/logger.dart';
import 'package:kazumi/request/config/api_endpoints.dart';
import 'package:kazumi/request/clients/rules_repo_client.dart';
import 'package:kazumi/plugins/plugins.dart';
import 'package:kazumi/modules/plugin/plugin_http_module.dart';
import 'package:kazumi/services/storage/storage.dart';

class PluginSourceRepository {
  const PluginSourceRepository({
    required this.indexUrl,
    required this.pluginBaseUrl,
  });

  final String indexUrl;
  final String pluginBaseUrl;
}

class PluginCatalogApi {
  static final RulesRepoClient _client = RulesRepoClient.instance;

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
    final configured = GStorage.getSetting(SettingsKeys.pluginSourceIndexUrl);
    if (configured.trim().isNotEmpty) {
      return _normalizeIndexUrl(configured);
    }
    return _normalizeIndexUrl(ApiEndpoints.defaultPluginSourceIndex);
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
      _normalizeIndexUrl(ApiEndpoints.pluginShop),
    };

    for (final indexUrl in candidates) {
      try {
        final res = await _client.getText(indexUrl);
        final jsonData = _decodeJsonList(res);
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
    final repository = await _resolveRepository(forceRefresh: true);
    if (repository == null) {
      throw const FormatException('No compatible rule repository is available');
    }
    final raw = await _client.getText(repository.indexUrl);
    final result = parsePluginList(raw);
    if (result.skippedItems > 0) {
      KazumiLogger().w(
        'Plugin: skipped ${result.skippedItems} invalid rule catalog item(s)',
      );
    }
    return result.items;
  }

  static PluginCatalogParseResult parsePluginList(String raw) {
    final jsonData = json.decode(raw);
    if (jsonData is! List) {
      throw const FormatException('Rule catalog root must be a JSON array');
    }
    final items = <PluginHTTPItem>[];
    var skippedItems = 0;
    for (var index = 0; index < jsonData.length; index++) {
      try {
        items.add(_parsePluginListItem(jsonData[index], index));
      } on FormatException {
        skippedItems++;
      }
    }
    if (jsonData.isNotEmpty && items.isEmpty) {
      throw const FormatException('Rule catalog contains no valid items');
    }
    return PluginCatalogParseResult(
      items: List.unmodifiable(items),
      skippedItems: skippedItems,
    );
  }

  static PluginHTTPItem _parsePluginListItem(Object? value, int index) {
    if (value is! Map) {
      throw FormatException('Rule catalog item $index must be an object');
    }
    try {
      return PluginHTTPItem.fromJson(Map<String, dynamic>.from(value));
    } catch (error) {
      throw FormatException('Invalid rule catalog item $index: $error');
    }
  }

  static Future<Plugin> getPlugin(String name) async {
    final repository = await _resolveRepository();
    if (repository == null) {
      throw const FormatException('No compatible rule repository is available');
    }
    final raw = await _client.getText('${repository.pluginBaseUrl}$name.json');
    final jsonData = json.decode(raw);
    if (jsonData is! Map) {
      throw FormatException('Rule $name must be a JSON object');
    }
    return Plugin.fromJson(Map<String, dynamic>.from(jsonData));
  }
}

class PluginCatalogParseResult {
  const PluginCatalogParseResult({
    required this.items,
    required this.skippedItems,
  });

  final List<PluginHTTPItem> items;
  final int skippedItems;
}
