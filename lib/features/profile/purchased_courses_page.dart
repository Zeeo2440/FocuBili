import 'package:flutter/material.dart';

import '../../services/bilibili_cookie_store_factory.dart';
import '../../services/bilibili_course_service.dart';
import '../course/course_page.dart';

/// Current-account purchases, opened through the existing native course player.
class PurchasedCoursesPage extends StatefulWidget {
  const PurchasedCoursesPage({super.key, this.service});
  final BilibiliCourseService? service;

  @override
  State<PurchasedCoursesPage> createState() => _PurchasedCoursesPageState();
}

class _PurchasedCoursesPageState extends State<PurchasedCoursesPage> {
  late final BilibiliCourseService _service;
  List<PurchasedCourse> _courses = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _service =
        widget.service ??
        BilibiliCourseService(
          readCookies: () => createDefaultBilibiliCookieStore().readCookies(),
        );
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _courses = const [];
    });
    try {
      final courses = await _service.purchasedCourses();
      if (mounted) setState(() => _courses = courses);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('已购课程'),
        actions: [
          IconButton(
            tooltip: '刷新',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                itemCount: _courses.isEmpty ? 1 : _courses.length,
                itemBuilder: (context, index) {
                  if (_courses.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 64,
                        horizontal: 16,
                      ),
                      child: Column(
                        children: [
                          Text(
                            _error ?? '当前账号暂无已购课程。\n请确认登录的是购买课程的账号。',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          OutlinedButton(
                            onPressed: _load,
                            child: const Text('重新加载'),
                          ),
                        ],
                      ),
                    );
                  }
                  final course = _courses[index];
                  final unavailable = course.unavailable || course.expired;
                  return Card(
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(12),
                      leading: SizedBox(
                        width: 88,
                        height: 56,
                        child: course.cover.isEmpty
                            ? const Icon(Icons.school_outlined)
                            : ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  course.cover,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, error, stack) =>
                                      const Icon(Icons.school_outlined),
                                ),
                              ),
                      ),
                      title: Text(
                        course.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        course.unavailable
                            ? '课程已失效'
                            : course.expired
                            ? '课程已过期'
                            : course.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: unavailable
                          ? null
                          : const Icon(Icons.chevron_right_rounded),
                      enabled: !unavailable,
                      onTap: unavailable
                          ? null
                          : () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => CoursePage(uri: course.uri),
                              ),
                            ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
