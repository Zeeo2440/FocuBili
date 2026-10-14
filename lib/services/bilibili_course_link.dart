/// Strictly parse official classroom links; never treat an ss/ep ID as an AV ID.
abstract final class BilibiliCourseLink {
  static final _keyPattern = RegExp(r'^cheese:ss([1-9][0-9]*)$');

  static bool isStorageKey(String value) => _keyPattern.hasMatch(value);

  static Uri? fromStorageKey(String value) {
    final match = _keyPattern.firstMatch(value.trim());
    return match == null
        ? null
        : Uri.https('www.bilibili.com', '/cheese/play/ss${match.group(1)}');
  }

  static Uri? parse(String input) {
    final uri = Uri.tryParse(input.trim());
    if (uri == null ||
        !const {'https', 'http'}.contains(uri.scheme) ||
        !const {
          'www.bilibili.com',
          'm.bilibili.com',
          'bilibili.com',
        }.contains(uri.host) ||
        uri.userInfo.isNotEmpty ||
        uri.hasPort ||
        !RegExp(r'^/cheese/play/(ss|ep)[1-9][0-9]*/?$').hasMatch(uri.path)) {
      return null;
    }
    return Uri.https(
      'www.bilibili.com',
      '/cheese/play/${uri.pathSegments.where((s) => s.isNotEmpty).last}',
    );
  }

  /// Keep the top-level browser inside classroom pages; account login is done
  /// through the existing profile screen. Subresources retain normal loading.
  static bool allowsNavigation(String url) => parse(url) != null;
}
