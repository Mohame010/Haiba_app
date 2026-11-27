import 'package:material_ui/material_ui.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../level_assessment/data/services/level_assessment_service.dart';
import '../../../level_assessment/domain/entities/level_assessment.dart';
import '../../data/services/commerce_offer_service.dart';
import '../../domain/entities/commerce_offer_entity.dart';
import '../widgets/offer_purchase_sheet.dart';

class RecommendedCoursesScreen extends StatefulWidget {
  const RecommendedCoursesScreen({super.key});

  @override
  State<RecommendedCoursesScreen> createState() =>
      _RecommendedCoursesScreenState();
}

class _RecommendedCoursesScreenState extends State<RecommendedCoursesScreen> {
  bool _loading = true;
  String? _error;
  LevelAssessmentResult? _result;
  List<Map<String, dynamic>> _courses = const [];
  Set<String> _enrolled = const {};
  List<CommerceOfferEntity> _offers = const [];

  SupabaseClient get _client => Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final resultFuture = LevelAssessmentService.instance.latestResult();
      final coursesFuture = _client
          .from('courses')
          .select(
            '*, course_lectures(lecture_id,sort_order,lectures(title,online_price,price))',
          )
          .eq('teacher_id', AppConstants.activeTeacherId)
          .eq('is_published', true)
          .order('created_at', ascending: false);
      final offersFuture = CommerceOfferService.instance.getActiveOffers();
      final result = await resultFuture;
      final rawCourses = await coursesFuture;
      final offers = await offersFuture;
      final userId = _client.auth.currentUser?.id;
      var enrolled = <String>{};
      if (userId != null) {
        final rows = await _client
            .from('course_enrollments')
            .select('course_id')
            .eq('student_id', userId)
            .eq('status', 'active');
        enrolled = rows
            .map((row) => row['course_id'] as String?)
            .whereType<String>()
            .toSet();
      }
      if (!mounted) return;
      setState(() {
        _result = result;
        _courses = rawCourses
            .map((row) => Map<String, dynamic>.from(row as Map))
            .toList();
        _enrolled = enrolled;
        _offers = offers;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'تعذر تحميل الترشيحات. تأكد من توفر اتصال بالإنترنت.\n$error';
      });
    }
  }

  int _score(String skill, LevelAssessmentResult result) => switch (skill) {
    'pronunciation' => result.pronunciationScore,
    'reading' => result.readingScore,
    'writing' => result.writingScore,
    _ => result.overallScore,
  };

  StudentLevel _level(String skill, LevelAssessmentResult result) =>
      switch (skill) {
        'pronunciation' => result.pronunciationLevel,
        'reading' => result.readingLevel,
        'writing' => result.writingLevel,
        _ => result.overallLevel,
      };

  List<Map<String, dynamic>> _forSkill(
    String skill,
    LevelAssessmentResult result,
  ) {
    final score = _score(skill, result);
    final level = _level(skill, result).databaseValue;
    return _courses.where((course) {
      final target = course['recommended_skill'] as String? ?? 'overall';
      final courseLevel = course['level'] as String?;
      final min = (course['min_placement_score'] as num?)?.toInt() ?? 0;
      final max = (course['max_placement_score'] as num?)?.toInt() ?? 100;
      return target == skill &&
          courseLevel == level &&
          score >= min &&
          score <= max;
    }).toList();
  }

  Future<void> _openCourse(Map<String, dynamic> course) async {
    final courseId = course['id'] as String;
    if (_enrolled.contains(courseId)) {
      final lessons = course['course_lectures'] as List<dynamic>? ?? const [];
      if (lessons.isNotEmpty && mounted) {
        final firstLesson = lessons.first;
        final lectureId = firstLesson is Map
            ? (firstLesson['lecture_id'] as String? ?? '')
            : '';
        if (lectureId.isNotEmpty) {
          context.push(
            AppRoutes.lectureDetails,
            extra: lectureId,
          );
        }
      }
      return;
    }

    final price = (course['price'] as num?)?.toDouble() ?? 0;
    if (price <= 0) {
      await _client.rpc(
        'enroll_free_course',
        params: {'p_course_id': courseId},
      );
      await _load();
      return;
    }
    CommerceOfferEntity? offer;
    for (final item in _offers) {
      if (item.items.any(
        (target) => target.itemType == 'course' && target.itemId == courseId,
      )) {
        offer = item;
        break;
      }
    }
    final purchase =
        offer ??
        CommerceOfferEntity.direct(
          itemType: 'course',
          itemId: courseId,
          title: course['title'] as String? ?? 'الكورس',
          description: course['description'] as String? ?? '',
          price: price,
        );
    if (!mounted) return;
    await OfferPurchaseSheet.show(context, purchase, onActivated: _load);
  }

  Future<void> _showCoursePreview(Map<String, dynamic> course) async {
    final courseId = course['id'] as String? ?? '';
    final owned = _enrolled.contains(courseId);
    final price = (course['price'] as num?)?.toDouble() ?? 0;
    final rawLessons = course['course_lectures'] as List<dynamic>? ?? const [];

    final lessons = <Map<String, dynamic>>[];
    for (final raw in rawLessons) {
      if (raw is Map) {
        final lecture = raw['lectures'];
        if (lecture is Map) {
          lessons.add({
            'id': raw['lecture_id']?.toString() ?? '',
            'title': lecture['title']?.toString() ?? 'حصة',
            'price': lecture['price'],
            'online_price': lecture['online_price'],
          });
        }
      }
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.78,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
          ),
          padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 24.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 44.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
              ),
              SizedBox(height: 16.h),
              Row(
                children: [
                  Container(
                    width: 48.w,
                    height: 48.w,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withAlpha(20),
                      borderRadius: BorderRadius.circular(14.r),
                    ),
                    child: const Icon(
                      Icons.play_lesson_rounded,
                      color: AppColors.primary,
                      size: 26,
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          course['title'] as String? ?? 'الكورس',
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w800,
                            fontFamily: 'IBM',
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 3.h),
                        Text(
                          '${lessons.length} حصة مرتبة داخل هذا الكورس',
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: AppColors.textSecondary,
                            fontFamily: 'IBM',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (course['description'] != null &&
                  course['description'].toString().trim().isNotEmpty) ...[
                SizedBox(height: 12.h),
                Text(
                  course['description'].toString().trim(),
                  style: TextStyle(
                    fontSize: 12.5.sp,
                    color: AppColors.textSecondary,
                    height: 1.4,
                    fontFamily: 'IBM',
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              SizedBox(height: 16.h),
              Text(
                'محتوى الكورس والحصص',
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'IBM',
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: 8.h),
              Flexible(
                child: lessons.isEmpty
                    ? Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 20.h),
                          child: Text(
                            'لا توجد حصص مدرجة في هذا الكورس حاليًا.',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontFamily: 'IBM',
                              fontSize: 12.sp,
                            ),
                          ),
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: lessons.length,
                        separatorBuilder: (_, _) => SizedBox(height: 8.h),
                        itemBuilder: (context, index) {
                          final lesson = lessons[index];
                          final lectureId = lesson['id'] as String? ?? '';
                          return Material(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12.r),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12.r),
                              onTap: owned && lectureId.isNotEmpty
                                  ? () {
                                      Navigator.pop(sheetContext);
                                      context.push(
                                        AppRoutes.lectureDetails,
                                        extra: lectureId,
                                      );
                                    }
                                  : null,
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 14.w,
                                  vertical: 12.h,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12.r),
                                  border: Border.all(
                                    color: const Color(0xFFE2E8F0),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 13.r,
                                      backgroundColor:
                                          AppColors.primary.withAlpha(20),
                                      child: Text(
                                        '${index + 1}',
                                        style: TextStyle(
                                          color: AppColors.primary,
                                          fontSize: 11.sp,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 10.w),
                                    Expanded(
                                      child: Text(
                                        lesson['title'] as String? ?? 'حصة',
                                        style: TextStyle(
                                          fontSize: 13.sp,
                                          fontWeight: FontWeight.w700,
                                          fontFamily: 'IBM',
                                          color: AppColors.textPrimary,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (owned)
                                      Icon(
                                        Icons.play_circle_fill_rounded,
                                        color: AppColors.primary,
                                        size: 20.sp,
                                      )
                                    else
                                      Icon(
                                        Icons.lock_outline_rounded,
                                        color: Colors.grey.shade400,
                                        size: 18.sp,
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
              SizedBox(height: 16.h),
              FilledButton.icon(
                onPressed: () {
                  Navigator.pop(sheetContext);
                  _openCourse(course);
                },
                icon: Icon(
                  owned
                      ? Icons.play_arrow_rounded
                      : Icons.shopping_bag_rounded,
                ),
                label: Text(
                  owned
                      ? 'ابدأ مشاهدة أول حصة'
                      : price <= 0
                          ? 'تسجيل مجاني في الكورس'
                          : 'اشترك الآن بسعر ${price.toStringAsFixed(0)} ج.م',
                  style: TextStyle(
                    fontFamily: 'IBM',
                    fontWeight: FontWeight.w800,
                    fontSize: 14.sp,
                  ),
                ),
                style: FilledButton.styleFrom(
                  minimumSize: Size.fromHeight(52.h),
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16.r),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        context.go(AppRoutes.main);
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            tooltip: 'الرئيسية',
            onPressed: () => context.go(AppRoutes.main),
          ),
          title: const Text(
            'كورسات مناسبة لمستواك',
            style: TextStyle(fontFamily: 'IBM', fontWeight: FontWeight.w800),
          ),
          centerTitle: true,
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _Message(message: _error!, onPressed: _load)
                : _result == null
                    ? _Message(
                        message:
                            'قم بإجراء اختبار تحديد المستوى أولاً لنتمكن من ترشيح الكورسات بدقة.',
                        action: 'حدد مستواك',
                        onPressed: () =>
                            context.push(AppRoutes.levelAssessmentIntro),
                      )
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView(
                          padding: EdgeInsets.fromLTRB(18.w, 14.h, 18.w, 30.h),
                          children: [
                            _Summary(result: _result!),
                            SizedBox(height: 20.h),
                            for (final skill in const [
                              'pronunciation',
                              'reading',
                              'writing',
                              'overall',
                            ])
                              _SkillCourses(
                                skill: skill,
                                score: _score(skill, _result!),
                                courses: _forSkill(skill, _result!),
                                enrolled: _enrolled,
                                onOpen: _openCourse,
                                onPreview: _showCoursePreview,
                              ),
                          ],
                        ),
                      ),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  final LevelAssessmentResult result;

  const _Summary({required this.result});

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.all(18.w),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF312E81), Color(0xFF7C3AED)],
      ),
      borderRadius: BorderRadius.circular(22.r),
    ),
    child: Row(
      children: [
        const Icon(
          Icons.auto_awesome_rounded,
          color: Color(0xFFFDE68A),
          size: 34,
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: Text(
            'ترشيحات مخصصة وفقًا لمستواك في كل مهارة على حدة.',
            style: TextStyle(
              color: Colors.white,
              fontFamily: 'IBM',
              fontWeight: FontWeight.w800,
              fontSize: 14.sp,
            ),
          ),
        ),
        Text(
          '${result.overallScore}%',
          style: TextStyle(
            color: const Color(0xFFFDE68A),
            fontSize: 20.sp,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    ),
  );
}

class _SkillCourses extends StatelessWidget {
  final String skill;
  final int score;
  final List<Map<String, dynamic>> courses;
  final Set<String> enrolled;
  final Future<void> Function(Map<String, dynamic>) onOpen;
  final Future<void> Function(Map<String, dynamic>) onPreview;

  const _SkillCourses({
    required this.skill,
    required this.score,
    required this.courses,
    required this.enrolled,
    required this.onOpen,
    required this.onPreview,
  });

  String get title => switch (skill) {
    'pronunciation' => 'كورسات النطق',
    'reading' => 'كورسات القراءة',
    'writing' => 'كورسات الكتابة',
    _ => 'كورسات المستوى العام',
  };

  IconData get icon => switch (skill) {
    'pronunciation' => Icons.record_voice_over_rounded,
    'reading' => Icons.menu_book_rounded,
    'writing' => Icons.edit_note_rounded,
    _ => Icons.school_rounded,
  };

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: 22.h),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: AppColors.primary),
            SizedBox(width: 8.w),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontFamily: 'IBM',
                  fontSize: 17.sp,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Text(
              'درجتك $score%',
              style: const TextStyle(
                color: AppColors.primary,
                fontFamily: 'IBM',
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        SizedBox(height: 10.h),
        if (courses.isEmpty)
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(15.w),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15.r),
            ),
            child: const Text(
              'لا يوجد كورس مخصص لهذه الدرجة حاليًا.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'IBM',
                color: AppColors.textSecondary,
              ),
            ),
          )
        else
          ...courses.map((course) {
            final owned = enrolled.contains(course['id']);
            final price = (course['price'] as num?)?.toDouble() ?? 0;
            return Card(
              margin: EdgeInsets.only(bottom: 10.h),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(17.r),
                side: BorderSide(color: AppColors.primary.withAlpha(30)),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(17.r),
                onTap: () => onPreview(course),
                child: ListTile(
                  contentPadding: EdgeInsets.all(12.w),
                  leading: CircleAvatar(
                    backgroundColor: AppColors.primary.withAlpha(18),
                    child: const Icon(
                      Icons.play_lesson_rounded,
                      color: AppColors.primary,
                    ),
                  ),
                  title: Text(
                    course['title'] as String? ?? 'كورس',
                    style: const TextStyle(
                      fontFamily: 'IBM',
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  subtitle: Text(
                    owned
                        ? 'ضمن اشتراكاتي'
                        : price == 0
                            ? 'مجاني'
                            : '${price.toStringAsFixed(0)} ج.م',
                    style: TextStyle(
                      fontFamily: 'IBM',
                      color: owned
                          ? const Color(0xFF047857)
                          : AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  trailing: FilledButton(
                    onPressed: () => onOpen(course),
                    child: Text(owned ? 'ابدأ' : 'اشترك'),
                  ),
                ),
              ),
            );
          }),
      ],
    ),
  );
}

class _Message extends StatelessWidget {
  final String message;
  final String action;
  final VoidCallback onPressed;

  const _Message({
    required this.message,
    required this.onPressed,
    this.action = 'إعادة المحاولة',
  });

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.school_outlined, size: 54, color: AppColors.primary),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 14),
          FilledButton(onPressed: onPressed, child: Text(action)),
        ],
      ),
    ),
  );
}
