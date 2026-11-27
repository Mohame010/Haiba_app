import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../lectures/data/services/offline_lecture_service.dart';
import '../../../lectures/presentation/widgets/video_player_widget.dart';

class PlatformPromoVideoCard extends StatefulWidget {
  const PlatformPromoVideoCard({super.key});

  @override
  State<PlatformPromoVideoCard> createState() => _PlatformPromoVideoCardState();
}

class _PlatformPromoVideoCardState extends State<PlatformPromoVideoCard> {
  late Future<Map<String, dynamic>?> _settingsFuture;

  @override
  void initState() {
    super.initState();
    _settingsFuture = _loadSettings();
  }

  Future<Map<String, dynamic>?> _loadSettings() async {
    final row = await Supabase.instance.client
        .from('app_settings')
        .select('value')
        .eq('key', 'student_promo_video')
        .maybeSingle();
    final value = row?['value'];
    return value is Map ? Map<String, dynamic>.from(value) : null;
  }

  Future<void> _playVideo(String url, String title) async {
    final uri = Uri.tryParse(url);
    if (uri == null ||
        !uri.hasScheme ||
        (uri.scheme != 'https' && uri.scheme != 'http')) {
      _showMessage('رابط الفيديو غير صالح.');
      return;
    }

    final cache = OfflineLectureService.instance;
    final cachedPath = await cache.getCachedVideoPath(
      cacheKey: 'student_promo_video',
      sourceUrl: url,
    );
    if (!mounted) return;
    if (cachedPath == null) {
      unawaited(
        cache
            .cacheVideo(cacheKey: 'student_promo_video', sourceUrl: url)
            .catchError((_) => url),
      );
    }
    final playbackUrl = cachedPath == null
        ? url
        : Uri.file(cachedPath).toString();

    await showGeneralDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      barrierDismissible: false,
      transitionDuration: Duration.zero,
      transitionBuilder: (_, _, _, child) => child,
      pageBuilder: (_, _, _) =>
          _PromoVideoPlayerDialog(videoUrl: playbackUrl, title: title),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _settingsFuture,
      builder: (context, snapshot) {
        final settings = snapshot.data ?? const <String, dynamic>{};
        final url = settings['video_url']?.toString().trim() ?? '';
        final title = settings['title']?.toString().trim().isNotEmpty == true
            ? settings['title'].toString().trim()
            : 'جولة سريعة في منصتك';
        final thumbnailUrl = settings['thumbnail_url']?.toString().trim();
        final isReady = url.isNotEmpty;

        return Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(22.r),
            child: InkWell(
              onTap: isReady ? () => _playVideo(url, title) : null,
              borderRadius: BorderRadius.circular(22.r),
              child: Ink(
                height: 176.h,
                decoration: BoxDecoration(
                  color: const Color(0xFF182343),
                  borderRadius: BorderRadius.circular(22.r),
                  image: thumbnailUrl != null && thumbnailUrl.isNotEmpty
                      ? DecorationImage(
                          image: NetworkImage(thumbnailUrl),
                          fit: BoxFit.cover,
                          onError: (_, _) {},
                        )
                      : null,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF312E81).withAlpha(30),
                      blurRadius: 18,
                      offset: const Offset(0, 7),
                    ),
                  ],
                ),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22.r),
                    gradient: const LinearGradient(
                      begin: Alignment.centerRight,
                      end: Alignment.centerLeft,
                      colors: [
                        Color(0xE8121A36),
                        Color(0xA8121A36),
                        Color(0x28121A36),
                      ],
                    ),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(18.w),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 10.w,
                                  vertical: 5.h,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withAlpha(28),
                                  borderRadius: BorderRadius.circular(20.r),
                                  border: Border.all(
                                    color: Colors.white.withAlpha(45),
                                  ),
                                ),
                                child: Text(
                                  'فيديو تعريفي',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11.sp,
                                    fontWeight: FontWeight.w700,
                                    fontFamily: 'IBM',
                                  ),
                                ),
                              ),
                              SizedBox(height: 10.h),
                              Text(
                                title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18.sp,
                                  height: 1.35,
                                  fontWeight: FontWeight.w800,
                                  fontFamily: 'IBM',
                                ),
                              ),
                              SizedBox(height: 5.h),
                              Text(
                                isReady
                                    ? 'اكتشف رحلتك التعليمية في دقيقة'
                                    : snapshot.hasError
                                    ? 'تعذر تحميل الفيديو الآن'
                                    : 'قريبًا — جولة تساعدك تبدأ',
                                style: TextStyle(
                                  color: Colors.white.withAlpha(205),
                                  fontSize: 12.sp,
                                  fontFamily: 'IBM',
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: 14.w),
                        Container(
                          width: 58.w,
                          height: 58.w,
                          decoration: BoxDecoration(
                            color: isReady
                                ? Colors.white
                                : Colors.white.withAlpha(45),
                            shape: BoxShape.circle,
                            boxShadow: isReady
                                ? const [
                                    BoxShadow(
                                      color: Color(0x55000000),
                                      blurRadius: 14,
                                      offset: Offset(0, 5),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Icon(
                            isReady
                                ? Icons.play_arrow_rounded
                                : Icons.school_rounded,
                            color: isReady ? AppColors.primary : Colors.white,
                            size: 34.w,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PromoVideoPlayerDialog extends StatelessWidget {
  const _PromoVideoPlayerDialog({required this.videoUrl, required this.title});

  final String videoUrl;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 24.h),
      child: Stack(
        children: [
          VideoPlayerWidget(
            videoUrl: videoUrl,
            title: title,
            autoplay: true,
            adaptiveAspectRatio: true,
            portraitFullscreen: false,
          ),
          PositionedDirectional(
            top: 6,
            end: 6,
            child: IconButton(
              onPressed: () => Navigator.of(context).pop(),
              tooltip: 'إغلاق الفيديو',
              style: IconButton.styleFrom(
                backgroundColor: Colors.black54,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.close_rounded),
            ),
          ),
        ],
      ),
    );
  }
}
