import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shimmer/shimmer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/di/dependency_injection.dart';
import '../../../core/helpers/app_logger.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/services/device_session_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../novels/data/novels_repository.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _profile;
  Map<String, dynamic>? _support;
  String _teacherName = '';
  int _rank = 0;
  int _completedLectures = 0;
  int _completedExams = 0;
  bool _loading = true;
  bool _isLoggingOut = false;
  bool _isDeleting = false;
  String? _error;
  Map<String, dynamic>? _libraryStatus;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) {
      if (mounted) context.go(AppRoutes.login);
      return;
    }

    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final profile = await client
          .from('students')
          .select()
          .eq('id', user.id)
          .single();
      final points = (profile['points'] as num?)?.toInt() ?? 0;
      final grade = profile['grade'] as String? ?? '';

      if (!mounted) return;
      setState(() {
        _profile = profile;
      });

      try {
        final results = await Future.wait<dynamic>([
          client
              .from('students')
              .count(CountOption.exact)
              .eq('grade', grade)
              .gt('points', points),
          client
              .from('student_lecture_access')
              .count(CountOption.exact)
              .eq('student_id', user.id),
          client
              .from('exam_submissions')
              .count(CountOption.exact)
              .eq('student_id', user.id),
          client
              .from('teachers')
              .select('name')
              .eq('id', AppConstants.activeTeacherId)
              .maybeSingle(),
          client
              .from('app_settings')
              .select('value')
              .eq('key', 'student_support')
              .maybeSingle(),
          NovelsRepository().fetchLibrarySubscriptionStatus(),
        ]);

        if (!mounted) return;
        final teacher = results[3] as Map<String, dynamic>?;
        final supportRow = results[4] as Map<String, dynamic>?;
        final libraryStatus = results[5] as Map<String, dynamic>?;
        setState(() {
          _rank = (results[0] as int) + 1;
          _completedLectures = results[1] as int;
          _completedExams = results[2] as int;
          _teacherName = teacher?['name'] as String? ?? '';
          _support = supportRow?['value'] is Map
              ? Map<String, dynamic>.from(supportRow!['value'] as Map)
              : null;
          _libraryStatus = libraryStatus;
        });
      } catch (error, stackTrace) {
        AppLogger.authLog(
          'Optional profile statistics could not be loaded',
          error: '$error\n$stackTrace',
        );
      }

      if (mounted) {
        setState(() => _loading = false);
      }
    } catch (error, stackTrace) {
      AppLogger.authLog(
        'Error loading profile from Supabase',
        error: '$error\n$stackTrace',
      );
      if (!mounted) return;
      setState(() {
        _error = 'تعذر تحميل بيانات الحساب';
        _loading = false;
      });
    }
  }

  void _copyToClipboard(String text, String message) {
    Clipboard.setData(ClipboardData(text: text));
    HapticFeedback.lightImpact();
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Color(0xFF22C55E),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check, color: Colors.white, size: 14),
            ),
            const SizedBox(width: 10),
            Text(
              message,
              style: const TextStyle(
                fontFamily: 'IBM',
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF0F172A),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14.r),
        ),
        margin: EdgeInsets.all(16.w),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _logout() async {
    if (_isLoggingOut || _isDeleting) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24.r),
        ),
        iconPadding: EdgeInsets.only(top: 24.h),
        icon: Container(
          width: 64.w,
          height: 64.w,
          decoration: BoxDecoration(
            color: const Color(0xFFFEE2E2),
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFFECACA), width: 4.w),
          ),
          child: const Icon(
            Icons.logout_rounded,
            color: AppColors.error,
            size: 30,
          ),
        ),
        title: Text(
          'تسجيل الخروج؟',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'IBM',
            fontWeight: FontWeight.w800,
            fontSize: 18.sp,
            color: AppColors.textPrimary,
          ),
        ),
        content: Text(
          'هل أنت متأكد أنك تريد تسجيل الخروج من حسابك على هذا الجهاز؟ سيتعين عليك تسجيل الدخول مجددًا.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'IBM',
            fontSize: 13.sp,
            color: AppColors.textSecondary,
            height: 1.5,
          ),
        ),
        actionsPadding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 20.h),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 12.h),
                    side: const BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14.r),
                    ),
                  ),
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: Text(
                    'إلغاء',
                    style: TextStyle(
                      fontFamily: 'IBM',
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      fontSize: 14.sp,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    elevation: 0,
                    padding: EdgeInsets.symmetric(vertical: 12.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14.r),
                    ),
                  ),
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: Text(
                    'تسجيل الخروج',
                    style: TextStyle(
                      fontFamily: 'IBM',
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      fontSize: 14.sp,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (mounted) {
      setState(() => _isLoggingOut = true);
    }
    try {
      await getIt<DeviceSessionService>().signOutCurrentDevice();
    } catch (error, stackTrace) {
      AppLogger.authLog(
        'Profile logout cleanup failed',
        error: error,
        stackTrace: stackTrace,
      );
      try {
        await Supabase.instance.client.auth
            .signOut(scope: SignOutScope.local)
            .timeout(const Duration(seconds: 3));
      } catch (fallbackError) {
        AppLogger.authLog('Fallback local logout failed', error: fallbackError);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoggingOut = false);
      }
      AppRouter.pushLoginAndClearStack();
    }
  }

  Future<void> _deleteAccount() async {
    if (_isDeleting || _isLoggingOut) return;

    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final canDelete = controller.text.trim() == 'حذف';
          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24.r),
            ),
            iconPadding: EdgeInsets.only(top: 24.h),
            icon: Container(
              width: 64.w,
              height: 64.w,
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFFECACA), width: 4.w),
              ),
              child: const Icon(
                Icons.delete_forever_rounded,
                color: AppColors.error,
                size: 32,
              ),
            ),
            title: Text(
              'حذف الحساب نهائيًا؟',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'IBM',
                fontWeight: FontWeight.w800,
                fontSize: 18.sp,
                color: AppColors.textPrimary,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: EdgeInsets.all(12.w),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(14.r),
                    border: Border.all(
                      color: const Color(0xFFFCA5A5).withOpacity(0.4),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        color: AppColors.error,
                        size: 20,
                      ),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: Text(
                          'سيتم مسح حسابك وكافة النقاط والحصص وسجل الاختبارات بشكل نهائي، ولا يمكن استرجاع هذه البيانات مجددًا.',
                          style: TextStyle(
                            fontFamily: 'IBM',
                            fontSize: 12.sp,
                            color: const Color(0xFF991B1B),
                            height: 1.45,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16.h),
                Text(
                  'للمتابعة، يرجى كتابة كلمة "حذف" في الحقل أدناه:',
                  style: TextStyle(
                    fontFamily: 'IBM',
                    fontSize: 12.5.sp,
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 10.h),
                TextField(
                  controller: controller,
                  onChanged: (_) => setDialogState(() {}),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'IBM',
                    fontWeight: FontWeight.w700,
                    fontSize: 15.sp,
                  ),
                  decoration: InputDecoration(
                    hintText: 'اكتب "حذف"',
                    hintStyle: TextStyle(
                      fontFamily: 'IBM',
                      color: AppColors.textMuted,
                      fontSize: 13.sp,
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16.w,
                      vertical: 12.h,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14.r),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14.r),
                      borderSide: const BorderSide(
                        color: AppColors.error,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            actionsPadding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 20.h),
            actionsAlignment: MainAxisAlignment.center,
            actions: [
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 12.h),
                        side: const BorderSide(color: AppColors.border),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14.r),
                        ),
                      ),
                      onPressed: () => Navigator.pop(dialogContext, false),
                      child: Text(
                        'إلغاء',
                        style: TextStyle(
                          fontFamily: 'IBM',
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                          fontSize: 14.sp,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error,
                        disabledBackgroundColor: AppColors.error.withOpacity(
                          0.35,
                        ),
                        elevation: 0,
                        padding: EdgeInsets.symmetric(vertical: 12.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14.r),
                        ),
                      ),
                      onPressed: canDelete
                          ? () => Navigator.pop(dialogContext, true)
                          : null,
                      child: Text(
                        'حذف حسابي',
                        style: TextStyle(
                          fontFamily: 'IBM',
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          fontSize: 14.sp,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
    controller.dispose();
    if (confirmed != true) return;

    if (mounted) setState(() => _isDeleting = true);
    try {
      await Supabase.instance.client.rpc('delete_my_account');

      try {
        await getIt<DeviceSessionService>().signOutCurrentDevice();
      } catch (_) {
        try {
          await Supabase.instance.client.auth
              .signOut(scope: SignOutScope.local)
              .timeout(const Duration(seconds: 3));
        } catch (_) {}
      }
      AppRouter.pushLoginAndClearStack();
    } catch (error, stackTrace) {
      AppLogger.authLog('Delete account failed', error: '$error\n$stackTrace');
      if (!mounted) return;
      setState(() => _isDeleting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر حذف الحساب، حاول مرة أخرى')),
      );
    }
  }

  Future<void> _launchSupport(String type) async {
    final phone = (_support?[type] as String? ?? '').replaceAll(
      RegExp(r'[^0-9+]'),
      '',
    );
    if (phone.isEmpty) return;
    final uri = type == 'whatsapp'
        ? Uri.parse(
            'https://wa.me/$phone?text=${Uri.encodeComponent('مرحباً، أحتاج مساعدة في منصة كيو 360 التعليمية')}',
          )
        : Uri(scheme: 'tel', path: phone);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _showSupportOptions() {
    final whatsappAvailable =
        (_support?['whatsapp'] as String? ?? '').isNotEmpty;
    final phoneAvailable = (_support?['phone'] as String? ?? '').isNotEmpty;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      showDragHandle: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 24.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 52.w,
                height: 52.w,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.support_agent_rounded,
                  color: AppColors.primary,
                  size: 28,
                ),
              ),
              SizedBox(height: 12.h),
              Text(
                'فريق الدعم الفني والطلابي',
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'IBM',
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                _support?['available_hours'] as String? ??
                    'جاهزون لمساعدتك والإجابة عن كافة استفساراتك',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontFamily: 'IBM',
                  fontSize: 12.5.sp,
                ),
              ),
              SizedBox(height: 20.h),
              if (whatsappAvailable)
                _supportOptionTile(
                  icon: Icons.chat_rounded,
                  title: 'محادثة عبر واتساب',
                  subtitle: _support?['whatsapp'] as String? ?? '',
                  color: const Color(0xFF16A34A),
                  bgColor: const Color(0xFFE8F8EE),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _launchSupport('whatsapp');
                  },
                ),
              if (phoneAvailable) ...[
                if (whatsappAvailable) SizedBox(height: 10.h),
                _supportOptionTile(
                  icon: Icons.phone_rounded,
                  title: 'اتصال هاتفي مباشر',
                  subtitle: _support?['phone'] as String? ?? '',
                  color: const Color(0xFF2563EB),
                  bgColor: const Color(0xFFEFF6FF),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _launchSupport('phone');
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _supportOptionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required Color bgColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(16.r),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16.r),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 44.w,
                height: 44.w,
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              SizedBox(width: 14.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontFamily: 'IBM',
                        fontWeight: FontWeight.w700,
                        fontSize: 14.sp,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontFamily: 'IBM',
                        fontSize: 12.sp,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14.sp,
                color: AppColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        title: Text(
          'الملف الشخصي',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontFamily: 'IBM',
            fontSize: 18.sp,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'تحديث البيانات',
            icon: const Icon(
              Icons.refresh_rounded,
              color: AppColors.textPrimary,
            ),
            onPressed: _loading ? null : _loadProfile,
          ),
        ],
      ),
      body: _loading
          ? _buildShimmerLoading()
          : _error != null
          ? _buildErrorView()
          : RefreshIndicator(
              onRefresh: _loadProfile,
              color: AppColors.primary,
              backgroundColor: Colors.white,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 36.h),
                children: [
                  _buildHeader(),
                  SizedBox(height: 18.h),
                  _buildStatsDashboard(),
                  SizedBox(height: 20.h),
                  _buildLibrarySubscriptionCard(),
                  SizedBox(height: 20.h),
                  _buildInfoSection(),
                  SizedBox(height: 16.h),
                  _buildSupportBanner(),
                  SizedBox(height: 16.h),
                  _buildAccountManagementSection(),
                ],
              ),
            ),
    );
  }

  Widget _buildHeader() {
    final name = _profile?['name'] as String? ?? 'طالب جديد';
    final code = _profile?['student_code'] as String? ?? '';
    final grade = _profile?['grade'] as String? ?? '';
    final educationLevel = _profile?['education_level'] as String? ?? '';
    final initialLetter = name.trim().isNotEmpty
        ? name.trim().characters.first
        : 'ط';

    final gradeStageList = <String>[];
    if (grade.isNotEmpty) gradeStageList.add(grade);
    if (educationLevel.isNotEmpty) gradeStageList.add(educationLevel);
    final gradeStageText = gradeStageList.join(' • ');

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24.r),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F172A), Color(0xFF1E1B4B), Color(0xFF4338CA)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E1B4B).withOpacity(0.28),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.antiAlias,
        children: [
          // Background ambient light circles
          Positioned(
            top: -30.r,
            left: -20.r,
            child: Container(
              width: 120.r,
              height: 120.r,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.05),
              ),
            ),
          ),
          Positioned(
            bottom: -40.r,
            right: -20.r,
            child: Container(
              width: 140.r,
              height: 140.r,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF7C3AED).withOpacity(0.18),
              ),
            ),
          ),
          // Content
          Padding(
            padding: EdgeInsets.all(20.w),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Avatar with glowing ring
                    Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        Container(
                          padding: EdgeInsets.all(3.r),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [Color(0xFFFBBF24), Color(0xFF818CF8)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: CircleAvatar(
                            radius: 32.r,
                            backgroundColor: const Color(0xFF1E1B4B),
                            child: Text(
                              initialLetter,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 26.sp,
                                fontWeight: FontWeight.w800,
                                fontFamily: 'IBM',
                              ),
                            ),
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.all(2.5.r),
                          decoration: const BoxDecoration(
                            color: Color(0xFF1E1B4B),
                            shape: BoxShape.circle,
                          ),
                          child: Container(
                            padding: EdgeInsets.all(3.5.r),
                            decoration: const BoxDecoration(
                              color: Color(0xFF22C55E),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.check,
                              size: 9.r,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(width: 14.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 17.5.sp,
                              fontWeight: FontWeight.w800,
                              fontFamily: 'IBM',
                              letterSpacing: -0.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (gradeStageText.isNotEmpty) ...[
                            SizedBox(height: 6.h),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 10.w,
                                vertical: 4.h,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(20.r),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.1),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.school_rounded,
                                    size: 13.sp,
                                    color: const Color(0xFFE0E7FF),
                                  ),
                                  SizedBox(width: 5.w),
                                  Flexible(
                                    child: Text(
                                      gradeStageText,
                                      style: TextStyle(
                                        color: const Color(0xFFE0E7FF),
                                        fontSize: 11.5.sp,
                                        fontWeight: FontWeight.w600,
                                        fontFamily: 'IBM',
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                if (code.isNotEmpty) ...[
                  SizedBox(height: 16.h),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 14.w,
                      vertical: 10.h,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(16.r),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.12),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(6.r),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.14),
                            borderRadius: BorderRadius.circular(10.r),
                          ),
                          child: Icon(
                            Icons.badge_rounded,
                            size: 16.sp,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(width: 10.w),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'كود الطالب',
                              style: TextStyle(
                                fontSize: 10.5.sp,
                                color: Colors.white60,
                                fontFamily: 'IBM',
                              ),
                            ),
                            Text(
                              code,
                              style: TextStyle(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                fontFamily: 'IBM',
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => _copyToClipboard(
                              code,
                              'تم نسخ كود الطالب بنجاح',
                            ),
                            borderRadius: BorderRadius.circular(12.r),
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 12.w,
                                vertical: 6.h,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.18),
                                borderRadius: BorderRadius.circular(12.r),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.copy_rounded,
                                    size: 13.sp,
                                    color: Colors.white,
                                  ),
                                  SizedBox(width: 5.w),
                                  Text(
                                    'نسخ',
                                    style: TextStyle(
                                      fontSize: 12.sp,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                      fontFamily: 'IBM',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsDashboard() {
    final points = (_profile?['points'] as num?)?.toInt() ?? 0;
    final formattedPoints = NumberFormat('#,###').format(points);
    final rankText = _rank > 0 ? '#$_rank' : '-';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(bottom: 10.h, right: 4.w),
          child: Row(
            children: [
              Icon(
                Icons.insights_rounded,
                size: 18.sp,
                color: AppColors.primary,
              ),
              SizedBox(width: 6.w),
              Text(
                'مؤشرات الأداء والإنجاز',
                style: TextStyle(
                  fontFamily: 'IBM',
                  fontSize: 14.5.sp,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
        Row(
          children: [
            Expanded(
              child: _statCard(
                title: 'مجموع النقاط',
                value: formattedPoints,
                icon: Icons.stars_rounded,
                iconColor: const Color(0xFFD97706),
                bgColor: const Color(0xFFFFFBEB),
                borderColor: const Color(0xFFFDE68A),
              ),
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: _statCard(
                title: 'الترتيب العام',
                value: rankText,
                icon: Icons.emoji_events_rounded,
                iconColor: const Color(0xFF7C3AED),
                bgColor: const Color(0xFFF5F3FF),
                borderColor: const Color(0xFFDDD6FE),
              ),
            ),
          ],
        ),
        SizedBox(height: 10.h),
        Row(
          children: [
            Expanded(
              child: _statCard(
                title: 'الحصص المكتملة',
                value: '$_completedLectures',
                icon: Icons.play_circle_fill_rounded,
                iconColor: const Color(0xFF059669),
                bgColor: const Color(0xFFECFDF5),
                borderColor: const Color(0xFFA7F3D0),
              ),
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: _statCard(
                title: 'الاختبارات المنجزة',
                value: '$_completedExams',
                icon: Icons.task_alt_rounded,
                iconColor: const Color(0xFF0284C7),
                bgColor: const Color(0xFFF0F9FF),
                borderColor: const Color(0xFFBAE6FD),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _statCard({
    required String title,
    required String value,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required Color borderColor,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: AppColors.border.withOpacity(0.7)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44.w,
            height: 44.w,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(13.r),
              border: Border.all(color: borderColor, width: 1),
            ),
            child: Icon(icon, color: iconColor, size: 22.sp),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontFamily: 'IBM',
                    fontWeight: FontWeight.w800,
                    fontSize: 16.5.sp,
                    color: AppColors.textPrimary,
                    height: 1.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 2.h),
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'IBM',
                    fontSize: 11.sp,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLibrarySubscriptionCard() {
    final status = _libraryStatus;
    final active = status?['has_subscription'] == true;
    final plan = status?['plan'] is Map
        ? Map<String, dynamic>.from(status!['plan'] as Map)
        : null;
    final used = (status?['seconds_used'] as num?)?.toInt() ?? 0;
    final limit = (plan?['listening_limit_seconds'] as num?)?.toInt();
    final unlimited = limit == null || plan?['listening_period'] == 'unlimited';
    final usedLabel = unlimited
        ? '${used ~/ 60} دقيقة مستخدمة'
        : '${used ~/ 60} / ${limit! ~/ 60} دقيقة';
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: AppColors.primary.withAlpha(35)),
      ),
      child: Row(
        children: [
          Container(
            width: 46.w,
            height: 46.w,
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(18),
              borderRadius: BorderRadius.circular(14.r),
            ),
            child: Icon(
              active
                  ? Icons.workspace_premium_rounded
                  : Icons.lock_open_rounded,
              color: AppColors.primary,
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  active
                      ? (plan?['name']?.toString() ?? 'اشتراك المكتبة')
                      : 'لا يوجد اشتراك نشط',
                  style: TextStyle(
                    fontFamily: 'IBM',
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  active
                      ? '$usedLabel • ${plan?['open_all_novels'] == true ? 'فتح جميع الروايات' : 'استماع وفتح المحتوى'} • ${plan?['open_poetry'] == true ? 'الشعر' : ''} ${plan?['open_podcasts'] == true ? 'والبودكاست' : ''}'
                      : 'اشترك لفتح الروايات والشعر والبودكاست',
                  style: TextStyle(
                    fontFamily: 'IBM',
                    fontSize: 11.5.sp,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection() {
    final phone = _profile?['phone'] as String? ?? '';
    final groupName = _profile?['group_name'] as String?;
    final birthDate = _profile?['birth_date'] as String?;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(bottom: 10.h, right: 4.w),
          child: Row(
            children: [
              Icon(
                Icons.assignment_ind_rounded,
                size: 18.sp,
                color: AppColors.primary,
              ),
              SizedBox(width: 6.w),
              Text(
                'البيانات الأكاديمية والشخصية',
                style: TextStyle(
                  fontFamily: 'IBM',
                  fontSize: 14.5.sp,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20.r),
            border: Border.all(color: AppColors.border.withOpacity(0.7)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              if (phone.isNotEmpty) ...[
                _modernInfoTile(
                  icon: Icons.phone_android_rounded,
                  iconColor: const Color(0xFF2563EB),
                  iconBg: const Color(0xFFEFF6FF),
                  title: 'رقم الهاتف المسجل',
                  value: phone,
                  trailing: IconButton(
                    icon: Icon(
                      Icons.copy_rounded,
                      size: 16.sp,
                      color: AppColors.textSecondary,
                    ),
                    tooltip: 'نسخ رقم الهاتف',
                    onPressed: () =>
                        _copyToClipboard(phone, 'تم نسخ رقم الهاتف'),
                  ),
                ),
                const Divider(height: 1, color: AppColors.borderLight),
              ],
              _modernInfoTile(
                icon: Icons.school_rounded,
                iconColor: const Color(0xFF7C3AED),
                iconBg: const Color(0xFFF5F3FF),
                title: 'المعلم المشرف',
                value: _teacherName.isNotEmpty
                    ? _teacherName
                    : 'المنصة التعليمية',
              ),
              if (groupName != null && groupName.trim().isNotEmpty) ...[
                const Divider(height: 1, color: AppColors.borderLight),
                _modernInfoTile(
                  icon: Icons.groups_rounded,
                  iconColor: const Color(0xFFD97706),
                  iconBg: const Color(0xFFFFFBEB),
                  title: 'المجموعة الدراسية',
                  value: groupName,
                ),
              ],
              if (birthDate != null && birthDate.trim().isNotEmpty) ...[
                const Divider(height: 1, color: AppColors.borderLight),
                _modernInfoTile(
                  icon: Icons.cake_rounded,
                  iconColor: const Color(0xFFE11D48),
                  iconBg: const Color(0xFFFFF1F2),
                  title: 'تاريخ الميلاد',
                  value: birthDate,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _modernInfoTile({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String value,
    Widget? trailing,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      child: Row(
        children: [
          Container(
            width: 40.w,
            height: 40.w,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Icon(icon, color: iconColor, size: 20.sp),
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'IBM',
                    fontSize: 11.5.sp,
                    color: AppColors.textSecondary,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  value,
                  style: TextStyle(
                    fontFamily: 'IBM',
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  Widget _buildSupportBanner() {
    final availableHours = _support?['available_hours'] as String?;
    final hasWhatsapp = (_support?['whatsapp'] as String? ?? '').isNotEmpty;
    final hasPhone = (_support?['phone'] as String? ?? '').isNotEmpty;

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: AppColors.border.withOpacity(0.7)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
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
                width: 44.w,
                height: 44.w,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(13.r),
                ),
                child: const Icon(
                  Icons.support_agent_rounded,
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
                      'الدعم ومساعدة الطلاب',
                      style: TextStyle(
                        fontFamily: 'IBM',
                        fontSize: 14.5.sp,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      availableHours ??
                          'فريق الدعم متاح للإجابة على استفساراتك',
                      style: TextStyle(
                        fontFamily: 'IBM',
                        fontSize: 11.5.sp,
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 14.h),
          Row(
            children: [
              if (hasWhatsapp)
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF16A34A),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: EdgeInsets.symmetric(vertical: 10.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                    ),
                    onPressed: () => _launchSupport('whatsapp'),
                    icon: const Icon(Icons.chat_rounded, size: 16),
                    label: Text(
                      'واتساب',
                      style: TextStyle(
                        fontFamily: 'IBM',
                        fontWeight: FontWeight.w700,
                        fontSize: 13.sp,
                      ),
                    ),
                  ),
                ),
              if (hasWhatsapp && hasPhone) SizedBox(width: 8.w),
              if (hasPhone)
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: EdgeInsets.symmetric(vertical: 10.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                    ),
                    onPressed: () => _launchSupport('phone'),
                    icon: const Icon(Icons.phone_rounded, size: 16),
                    label: Text(
                      'اتصال',
                      style: TextStyle(
                        fontFamily: 'IBM',
                        fontWeight: FontWeight.w700,
                        fontSize: 13.sp,
                      ),
                    ),
                  ),
                ),
              if (!hasWhatsapp && !hasPhone)
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.border),
                      padding: EdgeInsets.symmetric(vertical: 10.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                    ),
                    onPressed: _showSupportOptions,
                    icon: const Icon(
                      Icons.headset_mic_rounded,
                      size: 16,
                      color: AppColors.primary,
                    ),
                    label: Text(
                      'خيارات الدعم',
                      style: TextStyle(
                        fontFamily: 'IBM',
                        fontWeight: FontWeight.w700,
                        fontSize: 13.sp,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAccountManagementSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(bottom: 10.h, right: 4.w),
          child: Row(
            children: [
              Icon(
                Icons.security_rounded,
                size: 18.sp,
                color: AppColors.primary,
              ),
              SizedBox(width: 6.w),
              Text(
                'إدارة الحساب والأمان',
                style: TextStyle(
                  fontFamily: 'IBM',
                  fontSize: 14.5.sp,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20.r),
            border: Border.all(color: AppColors.border.withOpacity(0.7)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              _actionTile(
                icon: Icons.logout_rounded,
                title: 'تسجيل الخروج',
                subtitle: _isLoggingOut
                    ? 'جاري إنهاء الجلسة...'
                    : 'الخروج من الحساب على هذا الجهاز',
                iconColor: const Color(0xFFEA580C),
                iconBg: const Color(0xFFFFF7ED),
                textColor: AppColors.textPrimary,
                isLoading: _isLoggingOut,
                onTap: _isLoggingOut ? () {} : _logout,
              ),
              const Divider(height: 1, color: AppColors.borderLight),
              _actionTile(
                icon: Icons.delete_forever_rounded,
                title: 'حذف الحساب نهائيًا',
                subtitle: _isDeleting
                    ? 'جاري حذف بيانات الحساب...'
                    : 'حذف حسابك وسجل درجاتك بشكل دائم',
                iconColor: AppColors.error,
                iconBg: const Color(0xFFFEF2F2),
                textColor: AppColors.error,
                isLoading: _isDeleting,
                onTap: _isDeleting ? () {} : _deleteAccount,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _actionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color iconColor,
    required Color iconBg,
    required Color textColor,
    required VoidCallback onTap,
    bool isLoading = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isLoading ? null : onTap,
        borderRadius: BorderRadius.circular(20.r),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
          child: Row(
            children: [
              Container(
                width: 42.w,
                height: 42.w,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: isLoading
                    ? Padding(
                        padding: const EdgeInsets.all(12),
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: iconColor,
                        ),
                      )
                    : Icon(icon, color: iconColor, size: 21.sp),
              ),
              SizedBox(width: 14.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontFamily: 'IBM',
                        fontWeight: FontWeight.w700,
                        fontSize: 14.sp,
                        color: textColor,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontFamily: 'IBM',
                        fontSize: 11.5.sp,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14.sp,
                color: AppColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShimmerLoading() {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.all(16.w),
      children: [
        Shimmer.fromColors(
          baseColor: Colors.grey.shade200,
          highlightColor: Colors.grey.shade50,
          child: Container(
            height: 160.h,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24.r),
            ),
          ),
        ),
        SizedBox(height: 20.h),
        Row(
          children: [
            Expanded(
              child: Shimmer.fromColors(
                baseColor: Colors.grey.shade200,
                highlightColor: Colors.grey.shade50,
                child: Container(
                  height: 72.h,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18.r),
                  ),
                ),
              ),
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: Shimmer.fromColors(
                baseColor: Colors.grey.shade200,
                highlightColor: Colors.grey.shade50,
                child: Container(
                  height: 72.h,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18.r),
                  ),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 10.h),
        Row(
          children: [
            Expanded(
              child: Shimmer.fromColors(
                baseColor: Colors.grey.shade200,
                highlightColor: Colors.grey.shade50,
                child: Container(
                  height: 72.h,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18.r),
                  ),
                ),
              ),
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: Shimmer.fromColors(
                baseColor: Colors.grey.shade200,
                highlightColor: Colors.grey.shade50,
                child: Container(
                  height: 72.h,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18.r),
                  ),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 20.h),
        Shimmer.fromColors(
          baseColor: Colors.grey.shade200,
          highlightColor: Colors.grey.shade50,
          child: Container(
            height: 130.h,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20.r),
            ),
          ),
        ),
        SizedBox(height: 16.h),
        Shimmer.fromColors(
          baseColor: Colors.grey.shade200,
          highlightColor: Colors.grey.shade50,
          child: Container(
            height: 100.h,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20.r),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72.w,
              height: 72.w,
              decoration: const BoxDecoration(
                color: Color(0xFFFEE2E2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                color: AppColors.error,
                size: 38,
              ),
            ),
            SizedBox(height: 16.h),
            Text(
              _error ?? 'تعذر تحميل بيانات الحساب',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'IBM',
                fontWeight: FontWeight.w800,
                fontSize: 16.sp,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              'يرجى التأكد من اتصالك بالإنترنت ثم إعادة المحاولة.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'IBM',
                fontSize: 13.sp,
                color: AppColors.textSecondary,
              ),
            ),
            SizedBox(height: 20.h),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14.r),
                ),
              ),
              onPressed: _loadProfile,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(
                'إعادة المحاولة',
                style: TextStyle(
                  fontFamily: 'IBM',
                  fontWeight: FontWeight.w700,
                  fontSize: 14.sp,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
