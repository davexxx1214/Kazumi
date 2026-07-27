import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/utils/media.dart';

void main() {
  group('isBlockedVideoSource', () {
    test('rejects known embedded advertising video CDNs', () {
      expect(
        isBlockedVideoSource(
          'https://v16-vod.capcutvod.com/path/advertisement.mp4',
        ),
        isTrue,
      );
      expect(
        isBlockedVideoSource(
          'https://v16s.topbuzzcdn.com/path/advertisement.mp4',
        ),
        isTrue,
      );
      expect(
        isBlockedVideoSource(
          'https://groupvideo.photo.qq.com/path/advertisement.mp4',
        ),
        isTrue,
      );
      expect(
        isBlockedVideoSource(
          '//v16-vod.capcutvod.com/path/advertisement.mp4',
        ),
        isTrue,
      );
    });

    test('rejects existing advertising tracker URLs case-insensitively', () {
      expect(
        isBlockedVideoSource(
          'https://GoogleAds.G.DoubleClick.net/pagead/video.mp4',
        ),
        isTrue,
      );
      expect(
        isBlockedVideoSource(
          'https://example.com/adtrafficquality/video.mp4',
        ),
        isTrue,
      );
    });

    test('keeps ordinary playback URLs', () {
      expect(
        isBlockedVideoSource(
          'https://media.example.com/anime/episode-01.m3u8',
        ),
        isFalse,
      );
      expect(
        isBlockedVideoSource(
          'https://cdn.example.org/video/episode-01.mp4?token=topbuzzcdn.com',
        ),
        isFalse,
      );
      expect(
        isBlockedVideoSource(
          'https://capcutvod.com.example.org/video/episode-01.mp4',
        ),
        isFalse,
      );
    });
  });
}
