import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../domain/entities/leaderboard_entry_entity.dart';
import '../cubits/leaderboard/leaderboard_cubit.dart';
import '../cubits/leaderboard/leaderboard_state.dart';

class LeaderboardScreen extends StatefulWidget {
  final String? examId;
  final String? initialGrade;
  final List<String>? teacherGrades;

  const LeaderboardScreen({
    super.key,
    this.examId,
    this.initialGrade,
    this.teacherGrades,
  });

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  final Map<String, GlobalKey> _gradeTabKeys = {};
  late List<String> _allGrades;
  late String _selectedGrade;
  bool _challengeMode = false;
  bool _resolvingInitialGrade = true;
  bool _isUniversityStudent = false;

  @override
  void initState() {
    super.initState();
    _allGrades =
        (widget.teacherGrades != null && widget.teacherGrades!.isNotEmpty)
        ? widget.teacherGrades!
        : AppConstants.allGrades;

    _selectedGrade = _allGrades.isNotEmpty
        ? _allGrades.first
        : 'الصف الأول الثانوي';
    _resolveInitialGrade();
  }

  Future<void> _resolveInitialGrade() async {
    String? grade = widget.initialGrade;
    String? educationLevel;
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;

    if (grade == null || grade.trim().isEmpty) {
      grade = user?.userMetadata?['grade'] as String?;
      educationLevel = user?.userMetadata?['education_level'] as String?;
      if (user != null) {
        try {
          final profile = await client
              .from('students')
              .select('grade,education_level')
              .eq('id', user.id)
              .maybeSingle();
          grade = profile?['grade'] as String? ?? grade;
          educationLevel =
              profile?['education_level'] as String? ?? educationLevel;
        } catch (_) {}
      }
    }

    final resolvedGrade = grade?.trim();
    if (resolvedGrade?.isNotEmpty == true &&
        !_allGrades.contains(resolvedGrade)) {
      _allGrades = [resolvedGrade!, ..._allGrades];
    }
    if (resolvedGrade?.isNotEmpty == true) {
      _selectedGrade = resolvedGrade!;
    }
    _isUniversityStudent =
        educationLevel == AppConstants.stageUniversity ||
        _selectedGrade.startsWith('الفرقة');

    if (!mounted) return;
    setState(() => _resolvingInitialGrade = false);
    _scrollSelectedGradeIntoView(animate: false);
    _fetchLeaderboard(_selectedGrade);
  }

  void _fetchLeaderboard(String grade) {
    context.read<LeaderboardCubit>().loadLeaderboard(
      examId: widget.examId,
      grade: _challengeMode ? null : grade,
      challengesOnly: _challengeMode,
    );
  }

  void _setChallengeMode(bool value) {
    if (_challengeMode == value) return;
    setState(() => _challengeMode = value);
    _fetchLeaderboard(_selectedGrade);
  }

  void _onGradeTabSelected(String grade) {
    if (_selectedGrade == grade) return;
    setState(() {
      _selectedGrade = grade;
    });
    _scrollSelectedGradeIntoView();
    _fetchLeaderboard(grade);
  }

  void _scrollSelectedGradeIntoView({bool animate = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final selectedContext = _gradeTabKeys[_selectedGrade]?.currentContext;
      if (selectedContext == null) return;
      Scrollable.ensureVisible(
        selectedContext,
        alignment: .5,
        duration: animate ? const Duration(milliseconds: 320) : Duration.zero,
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppColors.textPrimary,
            size: 20,
          ),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            }
          },
        ),
        title: Text(
          'لوحة الصدارة والترتيب',
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            fontFamily: 'IBM',
          ),
        ),
      ),
      body: SafeArea(
        child: _resolvingInitialGrade
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  _buildModeTabs(),
                  SizedBox(height: 10.h),
                  // Horizontal Grade Tabs Selector (Scoped to Teacher's Grades)
                  if (!_challengeMode) ...[
                    _buildGradeTabs(),
                    SizedBox(height: 10.h),
                  ],

                  // Main Content Area
                  Expanded(
                    child: BlocBuilder<LeaderboardCubit, LeaderboardState>(
                      builder: (context, state) {
                        if (state is LeaderboardLoading ||
                            state is LeaderboardInitial) {
                          return _buildShimmerLoading();
                        }

                        if (state is LeaderboardError) {
                          return Center(
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
                                  onPressed: () =>
                                      _fetchLeaderboard(_selectedGrade),
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
                          );
                        }

                        if (state is LeaderboardLoaded) {
                          final entries = state.entries;
                          final currentUser = state.currentUserEntry;

                          return RefreshIndicator(
                            color: AppColors.primary,
                            onRefresh: () async {
                              _fetchLeaderboard(_selectedGrade);
                            },
                            child: Column(
                              children: [
                                Expanded(
                                  child: SingleChildScrollView(
                                    physics:
                                        const AlwaysScrollableScrollPhysics(
                                          parent: BouncingScrollPhysics(),
                                        ),
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 20.w,
                                      vertical: 6.h,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        // Top Banner
                                        _buildTopRankBanner(
                                          currentUser: currentUser,
                                          totalCount: state.totalCount,
                                          grade: _challengeMode
                                              ? 'لوحة شرف التحديات'
                                              : _selectedGrade,
                                        ),
                                        SizedBox(height: 18.h),

                                        // List Header
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              'ترتيب الطلاب',
                                              style: TextStyle(
                                                fontSize: 15.sp,
                                                fontWeight: FontWeight.w800,
                                                color: AppColors.textPrimary,
                                                fontFamily: 'IBM',
                                              ),
                                            ),
                                            Text(
                                              '${state.totalCount} طالب مسجل',
                                              style: TextStyle(
                                                fontSize: 12.sp,
                                                fontWeight: FontWeight.w500,
                                                color: AppColors.textSecondary,
                                                fontFamily: 'IBM',
                                              ),
                                            ),
                                          ],
                                        ),
                                        SizedBox(height: 12.h),

                                        // Rankings List or Empty State
                                        if (entries.isEmpty)
                                          _buildEmptyState()
                                        else
                                          Container(
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(22.r),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black.withAlpha(
                                                    8,
                                                  ),
                                                  blurRadius: 16,
                                                  offset: const Offset(0, 4),
                                                ),
                                              ],
                                            ),
                                            child: ListView.separated(
                                              shrinkWrap: true,
                                              physics:
                                                  const NeverScrollableScrollPhysics(),
                                              itemCount: entries.length,
                                              separatorBuilder:
                                                  (context, index) => Divider(
                                                    color:
                                                        AppColors.borderLight,
                                                    height: 1,
                                                  ),
                                              itemBuilder: (context, index) {
                                                final entry = entries[index];
                                                return _buildLeaderboardListItem(
                                                  entry,
                                                );
                                              },
                                            ),
                                          ),
                                        SizedBox(height: 90.h),
                                      ],
                                    ),
                                  ),
                                ),

                                // Bottom Sticky Current User Bar (when user belongs to this grade)
                                if (currentUser != null)
                                  _buildBottomUserBar(currentUser),
                              ],
                            ),
                          );
                        }

                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildGradeTabs() {
    return SizedBox(
      height: 42.h,
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 20.w),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: [
            for (var index = 0; index < _allGrades.length; index++) ...[
              if (index > 0) SizedBox(width: 8.w),
              Builder(
                builder: (context) {
                  final grade = _allGrades[index];
                  final isSelected = _selectedGrade == grade;
                  return GestureDetector(
                    key: _gradeTabKeys.putIfAbsent(grade, GlobalKey.new),
                    onTap: () => _onGradeTabSelected(grade),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: EdgeInsets.symmetric(
                        horizontal: 14.w,
                        vertical: 8.h,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF7C3AED)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(20.r),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFF7C3AED)
                              : AppColors.borderLight,
                          width: 1.2,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: const Color(0xFF7C3AED).withAlpha(60),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ]
                            : null,
                      ),
                      child: Center(
                        child: Text(
                          grade,
                          style: TextStyle(
                            fontSize: 12.5.sp,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: isSelected
                                ? Colors.white
                                : AppColors.textPrimary,
                            fontFamily: 'IBM',
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildModeTabs() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: Container(
        height: 48.h,
        padding: EdgeInsets.all(4.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: AppColors.borderLight, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            _buildModeTabItem(
              title: _isUniversityStudent ? 'ترتيب الفرق' : 'ترتيب الصفوف',
              icon: Icons.school_rounded,
              isSelected: !_challengeMode,
              onTap: () => _setChallengeMode(false),
            ),
            SizedBox(width: 6.w),
            _buildModeTabItem(
              title: 'شرف التحديات',
              icon: Icons.bolt_rounded,
              isSelected: _challengeMode,
              onTap: () => _setChallengeMode(true),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeTabItem({
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(12.r),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 18.w,
                  color: isSelected ? Colors.white : AppColors.textSecondary,
                ),
                SizedBox(width: 6.w),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13.5.sp,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                    color: isSelected ? Colors.white : AppColors.textSecondary,
                    fontFamily: 'IBM',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopRankBanner({
    LeaderboardEntryEntity? currentUser,
    required int totalCount,
    required String grade,
  }) {
    final hasUserRank = currentUser != null && currentUser.isCurrentUser;
    final rank = currentUser?.rank ?? 1;
    final pointsFormatted = currentUser != null
        ? NumberFormat('#,###').format(currentUser.points)
        : '0';

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 18.h),
      decoration: BoxDecoration(
        gradient: AppColors.leaderboardHeaderGradient,
        borderRadius: BorderRadius.circular(22.r),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3730A3).withAlpha(80),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Text Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(35),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Text(
                    grade,
                    style: TextStyle(
                      fontSize: 11.5.sp,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      fontFamily: 'IBM',
                    ),
                  ),
                ),
                SizedBox(height: 8.h),
                if (hasUserRank) ...[
                  Text(
                    _challengeMode
                        ? 'ترتيبك في تحديات المستر'
                        : _isUniversityStudent
                        ? 'ترتيبك في هذه الفرقة'
                        : 'ترتيبك في هذا الصف',
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withAlpha(220),
                      fontFamily: 'IBM',
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '#$rank',
                        style: TextStyle(
                          fontSize: 32.sp,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          fontFamily: 'IBM',
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Text(
                        'من $totalCount طالب',
                        style: TextStyle(
                          fontSize: 12.5.sp,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withAlpha(200),
                          fontFamily: 'IBM',
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    'مجموع نقاطك: $pointsFormatted نقطة',
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFFFDE68A),
                      fontFamily: 'IBM',
                    ),
                  ),
                ] else ...[
                  Text(
                    'لوحة الشرف والأوائل',
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      fontFamily: 'IBM',
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    _challengeMode
                        ? 'اجمع نقاط التحديات لتظهر في لوحة الشرف'
                        : 'استعرض المتفوقين في $grade',
                    style: TextStyle(
                      fontSize: 12.5.sp,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withAlpha(210),
                      fontFamily: 'IBM',
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Trophy Icon / Illustration
          Container(
            width: 72.w,
            height: 72.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withAlpha(25),
            ),
            child: Center(
              child: Icon(
                Icons.emoji_events_rounded,
                color: const Color(0xFFFBBF24),
                size: 46.w,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaderboardListItem(LeaderboardEntryEntity entry) {
    final isMe = entry.isCurrentUser;
    final formattedPoints = NumberFormat('#,###').format(entry.points);

    return Container(
      decoration: BoxDecoration(
        color: isMe ? const Color(0xFFFAF5FF) : Colors.transparent,
        borderRadius: BorderRadius.circular(16.r),
        border: isMe
            ? Border.all(
                color: const Color(0xFF7C3AED).withAlpha(140),
                width: 1.5,
              )
            : null,
      ),
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      child: Row(
        children: [
          // Rank Badge / Number
          _buildRankBadge(entry.rank),
          SizedBox(width: 12.w),

          // Avatar
          Container(
            width: 44.w,
            height: 44.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isMe
                  ? const Color(0xFF7C3AED).withAlpha(25)
                  : const Color(0xFFF3F4F6),
              border: Border.all(
                color: isMe ? const Color(0xFF7C3AED) : const Color(0xFFE5E7EB),
                width: 1.5,
              ),
              image: entry.avatarUrl != null && entry.avatarUrl!.isNotEmpty
                  ? DecorationImage(
                      image: NetworkImage(entry.avatarUrl!),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: (entry.avatarUrl == null || entry.avatarUrl!.isEmpty)
                ? Center(
                    child: Text(
                      entry.name.trim().isNotEmpty
                          ? entry.name.trim().characters.first
                          : 'ط',
                      style: TextStyle(
                        fontSize: 17.sp,
                        fontWeight: FontWeight.w800,
                        color: isMe
                            ? const Color(0xFF7C3AED)
                            : AppColors.textPrimary,
                        fontFamily: 'IBM',
                      ),
                    ),
                  )
                : null,
          ),
          SizedBox(width: 12.w),

          // Name and Points
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        entry.name,
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w800,
                          color: isMe
                              ? const Color(0xFF7C3AED)
                              : AppColors.textPrimary,
                          fontFamily: 'IBM',
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isMe) ...[
                      SizedBox(width: 6.w),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 6.w,
                          vertical: 1.5.h,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF7C3AED),
                          borderRadius: BorderRadius.circular(6.r),
                        ),
                        child: Text(
                          'أنت',
                          style: TextStyle(
                            fontSize: 10.sp,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontFamily: 'IBM',
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                SizedBox(height: 3.h),
                Text(
                  '$formattedPoints نقطة',
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                    color: isMe
                        ? const Color(0xFF7C3AED)
                        : AppColors.textSecondary,
                    fontFamily: 'IBM',
                  ),
                ),
              ],
            ),
          ),

          // Crown icon for #1
          if (entry.rank == 1)
            const Icon(
              Icons.military_tech_rounded,
              color: AppColors.goldMedal,
              size: 26,
            ),
        ],
      ),
    );
  }

  Widget _buildRankBadge(int rank) {
    if (rank == 1) {
      return Container(
        width: 32.w,
        height: 32.w,
        decoration: const BoxDecoration(
          color: Color(0xFFFEF3C7),
          shape: BoxShape.circle,
        ),
        child: const Center(
          child: Icon(
            Icons.workspace_premium_rounded,
            color: AppColors.goldMedal,
            size: 20,
          ),
        ),
      );
    }
    if (rank == 2) {
      return Container(
        width: 32.w,
        height: 32.w,
        decoration: const BoxDecoration(
          color: Color(0xFFF1F5F9),
          shape: BoxShape.circle,
        ),
        child: const Center(
          child: Icon(
            Icons.workspace_premium_rounded,
            color: AppColors.silverMedal,
            size: 20,
          ),
        ),
      );
    }
    if (rank == 3) {
      return Container(
        width: 32.w,
        height: 32.w,
        decoration: const BoxDecoration(
          color: Color(0xFFFEF3C7),
          shape: BoxShape.circle,
        ),
        child: const Center(
          child: Icon(
            Icons.workspace_premium_rounded,
            color: AppColors.bronzeMedal,
            size: 20,
          ),
        ),
      );
    }

    return Container(
      width: 32.w,
      height: 32.w,
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
      ),
      alignment: Alignment.center,
      child: Text(
        '$rank',
        style: TextStyle(
          fontSize: 13.sp,
          fontWeight: FontWeight.w800,
          color: AppColors.textSecondary,
          fontFamily: 'IBM',
        ),
      ),
    );
  }

  Widget _buildBottomUserBar(LeaderboardEntryEntity user) {
    final formattedPoints = NumberFormat('#,###').format(user.points);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22.r)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7C3AED).withAlpha(30),
            blurRadius: 18,
            offset: const Offset(0, -4),
          ),
        ],
        border: Border(
          top: BorderSide(
            color: const Color(0xFF7C3AED).withAlpha(50),
            width: 1.5,
          ),
        ),
      ),
      child: Row(
        children: [
          // Current User Rank Number
          Container(
            width: 36.w,
            height: 36.w,
            decoration: const BoxDecoration(
              color: Color(0xFFEDE9FE),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '${user.rank}',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF7C3AED),
                  fontFamily: 'IBM',
                ),
              ),
            ),
          ),
          SizedBox(width: 14.w),

          // Name and Points
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      user.name,
                      style: TextStyle(
                        fontSize: 14.5.sp,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        fontFamily: 'IBM',
                      ),
                    ),
                    SizedBox(width: 6.w),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 6.w,
                        vertical: 1.h,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF7C3AED),
                        borderRadius: BorderRadius.circular(5.r),
                      ),
                      child: Text(
                        'أنت',
                        style: TextStyle(
                          fontSize: 9.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontFamily: 'IBM',
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 2.h),
                Text(
                  '$formattedPoints نقطة',
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF7C3AED),
                    fontFamily: 'IBM',
                  ),
                ),
              ],
            ),
          ),

          // User Icon Badge
          Container(
            width: 40.w,
            height: 40.w,
            decoration: const BoxDecoration(
              color: Color(0xFFEDE9FE),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Icon(
                Icons.person_rounded,
                color: const Color(0xFF7C3AED),
                size: 22.w,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 40.h, horizontal: 20.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Column(
        children: [
          Icon(
            Icons.military_tech_outlined,
            size: 54.w,
            color: const Color(0xFF9CA3AF),
          ),
          SizedBox(height: 12.h),
          Text(
            _challengeMode
                ? 'لا توجد نتائج تحديات حتى الآن'
                : _isUniversityStudent
                ? 'لا يوجد متصدرين مسجلين في هذه الفرقة بعد'
                : 'لا يوجد متصدرين مسجلين في هذا الصف بعد',
            style: TextStyle(
              fontSize: 14.5.sp,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              fontFamily: 'IBM',
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 6.h),
          Text(
            'كن أول من يحل الامتحانات ويكسب النقاط ليتصدر القائمة!',
            style: TextStyle(
              fontSize: 12.5.sp,
              color: AppColors.textSecondary,
              fontFamily: 'IBM',
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerLoading() {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 8.h),
      child: Shimmer.fromColors(
        baseColor: Colors.grey.shade300,
        highlightColor: Colors.grey.shade100,
        child: Column(
          children: [
            Container(
              width: double.infinity,
              height: 120.h,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22.r),
              ),
            ),
            SizedBox(height: 20.h),
            Container(
              width: double.infinity,
              height: 300.h,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22.r),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
