import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../novels/domain/novel_entities.dart';
import '../../../podcasts/data/repositories/podcasts_repository.dart';
import '../../../podcasts/domain/entities/podcast_entity.dart';
import '../../../podcasts/presentation/screens/podcast_player_screen.dart';
import '../../../poetry/data/repositories/poetry_repository.dart';
import '../cubits/home/home_cubit.dart';
import '../cubits/home/home_state.dart';
import '../widgets/banners_carousel_widget.dart';
import '../widgets/home_header_widget.dart';
import '../widgets/live_leaderboard_widget.dart';
import '../widgets/platform_promo_video_card.dart';
import '../widgets/upcoming_exam_card_widget.dart';
import '../../domain/entities/banner_entity.dart';
import '../../data/services/platform_feedback_service.dart';
import '../widgets/platform_feedback_dialog.dart';
import '../../../lectures/data/services/commerce_offer_service.dart';
import '../../../lectures/data/services/learning_activity_service.dart';
import '../../../lectures/data/services/offline_lecture_service.dart';
import '../../../lectures/domain/entities/commerce_offer_entity.dart';
import '../../../lectures/domain/entities/lecture_content_entity.dart';
import '../../../lectures/presentation/screens/offline_lecture_screen.dart';
import '../../../lectures/presentation/widgets/offer_purchase_sheet.dart';
import '../../../level_assessment/data/services/level_assessment_service.dart';
import '../../../level_assessment/domain/entities/level_assessment.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.refreshSignal = 0});

  final int refreshSignal;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  List<CommerceOfferEntity> _offers = const [];
  CommerceOfferEntity? _courseSavingOffer;
  LearningActivity? _continueActivity;
  List<DownloadedLecture> _offlineDownloads = const [];
  LevelAssessmentResult? _assessmentResult;
  List<PodcastEpisode> _podcasts = const [];
  final PodcastsRepository _podcastsRepo = PodcastsRepository();
  List<Novel> _poems = const [];
  final PoetryRepository _poetryRepo = PoetryRepository();
  late final AnimationController _entranceController;
  bool _hasStartedEntranceAnimation = false;
  bool _feedbackPromptScheduled = false;
  Timer? _feedbackSyncTimer;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    context.read<HomeCubit>().loadHomeData();
    _loadOffers();
    _loadCourseSavingOffer();
    _loadContinueActivity();
    _loadOfflineDownloads();
    _loadAssessmentResult();
    _loadPodcasts();
    _loadPoems();
    unawaited(PlatformFeedbackService.instance.syncPending());
    _feedbackSyncTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => unawaited(PlatformFeedbackService.instance.syncPending()),
    );
  }

  @override
  void dispose() {
    _feedbackSyncTimer?.cancel();
    _entranceController.dispose();
    super.dispose();
  }

  Future<void> _maybeRequestFeedback(String studentName) async {
    if (_feedbackPromptScheduled) return;
    _feedbackPromptScheduled = true;
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) return;

    final accountCreatedAt = DateTime.tryParse(currentUser.createdAt);
    if (accountCreatedAt == null ||
        !PlatformFeedbackService.isInitialFeedbackEligible(
          accountCreatedAt: accountCreatedAt,
        )) {
      return;
    }
    final userId = currentUser.id;

    final feedback = PlatformFeedbackService.instance;
    await feedback.refreshStatusFromRemote(userId);
    if (!await feedback.isDue(userId) || !mounted) return;
    final isRequired = !await feedback.hasCompletedInitialFeedback(userId);
    if (!mounted) return;

    final draft = await showPlatformFeedbackDialog(
      context,
      isRequired: isRequired,
    );
    if (!mounted) return;
    if (draft == null) {
      if (!isRequired) await feedback.markSkipped(userId);
      return;
    }

    final uploaded = await feedback.submit(
      userId: userId,
      studentName: studentName,
      draft: draft,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          uploaded
              ? 'شكرًا، تم إرسال تقييمك.'
              : 'تم حفظ تقييمك وسنرسله تلقائيًا عند عودة الإنترنت.',
        ),
      ),
    );
  }

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshSignal != widget.refreshSignal) {
      _loadContinueActivity();
      _loadOfflineDownloads();
      _loadAssessmentResult();
      _loadPodcasts();
      _loadPoems();
    }
  }

  Future<void> _loadPodcasts() async {
    try {
      final episodes = await _podcastsRepo.fetchEpisodes();
      if (mounted) setState(() => _podcasts = episodes);
    } catch (_) {}
  }

  Future<void> _loadPoems() async {
    try {
      final poems = await _poetryRepo.fetchPoems();
      if (mounted) setState(() => _poems = poems);
    } catch (_) {}
  }

  Future<void> _loadContinueActivity() async {
    final activity = await LearningActivityService.instance.latestActivity();
    if (mounted) setState(() => _continueActivity = activity);
  }

  Future<void> _loadOfflineDownloads() async {
    final downloads = await OfflineLectureService.instance.getDownloads();
    if (mounted) setState(() => _offlineDownloads = downloads);
  }

  Future<void> _loadAssessmentResult() async {
    try {
      final result = await LevelAssessmentService.instance.latestResult();
      if (mounted) setState(() => _assessmentResult = result);
    } catch (_) {}
  }

  Future<void> _loadOffers() async {
    try {
      final offers = await CommerceOfferService.instance.getActiveOffers();
      if (mounted) setState(() => _offers = offers);
    } catch (_) {}
  }

  Future<void> _loadCourseSavingOffer() async {
    try {
      final client = Supabase.instance.client;
      final List<dynamic> courseRows = await client
          .from('courses')
          .select(
            'id, title, description, price, course_lectures(lecture_id, sort_order, lectures(title, online_price, price, is_published))',
          )
          .eq('teacher_id', AppConstants.activeTeacherId)
          .eq('is_published', true)
          .order('created_at', ascending: false);

      final List<dynamic> directLectureRows = await client
          .from('lectures')
          .select('id, course_id, title, online_price, price')
          .eq('teacher_id', AppConstants.activeTeacherId)
          .eq('is_published', true);
      final directByCourse = <String, List<Map<String, dynamic>>>{};
      for (final raw in directLectureRows) {
        final lecture = Map<String, dynamic>.from(raw as Map);
        final courseId = lecture['course_id'] as String?;
        if (courseId != null) {
          directByCourse.putIfAbsent(courseId, () => []).add(lecture);
        }
      }

      final enrolledCourseIds = <String>{};
      final userId = client.auth.currentUser?.id;
      if (userId != null) {
        final List<dynamic> enrollmentRows = await client
            .from('course_enrollments')
            .select('course_id')
            .eq('student_id', userId)
            .eq('status', 'active');
        enrolledCourseIds.addAll(
          enrollmentRows
              .map((row) => row['course_id'] as String?)
              .whereType<String>(),
        );
        final List<dynamic> entitlementRows = await client
            .from('student_entitlements')
            .select('course_id')
            .eq('item_type', 'course')
            .eq('is_active', true);
        enrolledCourseIds.addAll(
          entitlementRows
              .map((row) => row['course_id'] as String?)
              .whereType<String>(),
        );
      }

      CommerceOfferEntity? bestOffer;
      double bestSaving = 0;
      for (final raw in courseRows) {
        final course = Map<String, dynamic>.from(raw as Map);
        final courseId = course['id'] as String?;
        final coursePrice = (course['price'] as num?)?.toDouble() ?? 0;
        if (courseId == null ||
            enrolledCourseIds.contains(courseId) ||
            coursePrice <= 0) {
          continue;
        }

        final lessons = <String, Map<String, dynamic>>{};
        for (final rawMapping
            in course['course_lectures'] as List<dynamic>? ?? const []) {
          final mapping = Map<String, dynamic>.from(rawMapping as Map);
          final lectureId = mapping['lecture_id'] as String?;
          final lecture = mapping['lectures'];
          if (lectureId != null &&
              lecture is Map &&
              lecture['is_published'] != false) {
            lessons[lectureId] = Map<String, dynamic>.from(lecture);
          }
        }
        for (final lecture in directByCourse[courseId] ?? const []) {
          final lectureId = lecture['id'] as String?;
          if (lectureId != null) lessons.putIfAbsent(lectureId, () => lecture);
        }

        final individualPrice = lessons.values.fold<double>(0, (total, item) {
          final price =
              (item['online_price'] as num?)?.toDouble() ??
              (item['price'] as num?)?.toDouble() ??
              0;
          return total + price;
        });
        final saving = individualPrice - coursePrice;
        if (lessons.isEmpty || saving <= bestSaving) continue;

        bestSaving = saving;
        bestOffer = CommerceOfferEntity(
          id: courseId,
          title: course['title'] as String? ?? 'الكورس الكامل',
          description: course['description'] as String? ?? '',
          badgeText: 'وفر مع الكورس الكامل',
          originalPrice: individualPrice,
          offerPrice: coursePrice,
          currency: 'EGP',
          isDirectPurchase: true,
          items: [
            CommerceOfferItemEntity(
              id: courseId,
              itemType: 'course',
              itemId: courseId,
              title: course['title'] as String? ?? 'الكورس الكامل',
              includedLectureTitles: lessons.values
                  .map((item) => item['title'] as String? ?? 'حصة')
                  .toList(),
            ),
          ],
        );
      }

      if (mounted) setState(() => _courseSavingOffer = bestOffer);
    } catch (_) {
      if (mounted) setState(() => _courseSavingOffer = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: BlocBuilder<HomeCubit, HomeState>(
          builder: (context, state) {
            if (state is HomeLoading || state is HomeInitial) {
              if (_offlineDownloads.isNotEmpty) {
                return _buildOfflineHome();
              }
              return _buildShimmerLoading();
            }

            if (state is HomeError) {
              if (_offlineDownloads.isNotEmpty) {
                return _buildOfflineHome(message: state.message);
              }
              return Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20.w),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.error_outline_rounded,
                        size: 48.w,
                        color: AppColors.error,
                      ),
                      SizedBox(height: 12.h),
                      Text(
                        state.message,
                        style: TextStyle(
                          fontSize: 14.sp,
                          color: AppColors.textSecondary,
                          fontFamily: 'IBM',
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 16.h),
                      ElevatedButton(
                        onPressed: () {
                          context.read<HomeCubit>().loadHomeData();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                        ),
                        child: const Text('إعادة المحاولة'),
                      ),
                    ],
                  ),
                ),
              );
            }

            if (state is HomeLoaded) {
              if (!_hasStartedEntranceAnimation) {
                _hasStartedEntranceAnimation = true;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;
                  if (MediaQuery.disableAnimationsOf(context)) {
                    _entranceController.value = 1;
                  } else {
                    _entranceController.forward();
                  }
                });
              }
              final summary = state.summary;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  unawaited(_maybeRequestFeedback(summary.studentName));
                }
              });
              final offerBanners = _offers
                  .map(
                    (offer) => BannerEntity(
                      id: 'offer_${offer.id}',
                      title: offer.title,
                      subtitle: offer.description.isNotEmpty
                          ? offer.description
                          : '${offer.contentCount} حصة بسعر ${offer.offerPrice.toStringAsFixed(0)} ج.م',
                      buttonText: 'عرض المحتوى والسعر',
                      imageUrl: offer.imageUrl,
                      offerId: offer.id,
                    ),
                  )
                  .toList();

              return RefreshIndicator(
                color: AppColors.primary,
                onRefresh: () async {
                  await Future.wait([
                    context.read<HomeCubit>().loadHomeData(),
                    _loadOffers(),
                    _loadCourseSavingOffer(),
                    _loadContinueActivity(),
                    _loadOfflineDownloads(),
                    _loadAssessmentResult(),
                    _loadPodcasts(),
                    _loadPoems(),
                  ]);
                },
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      padding: EdgeInsets.symmetric(vertical: 12.h),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // 1. Header (Greeting + Integrated Level Display + Points + Notifications)
                          _buildEntrance(
                            start: 0,
                            end: 0.35,
                            child: Padding(
                              padding: EdgeInsets.symmetric(horizontal: 20.w),
                              child: HomeHeaderWidget(
                                studentName: summary.studentName,
                                grade: summary.grade,
                                assessmentLevel:
                                    _assessmentResult?.overallLevel.arabicName,
                                points: summary.points,
                                unreadNotificationsCount:
                                    summary.unreadNotificationsCount,
                                onNotificationTap: () {
                                  context.push(AppRoutes.notifications);
                                },
                                onPointsTap: () {
                                  context.push(AppRoutes.leaderboard);
                                },
                                onLevelTap: () {
                                  context.push(
                                    AppRoutes.levelAssessmentIntro,
                                    extra: false,
                                  );
                                },
                              ),
                            ),
                          ),
                          SizedBox(height: 20.h),

                          // 2. Enlarged Banners Carousel (Hero Section)
                          _buildEntrance(
                            start: 0.05,
                            end: 0.45,
                            offset: const Offset(0, 0.08),
                            child: BannersCarouselWidget(
                              banners: [...offerBanners, ...summary.banners],
                              onBannerTap: (banner) {
                                if (banner.offerId != null) {
                                  final offer = _offers.firstWhere(
                                    (item) => item.id == banner.offerId,
                                  );
                                  OfferPurchaseSheet.show(context, offer);
                                  return;
                                }
                                if (banner.actionRoute != null) {
                                  context.push(banner.actionRoute!);
                                }
                              },
                            ),
                          ),
                          SizedBox(height: 24.h),

                          // 3. Continue Learning Section (Prioritized for immediate study continuation)
                          if (_continueActivity != null) ...[
                            _buildEntrance(
                              start: 0.1,
                              end: 0.5,
                              child: _buildContinueSection(_continueActivity!),
                            ),
                            SizedBox(height: 24.h),
                          ],

                          // 4. Feature Tools Grid (Divided 2x2 Grid: Novels, Study Env, Abu Al Areef, Level Assessment)
                          _buildEntrance(
                            start: 0.15,
                            end: 0.55,
                            child: _buildFeatureToolsGrid(),
                          ),
                          SizedBox(height: 24.h),

                          // 5. Special Course Saving Offer (if available)
                          if (_courseSavingOffer case final courseOffer?) ...[
                            _buildEntrance(
                              start: 0.2,
                              end: 0.6,
                              offset: const Offset(0, 0.08),
                              child: _buildCourseSavingBanner(courseOffer),
                            ),
                            SizedBox(height: 24.h),
                          ],

                          // 6. Platform Promo Video Card
                          _buildEntrance(
                            start: 0.25,
                            end: 0.65,
                            child: const PlatformPromoVideoCard(),
                          ),
                          SizedBox(height: 24.h),

                          // 7. Podcasts Section (New video section with clean empty state)
                          _buildEntrance(
                            start: 0.3,
                            end: 0.7,
                            child: _buildPodcastsSection(),
                          ),
                          SizedBox(height: 24.h),

                          // 8. Poetry Section (English Poems divided by levels with reader)
                          _buildEntrance(
                            start: 0.32,
                            end: 0.72,
                            child: _buildPoetrySection(),
                          ),
                          SizedBox(height: 24.h),

                          // 8. Offline Downloads Section (if any offline lectures available)
                          if (_offlineDownloads.isNotEmpty) ...[
                            _buildEntrance(
                              start: 0.35,
                              end: 0.75,
                              child: _buildOfflineSection(),
                            ),
                            SizedBox(height: 24.h),
                          ],

                          // 9. Upcoming Exam Section (if scheduled)
                          if (summary.upcomingExam != null) ...[
                            _buildEntrance(
                              start: 0.4,
                              end: 0.8,
                              child: Padding(
                                padding: EdgeInsets.symmetric(horizontal: 20.w),
                                child: UpcomingExamCardWidget(
                                  exam: summary.upcomingExam,
                                  onExamTap: () {
                                    context.push(
                                      AppRoutes.examDetails,
                                      extra: summary.upcomingExam!.id,
                                    );
                                  },
                                  onViewAllTap: () {
                                    context.push(AppRoutes.allExams);
                                  },
                                ),
                              ),
                            ),
                            SizedBox(height: 24.h),
                          ],

                          // 10. Live Leaderboard Section
                          if (summary.topLeaderboard.isNotEmpty) ...[
                            _buildEntrance(
                              start: 0.45,
                              end: 0.85,
                              child: Padding(
                                padding: EdgeInsets.symmetric(horizontal: 20.w),
                                child: LiveLeaderboardWidget(
                                  topStudents: summary.topLeaderboard,
                                  grade: summary.grade,
                                  onViewAllTap: () {
                                    context.push(
                                      AppRoutes.leaderboard,
                                      extra: {
                                        'grade': summary.grade,
                                        'teacherGrades':
                                            summary.teacher?.grades,
                                      },
                                    );
                                  },
                                ),
                              ),
                            ),
                            SizedBox(height: 24.h),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }

            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  // Section Header helper adhering to 04-ui-ux.md
  Widget _buildSectionHeader({
    required String title,
    String? subtitle,
    Widget? trailing,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 16.5.sp,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  fontFamily: 'IBM',
                ),
              ),
              if (subtitle != null && subtitle.isNotEmpty) ...[
                SizedBox(height: 2.h),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11.5.sp,
                    color: AppColors.textSecondary,
                    fontFamily: 'IBM',
                  ),
                ),
              ],
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }

  // 2-Column Grid grouping educational features & tools into an attractive layout
  Widget _buildFeatureToolsGrid() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSectionHeader(
            title: 'خدمات وأدوات تعليمية',
            subtitle: 'أدوات ذكية مصممة لتطوير مهاراتك الدراسية',
          ),
          SizedBox(height: 12.h),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12.h,
            crossAxisSpacing: 12.w,
            childAspectRatio: 1.25,
            children: [
              _buildFeatureGridCard(
                title: 'بيئة المذاكرة',
                subtitle: 'ذاكر على PDF بالملاحظات والتظليل',
                icon: Icons.menu_book_rounded,
                color: const Color(0xFF0F766E),
                onTap: () => context.push(AppRoutes.studyEnvironment),
              ),
              _buildFeatureGridCard(
                title: 'روايات إنجليزية',
                subtitle: 'قراءة تفاعلية وترجمة ونطق سياقي',
                icon: Icons.auto_stories_rounded,
                color: AppColors.primary,
                onTap: () => context.push(AppRoutes.novels),
              ),
              _buildFeatureGridCard(
                title: 'شعر وقصائد إنجليزية',
                subtitle: 'قصائد تفاعلية مقسمة حسب المستويات',
                icon: Icons.menu_book_rounded,
                color: const Color(0xFF0284C7),
                onTap: () => context.push(AppRoutes.poetry),
              ),
              _buildFeatureGridCard(
                title: 'لعبة أبو العريف',
                subtitle: 'تحديات لغوية ممتعة أوفلاين ومع زملائك',
                icon: Icons.sports_esports_rounded,
                color: const Color(0xFFEA580C),
                onTap: () => context.push(AppRoutes.abuAlAreef),
              ),
              // _buildFeatureGridCard(
              //   title: 'تحديد المستوى',
              //   subtitle: 'اختبار دقيق لمعرفة مستواك والكورس الأنسب',
              //   icon: Icons.psychology_alt_rounded,
              //   color: const Color(0xFF7C3AED),
              //   onTap: () =>
              //       context.push(AppRoutes.levelAssessmentIntro, extra: false),
              // ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureGridCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18.r),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18.r),
        child: Container(
          padding: EdgeInsets.all(14.w),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18.r),
            border: Border.all(color: AppColors.border.withAlpha(100)),
            boxShadow: [
              BoxShadow(
                color: color.withAlpha(16),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 42.w,
                    height: 42.w,
                    decoration: BoxDecoration(
                      color: color.withAlpha(24),
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Icon(icon, color: color, size: 22.sp),
                  ),
                  Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 14.sp,
                    color: color,
                  ),
                ],
              ),
              SizedBox(height: 8.h),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      fontFamily: 'IBM',
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 3.h),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 10.5.sp,
                      color: AppColors.textSecondary,
                      fontFamily: 'IBM',
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Podcasts Section (Interactive audio-book style with videos, text & waves)
  Widget _buildPodcastsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 20.w),
          child: _buildSectionHeader(
            title: 'بودكاستس',
            subtitle: 'حلقات ولقاءات مرئية تثقيفية بمزامنة النص والصوت',
          ),
        ),
        SizedBox(height: 12.h),
        if (_podcasts.isEmpty)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w),
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 26.h),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20.r),
                border: Border.all(color: AppColors.border.withAlpha(110)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(6),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 58.w,
                    height: 58.w,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withAlpha(20),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.podcasts_rounded,
                      size: 30.sp,
                      color: AppColors.primary,
                    ),
                  ),
                  SizedBox(height: 14.h),
                  Text(
                    'لا توجد حلقات بودكاست متاحة حاليًا',
                    style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      fontFamily: 'IBM',
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 6.h),
                  Text(
                    'سيتم نشر لقاءات وفيديوهات تعليمية قريبًا. ترقبوا جديدنا!',
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: AppColors.textSecondary,
                      fontFamily: 'IBM',
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          )
        else
          SizedBox(
            height: 235.h,
            child: ListView.separated(
              padding: EdgeInsets.symmetric(horizontal: 20.w),
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: _podcasts.length,
              separatorBuilder: (_, _) => SizedBox(width: 14.w),
              itemBuilder: (context, index) {
                final ep = _podcasts[index];
                return GestureDetector(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => PodcastPlayerScreen(episode: ep),
                      ),
                    );
                  },
                  child: Container(
                    width: 250.w,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20.r),
                      border: Border.all(color: AppColors.border.withAlpha(90)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(8),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Cover artwork & Badges
                        Expanded(
                          flex: 12,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              if (ep.coverUrl != null &&
                                  ep.coverUrl!.isNotEmpty)
                                Image.network(
                                  ep.coverUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => Container(
                                    decoration: const BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Color(0xFF6366F1),
                                          Color(0xFF4F46E5),
                                        ],
                                      ),
                                    ),
                                  ),
                                )
                              else
                                Container(
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Color(0xFF6366F1),
                                        Color(0xFF4F46E5),
                                      ],
                                    ),
                                  ),
                                ),
                              Positioned.fill(
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.black.withAlpha(20),
                                        Colors.black.withAlpha(160),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              // Duration Pill
                              Positioned(
                                top: 10.h,
                                right: 10.w,
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 8.w,
                                    vertical: 4.h,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withAlpha(150),
                                    borderRadius: BorderRadius.circular(10.r),
                                    border: Border.all(color: Colors.white24),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.graphic_eq_rounded,
                                        color: Colors.white,
                                        size: 12,
                                      ),
                                      SizedBox(width: 4.w),
                                      Text(
                                        ep.durationFormatted,
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 10.5.sp,
                                          fontWeight: FontWeight.w700,
                                          fontFamily: 'IBM',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              // Video Segment Badge
                              if (ep.videoSegments.isNotEmpty)
                                Positioned(
                                  top: 10.h,
                                  left: 10.w,
                                  child: Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 8.w,
                                      vertical: 4.h,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(
                                        0xFFEF4444,
                                      ).withAlpha(210),
                                      borderRadius: BorderRadius.circular(10.r),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.videocam_rounded,
                                          color: Colors.white,
                                          size: 12,
                                        ),
                                        SizedBox(width: 3.w),
                                        Text(
                                          'فيديو تفاعلي',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 9.5.sp,
                                            fontWeight: FontWeight.w800,
                                            fontFamily: 'IBM',
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              // Center Play Button Overlay
                              Center(
                                child: Container(
                                  width: 42.w,
                                  height: 42.w,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withAlpha(220),
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withAlpha(50),
                                        blurRadius: 10,
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.play_arrow_rounded,
                                    color: AppColors.primary,
                                    size: 26,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Title & Host details
                        Expanded(
                          flex: 9,
                          child: Padding(
                            padding: EdgeInsets.all(10.w),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  ep.title,
                                  style: TextStyle(
                                    fontSize: 13.sp,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textPrimary,
                                    fontFamily: 'IBM',
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.right,
                                ),
                                SizedBox(height: 3.h),
                                Text(
                                  ep.host,
                                  style: TextStyle(
                                    fontSize: 11.sp,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.textSecondary,
                                    fontFamily: 'IBM',
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.right,
                                ),
                                SizedBox(height: 4.h),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      ep.category,
                                      style: TextStyle(
                                        fontSize: 10.sp,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.primary,
                                        fontFamily: 'IBM',
                                      ),
                                    ),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.translate_rounded,
                                          size: 12.sp,
                                          color: AppColors.textSecondary,
                                        ),
                                        SizedBox(width: 3.w),
                                        Text(
                                          'نص + ترجمة',
                                          style: TextStyle(
                                            fontSize: 9.5.sp,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.textSecondary,
                                            fontFamily: 'IBM',
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
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
    );
  }

  // Poetry Section (English Poems with Level badges, tap to read in Novel Reader)
  Widget _buildPoetrySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 20.w),
          child: _buildSectionHeader(
            title: 'شعر وقصائد إنجليزية',
            subtitle: 'قصائد ملهمة مقسمة حسب المستويات مع ترجمة ونطق تفاعلي',
            trailing: InkWell(
              onTap: () => context.push(AppRoutes.poetry),
              borderRadius: BorderRadius.circular(8.r),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'عرض الكل',
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                        fontFamily: 'IBM',
                      ),
                    ),
                    SizedBox(width: 2.w),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 11.sp,
                      color: AppColors.primary,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        SizedBox(height: 12.h),
        if (_poems.isEmpty)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w),
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 24.h),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20.r),
                border: Border.all(color: AppColors.border.withAlpha(110)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.menu_book_rounded,
                    size: 32.sp,
                    color: const Color(0xFF0284C7),
                  ),
                  SizedBox(height: 10.h),
                  Text(
                    'جاري تحميل القصائد الشعرية...',
                    style: TextStyle(
                      fontSize: 13.sp,
                      color: AppColors.textSecondary,
                      fontFamily: 'IBM',
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          SizedBox(
            height: 200.h,
            child: ListView.separated(
              padding: EdgeInsets.symmetric(horizontal: 20.w),
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: _poems.length,
              separatorBuilder: (_, _) => SizedBox(width: 12.w),
              itemBuilder: (context, index) {
                final poem = _poems[index];
                Color levelColor;
                String levelLabel;
                switch (poem.level.toLowerCase()) {
                  case 'beginner':
                    levelColor = const Color(0xFF10B981);
                    levelLabel = 'مبتدئ A1-A2';
                    break;
                  case 'intermediate':
                    levelColor = const Color(0xFFF59E0B);
                    levelLabel = 'متوسط B1-B2';
                    break;
                  case 'advanced':
                  default:
                    levelColor = const Color(0xFFEF4444);
                    levelLabel = 'متقدم C1';
                    break;
                }

                return GestureDetector(
                  onTap: () {
                    context.push(AppRoutes.novelReader, extra: poem.id);
                  },
                  child: Container(
                    width: 220.w,
                    padding: EdgeInsets.all(14.w),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18.r),
                      border: Border.all(color: AppColors.border.withAlpha(90)),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0284C7).withAlpha(10),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 8.w,
                                vertical: 3.h,
                              ),
                              decoration: BoxDecoration(
                                color: levelColor.withAlpha(25),
                                borderRadius: BorderRadius.circular(8.r),
                              ),
                              child: Text(
                                levelLabel,
                                style: TextStyle(
                                  fontSize: 10.sp,
                                  fontWeight: FontWeight.w700,
                                  color: levelColor,
                                  fontFamily: 'IBM',
                                ),
                              ),
                            ),
                            Container(
                              width: 28.w,
                              height: 28.w,
                              decoration: BoxDecoration(
                                color: const Color(0xFF0284C7).withAlpha(20),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.format_quote_rounded,
                                size: 16,
                                color: Color(0xFF0284C7),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 10.h),
                        Text(
                          poem.title,
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                            fontFamily: 'IBM',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          poem.description,
                          style: TextStyle(
                            fontSize: 11.sp,
                            color: AppColors.textSecondary,
                            fontFamily: 'IBM',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const Spacer(),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8.w,
                            vertical: 6.h,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10.r),
                            border: Border.all(
                              color: AppColors.border.withAlpha(60),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.volume_up_rounded,
                                size: 14.sp,
                                color: AppColors.primary,
                              ),
                              SizedBox(width: 4.w),
                              Expanded(
                                child: Text(
                                  'ترجمة + نطق لكل بيت',
                                  style: TextStyle(
                                    fontSize: 9.5.sp,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textSecondary,
                                    fontFamily: 'IBM',
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Icon(
                                Icons.arrow_back_ios_new_rounded,
                                size: 11.sp,
                                color: AppColors.textSecondary,
                              ),
                            ],
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
    );
  }

  Widget _buildCourseSavingBanner(CommerceOfferEntity offer) {
    final originalPrice = offer.originalPrice ?? offer.offerPrice;
    final saving = originalPrice - offer.offerPrice;
    final percent = originalPrice <= 0
        ? 0
        : ((saving / originalPrice) * 100).round();
    final lessonsCount = offer.items.fold<int>(
      0,
      (total, item) => total + item.includedLectureTitles.length,
    );

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => OfferPurchaseSheet.show(
            context,
            offer,
            onActivated: () async {
              await Future.wait([_loadCourseSavingOffer(), _loadOffers()]);
            },
          ),
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
                  offer.title,
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
                  'اشترك في $lessonsCount حصة مع بعض ووفر ${saving.toStringAsFixed(0)} ج.م بدل شراء كل حصة لوحدها',
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
                      '${offer.offerPrice.toStringAsFixed(0)} ج.م',
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

  Widget _buildEntrance({
    required double start,
    required double end,
    required Widget child,
    Offset offset = const Offset(0, 0.12),
  }) {
    final animation = CurvedAnimation(
      parent: _entranceController,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: offset,
          end: Offset.zero,
        ).animate(animation),
        child: child,
      ),
    );
  }

  Widget _buildOfflineSection() {
    final downloads = _offlineDownloads.take(6).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 20.w),
          child: Row(
            children: [
              Container(
                width: 34.w,
                height: 34.w,
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(11.r),
                ),
                child: const Icon(
                  Icons.offline_bolt_rounded,
                  color: Color(0xFF047857),
                  size: 20,
                ),
              ),
              SizedBox(width: 9.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'مكتبتك بدون إنترنت',
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        fontFamily: 'IBM',
                      ),
                    ),
                    Text(
                      'كمّل في أي وقت • ${_offlineDownloads.length} حصة',
                      style: TextStyle(
                        fontSize: 11.sp,
                        color: AppColors.textSecondary,
                        fontFamily: 'IBM',
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.lock_rounded,
                size: 18,
                color: Color(0xFF059669),
              ),
            ],
          ),
        ),
        SizedBox(height: 12.h),
        SizedBox(
          height: 142.h,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: downloads.length,
            separatorBuilder: (_, _) => SizedBox(width: 0.w),
            itemBuilder: (context, index) {
              final lecture = downloads[index];
              final videos = lecture.contents
                  .where((item) => item.type == ContentType.video)
                  .length;
              final pdfs = lecture.contents
                  .where((item) => item.type == ContentType.pdf)
                  .length;
              return Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(20.r),
                  onTap: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => OfflineLectureScreen(lecture: lecture),
                      ),
                    );
                    await _loadOfflineDownloads();
                  },
                  child: Container(
                    width: 255.w,
                    padding: EdgeInsets.all(14.w),
                    margin: const EdgeInsetsDirectional.fromSTEB(20, 0, 0, 0),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topRight,
                        end: Alignment.bottomLeft,
                        colors: [Color(0xFF064E3B), Color(0xFF10B981)],
                      ),
                      borderRadius: BorderRadius.circular(20.r),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF059669).withAlpha(45),
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(7.w),
                              decoration: BoxDecoration(
                                color: Colors.white.withAlpha(35),
                                borderRadius: BorderRadius.circular(10.r),
                              ),
                              child: const Icon(
                                Icons.play_arrow_rounded,
                                color: Colors.white,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 8.w,
                                vertical: 4.h,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withAlpha(35),
                                borderRadius: BorderRadius.circular(20.r),
                              ),
                              child: Text(
                                'محفوظ بأمان',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 9.5.sp,
                                  fontWeight: FontWeight.w700,
                                  fontFamily: 'IBM',
                                ),
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Text(
                          lecture.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w800,
                            fontFamily: 'IBM',
                          ),
                        ),
                        SizedBox(height: 5.h),
                        Text(
                          '${lecture.chapter} • $videos فيديو${pdfs > 0 ? ' • $pdfs PDF' : ''}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withAlpha(210),
                            fontSize: 10.5.sp,
                            fontFamily: 'IBM',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildOfflineHome({String? message}) {
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async {
        await Future.wait([
          context.read<HomeCubit>().loadHomeData(),
          _loadOfflineDownloads(),
        ]);
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: EdgeInsets.symmetric(vertical: 24.h),
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w),
            child: Container(
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(color: const Color(0xFFA7F3D0)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.wifi_off_rounded,
                    color: Color(0xFF047857),
                    semanticLabel: 'بدون اتصال بالإنترنت',
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'أنت الآن بدون إنترنت',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: const Color(0xFF065F46),
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          'فيديوهاتك المحمّلة جاهزة للمشاهدة. اسحب للأسفل لإعادة المحاولة.',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: const Color(0xFF047857),
                                height: 1.5,
                              ),
                        ),
                        if (message?.isNotEmpty == true) ...[
                          SizedBox(height: 8.h),
                          Text(
                            message!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: AppColors.textSecondary),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 24.h),
          _buildOfflineSection(),
        ],
      ),
    );
  }

  Widget _buildContinueSection(LearningActivity activity) {
    final percentage = (activity.progress * 100).round();
    final subtitle = activity.courseTitle?.isNotEmpty == true
        ? 'من كورس ${activity.courseTitle}'
        : activity.chapter;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSectionHeader(
            title: 'أكمل من حيث توقفت',
            subtitle: 'تابع تقدمك الدراسي واستأنف الحصة الأخيرة',
          ),
          SizedBox(height: 12.h),
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20.r),
            child: InkWell(
              borderRadius: BorderRadius.circular(20.r),
              onTap: () async {
                await context.push(
                  AppRoutes.lectureDetails,
                  extra: activity.lectureId,
                );
                await _loadContinueActivity();
              },
              child: Container(
                padding: EdgeInsets.all(14.w),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20.r),
                  border: Border.all(color: AppColors.border.withAlpha(120)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(8),
                      blurRadius: 16,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(15.r),
                      child: Container(
                        width: 92.w,
                        height: 78.h,
                        color: AppColors.primary.withAlpha(18),
                        child: activity.thumbnailUrl?.isNotEmpty == true
                            ? Image.network(
                                activity.thumbnailUrl!,
                                fit: BoxFit.cover,
                                cacheWidth: 250,
                                errorBuilder: (_, _, _) => const Icon(
                                  Icons.play_lesson_rounded,
                                  color: AppColors.primary,
                                ),
                              )
                            : const Icon(
                                Icons.play_lesson_rounded,
                                color: AppColors.primary,
                                size: 34,
                              ),
                      ),
                    ),
                    SizedBox(width: 13.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            activity.lectureTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14.5.sp,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                              fontFamily: 'IBM',
                            ),
                          ),
                          if (subtitle.isNotEmpty) ...[
                            SizedBox(height: 4.h),
                            Text(
                              subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11.5.sp,
                                color: AppColors.textSecondary,
                                fontFamily: 'IBM',
                              ),
                            ),
                          ],
                          SizedBox(height: 10.h),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8.r),
                            child: LinearProgressIndicator(
                              value: activity.progress,
                              minHeight: 6.h,
                              color: AppColors.primary,
                              backgroundColor: AppColors.primary.withAlpha(25),
                            ),
                          ),
                          SizedBox(height: 5.h),
                          Text(
                            percentage > 0
                                ? 'أكملت $percentage%'
                                : 'ابدأ المشاهدة',
                            style: TextStyle(
                              fontSize: 10.5.sp,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                              fontFamily: 'IBM',
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Container(
                      width: 40.w,
                      height: 40.w,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
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
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Header (Greeting + Level chip + Points + Bell)
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 140.w,
                        height: 18.h,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(6.r),
                        ),
                      ),
                      SizedBox(height: 6.h),
                      Row(
                        children: [
                          Container(
                            width: 85.w,
                            height: 22.h,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8.r),
                            ),
                          ),
                          SizedBox(width: 6.w),
                          Container(
                            width: 75.w,
                            height: 22.h,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8.r),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 8.w),
                Container(
                  width: 82.w,
                  height: 34.h,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20.r),
                  ),
                ),
                SizedBox(width: 8.w),
                Container(
                  width: 42.w,
                  height: 42.w,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
            SizedBox(height: 20.h),

            // 2. Large Banner Carousel Shimmer
            Container(
              width: double.infinity,
              height: 195.h,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20.r),
              ),
            ),
            SizedBox(height: 12.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 22.w,
                  height: 7.h,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4.r),
                  ),
                ),
                SizedBox(width: 6.w),
                Container(
                  width: 7.w,
                  height: 7.h,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: 6.w),
                Container(
                  width: 7.w,
                  height: 7.h,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
            SizedBox(height: 24.h),

            // 3. Grid Tools Shimmer (2x2)
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 120.h,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18.r),
                    ),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Container(
                    height: 120.h,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18.r),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12.h),
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 120.h,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18.r),
                    ),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Container(
                    height: 120.h,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18.r),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 24.h),

            // 4. Promo Section Shimmer
            Container(
              width: double.infinity,
              height: 140.h,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20.r),
              ),
            ),
            SizedBox(height: 24.h),
          ],
        ),
      ),
    );
  }
}
