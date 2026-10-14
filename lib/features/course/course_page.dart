import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../services/bilibili_course_link.dart';

/// Android classroom compatibility page. Android WebView shares the app's
/// existing CookieManager; no session cookie is copied into Dart or JavaScript.
class CoursePage extends StatefulWidget {
  const CoursePage({super.key, required this.uri});
  final Uri uri;

  @override
  State<CoursePage> createState() => _CoursePageState();
}

class _CoursePageState extends State<CoursePage> with WidgetsBindingObserver {
  WebViewController? _controller;
  String? _error;
  int _progress = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      setState(() => _error = '课堂网页入口目前仅支持安卓版。');
      return;
    }
    final uri = BilibiliCourseLink.parse(widget.uri.toString());
    if (uri == null) {
      setState(() => _error = '无效的 B站课堂链接。');
      return;
    }
    try {
      final controller = WebViewController();
      await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
      // Request the desktop classroom on tablets, avoiding mobile app prompts.
      await controller.setUserAgent('Mozilla/5.0 (X11; Linux x86_64) '
          'AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36');
      await controller.setNavigationDelegate(NavigationDelegate(
        onNavigationRequest: (request) {
          if (!request.isMainFrame ||
              BilibiliCourseLink.allowsNavigation(request.url)) {
            return NavigationDecision.navigate;
          }
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('已留在课堂。需要登录时，请返回“我的”登录后重试。'),
            ));
          }
          return NavigationDecision.prevent;
        },
        onPageStarted: (_) {
          if (mounted) setState(() { _progress = 0; _error = null; });
        },
        onProgress: (value) {
          if (mounted) setState(() => _progress = value);
        },
        onWebResourceError: (error) {
          if (mounted && error.isForMainFrame == true) {
            setState(() => _error = '课程页面加载失败，请检查网络后重试。');
          }
        },
      ));
      if (!mounted) return;
      setState(() => _controller = controller);
      await controller.loadRequest(uri);
    } catch (_) {
      if (mounted) setState(() => _error = '无法打开课堂，请检查系统 WebView 后重试。');
    }
  }

  Future<void> _pauseMedia() async {
    try {
      await _controller?.runJavaScript(
        'document.querySelectorAll("video,audio").forEach(v => v.pause());',
      );
    } catch (_) { /* The platform view may already have been removed. */ }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) unawaited(_pauseMedia());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_pauseMedia());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('B站课堂（网页兼容）'), actions: [
      IconButton(tooltip: '重新加载', icon: const Icon(Icons.refresh),
        onPressed: () async {
          if (_controller == null) {
            await _initialize();
          } else {
            try { await _controller!.loadRequest(widget.uri); }
            catch (_) {
              if (mounted) setState(() => _error = '加载失败，请重试。');
            }
          }
        }),
    ]),
    body: SafeArea(child: Column(children: [
      const Padding(padding: EdgeInsets.all(8), child: Text(
        '请先在“我的”登录购买课程的账号。购买权限、选课和播放由 B站官方网页处理。',
      )),
      if (_error != null) Padding(
        padding: const EdgeInsets.all(12), child: Text(_error!),
      ),
      if (_progress < 100 && _error == null)
        LinearProgressIndicator(value: _progress / 100),
      if (_controller != null)
        Expanded(child: WebViewWidget(controller: _controller!)),
    ])),
  );
}
