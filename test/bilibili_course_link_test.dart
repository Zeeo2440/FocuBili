import 'package:flutter_test/flutter_test.dart';
import 'package:focubili/services/bilibili_course_link.dart';
import 'package:focubili/services/bilibili_deep_link_service.dart';

void main() {
  test('normalizes purchased course link without sharing parameters', () {
    final target = BilibiliDeepLinkParser.parse(
      'https://www.bilibili.com/cheese/play/ss968174948?bsource=link_copy',
    );
    expect(target?.courseUri.toString(),
        'https://www.bilibili.com/cheese/play/ss968174948');
    expect(target?.displayId, 'ss968174948');
    expect(target?.bvid, isEmpty);
  });
  test('supports episodes and mobile links', () {
    expect(BilibiliCourseLink.parse('https://m.bilibili.com/cheese/play/ep123/')
        .toString(), 'https://www.bilibili.com/cheese/play/ep123');
  });
  test('rejects unrelated URLs and invalid IDs', () {
    for (final url in [
      'https://www.bilibili.com.evil.test/cheese/play/ss123',
      'https://evil.test/cheese/play/ss123',
      'https://user@www.bilibili.com/cheese/play/ss123',
      'https://www.bilibili.com:444/cheese/play/ss123',
      'https://www.bilibili.com/cheese/play/ss0',
      'https://www.bilibili.com/cheese/play/ss-1',
      'https://www.bilibili.com/cheese/play/ss123/extra',
      'https://www.bilibili.com/bangumi/play/ss123',
      'javascript:alert(1)',
    ]) {
      expect(BilibiliCourseLink.parse(url), isNull, reason: url);
    }
  });
  test('resolves share text and shortened course links', () async {
    final resolver = BilibiliIncomingLinkResolver(expandShortLink: (_) async =>
      Uri.parse('https://www.bilibili.com/cheese/play/ep123'));
    expect((await resolver.resolve('课程 https://b23.tv/abc。'))?.displayId,
        'ep123');
    expect((await resolver.resolve(
      '课程 https://www.bilibili.com/cheese/play/ss968174948。'))?.displayId,
        'ss968174948');
  });
  test('ordinary videos still use the native video target', () {
    final target = BilibiliDeepLinkParser.parse(
      'https://www.bilibili.com/video/BV1xx411c7mD?p=2');
    expect(target?.bvid, 'BV1xx411c7mD');
    expect(target?.partPageNumber, 2);
    expect(target?.courseUri, isNull);
  });
  test('focus navigation excludes homepage, external sites and app schemes', () {
    for (final url in ['https://www.bilibili.com/',
      'bilibili://video/123', 'https://example.com/']) {
      expect(BilibiliCourseLink.allowsNavigation(url), isFalse);
    }
  });
}
