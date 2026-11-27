import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../domain/abu_al_areef_question.dart';

class AbuAlAreefSetupScreen extends StatefulWidget {
  const AbuAlAreefSetupScreen({super.key});

  @override
  State<AbuAlAreefSetupScreen> createState() => _AbuAlAreefSetupScreenState();
}

class _AbuAlAreefSetupScreenState extends State<AbuAlAreefSetupScreen> {
  final _firstName = TextEditingController(text: 'اللاعب الأول');
  final _secondName = TextEditingController(text: 'اللاعب الثاني');
  final _formKey = GlobalKey<FormState>();
  bool _multiplayer = false;
  int _rounds = 10;

  static const List<int> _roundOptions = [5, 10, 15, 20];

  @override
  void dispose() {
    _firstName.dispose();
    _secondName.dispose();
    super.dispose();
  }

  void _start() {
    final first = _firstName.text.trim();
    final second = _secondName.text.trim();

    if (first.isEmpty) {
      _showWarning('يرجى كتابة اسم اللاعب الأول للمتابعة');
      return;
    }
    if (_multiplayer && second.isEmpty) {
      _showWarning('يرجى كتابة اسم اللاعب الثاني للمنافسة');
      return;
    }

    context.push(
      AppRoutes.abuAlAreefGame,
      extra: AbuAlAreefConfig(
        multiplayer: _multiplayer,
        firstPlayer: first,
        secondPlayer: _multiplayer ? second : '',
        rounds: _rounds,
      ),
    );
  }

  void _showWarning(String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.info_outline_rounded, color: Colors.white, size: 20),
            SizedBox(width: 8.w),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontFamily: 'IBM',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
        margin: EdgeInsets.all(16.w),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'لعبة أبو العريف',
          style: TextStyle(
            fontFamily: 'IBM',
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Form(
              key: _formKey,
              child: ListView(
                padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                children: [
                  _buildHeroHeader(),
                  SizedBox(height: 24.h),
                  _buildSectionTitle('نمط اللعب'),
                  SizedBox(height: 12.h),
                  _buildGameModeSelector(),
                  SizedBox(height: 24.h),
                  _buildSectionTitle('بيانات المتسابقين'),
                  SizedBox(height: 12.h),
                  _buildPlayerInputs(),
                  SizedBox(height: 24.h),
                  _buildSectionTitle('عدد الجولات'),
                  SizedBox(height: 12.h),
                  _buildRoundsSelector(),
                  SizedBox(height: 24.h),
                  _buildInfoCard(),
                  SizedBox(height: 20.h),
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: Container(
        color: Colors.white,
        child: SafeArea(
          top: false,
          child: Center(
            heightFactor: 1.0,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Container(
                padding: EdgeInsets.all(16.w),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    top: BorderSide(color: AppColors.border, width: 1),
                  ),
                ),
                child: FilledButton.icon(
                  onPressed: _start,
                  icon: const Icon(Icons.sports_esports_rounded, size: 22),
                  label: const Text(
                    'ابدأ التحدي الآن',
                    style: TextStyle(
                      fontFamily: 'IBM',
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    minimumSize: Size.fromHeight(54.h),
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16.r),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeroHeader() {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF312E81), Color(0xFF6D28D9)],
        ),
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6D28D9).withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 56.w,
                height: 56.w,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(16.r),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.psychology_rounded,
                  color: Color(0xFFFDE68A),
                  size: 34,
                ),
              ),
              SizedBox(width: 14.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '3000 سؤال إنجليزي متنوع',
                      style: TextStyle(
                        color: Colors.white,
                        fontFamily: 'IBM',
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      'قواعد ومفردات وتراكيب لغوية لجميع المستويات',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontFamily: 'IBM',
                        fontSize: 12.sp,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 14.h),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildHeaderFeature(Icons.cloud_off_rounded, 'أوفلاين بالكامل'),
                Container(width: 1, height: 16.h, color: Colors.white24),
                _buildHeaderFeature(Icons.speed_rounded, 'تحدي بالسرعة'),
                Container(width: 1, height: 16.h, color: Colors.white24),
                _buildHeaderFeature(Icons.workspace_premium_rounded, 'شهادة فوز'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderFeature(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: const Color(0xFFFDE68A)),
        SizedBox(width: 6.w),
        Text(
          text,
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'IBM',
            fontSize: 11.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        color: AppColors.textPrimary,
        fontFamily: 'IBM',
        fontSize: 15.sp,
        fontWeight: FontWeight.w800,
      ),
    );
  }

  Widget _buildGameModeSelector() {
    return Row(
      children: [
        Expanded(
          child: _buildModeCard(
            title: 'تحدي فردي',
            subtitle: 'العب لوحدك ضد الوقت',
            icon: Icons.person_rounded,
            isSelected: !_multiplayer,
            onTap: () => setState(() => _multiplayer = false),
          ),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: _buildModeCard(
            title: 'تحدي زوجي',
            subtitle: 'مع صاحبك على نفس الشاشة',
            icon: Icons.group_rounded,
            isSelected: _multiplayer,
            onTap: () => setState(() => _multiplayer = true),
          ),
        ),
      ],
    );
  }

  Widget _buildModeCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16.r),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.all(14.w),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary.withValues(alpha: 0.06)
                : Colors.white,
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.border,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 36.w,
                    height: 36.w,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      icon,
                      size: 20,
                      color: isSelected ? Colors.white : AppColors.primary,
                    ),
                  ),
                  Icon(
                    isSelected
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    size: 20,
                    color: isSelected ? AppColors.primary : AppColors.textMuted,
                  ),
                ],
              ),
              SizedBox(height: 10.h),
              Text(
                title,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontFamily: 'IBM',
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 2.h),
              Text(
                subtitle,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontFamily: 'IBM',
                  fontSize: 11.sp,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlayerInputs() {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          TextField(
            controller: _firstName,
            textInputAction:
                _multiplayer ? TextInputAction.next : TextInputAction.done,
            style: const TextStyle(
              fontFamily: 'IBM',
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              labelText: 'اسم اللاعب الأول',
              labelStyle: const TextStyle(fontFamily: 'IBM'),
              prefixIcon: const Icon(Icons.person_outline_rounded),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r),
                borderSide:
                    const BorderSide(color: AppColors.primary, width: 1.5),
              ),
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
            ),
          ),
          if (_multiplayer) ...[
            SizedBox(height: 12.h),
            TextField(
              controller: _secondName,
              textInputAction: TextInputAction.done,
              style: const TextStyle(
                fontFamily: 'IBM',
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                labelText: 'اسم اللاعب الثاني (المنافس)',
                labelStyle: const TextStyle(fontFamily: 'IBM'),
                prefixIcon: const Icon(Icons.group_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                  borderSide:
                      const BorderSide(color: AppColors.primary, width: 1.5),
                ),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRoundsSelector() {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'اختر عدد الأسئلة للتحدي',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontFamily: 'IBM',
                  fontSize: 13.sp,
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Text(
                  '$_rounds سؤال',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontFamily: 'IBM',
                    fontWeight: FontWeight.w800,
                    fontSize: 13.sp,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 14.h),
          Row(
            children: _roundOptions.map((count) {
              final isSelected = _rounds == count;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 3.w),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => setState(() => _rounds = count),
                      borderRadius: BorderRadius.circular(10.r),
                      child: Container(
                        height: 42.h,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.background,
                          borderRadius: BorderRadius.circular(10.r),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.border,
                          ),
                        ),
                        child: Text(
                          '$count',
                          style: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : AppColors.textPrimary,
                            fontFamily: 'IBM',
                            fontWeight: FontWeight.w800,
                            fontSize: 14.sp,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          SizedBox(height: 10.h),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppColors.primary,
              inactiveTrackColor: AppColors.indicatorInactive,
              thumbColor: AppColors.primary,
              overlayColor: AppColors.primary.withValues(alpha: 0.15),
              trackHeight: 4,
            ),
            child: Slider(
              value: _rounds.toDouble(),
              min: 5,
              max: 20,
              divisions: 3,
              label: '$_rounds سؤال',
              onChanged: (value) => setState(() => _rounds = value.round()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.lightbulb_outline_rounded,
            color: Color(0xFF2563EB),
            size: 20,
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'قواعد المنافسة',
                  style: TextStyle(
                    color: const Color(0xFF1E3A8A),
                    fontFamily: 'IBM',
                    fontSize: 12.5.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  'في التحدي الزوجي يربح النقطة من يضغط على الإجابة الصحيحة أولاً. لا توجد نقاط سالبة عند الخطأ.',
                  style: TextStyle(
                    color: const Color(0xFF1E40AF),
                    fontFamily: 'IBM',
                    fontSize: 11.5.sp,
                    height: 1.45,
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
