import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../domain/entities/lecture_content_entity.dart';
import '../../domain/entities/lecture_entity.dart';
import '../../data/services/offline_lecture_service.dart';
import '../../data/services/commerce_offer_service.dart';
import '../../domain/entities/commerce_offer_entity.dart';
import '../cubits/lectures_list/lectures_list_cubit.dart';
import '../cubits/lectures_list/lectures_list_state.dart';
import '../widgets/offer_purchase_sheet.dart';
import 'offline_lecture_screen.dart';
import '../../../level_assessment/data/services/level_assessment_service.dart';
import '../../../level_assessment/domain/entities/level_assessment.dart';

class LecturesListScreen extends StatefulWidget {
  const LecturesListScreen({super.key});

  @override
  State<LecturesListScreen> createState() => _LecturesListScreenState();
}

class _LecturesListScreenState extends State<LecturesListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedFilter = 'all';
  List<Map<String, dynamic>> _courses = const [];
  Set<String> _enrolledCourseIds = const {};
  bool _coursesLoading = true;
  List<DownloadedLecture> _downloads = const [];
  bool _downloadsLoading = true;
  List<CommerceOfferEntity> _offers = const [];
  bool _offersLoading = true;
  LevelAssessmentResult? _assessmentResult;
  bool _assessmentLoading = true;
  final Set<String> _expandedGroups = {};

  @override
  void initState() {
    super.initState();
    context.read<LecturesListCubit>().loadLectures();
    _loadCourses();
    _loadDownloads();
    _loadOffers();
    _loadAssessmentResult();
  }

  Future<void> _loadAssessmentResult() async {
    try {
      final result = await LevelAssessmentService.instance.latestResult();
      if (!mounted) return;
      setState(() {
        _assessmentResult = result;
        _assessmentLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _assessmentLoading = false);
    }
  }

  Future<void> _loadOffers() async {
    try {
      final offers = await CommerceOfferService.instance.getActiveOffers();
      if (!mounted) return;
      setState(() {
        _offers = offers;
        _offersLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _offersLoading = false);
    }
  }

  Future<void> _loadDownloads() async {
    final downloads = await OfflineLectureService.instance.getDownloads();
    if (!mounted) return;
    setState(() {
      _downloads = downloads;
      _downloadsLoading = false;
    });
  }

  Future<void> _loadCourses() async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    try {
      final List<dynamic> rows = await client
          .from('courses')
          .select(
            '*, course_lectures(lecture_id, sort_order, lectures(title, online_price, price))',
          )
          .eq('teacher_id', AppConstants.activeTeacherId)
          .eq('is_published', true)
          .order('created_at', ascending: false);
      final courses = rows
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList();

      // Support both relations used by the current database:
      // course_lectures and the direct lectures.course_id foreign key.
      final List<dynamic> directLectureRows = await client
          .from('lectures')
          .select('id, course_id, title, online_price, price, created_at')
          .eq('teacher_id', AppConstants.activeTeacherId)
          .eq('is_published', true)
          .order('created_at');
      final directByCourse = <String, List<Map<String, dynamic>>>{};
      for (final raw in directLectureRows) {
        final lecture = Map<String, dynamic>.from(raw as Map);
        final courseId = lecture['course_id'] as String?;
        if (courseId != null) {
          directByCourse.putIfAbsent(courseId, () => []).add(lecture);
        }
      }
      for (final course in courses) {
        final courseId = course['id'] as String;
        final merged = <String, Map<String, dynamic>>{};
        for (final raw
            in course['course_lectures'] as List<dynamic>? ?? const []) {
          final mapping = Map<String, dynamic>.from(raw as Map);
          final lectureId = mapping['lecture_id'] as String?;
          final lecture = mapping['lectures'];
          if (lectureId != null) {
            merged[lectureId] = {
              ...mapping,
              if (lecture is Map) ...{
                'title': lecture['title'],
                'online_price': lecture['online_price'],
                'price': lecture['price'],
              },
            };
          }
        }
        var nextOrder = merged.length;
        for (final lecture in directByCourse[courseId] ?? const []) {
          final lectureId = lecture['id'] as String;
          merged.putIfAbsent(
            lectureId,
            () => {
              'lecture_id': lectureId,
              'sort_order': nextOrder++,
              'title': lecture['title'],
              'online_price': lecture['online_price'],
              'price': lecture['price'],
            },
          );
        }
        final lessons = merged.values.toList()
          ..sort(
            (a, b) => ((a['sort_order'] as num?) ?? 0).compareTo(
              (b['sort_order'] as num?) ?? 0,
            ),
          );
        course['course_lectures'] = lessons;
      }
      Set<String> enrolled = {};
      if (userId != null) {
        final List<dynamic> enrollmentRows = await client
            .from('course_enrollments')
            .select('course_id')
            .eq('student_id', userId)
            .eq('status', 'active');
        enrolled = enrollmentRows
            .map((row) => row['course_id'] as String)
            .toSet();
      }
      if (!mounted) return;
      setState(() {
        _courses = courses;
        _enrolledCourseIds = enrolled;
        _coursesLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _coursesLoading = false);
    }
  }

  Future<void> _openOrEnrollCourse(Map<String, dynamic> course) async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) return;
    final courseId = course['id'] as String;
    final isEnrolled = _enrolledCourseIds.contains(courseId);
    final lessons = (course['course_lectures'] as List<dynamic>? ?? [])
      ..sort(
        (a, b) => ((a['sort_order'] as num?) ?? 0).compareTo(
          (b['sort_order'] as num?) ?? 0,
        ),
      );

    if (!isEnrolled) {
      final price = (course['price'] as num?)?.toDouble() ?? 0;
      if (price > 0) {
        CommerceOfferEntity? matchingOffer;
        for (final offer in _offers) {
          if (offer.items.any(
            (item) => item.itemType == 'course' && item.itemId == courseId,
          )) {
            matchingOffer = offer;
            break;
          }
        }
        final purchase =
            matchingOffer ??
            CommerceOfferEntity.direct(
              itemType: 'course',
              itemId: courseId,
              title: course['title'] as String? ?? 'الكورس',
              description: course['description'] as String? ?? '',
              price: price,
            );
        await OfferPurchaseSheet.show(
          context,
          purchase,
          onActivated: _loadCourses,
        );
        return;
      }
      await client.rpc('enroll_free_course', params: {'p_course_id': courseId});
      await _loadCourses();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم الاشتراك في الكورس بنجاح')),
      );
    }

    if (lessons.isNotEmpty && mounted) {
      await context.push(
        AppRoutes.lectureDetails,
        extra: lessons.first['lecture_id'] as String,
      );
      await _loadDownloads();
    }
  }

  Future<void> _openLecturePurchase(LectureEntity lecture) async {
    CommerceOfferEntity? matchingOffer;
    for (final offer in _offers) {
      if (offer.items.any(
        (item) => item.itemType == 'lecture' && item.itemId == lecture.id,
      )) {
        matchingOffer = offer;
        break;
      }
    }
    final purchase =
        matchingOffer ??
        CommerceOfferEntity.direct(
          itemType: 'lecture',
          itemId: lecture.id,
          title: lecture.title,
          description: lecture.description,
          price: lecture.effectivePrice,
        );
    await OfferPurchaseSheet.show(
      context,
      purchase,
      onActivated: () => context.read<LecturesListCubit>().loadLectures(),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<LectureEntity> _filterLectures(List<LectureEntity> allLectures) {
    final filtered = allLectures.where((lecture) {
      // 1. Search Query Filter
      final query = _searchQuery.trim().toLowerCase();
      final matchesSearch =
          query.isEmpty ||
          lecture.title.toLowerCase().contains(query) ||
          lecture.description.toLowerCase().contains(query) ||
          lecture.chapter.toLowerCase().contains(query) ||
          lecture.subject.toLowerCase().contains(query) ||
          lecture.teacherName.toLowerCase().contains(query);

      if (!matchesSearch) return false;

      // 2. Chip Filter
      if (_selectedFilter == 'all') return true;
      if (_selectedFilter == 'available') {
        return lecture.hasAccess ||
            lecture.price <= 0 ||
            lecture.effectivePrice <= 0;
      }
      return lecture.chapter == _selectedFilter;
    }).toList();

    // Sort ascending: 01 -> 05 strictly
    filtered.sort(_compareLecturesAscending);
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'المحاضرات والكورسات',
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            fontFamily: 'IBM',
          ),
        ),
      ),
      body: SafeArea(
        child: BlocBuilder<LecturesListCubit, LecturesListState>(
          builder: (context, state) {
            if (state is LecturesListLoading || state is LecturesListInitial) {
              return _buildShimmerLoading();
            }

            if (state is LecturesListError) {
              return Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24.w),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.error_outline_rounded,
                        size: 52.w,
                        color: AppColors.error,
                      ),
                      SizedBox(height: 14.h),
                      Text(
                        state.message,
                        style: TextStyle(
                          fontSize: 14.sp,
                          color: AppColors.textSecondary,
                          fontFamily: 'IBM',
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 18.h),
                      ElevatedButton.icon(
                        onPressed: () =>
                            context.read<LecturesListCubit>().loadLectures(),
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text(
                          'إعادة المحاولة',
                          style: TextStyle(
                            fontFamily: 'IBM',
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(
                            horizontal: 24.w,
                            vertical: 12.h,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14.r),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            if (state is LecturesListLoaded) {
              final allLectures = state.lectures;
              final filteredLectures = _filterLectures(allLectures);
              final courseGroups = _buildLectureGroups(filteredLectures);

              // Extract unique chapters for filter chips
              final chapters = allLectures
                  .map((e) => e.chapter)
                  .where((c) => c.isNotEmpty)
                  .toSet()
                  .toList();

              return RefreshIndicator(
                color: AppColors.primary,
                onRefresh: () => Future.wait([
                  context.read<LecturesListCubit>().loadLectures(),
                  _loadCourses(),
                  _loadDownloads(),
                  _loadOffers(),
                  _loadAssessmentResult(),
                ]),
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  slivers: [
                    SliverToBoxAdapter(
                      child: _buildCourseSavingsBanner(allLectures),
                    ),
                    SliverToBoxAdapter(
                      child: _buildRecommendedCoursesSection(allLectures),
                    ),
                    SliverToBoxAdapter(
                      child: _buildCoursesSection(allLectures),
                    ),
                    SliverToBoxAdapter(child: _buildOffersSection()),
                    SliverToBoxAdapter(child: _buildDownloadsSection()),
                    // Search Bar & Filter Header
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 20.w,
                          vertical: 8.h,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Search Field
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16.r),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withAlpha(6),
                                    blurRadius: 10,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: TextField(
                                controller: _searchController,
                                onChanged: (value) {
                                  setState(() {
                                    _searchQuery = value;
                                  });
                                },
                                style: TextStyle(
                                  fontSize: 13.5.sp,
                                  fontFamily: 'IBM',
                                  color: AppColors.textPrimary,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'ابحث عن درس، موضوع، أو فصل...',
                                  hintStyle: TextStyle(
                                    fontSize: 13.sp,
                                    color: AppColors.textMuted,
                                    fontFamily: 'IBM',
                                  ),
                                  prefixIcon: const Icon(
                                    Icons.search_rounded,
                                    color: AppColors.textSecondary,
                                  ),
                                  suffixIcon: _searchQuery.isNotEmpty
                                      ? IconButton(
                                          icon: const Icon(
                                            Icons.clear_rounded,
                                            size: 18,
                                          ),
                                          onPressed: () {
                                            _searchController.clear();
                                            setState(() {
                                              _searchQuery = '';
                                            });
                                          },
                                        )
                                      : null,
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 16.w,
                                    vertical: 14.h,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(height: 14.h),

                            // Filter Chips Row
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
                              child: Row(
                                children: [
                                  _buildFilterChip('الكل', 'all'),
                                  SizedBox(width: 8.w),
                                  _buildFilterChip(
                                    'المتاحة للبدء',
                                    'available',
                                  ),
                                  ...chapters.map(
                                    (chap) => Padding(
                                      padding: EdgeInsets.only(right: 8.w),
                                      child: _buildFilterChip(chap, chap),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: 12.h),

                            // Stats / Counter Banner
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'المحاضرات المتاحة (${filteredLectures.length})',
                                  style: TextStyle(
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textPrimary,
                                    fontFamily: 'IBM',
                                  ),
                                ),
                                if (allLectures.isNotEmpty)
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 10.w,
                                      vertical: 4.h,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withAlpha(20),
                                      borderRadius: BorderRadius.circular(10.r),
                                    ),
                                    child: Text(
                                      allLectures.first.subject,
                                      style: TextStyle(
                                        fontSize: 11.5.sp,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.primary,
                                        fontFamily: 'IBM',
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Lectures List
                    if (filteredLectures.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.search_off_rounded,
                                size: 54.w,
                                color: AppColors.textMuted,
                              ),
                              SizedBox(height: 12.h),
                              Text(
                                'لم يتم العثور على حصص مطابقة',
                                style: TextStyle(
                                  fontSize: 14.5.sp,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textSecondary,
                                  fontFamily: 'IBM',
                                ),
                              ),
                              SizedBox(height: 6.h),
                              Text(
                                'جرّب البحث بكلمات أخرى أو اختر فصلاً مختلفاً',
                                style: TextStyle(
                                  fontSize: 12.sp,
                                  color: AppColors.textMuted,
                                  fontFamily: 'IBM',
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 20.w,
                          vertical: 8.h,
                        ),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final group = courseGroups[index];
                              return _buildCourseGroupCard(group);
                            },
                            childCount: courseGroups.length,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            }

            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  int? _extractEpisodeNumber(String? text) {
    if (text == null || text.trim().isEmpty) return null;
    final match = RegExp(
      r'(?:حلقة|الحلقة|الدرس|درس|محاضرة|المحاضرة|part|episode|lesson|#)\s*(\d+)',
      caseSensitive: false,
    ).firstMatch(text);
    if (match != null) {
      return int.tryParse(match.group(1) ?? '');
    }
    final digitsMatch = RegExp(r'(\d+)').firstMatch(text);
    if (digitsMatch != null) {
      return int.tryParse(digitsMatch.group(1) ?? '');
    }
    return null;
  }

  int _compareLecturesAscending(LectureEntity a, LectureEntity b) {
    // 1. Episode/Lesson number has highest priority (e.g. 01 < 02 < 03 < 04 < 05)
    final aLessonNum = _extractEpisodeNumber(a.lessonNumber);
    final bLessonNum = _extractEpisodeNumber(b.lessonNumber);
    if (aLessonNum != null && bLessonNum != null && aLessonNum != bLessonNum) {
      return aLessonNum.compareTo(bLessonNum);
    }
    if (aLessonNum != null && bLessonNum == null) return -1;
    if (aLessonNum == null && bLessonNum != null) return 1;

    // 2. Number extracted from title
    final aTitleNum = _extractEpisodeNumber(a.title);
    final bTitleNum = _extractEpisodeNumber(b.title);
    if (aTitleNum != null && bTitleNum != null && aTitleNum != bTitleNum) {
      return aTitleNum.compareTo(bTitleNum);
    }

    // 3. courseSortOrder if defined
    if (a.courseSortOrder != null &&
        b.courseSortOrder != null &&
        a.courseSortOrder != b.courseSortOrder) {
      return a.courseSortOrder!.compareTo(b.courseSortOrder!);
    }

    // 4. Alphabetical title
    return a.title.compareTo(b.title);
  }

  List<_LectureGroup> _buildLectureGroups(List<LectureEntity> lectures) {
    final groups = <_LectureGroup>[];
    final assignedIds = <String>{};

    // 1. Group by known courses from database
    for (final course in _courses) {
      final courseLessons = _lecturesInCourse(course, lectures);
      if (courseLessons.isNotEmpty) {
        courseLessons.sort(_compareLecturesAscending);
        groups.add(
          _LectureGroup(
            key: 'course_${course['id']}',
            title: course['title'] as String? ?? 'كورس متكامل',
            description: (course['description'] as String? ?? '').trim(),
            lectures: courseLessons,
            courseData: course,
          ),
        );
        for (final l in courseLessons) {
          assignedIds.add(l.id);
        }
      }
    }

    // 2. Group unassigned lectures by chapter (e.g. 'الصوتيات وتعليم القراءة')
    final unassigned =
        lectures.where((l) => !assignedIds.contains(l.id)).toList();
    final byChapter = <String, List<LectureEntity>>{};
    for (final l in unassigned) {
      final ch = l.chapter.trim();
      final key = ch.isNotEmpty
          ? ch
          : (l.subject.trim().isNotEmpty ? l.subject.trim() : 'عام');
      byChapter.putIfAbsent(key, () => []).add(l);
    }

    for (final entry in byChapter.entries) {
      final chapterLessons = entry.value..sort(_compareLecturesAscending);
      final rawTitle = entry.key;
      final displayTitle =
          rawTitle.startsWith('كورس') ? rawTitle : 'كورس $rawTitle';
      groups.add(
        _LectureGroup(
          key: 'chapter_${entry.key}',
          title: displayTitle,
          description:
              'جميع محاضرات وحلقات $rawTitle مرتبة بالتسلسل من الحلقة الأولى.',
          lectures: chapterLessons,
        ),
      );
    }

    return groups;
  }

  Widget _buildCourseGroupCard(_LectureGroup group) {
    final isExpanded = _expandedGroups.contains(group.key) ||
        _searchQuery.trim().isNotEmpty ||
        (_selectedFilter != 'all' && _selectedFilter != 'available');
    final lectures = group.lectures;
    final firstLesson = lectures.isNotEmpty ? lectures.first : null;
    final lastLesson = lectures.length > 1 ? lectures.last : null;

    return Container(
      margin: EdgeInsets.only(bottom: 16.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(
          color: isExpanded
              ? AppColors.primary.withAlpha(140)
              : AppColors.border,
          width: isExpanded ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isExpanded
                ? AppColors.primary.withAlpha(20)
                : Colors.black.withAlpha(8),
            blurRadius: isExpanded ? 16 : 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () {
              setState(() {
                if (_expandedGroups.contains(group.key)) {
                  _expandedGroups.remove(group.key);
                } else {
                  _expandedGroups.add(group.key);
                }
              });
            },
            borderRadius: BorderRadius.circular(20.r),
            child: Padding(
              padding: EdgeInsets.all(16.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48.w,
                        height: 48.w,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF4C1D95), Color(0xFF7C3AED)],
                          ),
                          borderRadius: BorderRadius.circular(14.r),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF7C3AED).withAlpha(40),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.school_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              group.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w800,
                                fontFamily: 'IBM',
                                color: AppColors.textPrimary,
                              ),
                            ),
                            SizedBox(height: 4.h),
                            Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 8.w,
                                    vertical: 2.h,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withAlpha(18),
                                    borderRadius: BorderRadius.circular(8.r),
                                  ),
                                  child: Text(
                                    '${lectures.length} محاضرات مرتبة',
                                    style: TextStyle(
                                      color: AppColors.primary,
                                      fontSize: 11.sp,
                                      fontFamily: 'IBM',
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                if (firstLesson != null && lastLesson != null) ...[
                                  SizedBox(width: 6.w),
                                  Text(
                                    'من ${firstLesson.lessonNumber} إلى ${lastLesson.lessonNumber}',
                                    style: TextStyle(
                                      color: AppColors.textMuted,
                                      fontSize: 10.5.sp,
                                      fontFamily: 'IBM',
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 8.w),
                      AnimatedRotation(
                        turns: isExpanded ? 0.5 : 0.0,
                        duration: const Duration(milliseconds: 250),
                        child: Container(
                          width: 36.w,
                          height: 36.w,
                          decoration: BoxDecoration(
                            color: isExpanded
                                ? AppColors.primary
                                : const Color(0xFFF3F4F6),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: isExpanded
                                ? Colors.white
                                : AppColors.textPrimary,
                            size: 22,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (group.description.isNotEmpty) ...[
                    SizedBox(height: 10.h),
                    Text(
                      group.description,
                      maxLines: isExpanded ? 3 : 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12.sp,
                        fontFamily: 'IBM',
                        height: 1.45,
                      ),
                    ),
                  ],
                  SizedBox(height: 8.h),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isExpanded
                            ? 'اضغط لإخفاء المحاضرات'
                            : 'اضغط لعرض جميع المحاضرات (${lectures.length})',
                        style: TextStyle(
                          fontSize: 11.5.sp,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                          fontFamily: 'IBM',
                        ),
                      ),
                      Icon(
                        isExpanded
                            ? Icons.expand_less_rounded
                            : Icons.expand_more_rounded,
                        size: 18,
                        color: AppColors.primary,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: !isExpanded
                ? const SizedBox.shrink()
                : Padding(
                    padding: EdgeInsets.fromLTRB(14.w, 0, 14.w, 16.h),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Divider(height: 1, color: AppColors.border),
                        SizedBox(height: 14.h),
                        ...lectures.map(
                          (lecture) => Padding(
                            padding: EdgeInsets.only(bottom: 12.h),
                            child: _buildLectureCard(lecture),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  List<LectureEntity> _lecturesInCourse(
    Map<String, dynamic> course,
    List<LectureEntity> allLectures,
  ) {
    final byId = {for (final lecture in allLectures) lecture.id: lecture};
    final lessons = course['course_lectures'] as List<dynamic>? ?? const [];
    final list = lessons
        .map((lesson) => byId[lesson['lecture_id']])
        .whereType<LectureEntity>()
        .toList();

    list.sort(_compareLecturesAscending);
    return list;
  }

  double _courseIndividualPrice(
    Map<String, dynamic> course,
    List<LectureEntity> allLectures,
  ) {
    return _lecturesInCourse(
      course,
      allLectures,
    ).fold(0, (total, lecture) => total + lecture.effectivePrice);
  }

  Widget _buildCourseSavingsBanner(List<LectureEntity> allLectures) {
    if (_coursesLoading || _courses.isEmpty) return const SizedBox.shrink();
    final discounted =
        _courses.where((course) {
          final coursePrice = (course['price'] as num?)?.toDouble() ?? 0;
          return coursePrice > 0 &&
              _courseIndividualPrice(course, allLectures) > coursePrice;
        }).toList()..sort((a, b) {
          final aSaving =
              _courseIndividualPrice(a, allLectures) -
              ((a['price'] as num?)?.toDouble() ?? 0);
          final bSaving =
              _courseIndividualPrice(b, allLectures) -
              ((b['price'] as num?)?.toDouble() ?? 0);
          return bSaving.compareTo(aSaving);
        });
    if (discounted.isEmpty) return const SizedBox.shrink();

    final course = discounted.first;
    final originalPrice = _courseIndividualPrice(course, allLectures);
    final coursePrice = (course['price'] as num).toDouble();
    final saving = originalPrice - coursePrice;
    final percent = ((saving / originalPrice) * 100).round();

    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 6.h),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showCoursePreview(course, allLectures),
          borderRadius: BorderRadius.circular(24.r),
          child: Ink(
            padding: EdgeInsets.all(18.w),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [Color(0xFF4C1D95), Color(0xFF7C3AED)],
              ),
              borderRadius: BorderRadius.circular(24.r),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF7C3AED).withAlpha(55),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 10.w,
                        vertical: 5.h,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFDE68A),
                        borderRadius: BorderRadius.circular(20.r),
                      ),
                      child: Text(
                        'وفر $percent%',
                        style: TextStyle(
                          color: const Color(0xFF78350F),
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'IBM',
                        ),
                      ),
                    ),
                    const Spacer(),
                    const Icon(
                      Icons.workspace_premium_rounded,
                      color: Color(0xFFFDE68A),
                    ),
                  ],
                ),
                SizedBox(height: 10.h),
                Text(
                  course['title'] as String? ?? 'باقة الكورس الكاملة',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'IBM',
                  ),
                ),
                SizedBox(height: 5.h),
                Text(
                  'اشترك في الكورس كامل ووفر ${saving.toStringAsFixed(0)} ج.م بدل شراء كل حصة لوحدها',
                  style: TextStyle(
                    color: Colors.white.withAlpha(220),
                    height: 1.4,
                    fontSize: 12.sp,
                    fontFamily: 'IBM',
                  ),
                ),
                SizedBox(height: 13.h),
                Row(
                  children: [
                    Text(
                      '${coursePrice.toStringAsFixed(0)} ج.م',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 21.sp,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'IBM',
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Text(
                      '${originalPrice.toStringAsFixed(0)} ج.م',
                      style: TextStyle(
                        color: Colors.white60,
                        fontSize: 12.sp,
                        decoration: TextDecoration.lineThrough,
                        decorationColor: Colors.white70,
                        fontFamily: 'IBM',
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'اعرض محتوى الكورس',
                      style: TextStyle(
                        color: const Color(0xFFFDE68A),
                        fontSize: 11.5.sp,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'IBM',
                      ),
                    ),
                    SizedBox(width: 4.w),
                    const Icon(
                      Icons.arrow_back_rounded,
                      color: Color(0xFFFDE68A),
                      size: 18,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showCoursePreview(
    Map<String, dynamic> course,
    List<LectureEntity> allLectures,
  ) async {
    final lessons = _lecturesInCourse(course, allLectures);
    final originalPrice = _courseIndividualPrice(course, allLectures);
    final coursePrice = (course['price'] as num?)?.toDouble() ?? 0;
    final enrolled = _enrolledCourseIds.contains(course['id']);
    final proceed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(sheetContext).height * .86,
        ),
        padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 20.h),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 44.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(8.r),
                ),
              ),
            ),
            SizedBox(height: 18.h),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48.w,
                  height: 48.w,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3E8FF),
                    borderRadius: BorderRadius.circular(15.r),
                  ),
                  child: const Icon(
                    Icons.school_rounded,
                    color: AppColors.primary,
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
                          fontSize: 19.sp,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'IBM',
                        ),
                      ),
                      Text(
                        '${lessons.length} حصة مرتبة داخل باقة واحدة',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12.sp,
                          fontFamily: 'IBM',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 16.h),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: lessons.length,
                separatorBuilder: (_, _) => SizedBox(height: 8.h),
                itemBuilder: (_, index) => Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 12.w,
                    vertical: 10.h,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(13.r),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 13.r,
                        backgroundColor: AppColors.primary.withAlpha(18),
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 10.sp,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      SizedBox(width: 10.w),
                      Expanded(
                        child: Text(
                          lessons[index].title,
                          style: TextStyle(
                            fontSize: 12.5.sp,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'IBM',
                          ),
                        ),
                      ),
                      if (lessons[index].price <= 0 ||
                          lessons[index].effectivePrice <= 0) ...[
                        SizedBox(width: 8.w),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8.w,
                            vertical: 3.h,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(6.r),
                          ),
                          child: Text(
                            'مجانية',
                            style: TextStyle(
                              color: const Color(0xFF16A34A),
                              fontSize: 10.sp,
                              fontWeight: FontWeight.w800,
                              fontFamily: 'IBM',
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(height: 14.h),
            if (!enrolled && originalPrice > coursePrice && coursePrice > 0)
              Container(
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(14.r),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.savings_rounded, color: Color(0xFFD97706)),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Text(
                        'سعر الكورس ${coursePrice.toStringAsFixed(0)} ج.م بدل ${originalPrice.toStringAsFixed(0)} ج.م للحصص منفردة',
                        style: TextStyle(
                          color: const Color(0xFF92400E),
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w800,
                          fontFamily: 'IBM',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            SizedBox(height: 12.h),
            FilledButton.icon(
              onPressed: () => Navigator.of(sheetContext).pop(true),
              icon: Icon(
                enrolled
                    ? Icons.play_arrow_rounded
                    : Icons.shopping_bag_rounded,
              ),
              label: Text(enrolled ? 'ابدأ مشاهدة الكورس' : 'اشترك في الكورس'),
              style: FilledButton.styleFrom(
                minimumSize: Size.fromHeight(52.h),
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15.r),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    if (proceed == true && mounted) await _openOrEnrollCourse(course);
  }

  Widget _buildCourseExpansionCard(
    Map<String, dynamic> course,
    List<LectureEntity> filteredLectures,
  ) {
    final lessons = _lecturesInCourse(course, filteredLectures);
    final price = (course['price'] as num?)?.toDouble() ?? 0;
    final individualPrice = lessons.fold<double>(
      0,
      (total, lecture) => total + lecture.effectivePrice,
    );
    final description = (course['description'] as String? ?? '').trim();
    final isEnrolled = _enrolledCourseIds.contains(course['id']);

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 48.w,
                height: 48.w,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF4C1D95), Color(0xFF7C3AED)],
                  ),
                  borderRadius: BorderRadius.circular(14.r),
                ),
                child: const Icon(
                  Icons.school_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            course['title'] as String? ?? 'كورس',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15.sp,
                              fontWeight: FontWeight.w800,
                              fontFamily: 'IBM',
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        if (isEnrolled)
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 8.w,
                              vertical: 2.h,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDCFCE7),
                              borderRadius: BorderRadius.circular(8.r),
                            ),
                            child: Text(
                              'مشترك بالفعل',
                              style: TextStyle(
                                color: const Color(0xFF15803D),
                                fontSize: 10.sp,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'IBM',
                              ),
                            ),
                          ),
                      ],
                    ),
                    SizedBox(height: 3.h),
                    Text(
                      individualPrice > price && price > 0
                          ? '${lessons.length} حصة • ${price.toStringAsFixed(0)} ج.م بدل ${individualPrice.toStringAsFixed(0)}'
                          : '${lessons.length} حصة • ${price == 0 ? 'مجاني' : '${price.toStringAsFixed(0)} ج.م'}',
                      style: TextStyle(
                        color: individualPrice > price && price > 0
                            ? const Color(0xFF15803D)
                            : AppColors.textSecondary,
                        fontSize: 11.5.sp,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'IBM',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (description.isNotEmpty) ...[
            SizedBox(height: 10.h),
            Text(
              description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.sp,
                color: AppColors.textSecondary,
                fontFamily: 'IBM',
                height: 1.45,
              ),
            ),
          ],
          SizedBox(height: 14.h),
          FilledButton.icon(
            onPressed: () => _showCoursePreview(course, filteredLectures),
            icon: const Icon(Icons.playlist_play_rounded, size: 22),
            label: Text(
              'عرض جميع الحلقات (${lessons.length} حلقة)',
              style: const TextStyle(
                fontFamily: 'IBM',
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              minimumSize: Size.fromHeight(44.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendedCoursesSection(List<LectureEntity> allLectures) {
    if (_assessmentLoading || _coursesLoading) {
      return const SizedBox.shrink();
    }

    final result = _assessmentResult;
    if (result == null) {
      return Padding(
        padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 16.h),
        child: InkWell(
          onTap: () =>
              context.push(AppRoutes.levelAssessmentIntro, extra: false),
          borderRadius: BorderRadius.circular(18.r),
          child: Ink(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F3FF),
              borderRadius: BorderRadius.circular(18.r),
              border: Border.all(color: const Color(0xFFDDD6FE)),
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(10.w),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(20),
                    borderRadius: BorderRadius.circular(13.r),
                  ),
                  child: const Icon(
                    Icons.auto_awesome_rounded,
                    color: AppColors.primary,
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'كورسات مناسبة لمستواك',
                        style: TextStyle(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'IBM',
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        'حدد مستواك أولًا عشان نرشحلك الأنسب',
                        style: TextStyle(
                          fontSize: 11.5.sp,
                          fontFamily: 'IBM',
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_back_rounded, color: AppColors.primary),
              ],
            ),
          ),
        ),
      );
    }

    final expected = result.overallLevel.databaseValue;
    final recommended = _courses.where((course) {
      if (_enrolledCourseIds.contains(course['id'])) return false;
      final raw = (course['level'] as String? ?? '').trim().toLowerCase();
      final normalized = switch (raw) {
        'مبتدئ' || 'مبتدأ' => 'beginner',
        'متوسط' => 'intermediate',
        'متميز' => 'distinguished',
        'أسطوري' || 'اسطوري' => 'legendary',
        _ => raw,
      };
      return normalized == expected;
    }).toList();

    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 16.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _buildSectionTitle(
                  'كورسات مناسبة لمستواك',
                  recommended.length,
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 9.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Text(
                  result.overallLevel.arabicName,
                  style: TextStyle(
                    color: const Color(0xFF047857),
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'IBM',
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () => context.push(AppRoutes.recommendedCourses),
                icon: const Icon(Icons.arrow_back_rounded, size: 17),
                label: const Text(
                  'الكل',
                  style: TextStyle(
                    fontFamily: 'IBM',
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          if (recommended.isEmpty)
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(
                'هنضيف كورسات جديدة لمستوى ${result.overallLevel.arabicName} قريبًا',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'IBM',
                  color: AppColors.textSecondary,
                ),
              ),
            )
          else
            _buildRecommendedGrid(
              recommended,
              allLectures,
              result.overallLevel.arabicName,
            ),
        ],
      ),
    );
  }

  Widget _buildRecommendedGrid(
    List<Map<String, dynamic>> courses,
    List<LectureEntity> allLectures,
    String levelName,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 500;
        final crossAxisCount = isWide ? 2 : 1;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 12.w,
            mainAxisSpacing: 12.h,
            mainAxisExtent: 168.h,
          ),
          itemCount: courses.length,
          itemBuilder: (context, index) {
            final course = courses[index];
            final lessons = _lecturesInCourse(course, allLectures);
            final price = (course['price'] as num?)?.toDouble() ?? 0;
            final description = (course['description'] as String? ?? '').trim();

            return Container(
              padding: EdgeInsets.all(14.w),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  colors: [Color(0xFF312E81), Color(0xFF6D28D9)],
                ),
                borderRadius: BorderRadius.circular(18.r),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6D28D9).withAlpha(35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8.w,
                          vertical: 3.h,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(35),
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        child: Text(
                          levelName,
                          style: TextStyle(
                            color: const Color(0xFFFDE68A),
                            fontSize: 10.5.sp,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'IBM',
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        price == 0
                            ? 'مجاني'
                            : '${price.toStringAsFixed(0)} ج.م',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w800,
                          fontFamily: 'IBM',
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    course['title'] as String? ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14.5.sp,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'IBM',
                    ),
                  ),
                  SizedBox(height: 3.h),
                  Text(
                    description.isNotEmpty
                        ? description
                        : '${lessons.length} حصة مرتبة ومناسبة لمستواك',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withAlpha(200),
                      fontSize: 11.sp,
                      fontFamily: 'IBM',
                    ),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    height: 38.h,
                    child: ElevatedButton.icon(
                      onPressed: () => _showCoursePreview(course, allLectures),
                      icon: const Icon(Icons.playlist_play_rounded, size: 19),
                      label: Text(
                        'عرض جميع الحلقات (${lessons.length})',
                        style: TextStyle(
                          fontSize: 11.5.sp,
                          fontWeight: FontWeight.w800,
                          fontFamily: 'IBM',
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.primary,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10.r),
                        ),
                        padding: EdgeInsets.symmetric(horizontal: 10.w),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCoursesSection(List<LectureEntity> allLectures) {
    if (_coursesLoading) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: LinearProgressIndicator(color: AppColors.primary),
      );
    }
    if (_courses.isEmpty) return const SizedBox.shrink();

    final subscriptions = _courses
        .where((course) => _enrolledCourseIds.contains(course['id']))
        .toList();
    final available = _courses
        .where((course) => !_enrolledCourseIds.contains(course['id']))
        .toList();

    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 16.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('اشتراكاتي', subscriptions.length),
          SizedBox(height: 10.h),
          if (subscriptions.isEmpty)
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(14.w),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(color: AppColors.border),
              ),
              child: const Text(
                'لا توجد كورسات مشترَك بها حتى الآن',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'IBM',
                  color: AppColors.textSecondary,
                ),
              ),
            )
          else
            _buildCourseCarousel(subscriptions, allLectures, enrolled: true),
          if (available.isNotEmpty) ...[
            SizedBox(height: 18.h),
            _buildSectionTitle('كورسات متاحة للاشتراك', available.length),
            SizedBox(height: 10.h),
            _buildCourseCarousel(available, allLectures, enrolled: false),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, int count) {
    return Row(
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 17.sp,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            fontFamily: 'IBM',
          ),
        ),
        SizedBox(width: 8.w),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
          decoration: BoxDecoration(
            color: AppColors.primary.withAlpha(18),
            borderRadius: BorderRadius.circular(10.r),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w800,
              fontSize: 11.sp,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCourseCarousel(
    List<Map<String, dynamic>> courses,
    List<LectureEntity> allLectures, {
    required bool enrolled,
  }) {
    return SizedBox(
      height: 150.h,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: courses.length,
        separatorBuilder: (_, _) => SizedBox(width: 12.w),
        itemBuilder: (context, index) =>
            _buildCourseCard(courses[index], allLectures, enrolled: enrolled),
      ),
    );
  }

  Widget _buildCourseCard(
    Map<String, dynamic> course,
    List<LectureEntity> allLectures, {
    required bool enrolled,
  }) {
    final lessons = course['course_lectures'] as List<dynamic>? ?? const [];
    final price = (course['price'] as num?)?.toDouble() ?? 0;
    return Container(
      width: 350.w,
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: enrolled
              ? const [Color(0xFF047857), Color(0xFF10B981)]
              : const [Color(0xFF312E81), Color(0xFF7C3AED)],
        ),
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            course['title'] as String? ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white,
              fontSize: 15.sp,
              fontWeight: FontWeight.w800,
              fontFamily: 'IBM',
            ),
          ),
          SizedBox(height: 5.h),
          Text(
            '${lessons.length} حصة • ${price == 0 ? 'مجاني' : '${price.toStringAsFixed(0)} ج.م'}',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 11.5.sp,
              fontFamily: 'IBM',
            ),
          ),
          const Spacer(),
          Align(
            alignment: Alignment.centerLeft,
            child: ElevatedButton.icon(
              onPressed: () => _showCoursePreview(course, allLectures),
              icon: Icon(
                enrolled ? Icons.play_arrow_rounded : Icons.lock_open_rounded,
                size: 18,
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.primary,
                elevation: 0,
              ),
              label: Text(enrolled ? 'مشاهدة الكورس' : 'اشترك الآن'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOffersSection() {
    if (_offersLoading) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 8.h),
        child: const LinearProgressIndicator(color: AppColors.primary),
      );
    }
    if (_offers.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 18.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'العروض المتاحة',
            style: TextStyle(
              fontSize: 17.sp,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
              fontFamily: 'IBM',
            ),
          ),
          SizedBox(height: 10.h),
          SizedBox(
            height: 142.h,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _offers.length,
              separatorBuilder: (_, _) => SizedBox(width: 10.w),
              itemBuilder: (context, index) {
                final offer = _offers[index];
                final purchased = offer.isPurchased;
                return InkWell(
                  onTap: purchased
                      ? () => ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'العرض ده تم شراؤه ومحتواه متاح عندك',
                            ),
                            behavior: SnackBarBehavior.floating,
                          ),
                        )
                      : () => OfferPurchaseSheet.show(
                          context,
                          offer,
                          onActivated: () async {
                            await Future.wait([
                              context.read<LecturesListCubit>().loadLectures(),
                              _loadCourses(),
                              _loadOffers(),
                            ]);
                          },
                        ),
                  borderRadius: BorderRadius.circular(18.r),
                  child: Container(
                    width: 270.w,
                    padding: EdgeInsets.all(14.w),
                    decoration: BoxDecoration(
                      color: purchased
                          ? const Color(0xFFF0FDF4)
                          : const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(18.r),
                      border: Border.all(
                        color: purchased
                            ? const Color(0xFF22C55E)
                            : const Color(0xFFF59E0B),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (purchased)
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 9.w,
                              vertical: 4.h,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDCFCE7),
                              borderRadius: BorderRadius.circular(20.r),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.check_circle_rounded,
                                  size: 15,
                                  color: Color(0xFF16A34A),
                                ),
                                SizedBox(width: 4.w),
                                const Text(
                                  'تم الشراء',
                                  style: TextStyle(
                                    color: Color(0xFF15803D),
                                    fontWeight: FontWeight.w900,
                                    fontFamily: 'IBM',
                                  ),
                                ),
                              ],
                            ),
                          )
                        else if (offer.badgeText?.isNotEmpty == true)
                          Text(
                            offer.badgeText!,
                            style: TextStyle(
                              color: const Color(0xFFB45309),
                              fontSize: 10.5.sp,
                              fontWeight: FontWeight.w800,
                              fontFamily: 'IBM',
                            ),
                          ),
                        Text(
                          offer.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'IBM',
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${offer.contentCount} حصة • ${offer.offerPrice.toStringAsFixed(0)} ج.م',
                          style: TextStyle(
                            color: purchased
                                ? const Color(0xFF15803D)
                                : AppColors.primary,
                            fontWeight: FontWeight.w800,
                            fontSize: 12.sp,
                            fontFamily: 'IBM',
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDownloadsSection() {
    if (_downloadsLoading) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 8.h),
        child: const LinearProgressIndicator(color: AppColors.primary),
      );
    }
    if (_downloads.isEmpty) return const SizedBox.shrink();

    final groups = <String, List<DownloadedLecture>>{};
    for (final download in _downloads) {
      groups.putIfAbsent(download.groupId, () => []).add(download);
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 18.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'تنزيلاتي',
                style: TextStyle(
                  fontSize: 17.sp,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                  fontFamily: 'IBM',
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 9.w, vertical: 3.h),
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(20),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Text(
                  '${_downloads.length} درس',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 11.sp,
                    fontFamily: 'IBM',
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          ...groups.values.map((items) {
            final first = items.first;
            return Card(
              margin: EdgeInsets.only(bottom: 8.h),
              elevation: 0,
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.r),
                side: const BorderSide(color: AppColors.borderLight),
              ),
              child: ExpansionTile(
                leading: Container(
                  padding: EdgeInsets.all(8.w),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(18),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    first.groupType == 'course'
                        ? Icons.school_rounded
                        : Icons.menu_book_rounded,
                    color: AppColors.primary,
                  ),
                ),
                title: Text(
                  first.groupTitle,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontFamily: 'IBM',
                    fontSize: 14.sp,
                  ),
                ),
                subtitle: Text(
                  '${items.length} فيديو محفوظ',
                  textAlign: TextAlign.right,
                  style: TextStyle(fontFamily: 'IBM', fontSize: 11.sp),
                ),
                children: items.map((download) {
                  return ListTile(
                    onTap: () async {
                      await Navigator.of(context).push<void>(
                        MaterialPageRoute(
                          builder: (_) =>
                              OfflineLectureScreen(lecture: download),
                        ),
                      );
                      _loadDownloads();
                    },
                    leading: const Icon(
                      Icons.play_circle_fill_rounded,
                      color: AppColors.primary,
                    ),
                    title: Text(
                      download.title,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontFamily: 'IBM',
                      ),
                    ),
                    subtitle: Text(
                      '${download.lessonNumber} • ${download.chapter}',
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontFamily: 'IBM'),
                    ),
                    trailing: IconButton(
                      tooltip: 'حذف التنزيل',
                      icon: const Icon(Icons.delete_outline_rounded),
                      onPressed: () async {
                        await OfflineLectureService.instance.deleteDownload(
                          download.lectureId,
                        );
                        await _loadDownloads();
                      },
                    ),
                  );
                }).toList(),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedFilter == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilter = value;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withAlpha(40),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : [],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.sp,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected ? Colors.white : AppColors.textSecondary,
            fontFamily: 'IBM',
          ),
        ),
      ),
    );
  }

  Widget _buildLectureCard(LectureEntity lecture) {
    // Find video duration
    final videoContent = lecture.contents
        .where((c) => c.contentType == ContentType.video)
        .firstOrNull;
    final durationMinutes =
        (videoContent != null && videoContent.durationSeconds > 0)
        ? (videoContent.durationSeconds / 60).ceil()
        : null;

    final hasPdf = lecture.contents.any(
      (c) => c.contentType == ContentType.pdf,
    );
    final hasAudio = lecture.contents.any(
      (c) => c.contentType == ContentType.audio,
    );
    final hasSummary = lecture.contents.any(
      (c) => c.contentType == ContentType.summary,
    );
    final hasExam = lecture.attachedExamId != null;

    final isFree = lecture.price <= 0 || lecture.effectivePrice <= 0;
    final hasAccess = lecture.hasAccess || isFree;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22.r),
        border: Border.all(color: AppColors.border.withAlpha(80)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22.r),
          onTap: () async {
            if (hasAccess) {
              await context.push(AppRoutes.lectureDetails, extra: lecture.id);
              await _loadDownloads();
            } else {
              _openLecturePurchase(lecture);
            }
          },
          child: Padding(
            padding: EdgeInsets.all(16.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Card Top Header: Lesson & Chapter + Access Tag (FIXED OVERFLOW)
                Row(
                  children: [
                    // Chapter & Lesson Tag (Flexible to prevent horizontal overflow)
                    Expanded(
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 10.w,
                          vertical: 4.h,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3E8FF),
                          borderRadius: BorderRadius.circular(10.r),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.auto_stories_rounded,
                              size: 13.sp,
                              color: const Color(0xFF7C3AED),
                            ),
                            SizedBox(width: 4.w),
                            Flexible(
                              child: Text(
                                '${lecture.lessonNumber} • ${lecture.chapter}',
                                style: TextStyle(
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF7C3AED),
                                  fontFamily: 'IBM',
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(width: 8.w),

                    // Access / Free / Center Discount Badge
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 10.w,
                        vertical: 4.h,
                      ),
                      decoration: BoxDecoration(
                        color: hasAccess
                            ? const Color(0xFFDCFCE7)
                            : (lecture.isCenterStudent
                                  ? const Color(0xFFE0E7FF)
                                  : const Color(0xFFFEF3C7)),
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            hasAccess
                                ? (isFree
                                      ? Icons.card_giftcard_rounded
                                      : Icons.check_circle_rounded)
                                : (lecture.isCenterStudent
                                      ? Icons.school_rounded
                                      : Icons.lock_rounded),
                            size: 12.sp,
                            color: hasAccess
                                ? const Color(0xFF16A34A)
                                : (lecture.isCenterStudent
                                      ? const Color(0xFF4F46E5)
                                      : const Color(0xFFD97706)),
                          ),
                          SizedBox(width: 4.w),
                          Text(
                            isFree
                                ? 'مجانية'
                                : (hasAccess
                                      ? 'متاح للبدء'
                                      : (lecture.isCenterStudent
                                            ? '${lecture.centerPrice.toStringAsFixed(0)} ج.م (خصم السنتر)'
                                            : '${lecture.price.toStringAsFixed(0)} ج.م')),
                            style: TextStyle(
                              fontSize: 10.5.sp,
                              fontWeight: FontWeight.w800,
                              color: hasAccess
                                  ? const Color(0xFF16A34A)
                                  : (lecture.isCenterStudent
                                        ? const Color(0xFF4F46E5)
                                        : const Color(0xFFD97706)),
                              fontFamily: 'IBM',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12.h),

                // Main Info Row: Thumbnail + Title & Teacher
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Thumbnail Container
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16.r),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 88.w,
                            height: 88.w,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              image: DecorationImage(
                                image: NetworkImage(
                                  lecture.thumbnailUrl ??
                                      'https://uzcikwdwnbxmqwulagxk.supabase.co/storage/v1/object/public/q360-content/app_logo.jpg',
                                ),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          Container(
                            width: 88.w,
                            height: 88.w,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withAlpha(120),
                                ],
                              ),
                            ),
                          ),
                          // Play or Lock Icon Circle
                          Container(
                            width: 36.w,
                            height: 36.w,
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(220),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withAlpha(40),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Icon(
                                hasAccess
                                    ? Icons.play_arrow_rounded
                                    : Icons.lock_rounded,
                                color: hasAccess
                                    ? AppColors.primary
                                    : const Color(0xFFD97706),
                                size: hasAccess ? 24 : 18,
                              ),
                            ),
                          ),
                          // Duration Pill
                          if (durationMinutes != null)
                            Positioned(
                              bottom: 4.h,
                              right: 4.w,
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 5.w,
                                  vertical: 2.h,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withAlpha(180),
                                  borderRadius: BorderRadius.circular(6.r),
                                ),
                                child: Text(
                                  '$durationMinutes د',
                                  style: TextStyle(
                                    fontSize: 9.sp,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                    fontFamily: 'IBM',
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    SizedBox(width: 14.w),

                    // Lecture Title, Description, and Teacher
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            lecture.title,
                            style: TextStyle(
                              fontSize: 15.sp,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                              fontFamily: 'IBM',
                              height: 1.3,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 4.h),
                          if (lecture.description.isNotEmpty)
                            Text(
                              lecture.description,
                              style: TextStyle(
                                fontSize: 11.5.sp,
                                color: AppColors.textSecondary,
                                fontFamily: 'IBM',
                                height: 1.4,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          SizedBox(height: 8.h),
                          // Teacher Info Row
                          Row(
                            children: [
                              Container(
                                width: 22.w,
                                height: 22.w,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.primary.withAlpha(30),
                                  image: lecture.teacherAvatarUrl != null
                                      ? DecorationImage(
                                          image: NetworkImage(
                                            lecture.teacherAvatarUrl!,
                                          ),
                                          fit: BoxFit.cover,
                                        )
                                      : null,
                                ),
                                child: lecture.teacherAvatarUrl == null
                                    ? Center(
                                        child: Icon(
                                          Icons.person_rounded,
                                          size: 14.sp,
                                          color: AppColors.primary,
                                        ),
                                      )
                                    : null,
                              ),
                              SizedBox(width: 6.w),
                              Expanded(
                                child: Text(
                                  '${lecture.teacherName} • ${lecture.teacherTitle}',
                                  style: TextStyle(
                                    fontSize: 11.sp,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                    fontFamily: 'IBM',
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 10.h),

                // Divider
                Divider(color: AppColors.border.withAlpha(100), height: 1),
                SizedBox(height: 10.h),

                // Bottom Content Badges & Action CTA
                Row(
                  children: [
                    // Content Badges
                    Expanded(
                      child: Wrap(
                        spacing: 6.w,
                        runSpacing: 4.h,
                        children: [
                          if (videoContent != null)
                            _buildMediaBadge(
                              Icons.play_circle_fill_rounded,
                              'فيديو',
                              const Color(0xFF3B82F6),
                            ),
                          if (hasPdf)
                            _buildMediaBadge(
                              Icons.picture_as_pdf_rounded,
                              'PDF',
                              const Color(0xFFEF4444),
                            ),
                          if (hasAudio)
                            _buildMediaBadge(
                              Icons.headphones_rounded,
                              'صوتي',
                              const Color(0xFF10B981),
                            ),
                          if (hasSummary)
                            _buildMediaBadge(
                              Icons.article_rounded,
                              'ملخص',
                              const Color(0xFF8B5CF6),
                            ),
                          if (hasExam)
                            _buildMediaBadge(
                              Icons.quiz_rounded,
                              'امتحان',
                              const Color(0xFFF59E0B),
                            ),
                        ],
                      ),
                    ),
                    SizedBox(width: 8.w),

                    // Arrow / CTA
                    GestureDetector(
                      onTap: () {
                        if (hasAccess) {
                          context.push(
                            AppRoutes.lectureDetails,
                            extra: lecture.id,
                          );
                        } else {
                          _openLecturePurchase(lecture);
                        }
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 10.w,
                          vertical: 6.h,
                        ),
                        decoration: BoxDecoration(
                          color: hasAccess
                              ? AppColors.primary
                              : const Color(0xFF10B981),
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              hasAccess ? 'ابدأ المحاضرة' : 'شراء الحصة',
                              style: TextStyle(
                                fontSize: 11.5.sp,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                fontFamily: 'IBM',
                              ),
                            ),
                            SizedBox(width: 4.w),
                            Icon(
                              hasAccess
                                  ? Icons.arrow_forward_ios_rounded
                                  : Icons.shopping_bag_outlined,
                              color: Colors.white,
                              size: 11.sp,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMediaBadge(IconData icon, String label, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12.sp, color: color),
          SizedBox(width: 3.w),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.sp,
              fontWeight: FontWeight.w700,
              color: color,
              fontFamily: 'IBM',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerLoading() {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
      child: Shimmer.fromColors(
        baseColor: Colors.grey.shade300,
        highlightColor: Colors.grey.shade100,
        child: Column(
          children: [
            Container(
              height: 48.h,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16.r),
              ),
            ),
            SizedBox(height: 14.h),
            Row(
              children: [
                Container(
                  width: 80.w,
                  height: 32.h,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
                SizedBox(width: 8.w),
                Container(
                  width: 100.w,
                  height: 32.h,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
                SizedBox(width: 8.w),
                Container(
                  width: 90.w,
                  height: 32.h,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
              ],
            ),
            SizedBox(height: 20.h),
            ...List.generate(
              3,
              (index) => Padding(
                padding: EdgeInsets.only(bottom: 16.h),
                child: Container(
                  height: 160.h,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22.r),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LectureGroup {
  final String key;
  final String title;
  final String description;
  final List<LectureEntity> lectures;
  final Map<String, dynamic>? courseData;

  const _LectureGroup({
    required this.key,
    required this.title,
    required this.description,
    required this.lectures,
    this.courseData,
  });
}

