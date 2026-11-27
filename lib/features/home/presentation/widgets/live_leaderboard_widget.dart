import 'package:material_ui/material_ui.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../domain/entities/leaderboard_entry_entity.dart';

class LiveLeaderboardWidget extends StatelessWidget {
  final List<LeaderboardEntryEntity> topStudents;
  final String? grade;
  final VoidCallback? onViewAllTap;
  final Function(LeaderboardEntryEntity)? onStudentTap;

  const LiveLeaderboardWidget({
    super.key,
    required this.topStudents,
    this.grade,
    this.onViewAllTap,
    this.onStudentTap,
  });

  @override
  Widget build(BuildContext context) {
    if (topStudents.isEmpty) return const SizedBox.shrink();

    // Extract top 3 rankers safely
    LeaderboardEntryEntity? rank1;
    LeaderboardEntryEntity? rank2;
    LeaderboardEntryEntity? rank3;

    for (final student in topStudents) {
      if (student.rank == 1) rank1 = student;
      if (student.rank == 2) rank2 = student;
      if (student.rank == 3) rank3 = student;
    }

    rank1 ??= topStudents.isNotEmpty ? topStudents[0] : null;
    rank2 ??= topStudents.length > 1 ? topStudents[1] : null;
    rank3 ??= topStudents.length > 2 ? topStudents[2] : null;

    final remainingStudents =
        topStudents.where((s) => s.rank > 3).take(2).toList();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.03),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 18.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Header Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(9.w),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFEF3C7), Color(0xFFFDE68A)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14.r),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.emoji_events_rounded,
                      color: const Color(0xFFD97706),
                      size: 22.w,
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'لوحة الشرف والمتفوقين',
                        style: TextStyle(
                          fontSize: 15.5.sp,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                          fontFamily: 'IBM',
                        ),
                      ),
                      if (grade != null && grade!.isNotEmpty) ...[
                        SizedBox(height: 2.h),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 6.w,
                            vertical: 1.5.h,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(6.r),
                          ),
                          child: Text(
                            grade!,
                            style: TextStyle(
                              fontSize: 10.5.sp,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                              fontFamily: 'IBM',
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
              InkWell(
                onTap: onViewAllTap,
                borderRadius: BorderRadius.circular(10.r),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  child: Row(
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
                      SizedBox(width: 3.w),
                      const Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 11,
                        color: AppColors.primary,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: 18.h),

          // 2. Stepped Pyramid Podium (Left: Rank 2, Center: Rank 1, Right: Rank 3)
          Container(
            padding: EdgeInsets.only(top: 8.h),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFFF8FAFC),
                  Colors.white.withValues(alpha: 0.0),
                ],
              ),
              borderRadius: BorderRadius.circular(18.r),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Rank 2: Silver (Medium height)
                if (rank2 != null)
                  Expanded(
                    child: _buildPodiumColumn(
                      student: rank2,
                      rank: 2,
                      podiumHeight: 70.h,
                      pedestalGradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFFF1F5F9), Color(0xFFCBD5E1)],
                      ),
                      topBevelColor: const Color(0xFFE2E8F0),
                      borderColor: const Color(0xFF94A3B8),
                      badgeColor: const Color(0xFF64748B),
                      avatarSize: 48.w,
                    ),
                  ),

                SizedBox(width: 6.w),

                // Rank 1: Gold (Center & Highest)
                if (rank1 != null)
                  Expanded(
                    child: _buildPodiumColumn(
                      student: rank1,
                      rank: 1,
                      podiumHeight: 102.h,
                      pedestalGradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFFFEF3C7), Color(0xFFFDE68A)],
                      ),
                      topBevelColor: const Color(0xFFFFFBEB),
                      borderColor: const Color(0xFFF59E0B),
                      badgeColor: const Color(0xFFD97706),
                      avatarSize: 62.w,
                      isWinner: true,
                    ),
                  ),

                SizedBox(width: 6.w),

                // Rank 3: Bronze (Lowest height)
                if (rank3 != null)
                  Expanded(
                    child: _buildPodiumColumn(
                      student: rank3,
                      rank: 3,
                      podiumHeight: 52.h,
                      pedestalGradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFFFFEDD5), Color(0xFFFED7AA)],
                      ),
                      topBevelColor: const Color(0xFFFFF7ED),
                      borderColor: const Color(0xFFD97706),
                      badgeColor: const Color(0xFFB45309),
                      avatarSize: 46.w,
                    ),
                  ),
              ],
            ),
          ),

          // 3. Podium Base Platform Line
          Container(
            height: 5.h,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFFCBD5E1),
                  Color(0xFFF59E0B),
                  Color(0xFFFED7AA),
                ],
              ),
              borderRadius: BorderRadius.circular(3.r),
            ),
          ),

          // 4. Remaining Students List (Ranks 4, 5)
          if (remainingStudents.isNotEmpty) ...[
            SizedBox(height: 14.h),
            for (final s in remainingStudents) _buildCompactStudentRow(s),
          ],
        ],
      ),
    );
  }

  Widget _buildPodiumColumn({
    required LeaderboardEntryEntity student,
    required int rank,
    required double podiumHeight,
    required Gradient pedestalGradient,
    required Color topBevelColor,
    required Color borderColor,
    required Color badgeColor,
    required double avatarSize,
    bool isWinner = false,
  }) {
    final formattedPoints = NumberFormat('#,###').format(student.points);

    return GestureDetector(
      onTap: () => onStudentTap?.call(student),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Crown / Trophy for 1st Place
          if (isWinner)
            Padding(
              padding: EdgeInsets.only(bottom: 2.h),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 28.w,
                    height: 28.w,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.35),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.military_tech_rounded,
                    color: const Color(0xFFF59E0B),
                    size: 28.w,
                  ),
                ],
              ),
            )
          else
            SizedBox(height: 14.h),

          // Avatar Stack with Medal Ring & Rank Pill
          Stack(
            alignment: Alignment.bottomCenter,
            clipBehavior: Clip.none,
            children: [
              Container(
                width: avatarSize,
                height: avatarSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isWinner
                      ? const Color(0xFFFFFBEB)
                      : badgeColor.withValues(alpha: 0.08),
                  border: Border.all(
                    color: isWinner ? const Color(0xFFF59E0B) : borderColor,
                    width: isWinner ? 3 : 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: badgeColor.withValues(alpha: isWinner ? 0.3 : 0.12),
                      blurRadius: isWinner ? 12 : 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    student.name.trim().isNotEmpty
                        ? student.name.trim().characters.first
                        : 'ط',
                    style: TextStyle(
                      fontSize: isWinner ? 22.sp : 17.sp,
                      fontWeight: FontWeight.w900,
                      color: isWinner ? const Color(0xFFB45309) : badgeColor,
                      fontFamily: 'IBM',
                    ),
                  ),
                ),
              ),

              // Rank Pill Badge
              Positioned(
                bottom: -5.h,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 1.5.h),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isWinner
                          ? [const Color(0xFFF59E0B), const Color(0xFFD97706)]
                          : [badgeColor, badgeColor.withValues(alpha: 0.85)],
                    ),
                    borderRadius: BorderRadius.circular(10.r),
                    border: Border.all(color: Colors.white, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isWinner) ...[
                        Icon(Icons.star_rounded,
                            size: 9.w, color: Colors.white),
                        SizedBox(width: 1.w),
                      ],
                      Text(
                        '#$rank',
                        style: TextStyle(
                          fontSize: 9.5.sp,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          fontFamily: 'IBM',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: 10.h),

          // Student Name
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 2.w),
            child: Text(
              student.name,
              style: TextStyle(
                fontSize: isWinner ? 12.sp : 11.sp,
                fontWeight: isWinner ? FontWeight.w800 : FontWeight.w700,
                color: student.isCurrentUser
                    ? AppColors.primary
                    : AppColors.textPrimary,
                fontFamily: 'IBM',
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),

          SizedBox(height: 3.h),

          // Points Pill
          Container(
            padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
            decoration: BoxDecoration(
              color: isWinner
                  ? const Color(0xFFFEF3C7)
                  : badgeColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.bolt_rounded,
                  size: 11.w,
                  color: isWinner ? const Color(0xFFD97706) : badgeColor,
                ),
                SizedBox(width: 2.w),
                Flexible(
                  child: Text(
                    formattedPoints,
                    style: TextStyle(
                      fontSize: 10.5.sp,
                      fontWeight: FontWeight.w700,
                      color: isWinner ? const Color(0xFFB45309) : badgeColor,
                      fontFamily: 'IBM',
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 8.h),

          // 3D Stepped Podium Block with Top Highlight
          Container(
            width: double.infinity,
            height: podiumHeight,
            decoration: BoxDecoration(
              gradient: pedestalGradient,
              borderRadius: BorderRadius.vertical(top: Radius.circular(14.r)),
              border: Border.all(
                color: isWinner
                    ? const Color(0xFFFDE68A)
                    : Colors.white.withValues(alpha: 0.8),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 6,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              children: [
                // Top Bevel highlight bar
                Container(
                  height: 3.h,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: topBevelColor,
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(14.r)),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Container(
                      width: isWinner ? 36.w : 28.w,
                      height: isWinner ? 36.w : 28.w,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.8),
                          width: 1.5,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          '$rank',
                          style: TextStyle(
                            fontSize: isWinner ? 20.sp : 15.sp,
                            fontWeight: FontWeight.w900,
                            color: isWinner
                                ? const Color(0xFFB45309)
                                : badgeColor,
                            fontFamily: 'IBM',
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactStudentRow(LeaderboardEntryEntity student) {
    final formattedPoints = NumberFormat('#,###').format(student.points);

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.h),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: student.isCurrentUser
              ? AppColors.primary.withValues(alpha: 0.07)
              : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(
            color: student.isCurrentUser
                ? AppColors.primary.withValues(alpha: 0.35)
                : const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 26.w,
              height: 26.w,
              decoration: BoxDecoration(
                color: student.isCurrentUser
                    ? AppColors.primary
                    : const Color(0xFFE2E8F0),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '${student.rank}',
                  style: TextStyle(
                    fontSize: 11.5.sp,
                    fontWeight: FontWeight.w800,
                    color: student.isCurrentUser
                        ? Colors.white
                        : AppColors.textSecondary,
                    fontFamily: 'IBM',
                  ),
                ),
              ),
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: Text(
                student.name,
                style: TextStyle(
                  fontSize: 12.5.sp,
                  fontWeight: student.isCurrentUser
                      ? FontWeight.w800
                      : FontWeight.w600,
                  color: student.isCurrentUser
                      ? AppColors.primary
                      : AppColors.textPrimary,
                  fontFamily: 'IBM',
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (student.isCurrentUser)
              Container(
                margin: EdgeInsets.only(left: 6.w),
                padding:
                    EdgeInsets.symmetric(horizontal: 6.w, vertical: 1.5.h),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(6.r),
                ),
                child: Text(
                  'أنت',
                  style: TextStyle(
                    fontSize: 9.sp,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    fontFamily: 'IBM',
                  ),
                ),
              ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.bolt_rounded,
                  size: 13.w,
                  color: const Color(0xFFF59E0B),
                ),
                SizedBox(width: 2.w),
                Text(
                  '$formattedPoints نقطة',
                  style: TextStyle(
                    fontSize: 11.5.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                    fontFamily: 'IBM',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
