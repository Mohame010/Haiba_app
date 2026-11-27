import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../data/teacher_admin_service.dart';

class PronunciationSubmissionReview extends StatelessWidget {
  const PronunciationSubmissionReview({
    super.key,
    required this.service,
    required this.submissions,
    required this.isLoading,
    required this.error,
    required this.onRetry,
  });

  final TeacherAdminService service;
  final List<Map<String, dynamic>> submissions;
  final bool isLoading;
  final String? error;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (error != null) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(24.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 44),
              SizedBox(height: 12.h),
              Text(
                'تعذر تحميل تسجيلات الطلاب\n$error',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13.sp, fontFamily: 'IBM'),
              ),
              SizedBox(height: 12.h),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
      );
    }
    if (submissions.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(24.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.record_voice_over_outlined,
                size: 52,
                color: Color(0xFF8B5CF6),
              ),
              SizedBox(height: 12.h),
              Text(
                'ستظهر هنا تسجيلات الطلاب بعد تسليمها',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: const Color(0xFF6B7280),
                  fontSize: 14.sp,
                  fontFamily: 'IBM',
                ),
              ),
              SizedBox(height: 12.h),
              TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('تحديث'),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRetry,
      child: ListView(
        padding: EdgeInsets.all(16.w),
        children: [
          Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F3FF),
              borderRadius: BorderRadius.circular(18.r),
            ),
            child: Row(
              children: [
                const Icon(Icons.headphones_rounded, color: Color(0xFF6D28D9)),
                SizedBox(width: 10.w),
                Expanded(
                  child: Text(
                    '${submissions.length} تسجيل نطق • استمع وراجع أداء كل طالب',
                    style: TextStyle(
                      color: const Color(0xFF4C1D95),
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'IBM',
                    ),
                  ),
                ),
                IconButton(
                  onPressed: onRetry,
                  tooltip: 'تحديث',
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
          ),
          SizedBox(height: 12.h),
          for (final submission in submissions)
            _PronunciationSubmissionTile(
              key: ValueKey(submission['submission_id']),
              service: service,
              submission: submission,
            ),
        ],
      ),
    );
  }
}

class _PronunciationSubmissionTile extends StatefulWidget {
  const _PronunciationSubmissionTile({
    super.key,
    required this.service,
    required this.submission,
  });

  final TeacherAdminService service;
  final Map<String, dynamic> submission;

  @override
  State<_PronunciationSubmissionTile> createState() =>
      _PronunciationSubmissionTileState();
}

class _PronunciationSubmissionTileState
    extends State<_PronunciationSubmissionTile> {
  final AudioPlayer _player = AudioPlayer();
  StreamSubscription<void>? _completeSubscription;
  bool _playing = false;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _completeSubscription = _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _playing = false);
    });
  }

  Future<void> _togglePlayback() async {
    if (_loading) return;
    if (_playing) {
      await _player.stop();
      if (mounted) setState(() => _playing = false);
      return;
    }
    setState(() => _loading = true);
    try {
      final url = await widget.service.createPronunciationAudioUrl(
        widget.submission['audio_path'] as String,
      );
      await _player.play(UrlSource(url));
      if (mounted) setState(() => _playing = true);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('تعذر تشغيل التسجيل: $error')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _completeSubscription?.cancel();
    unawaited(_player.dispose());
    super.dispose();
  }

  String _submittedAt() {
    final raw = widget.submission['submitted_at'] as String?;
    if (raw == null) return '';
    final date = DateTime.tryParse(raw)?.toLocal();
    if (date == null) return '';
    String twoDigits(int value) => value.toString().padLeft(2, '0');
    return '${twoDigits(date.day)}/${twoDigits(date.month)}/${date.year}'
        ' • ${twoDigits(date.hour)}:${twoDigits(date.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final durationMs = (widget.submission['duration_ms'] as num?)?.toInt() ?? 0;
    final sizeBytes =
        (widget.submission['file_size_bytes'] as num?)?.toInt() ?? 0;
    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: const Color(0xFFE7E9F0)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 48.w,
            height: 48.w,
            child: IconButton.filled(
              onPressed: _loading ? null : _togglePlayback,
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xFF6D28D9),
                foregroundColor: Colors.white,
              ),
              icon: _loading
                  ? SizedBox.square(
                      dimension: 18.w,
                      child: const CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Icon(
                      _playing ? Icons.stop_rounded : Icons.play_arrow_rounded,
                    ),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.submission['student_name']?.toString() ??
                      'طالب بدون اسم',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: const Color(0xFF1E1B4B),
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'IBM',
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  '${widget.submission['word'] ?? ''} • ${widget.submission['lecture_title'] ?? ''}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: const Color(0xFF4B5563),
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'IBM',
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  '${_submittedAt()} • ${(durationMs / 1000).toStringAsFixed(1)} ث • ${(sizeBytes / 1024).toStringAsFixed(1)} ك.ب',
                  style: TextStyle(
                    color: const Color(0xFF9CA3AF),
                    fontSize: 10.sp,
                    fontFamily: 'IBM',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
