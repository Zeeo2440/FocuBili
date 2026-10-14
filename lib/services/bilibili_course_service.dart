import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../models/video_preview.dart';
import 'bilibili_course_link.dart';

/// Transport is injectable so tests never use a real login or paid content.
typedef CourseJsonRequest = Future<String> Function(Uri uri, String cookie);

class CourseLookupException implements Exception {
  const CourseLookupException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Reads official classroom metadata. Playback authorization remains server-side.
class BilibiliCourseService {
  BilibiliCourseService({
    CourseJsonRequest? requestJson,
    required Future<String> Function() readCookies,
  }) : _requestJson = requestJson ?? _request,
       _readCookies = readCookies;

  final CourseJsonRequest _requestJson;
  final Future<String> Function() _readCookies;

  Future<VideoPreview> lookup(Uri input) async {
    final uri = BilibiliCourseLink.parse(input.toString());
    if (uri == null) throw const CourseLookupException('无效的课堂链接。');
    try {
      // Keep a single session snapshot across pagination. Never store it in data.
      final cookie = await _readCookies().timeout(const Duration(seconds: 10));
      final target = uri.pathSegments.last;
      final requestedEpisode = target.startsWith('ep')
          ? int.parse(target.substring(2))
          : null;
      final data = _data(
        await _requestJson(
          Uri.https('api.bilibili.com', '/pugv/view/web/season', {
            requestedEpisode == null ? 'season_id' : 'ep_id': target.substring(
              2,
            ),
          }),
          cookie,
        ),
      );
      final seasonId = _int(data['season_id']);
      if (seasonId <= 0) throw const CourseLookupException('课程接口缺少课程编号。');
      final rawEpisodes = <Map<String, dynamic>>[];
      void append(Object? items) {
        if (items is List) {
          for (final item in items) {
            if (item is Map<String, dynamic>) rawEpisodes.add(item);
          }
        }
      }

      append(data['episodes']);
      final page = _map(data['episode_page']);
      final total = _int(page['total']);
      if (page['next'] == true || (total > rawEpisodes.length)) {
        // Restart the dedicated list at page 1: season endpoint page size varies.
        rawEpisodes.clear();
        var finished = false;
        for (var pn = 1; pn <= 100; pn++) {
          final batch = _data(
            await _requestJson(
              Uri.https('api.bilibili.com', '/pugv/view/web/ep/list', {
                'season_id': '$seasonId',
                'pn': '$pn',
                'ps': '100',
              }),
              cookie,
            ),
          );
          final before = rawEpisodes.length;
          append(batch['items']);
          final pageInfo = _map(batch['page']);
          final batchTotal = _int(pageInfo['total']);
          if (pageInfo['next'] == false ||
              (batchTotal > 0 && rawEpisodes.length >= batchTotal)) {
            finished = true;
            break;
          }
          if (before == rawEpisodes.length) break;
        }
        if (!finished || (total > 0 && rawEpisodes.length < total)) {
          throw const CourseLookupException('课程目录未加载完整，请重试。');
        }
      }
      // Preserve official order, keep valid unavailable chapters so the server
      // can explain purchase restrictions when selected; never infer entitlement.
      final seen = <int>{};
      final parts = <VideoPart>[];
      for (final ep in rawEpisodes) {
        final id = _int(ep['id']);
        final cid = _int(ep['cid']);
        final aid = _int(ep['aid']);
        if (id <= 0 || cid <= 0 || aid <= 0 || !seen.add(id)) continue;
        parts.add(
          VideoPart(
            pageNumber: parts.length + 1,
            cid: cid,
            title: _text(ep['title'], '课程章节'),
            duration: Duration(seconds: _int(ep['duration']).clamp(0, 86400)),
            courseEpisodeId: id,
            courseAid: aid,
          ),
        );
      }
      if (parts.isEmpty) throw const CourseLookupException('该课程尚无可播放的视频章节。');
      final selected = requestedEpisode == null
          ? parts.first
          : parts
                .where((part) => part.courseEpisodeId == requestedEpisode)
                .firstOrNull;
      if (selected == null) {
        throw const CourseLookupException('目录中没有找到指定章节，请从课程主页重新打开。');
      }
      // A concurrent logout/account switch must not publish stale metadata.
      if (cookie != await _readCookies().timeout(const Duration(seconds: 10))) {
        throw const CourseLookupException('登录状态已变化，请重新打开课程。');
      }
      final author = _map(data['up_info']);
      return VideoPreview(
        bvid: 'cheese:ss$seasonId',
        courseSeasonId: seasonId,
        cid: selected.cid,
        title: _text(data['title'], 'B站课堂'),
        ownerName: _text(author['uname'], '课程讲师'),
        ownerMid: _int(author['mid']),
        ownerAvatarUrl: _image(author['avatar']),
        thumbnailUrl: _image(data['cover']),
        description: _text(data['subtitle'], ''),
        duration: Duration(
          seconds: parts.fold<int>(0, (sum, p) => sum + p.duration.inSeconds),
        ),
        parts: List.unmodifiable(parts),
      );
    } on CourseLookupException {
      rethrow;
    } on TimeoutException {
      throw const CourseLookupException('课程目录请求超时，请检查网络后重试。');
    } catch (_) {
      throw const CourseLookupException('课程目录加载失败，请检查网络和登录状态后重试。');
    }
  }

  static Map<String, dynamic> _data(String json) {
    final root = _map(jsonDecode(json));
    final code = _int(root['code'], fallback: -1);
    if (code != 0) {
      throw CourseLookupException(switch (code) {
        -101 => '登录已失效，请在“我的”重新登录购买课程的账号。',
        -403 => '当前账号没有该课程的访问权限，请确认购买账号。',
        -404 => '课程不存在或已下架。',
        _ => '课程接口请求失败（错误码 $code），请稍后重试。',
      });
    }
    if (root['data'] is! Map) {
      throw const CourseLookupException('课程接口返回的数据不完整。');
    }
    return _map(root['data']);
  }

  static Map<String, dynamic> _map(Object? value) =>
      value is Map<String, dynamic> ? value : {};
  static int _int(Object? value, {int fallback = 0}) =>
      value is num ? value.toInt() : int.tryParse('$value') ?? fallback;
  static String _text(Object? value, String fallback) =>
      value is String && value.trim().isNotEmpty ? value.trim() : fallback;
  static String _image(Object? value) {
    var text = _text(value, '');
    if (text.startsWith('//')) text = 'https:$text';
    if (text.startsWith('http://')) text = 'https://${text.substring(7)}';
    return Uri.tryParse(text)?.scheme == 'https' ? text : '';
  }

  static Future<String> _request(Uri uri, String cookie) async {
    // Only fixed official API endpoints may receive the in-memory session.
    if (uri.scheme != 'https' ||
        uri.host != 'api.bilibili.com' ||
        !const {
          '/pugv/view/web/season',
          '/pugv/view/web/ep/list',
        }.contains(uri.path)) {
      throw const CourseLookupException('无效的课程请求地址。');
    }
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 12);
    try {
      final request = await client
          .getUrl(uri)
          .timeout(const Duration(seconds: 15));
      request.followRedirects = false;
      request.headers.set(
        HttpHeaders.refererHeader,
        'https://www.bilibili.com/',
      );
      request.headers.set(
        HttpHeaders.userAgentHeader,
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36',
      );
      if (cookie.isNotEmpty) {
        request.headers.set(HttpHeaders.cookieHeader, cookie);
      }
      final response = await request.close().timeout(
        const Duration(seconds: 15),
      );
      if (response.statusCode != 200) {
        throw CourseLookupException('课程服务暂不可用（HTTP ${response.statusCode}）。');
      }
      return await response
          .transform(utf8.decoder)
          .join()
          .timeout(const Duration(seconds: 15));
    } finally {
      client.close(force: true);
    }
  }
}
