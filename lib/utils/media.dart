import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

const Set<String> _blockedVideoSourceHosts = {
  'capcutvod.com',
  'topbuzzcdn.com',
  'groupvideo.photo.qq.com',
};

bool isBlockedVideoSource(String source) {
  final lower = source.trim().toLowerCase();
  if (lower.contains('googleads') ||
      lower.contains('googlesyndication') ||
      lower.contains('adtrafficquality') ||
      lower.contains('doubleclick')) {
    return true;
  }

  final host = Uri.tryParse(source)?.host.toLowerCase();
  if (host == null || host.isEmpty) {
    return false;
  }
  return _blockedVideoSourceHosts.any(
    (blockedHost) => host == blockedHost || host.endsWith('.$blockedHost'),
  );
}

String decodeVideoSource(String iframeUrl) {
  final decodedUrl = Uri.decodeFull(iframeUrl);
  final regExp = RegExp(
    r'(http[s]?://.*?\.m3u8)|(http[s]?://.*?\.mp4)',
    caseSensitive: false,
  );

  final uri = Uri.parse(decodedUrl);
  final params = uri.queryParameters;

  var matchedUrl = iframeUrl;
  params.forEach((key, value) {
    if (regExp.hasMatch(value)) {
      matchedUrl = value;
      return;
    }
  });

  return Uri.encodeFull(matchedUrl);
}

int extractEpisodeNumber(String input) {
  final regExp = RegExp(r'第?(\d+)[话集]?');
  final match = regExp.firstMatch(input);

  if (match != null && match.group(1) != null) {
    return int.tryParse(match.group(1)!) ?? 0;
  }

  return 0;
}

Future<String> getPlayerTempPath() async {
  final directory = await getTemporaryDirectory();
  return directory.path;
}

String buildShadersAbsolutePath(String baseDirectory, List<String> shaders) {
  final absolutePaths = shaders.map((shader) {
    return path.join(baseDirectory, shader);
  }).toList();
  if (Platform.isWindows) {
    return absolutePaths.join(';');
  }
  return absolutePaths.join(':');
}
