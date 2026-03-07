import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/utils/m3u8_parser.dart';

void main() {
  group('M3U8 Parser', () {
    test('detects master playlists and picks the best variant', () {
      const content = '''
#EXTM3U
#EXT-X-STREAM-INF:BANDWIDTH=1280000,RESOLUTION=640x360
low/index.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=2560000,RESOLUTION=1280x720
mid/index.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=5120000,RESOLUTION=1920x1080
hi/index.m3u8
''';

      expect(M3u8Parser.detectType(content), M3u8Type.master);

      final master = M3u8Parser.parseMasterPlaylist(
        content,
        'https://example.com/root/master.m3u8',
      );

      expect(master.variants, hasLength(3));
      expect(master.bestVariant.bandwidth, 5120000);
      expect(
        master.bestVariant.uri,
        'https://example.com/root/hi/index.m3u8',
      );
    });

    test('parses VOD media playlists with ENDLIST', () {
      const content = '''
#EXTM3U
#EXT-X-VERSION:3
#EXT-X-PLAYLIST-TYPE:VOD
#EXT-X-TARGETDURATION:10
#EXTINF:9.0,
seg_00000.ts
#EXTINF:9.5,
seg_00001.ts
#EXT-X-ENDLIST
''';

      expect(M3u8Parser.detectType(content), M3u8Type.media);

      final playlist = M3u8Parser.parseMediaPlaylist(
        content,
        'https://example.com/videos/index.m3u8',
      );

      expect(playlist.isVod, isTrue);
      expect(playlist.targetDuration, 10);
      expect(playlist.segments, hasLength(2));
      expect(
        playlist.segments.first.uri,
        'https://example.com/videos/seg_00000.ts',
      );
    });

    test('treats finite playlists without ENDLIST as VOD fallback', () {
      const content = '''
#EXTM3U
#EXT-X-VERSION:3
#EXT-X-TARGETDURATION:10
#EXT-X-MEDIA-SEQUENCE:0
#EXTINF:10.0,
https://example.com/seg_00000.ts
#EXTINF:10.0,
https://example.com/seg_00001.ts
#EXTINF:8.5,
https://example.com/seg_00002.ts
''';

      final playlist = M3u8Parser.parseMediaPlaylist(
        content,
        'https://example.com/playlist.m3u8',
      );

      expect(playlist.isVod, isTrue);
      expect(playlist.segments, hasLength(3));
    });

    test('rejects EVENT playlists as non-VOD without ENDLIST', () {
      const content = '''
#EXTM3U
#EXT-X-VERSION:3
#EXT-X-PLAYLIST-TYPE:EVENT
#EXT-X-TARGETDURATION:10
#EXT-X-MEDIA-SEQUENCE:0
#EXTINF:10.0,
https://example.com/seg_00000.ts
#EXTINF:10.0,
https://example.com/seg_00001.ts
''';

      final playlist = M3u8Parser.parseMediaPlaylist(
        content,
        'https://example.com/event.m3u8',
      );

      expect(playlist.isVod, isFalse);
    });

    test('honors explicit VOD tags even without ENDLIST', () {
      const content = '''
#EXTM3U
#EXT-X-VERSION:3
#EXT-X-PLAYLIST-TYPE:VOD
#EXT-X-TARGETDURATION:10
#EXT-X-MEDIA-SEQUENCE:0
#EXTINF:10.0,
https://example.com/seg_00000.ts
#EXTINF:10.0,
https://example.com/seg_00001.ts
''';

      final playlist = M3u8Parser.parseMediaPlaylist(
        content,
        'https://example.com/vod.m3u8',
      );
      expect(playlist.isVod, isTrue);

      const emptyVod = '''
#EXTM3U
#EXT-X-VERSION:3
#EXT-X-PLAYLIST-TYPE:VOD
#EXT-X-TARGETDURATION:10
''';

      final emptyPlaylist = M3u8Parser.parseMediaPlaylist(
        emptyVod,
        'https://example.com/empty.m3u8',
      );
      expect(emptyPlaylist.isVod, isTrue);
      expect(emptyPlaylist.segments, isEmpty);
    });

    test('resolves nested m3u8 segments recursively', () async {
      const outerContent = '''
#EXTM3U
#EXT-X-VERSION:3
#EXT-X-TARGETDURATION:30
#EXTINF:10.0,
https://example.com/seg_00000.ts
#EXTINF:30.0,
https://example.com/nested.m3u8
#EXTINF:10.0,
https://example.com/seg_00002.ts
#EXT-X-ENDLIST
''';

      const nestedContent = '''
#EXTM3U
#EXT-X-VERSION:3
#EXT-X-TARGETDURATION:10
#EXTINF:10.0,
seg_a.ts
#EXTINF:10.0,
seg_b.ts
#EXTINF:10.0,
seg_c.ts
#EXT-X-ENDLIST
''';

      final outer = M3u8Parser.parseMediaPlaylist(
        outerContent,
        'https://example.com/main.m3u8',
      );

      final resolved = await M3u8Parser.resolveNestedSegments(
        outer.segments,
        (url) async {
          if (url.contains('nested.m3u8')) return nestedContent;
          throw Exception('Unknown URL: $url');
        },
      );

      expect(resolved, hasLength(5));
      expect(
        resolved.map((seg) => seg.uri),
        orderedEquals([
          'https://example.com/seg_00000.ts',
          'https://example.com/seg_a.ts',
          'https://example.com/seg_b.ts',
          'https://example.com/seg_c.ts',
          'https://example.com/seg_00002.ts',
        ]),
      );
      expect(resolved.any((seg) => seg.uri.endsWith('.m3u8')), isFalse);
    });
  });
}
