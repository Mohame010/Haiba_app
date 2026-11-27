import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/routing/app_routes.dart';
import '../../domain/entities/notification_entity.dart';
import '../cubits/notifications_cubit.dart';
import '../cubits/notifications_state.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    context.read<NotificationsCubit>().loadNotifications();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppColors.secondary,
            size: 20,
          ),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'الإشعارات',
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            fontFamily: 'IBM',
          ),
        ),
        actions: [
          BlocBuilder<NotificationsCubit, NotificationsState>(
            builder: (context, state) {
              if (state is NotificationsLoaded && state.unreadCount > 0) {
                return TextButton(
                  onPressed: () {
                    context.read<NotificationsCubit>().markAllAsRead();
                  },
                  child: Text(
                    'قراءة الكل',
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                      fontFamily: 'IBM',
                    ),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      body: SafeArea(
        child: BlocBuilder<NotificationsCubit, NotificationsState>(
          builder: (context, state) {
            return switch (state) {
              NotificationsLoading() ||
              NotificationsInitial() => _buildShimmerLoading(),
              NotificationsError(:final message) => _buildErrorState(message),
              NotificationsLoaded(:final notifications) =>
                notifications.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        color: AppColors.primary,
                        onRefresh: () async {
                          await context
                              .read<NotificationsCubit>()
                              .loadNotifications();
                        },
                        child: ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(
                            parent: BouncingScrollPhysics(),
                          ),
                          padding: EdgeInsets.symmetric(
                            horizontal: 18.w,
                            vertical: 16.h,
                          ),
                          itemCount: notifications.length,
                          separatorBuilder: (context, index) =>
                              SizedBox(height: 12.h),
                          itemBuilder: (context, index) {
                            final notification = notifications[index];
                            return _buildNotificationCard(notification);
                          },
                        ),
                      ),
            };
          },
        ),
      ),
    );
  }

  Widget _buildNotificationCard(NotificationEntity notification) {
    final formattedTime = _formatNotificationDateTime(notification.createdAt);

    return GestureDetector(
      onTap: () {
        if (!notification.isRead) {
          context.read<NotificationsCubit>().markAsRead(notification.id);
        }
        if (notification.actionRoute != AppRoutes.notifications) {
          AppRouter.openNotificationDestination(
            route: notification.actionRoute,
            actionId: notification.actionId,
          );
        }
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
        decoration: BoxDecoration(
          color: notification.isRead ? Colors.white : const Color(0xFFF5F3FF),
          borderRadius: BorderRadius.circular(18.r),
          border: Border.all(
            color: notification.isRead
                ? AppColors.border
                : AppColors.primary.withAlpha(80),
            width: notification.isRead ? 1 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: notification.isRead
                  ? Colors.black.withAlpha(6)
                  : AppColors.primary.withAlpha(20),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Notification Icon
            Container(
              width: 44.w,
              height: 44.w,
              decoration: BoxDecoration(
                color: notification.isRead
                    ? AppColors.cardLight
                    : AppColors.primary.withAlpha(30),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(
                  _getIconForRoute(notification.actionRoute),
                  color: notification.isRead
                      ? AppColors.textSecondary
                      : AppColors.primary,
                  size: 22.w,
                ),
              ),
            ),
            SizedBox(width: 12.w),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          notification.title,
                          style: TextStyle(
                            fontSize: 14.5.sp,
                            fontWeight: notification.isRead
                                ? FontWeight.w700
                                : FontWeight.w800,
                            color: AppColors.textPrimary,
                            fontFamily: 'IBM',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (!notification.isRead) ...[
                        SizedBox(width: 6.w),
                        Container(
                          width: 8.w,
                          height: 8.w,
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ],
                  ),
                  SizedBox(height: 6.h),
                  Text(
                    notification.body,
                    style: TextStyle(
                      fontSize: 12.5.sp,
                      fontWeight: FontWeight.w400,
                      color: AppColors.textSecondary,
                      height: 1.4,
                      fontFamily: 'IBM',
                    ),
                  ),
                  SizedBox(height: 10.h),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.access_time_rounded,
                            size: 13.sp,
                            color: AppColors.textMuted,
                          ),
                          SizedBox(width: 4.w),
                          Text(
                            formattedTime,
                            style: TextStyle(
                              fontSize: 11.5.sp,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textMuted,
                              fontFamily: 'IBM',
                            ),
                          ),
                        ],
                      ),
                      if (notification.actionRoute.isNotEmpty &&
                          notification.actionRoute != '/home')
                        Row(
                          children: [
                            Text(
                              'عرض التفاصيل',
                              style: TextStyle(
                                fontSize: 11.5.sp,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                                fontFamily: 'IBM',
                              ),
                            ),
                            SizedBox(width: 2.w),
                            Icon(
                              Icons.arrow_back_ios_new_rounded,
                              size: 10.sp,
                              color: AppColors.primary,
                            ),
                          ],
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 12-Hour Arabic date and time formatter: e.g. "اليوم - 04:30 م" or "السبت 24 مايو - 10:15 ص"
  String _formatNotificationDateTime(DateTime dt) {
    final local = dt.toLocal();
    final now = DateTime.now();

    // 12-hour format calculation
    final hour12 = local.hour == 0
        ? 12
        : (local.hour > 12 ? local.hour - 12 : local.hour);
    final period = local.hour >= 12 ? 'م' : 'ص';
    final minuteStr = local.minute.toString().padLeft(2, '0');
    final timeStr = '$hour12:$minuteStr $period';

    final isToday =
        local.year == now.year &&
        local.month == now.month &&
        local.day == now.day;
    final isYesterday =
        local.year == now.year &&
        local.month == now.month &&
        local.day == (now.day - 1);

    if (isToday) {
      return 'اليوم - $timeStr';
    } else if (isYesterday) {
      return 'أمس - $timeStr';
    } else {
      const arabicMonths = [
        'يناير',
        'فبراير',
        'مارس',
        'أبريل',
        'مايو',
        'يونيو',
        'يوليو',
        'أغسطس',
        'سبتمبر',
        'أكتوبر',
        'نوفمبر',
        'ديسمبر',
      ];
      final monthName = arabicMonths[local.month - 1];
      return '${local.day} $monthName - $timeStr';
    }
  }

  IconData _getIconForRoute(String route) {
    if (route.contains('exam')) {
      return Icons.assignment_outlined;
    } else if (route.contains('lecture')) {
      return Icons.play_lesson_outlined;
    } else if (route.contains('leaderboard')) {
      return Icons.emoji_events_outlined;
    }
    return Icons.notifications_active_outlined;
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 32.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 90.w,
              height: 90.w,
              decoration: BoxDecoration(
                color: AppColors.primary.withAlpha(20),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.notifications_off_outlined,
                size: 44.w,
                color: AppColors.primary,
              ),
            ),
            SizedBox(height: 18.h),
            Text(
              'لا توجد إشعارات جديدة',
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                fontFamily: 'IBM',
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              'ستظهر هنا جميع التنبيهات الخاصة بالدروس، مواعيد الامتحانات، ولوحة الشرف فور صدورها.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.sp,
                color: AppColors.textSecondary,
                height: 1.5,
                fontFamily: 'IBM',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline_rounded, size: 48.w, color: AppColors.error),
          SizedBox(height: 12.h),
          Text(
            message,
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
                context.read<NotificationsCubit>().loadNotifications(),
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

  Widget _buildShimmerLoading() {
    return ListView.separated(
      padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 16.h),
      itemCount: 4,
      separatorBuilder: (context, index) => SizedBox(height: 12.h),
      itemBuilder: (context, index) => Shimmer.fromColors(
        baseColor: Colors.grey.shade200,
        highlightColor: Colors.grey.shade100,
        child: Container(
          height: 100.h,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18.r),
          ),
        ),
      ),
    );
  }
}
