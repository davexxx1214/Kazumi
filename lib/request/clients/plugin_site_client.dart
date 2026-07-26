import 'package:dio/dio.dart';
import 'package:kazumi/request/core/dio_factory.dart';
import 'package:kazumi/request/core/network_error_mapper.dart';
import 'package:kazumi/utils/http_headers.dart';

class PluginSiteClient {
  PluginSiteClient._();

  static final PluginSiteClient instance = PluginSiteClient._();

  Future<String> requestText(
    String url, {
    required String method,
    Map<String, dynamic> headers = const {},
    Map<String, dynamic> queryParameters = const {},
    Object? data,
    CancelToken? cancelToken,
    Future<void> Function(Uri uri)? validateTarget,
  }) async {
    try {
      var currentUrl = url;
      var currentMethod = method;
      var currentData = data;
      var currentQuery = queryParameters;
      var currentHeaders = _headers(headers);
      for (var redirectCount = 0; redirectCount <= 5; redirectCount++) {
        final currentUri = Uri.parse(currentUrl);
        await validateTarget?.call(currentUri);
        final response = await DioFactory.pluginDio.request<String>(
          currentUrl,
          queryParameters: currentQuery,
          data: currentData,
          options: Options(
            method: currentMethod,
            responseType: ResponseType.plain,
            headers: currentHeaders,
            followRedirects: false,
            validateStatus: (status) =>
                status != null && status >= 200 && status < 400,
          ),
          cancelToken: cancelToken,
        );
        final statusCode = response.statusCode ?? 0;
        if (statusCode < 300) {
          return response.data ?? '';
        }
        final location = response.headers.value('location');
        if (location == null || redirectCount == 5) {
          throw DioException(
            requestOptions: response.requestOptions,
            response: response,
            type: DioExceptionType.badResponse,
            error: 'Invalid or excessive redirect response',
          );
        }
        final nextUri = response.realUri.resolve(location);
        if (nextUri.host.toLowerCase() != currentUri.host.toLowerCase()) {
          currentHeaders = Map<String, dynamic>.from(currentHeaders)
            ..removeWhere(
              (name, _) => const {
                'authorization',
                'cookie',
                'host',
                'proxy-authorization',
              }.contains(name.toLowerCase()),
            );
        }
        if (statusCode == 303 ||
            ((statusCode == 301 || statusCode == 302) &&
                currentMethod.toUpperCase() == 'POST')) {
          currentMethod = 'GET';
          currentData = null;
        }
        currentUrl = nextUri.toString();
        currentQuery = const <String, dynamic>{};
      }
      throw StateError('Unreachable redirect handling state');
    } on DioException catch (e) {
      throw await NetworkErrorMapper.mapException(e);
    }
  }

  Map<String, dynamic> _headers(Map<String, dynamic> headers) {
    return {
      'user-agent': getRandomUA(),
      'Accept-Language': getRandomAcceptedLanguage(),
      'Connection': 'keep-alive',
      ...headers,
    };
  }
}
