import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../models/video_preview.dart';
import '../../services/bilibili_service.dart';
import '../player/player_page.dart';

/// Resolve classroom metadata and render the same native player as UGC videos.
class CoursePage extends StatefulWidget {
  const CoursePage({super.key, required this.uri});
  final Uri uri;
  @override
  State<CoursePage> createState() => _CoursePageState();
}

class _CoursePageState extends State<CoursePage> {
  late Future<VideoPreview> _video;
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _video = BilibiliVideoInfoService().lookupVideo(widget.uri.toString());
  }

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return Scaffold(
        appBar: AppBar(title: const Text('B站课堂')),
        body: const Center(child: Text('原生课堂播放目前支持安卓版。')),
      );
    }
    return FutureBuilder<VideoPreview>(
      future: _video,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          final video = snapshot.data!;
          return PlayerPage(
            video: video,
            // Explicit episode links override last selection; season links resume.
            initialPartCid: widget.uri.pathSegments.last.startsWith('ep')
                ? video.cid
                : null,
          );
        }
        return Scaffold(
          appBar: AppBar(title: const Text('B站课堂')),
          body: Center(
            child: snapshot.hasError
                ? Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(snapshot.error.toString()),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: () => setState(_load),
                          child: const Text('重试'),
                        ),
                      ],
                    ),
                  )
                : const CircularProgressIndicator(),
          ),
        );
      },
    );
  }
}
