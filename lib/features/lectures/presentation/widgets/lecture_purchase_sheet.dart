import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../../core/di/dependency_injection.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../data/datasources/lectures_remote_data_source.dart';
import '../../data/services/fawaterk_payment_service.dart';
import '../../domain/entities/lecture_entity.dart';
import '../cubits/lectures_list/lectures_list_cubit.dart';

class LecturePurchaseSheet extends StatefulWidget {
  final LectureEntity lecture;

  const LecturePurchaseSheet({super.key, required this.lecture});

  static Future<void> show(BuildContext context, LectureEntity lecture) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => LecturePurchaseSheet(lecture: lecture),
    );
  }

  @override
  State<LecturePurchaseSheet> createState() => _LecturePurchaseSheetState();
}

class _LecturePurchaseSheetState extends State<LecturePurchaseSheet> {
  FawaterkPaymentMethod _selectedMethod = FawaterkPaymentMethod.wallet;
  final TextEditingController _phoneController = TextEditingController(text: '01033912891');
  bool _isLoading = false;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _handleCheckout() async {
    setState(() {
      _isLoading = true;
    });

    final effectiveAmount = widget.lecture.effectivePrice;

    // 1. Call Fawaterk API
    final response = await FawaterkPaymentService.createInvoice(
      lectureId: widget.lecture.id,
      lectureTitle: widget.lecture.title,
      amount: effectiveAmount,
      studentName: 'أحمد محمد',
      studentPhone: _phoneController.text.trim(),
      paymentMethod: _selectedMethod,
    );

    // 2. Record purchase in Supabase
    final remoteDataSource = getIt<LecturesRemoteDataSource>();
    await remoteDataSource.purchaseLecture(
      lectureId: widget.lecture.id,
      amountPaid: effectiveAmount,
      isCenterStudent: widget.lecture.isCenterStudent,
      paymentMethod: _selectedMethod.name,
      invoiceId: response.invoiceId,
      paymentReference: response.fawryCode,
    );

    setState(() {
      _isLoading = false;
    });

    if (!mounted) return;

    Navigator.of(context).pop();

    // 3. Show Success & Fawry code or direct activation
    _showSuccessDialog(response, effectiveAmount);

    // 4. Reload lectures cubit
    context.read<LecturesListCubit>().loadLectures();
  }

  void _showSuccessDialog(FawaterkPaymentResponse response, double amount) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.r)),
        child: Padding(
          padding: EdgeInsets.all(24.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64.w,
                height: 64.w,
                decoration: const BoxDecoration(
                  color: Color(0xFFDCFCE7),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF16A34A),
                  size: 36,
                ),
              ),
              SizedBox(height: 16.h),
              Text(
                'تم تفعيل الحصة بنجاح!',
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  fontFamily: 'IBM',
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                'تم تأكيد الدفع عبر بوابة فواتيرك (Fawaterk) بمبلغ ${amount.toStringAsFixed(0)} ج.م',
                style: TextStyle(
                  fontSize: 13.sp,
                  color: AppColors.textSecondary,
                  fontFamily: 'IBM',
                ),
                textAlign: TextAlign.center,
              ),
              if (_selectedMethod == FawaterkPaymentMethod.fawry && response.fawryCode != null) ...[
                SizedBox(height: 14.h),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(color: const Color(0xFFF59E0B)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'كود الدفع في فوري:',
                        style: TextStyle(fontSize: 12.sp, color: const Color(0xFFB45309), fontFamily: 'IBM'),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        response.fawryCode!,
                        style: TextStyle(
                          fontSize: 20.sp,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFFB45309),
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              SizedBox(height: 20.h),
              SizedBox(
                width: double.infinity,
                height: 46.h,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    context.push(AppRoutes.lectureDetails, extra: widget.lecture.id);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
                  ),
                  child: Text(
                    'دخول الحصة الآن',
                    style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700, fontFamily: 'IBM'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isCenter = widget.lecture.isCenterStudent;
    final regularPrice = widget.lecture.price;
    final centerPrice = widget.lecture.centerPrice;
    final effectivePrice = widget.lecture.effectivePrice;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
      ),
      padding: EdgeInsets.only(
        left: 20.w,
        right: 20.w,
        top: 20.h,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24.h,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle Bar
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
            SizedBox(height: 18.h),

            // Header Title
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(20),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Text(
                    'بوابة فواتيرك (Fawaterk)',
                    style: TextStyle(
                      fontSize: 11.5.sp,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                      fontFamily: 'IBM',
                    ),
                  ),
                ),
                Text(
                  'شراء وتفعيل الحصة',
                  style: TextStyle(
                    fontSize: 17.sp,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    fontFamily: 'IBM',
                  ),
                ),
              ],
            ),
            SizedBox(height: 14.h),

            // Lecture Info Card
            Container(
              padding: EdgeInsets.all(14.w),
              decoration: BoxDecoration(
                color: AppColors.cardLight,
                borderRadius: BorderRadius.circular(16.r),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.lecture.title,
                    style: TextStyle(
                      fontSize: 14.5.sp,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      fontFamily: 'IBM',
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    '${widget.lecture.lessonNumber} • ${widget.lecture.chapter} • ${widget.lecture.teacherName}',
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: AppColors.textSecondary,
                      fontFamily: 'IBM',
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 14.h),

            // Center Attendance Discount Banner
            if (isCenter)
              Container(
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(14.r),
                  border: Border.all(color: const Color(0xFF86EFAC)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.verified_rounded, color: Color(0xFF16A34A), size: 22),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '🎉 تم التحقق: حضرت هذه الحصة في السنتر!',
                            style: TextStyle(
                              fontSize: 12.5.sp,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF166534),
                              fontFamily: 'IBM',
                            ),
                          ),
                          SizedBox(height: 2.h),
                          Text(
                            'تم تطبيق خصم طلبة السنتر: ${centerPrice.toStringAsFixed(0)} ج.م بدلاً من ${regularPrice.toStringAsFixed(0)} ج.م',
                            style: TextStyle(
                              fontSize: 11.5.sp,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF15803D),
                              fontFamily: 'IBM',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(14.r),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, color: AppColors.textSecondary, size: 20),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Text(
                        'سعر الحصة للمشاهدة الأونلاين: ${regularPrice.toStringAsFixed(0)} ج.م',
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                          fontFamily: 'IBM',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            SizedBox(height: 18.h),

            // Payment Methods
            Text(
              'اختر وسيلة الدفع (فواتيرك):',
              style: TextStyle(
                fontSize: 13.5.sp,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                fontFamily: 'IBM',
              ),
              textAlign: TextAlign.right,
            ),
            SizedBox(height: 10.h),

            _buildMethodOption(
              method: FawaterkPaymentMethod.wallet,
              title: 'المحافظ الإلكترونية',
              subtitle: 'فودافون كاش، اتصالات كاش، أورنج، وي، إنستاباي',
              icon: Icons.account_balance_wallet_rounded,
              badgeColor: const Color(0xFFEF4444),
            ),
            SizedBox(height: 8.h),

            _buildMethodOption(
              method: FawaterkPaymentMethod.card,
              title: 'البطاقة البنكية (Visa / MasterCard)',
              subtitle: 'دفع فوري آمن ومباشر عبر بطاقتك البنكية',
              icon: Icons.credit_card_rounded,
              badgeColor: const Color(0xFF3B82F6),
            ),
            SizedBox(height: 8.h),

            _buildMethodOption(
              method: FawaterkPaymentMethod.fawry,
              title: 'فوري باي (Fawry Pay)',
              subtitle: 'احصل على كود وادفع في أي منفذ أو فرع فوري',
              icon: Icons.storefront_rounded,
              badgeColor: const Color(0xFFF59E0B),
            ),
            SizedBox(height: 14.h),

            // Phone Field
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              style: TextStyle(fontSize: 13.5.sp, fontFamily: 'IBM'),
              decoration: InputDecoration(
                labelText: 'رقم الهاتف للدفع والإشعار',
                labelStyle: TextStyle(fontSize: 12.5.sp, color: AppColors.textSecondary, fontFamily: 'IBM'),
                prefixIcon: const Icon(Icons.phone_iphone_rounded, size: 20),
                filled: true,
                fillColor: AppColors.cardLight,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14.r),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            SizedBox(height: 20.h),

            // Pay Button
            SizedBox(
              height: 50.h,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleCheckout,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
                  elevation: 0,
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'إتمام الدفع (${effectivePrice.toStringAsFixed(0)} ج.م)',
                            style: TextStyle(
                              fontSize: 15.sp,
                              fontWeight: FontWeight.w800,
                              fontFamily: 'IBM',
                            ),
                          ),
                          SizedBox(width: 8.w),
                          const Icon(Icons.lock_outline_rounded, size: 18),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMethodOption({
    required FawaterkPaymentMethod method,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color badgeColor,
  }) {
    final isSelected = _selectedMethod == method;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedMethod = method;
        });
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withAlpha(12) : Colors.white,
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 20.w,
              height: 20.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? AppColors.primary : Colors.grey.shade400,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 10.w,
                        height: 10.w,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primary,
                        ),
                      ),
                    )
                  : null,
            ),
            SizedBox(width: 10.w),
            Container(
              padding: EdgeInsets.all(8.w),
              decoration: BoxDecoration(
                color: badgeColor.withAlpha(20),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: badgeColor, size: 20),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      fontFamily: 'IBM',
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11.sp,
                      color: AppColors.textSecondary,
                      fontFamily: 'IBM',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
