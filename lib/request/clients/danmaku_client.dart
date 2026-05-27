import 'package:dio/dio.dart';
import 'package:kazumi/request/core/dio_factory.dart';
import 'package:kazumi/request/core/network_error_mapper.dart';
import 'package:kazumi/services/logging/logger.dart';
import 'package:kazumi/utils/dandan_credentials.dart';
import 'package:kazumi/utils/http_headers.dart';
import 'package:kazumi/utils/crypto.dart';

class DanmakuClient {
  DanmakuClient._();

  static final DanmakuClient instance = DanmakuClient._();
  static bool _placeholderWarningLogged = false;

  static const _placeholderAppId = 'kvpx7qkqjh';
  static const _placeholderAppSecret = 'rABUaBLqdz7aCSi3fe88ZDj2gwga9Vax';

  Future<dynamic> get(
    String url, {
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic> headers = const {},
    CancelToken? cancelToken,
  }) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final uri = Uri.parse(url);
    _logPlaceholderCredentialsIfNeeded();
    final requestHeaders = <String, dynamic>{
      'user-agent': getRandomUA(),
      'referer': '',
      'X-Auth': 1,
      'X-AppId': dandanCredentials['id'],
      'X-Timestamp': timestamp,
      'X-Signature': generateDandanSignature(uri.path, timestamp),
      ...headers,
    };

    try {
      final response = await DioFactory.apiDio.get(
        url,
        queryParameters: queryParameters,
        options: Options(headers: requestHeaders),
        cancelToken: cancelToken,
      );
      return response.data;
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      final danDanError = e.response?.headers.value('x-error-message');
      KazumiLogger().w(
        'DanmakuClient: request failed ${statusCode ?? e.type.name} ${uri.path}'
        '${danDanError == null ? '' : ' ($danDanError)'}',
        error: e.message,
      );
      throw await NetworkErrorMapper.mapException(e);
    }
  }

  void _logPlaceholderCredentialsIfNeeded() {
    if (_placeholderWarningLogged) {
      return;
    }
    if (dandanCredentials['id'] == _placeholderAppId &&
        dandanCredentials['value'] == _placeholderAppSecret) {
      _placeholderWarningLogged = true;
      KazumiLogger().w(
        'DanmakuClient: placeholder DanDan API credentials are in use; '
        'release builds must inject DANDANAPI_APPID and DANDANAPI_KEY.',
      );
    }
  }
}
