import 'package:material_ui/material_ui.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../lectures/data/services/fawaterk_payment_service.dart';
import '../../../lectures/presentation/screens/offer_payment_screen.dart';
import '../../data/novels_repository.dart';
import '../../domain/novel_entities.dart';

class NovelSubscriptionSheet extends StatefulWidget {
  const NovelSubscriptionSheet({super.key, this.message});

  final String? message;

  static Future<bool?> show(BuildContext context, {String? message}) =>
      showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
        ),
        builder: (sheetContext) => Theme(
          data: Theme.of(sheetContext).copyWith(
            canvasColor: Colors.white,
            scaffoldBackgroundColor: Colors.white,
            colorScheme: Theme.of(sheetContext).colorScheme.copyWith(
              surface: Colors.white,
              onSurface: const Color(0xff17202A),
            ),
          ),
          child: NovelSubscriptionSheet(message: message),
        ),
      );

  @override
  State<NovelSubscriptionSheet> createState() => _NovelSubscriptionSheetState();
}

class _NovelSubscriptionSheetState extends State<NovelSubscriptionSheet> {
  final _repository = NovelsRepository();
  late Future<List<NovelSubscriptionPlan>> _plans;
  String? _error;
  String? _payingPlanId;

  @override
  void initState() {
    super.initState();
    _plans = _repository.fetchSubscriptionPlans();
  }

  Future<void> _buy(NovelSubscriptionPlan plan) async {
    if (_payingPlanId != null) return;
    setState(() {
      _payingPlanId = plan.id;
      _error = null;
    });
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw StateError('سجّل الدخول قبل شراء الاشتراك.');
      final metadata = user.userMetadata ?? const <String, dynamic>{};
      final response = await FawaterkPaymentService.createInvoice(
        lectureId: plan.id,
        lectureTitle: 'اشتراك الروايات - ${plan.name}',
        amount: plan.price,
        studentName: metadata['name'] as String? ?? 'طالب Q360',
        studentPhone: metadata['phone'] as String? ?? user.phone ?? '',
        paymentMethod: FawaterkPaymentMethod.card,
        itemLabel: 'اشتراك الروايات',
        itemType: 'novel_subscription',
        itemId: plan.id,
      );
      if (!response.isSuccess) {
        throw StateError(response.message ?? 'تعذر إنشاء فاتورة الدفع.');
      }
      final url = response.paymentUrl;
      final attemptId = response.attemptId;
      if (url == null ||
          url.isEmpty ||
          attemptId == null ||
          attemptId.isEmpty) {
        throw StateError('لم تُرجع خدمة الدفع بيانات فاتورة مكتملة.');
      }
      if (!mounted) return;
      final paid = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => OfferPaymentScreen(
            paymentUrl: url,
            attemptId: attemptId,
            title: 'اشتراك الروايات - ${plan.name}',
          ),
        ),
      );
      if (paid == true && mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) setState(() => _error = 'تعذر بدء الدفع: $error');
    } finally {
      if (mounted) setState(() => _payingPlanId = null);
    }
  }

  void _retry() {
    setState(() {
      _error = null;
      _plans = _repository.fetchSubscriptionPlans();
    });
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .85,
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20.w,
          8.h,
          20.w,
          MediaQuery.viewInsetsOf(context).bottom + 20.h,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 54.w,
                height: 54.w,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFEF3C7), Color(0xFFFDE68A)],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFF59E0B).withAlpha(40),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.workspace_premium_rounded,
                  color: Color(0xFFD97706),
                  size: 30,
                ),
              ),
            ),
            SizedBox(height: 12.h),
            Text(
              'اشترك في مكتبة الروايات',
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.w800,
                fontFamily: 'IBM',
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 6.h),
            Text(
              widget.message ??
                  'افتح الروايات المدفوعة واستمع بلا حد يومي طوال مدة اشتراكك.',
              style: TextStyle(
                fontSize: 12.5.sp,
                color: AppColors.textSecondary,
                fontFamily: 'IBM',
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 4.h),
            Text(
              'الروايات المجانية متاحة لك دائمًا بدون اشتراك.',
              style: TextStyle(
                fontSize: 11.sp,
                color: AppColors.textMuted,
                fontFamily: 'IBM',
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16.h),
            if (_error != null) ...[
              Container(
                padding: EdgeInsets.all(10.w),
                decoration: BoxDecoration(
                  color: AppColors.error.withAlpha(15),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Text(
                  _error!,
                  style: TextStyle(
                    color: AppColors.error,
                    fontSize: 11.5.sp,
                    fontFamily: 'IBM',
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              SizedBox(height: 8.h),
              TextButton(
                onPressed: _retry,
                child: const Text('إعادة المحاولة'),
              ),
            ],
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * .50,
              ),
              child: FutureBuilder<List<NovelSubscriptionPlan>>(
                future: _plans,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: TextButton(
                        onPressed: _retry,
                        child: const Text(
                          'تعذر تحميل الباقات — إعادة المحاولة',
                        ),
                      ),
                    );
                  }
                  final plans = snapshot.data ?? const [];
                  if (plans.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: EdgeInsets.all(20.w),
                        child: Text(
                          'لا توجد باقات متاحة حاليًا.',
                          style: TextStyle(
                            fontFamily: 'IBM',
                            fontSize: 13.sp,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    );
                  }
                  return ListView.separated(
                    shrinkWrap: true,
                    itemCount: plans.length,
                    separatorBuilder: (_, _) => SizedBox(height: 10.h),
                    itemBuilder: (context, index) {
                      final plan = plans[index];
                      final paying = _payingPlanId == plan.id;
                      return Material(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16.r),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16.r),
                          onTap: _payingPlanId == null
                              ? () => _buy(plan)
                              : null,
                          child: Container(
                            padding: EdgeInsets.all(16.w),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16.r),
                              border: Border.all(
                                color: AppColors.primary.withAlpha(50),
                                width: 1.2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withAlpha(6),
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
                                    color: AppColors.primary.withAlpha(16),
                                    borderRadius: BorderRadius.circular(12.r),
                                  ),
                                  child: const Icon(
                                    Icons.auto_stories_rounded,
                                    color: AppColors.primary,
                                  ),
                                ),
                                SizedBox(width: 12.w),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        plan.name,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 14.5.sp,
                                          fontFamily: 'IBM',
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      SizedBox(height: 3.h),
                                      Text(
                                        plan.description ??
                                            _featuresLabel(plan),
                                        style: TextStyle(
                                          fontSize: 11.5.sp,
                                          color: AppColors.textSecondary,
                                          fontFamily: 'IBM',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(width: 8.w),
                                paying
                                    ? SizedBox(
                                        width: 24.w,
                                        height: 24.w,
                                        child: const CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Container(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 12.w,
                                          vertical: 6.h,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary,
                                          borderRadius: BorderRadius.circular(
                                            10.r,
                                          ),
                                        ),
                                        child: Column(
                                          children: [
                                            if (plan.isDiscount &&
                                                plan.oldPrice != null)
                                              Text(
                                                '${plan.oldPrice!.toStringAsFixed(0)} ${plan.currency == 'EGP' ? 'ج.م' : plan.currency}',
                                                style: TextStyle(
                                                  decoration: TextDecoration
                                                      .lineThrough,
                                                  fontSize: 10.sp,
                                                  color: Colors.white70,
                                                  fontFamily: 'IBM',
                                                ),
                                              ),
                                            Text(
                                              '${plan.price.toStringAsFixed(0)} ${plan.currency == 'EGP' ? 'ج.م' : plan.currency}',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w800,
                                                fontSize: 12.5.sp,
                                                color: Colors.white,
                                                fontFamily: 'IBM',
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _durationLabel(int days) => switch (days) {
    30 => 'شهر كامل',
    180 => '6 أشهر',
    365 => 'سنة كاملة',
    _ => '$days يومًا',
  };

  String _featuresLabel(NovelSubscriptionPlan plan) {
    final listening =
        plan.listeningLimitSeconds == null ||
            plan.listeningPeriod == 'unlimited'
        ? 'استماع بلا حد'
        : '${(plan.listeningLimitSeconds! / 3600).toStringAsFixed(plan.listeningLimitSeconds! % 3600 == 0 ? 0 : 1)} ساعة أسبوعيًا';
    final opening = plan.openAllNovels
        ? 'فتح جميع الروايات'
        : (plan.openNovelsLimit == null
              ? 'فتح المحتوى المدفوع'
              : 'فتح ${plan.openNovelsLimit} روايات');
    return '${_durationLabel(plan.durationDays)} • $listening • $opening';
  }
}
