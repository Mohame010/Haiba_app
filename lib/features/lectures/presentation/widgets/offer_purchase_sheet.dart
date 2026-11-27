import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/helpers/app_logger.dart';
import '../../../core/theme/app_colors.dart';
import '../../data/services/commerce_offer_service.dart';
import '../../data/services/fawaterk_payment_service.dart';
import '../../domain/entities/commerce_offer_entity.dart';
import '../screens/offer_payment_screen.dart';

class OfferPurchaseSheet extends StatefulWidget {
  final CommerceOfferEntity offer;
  final FutureOr<void> Function()? onActivated;

  const OfferPurchaseSheet({super.key, required this.offer, this.onActivated});

  static Future<void> show(
    BuildContext context,
    CommerceOfferEntity offer, {
    FutureOr<void> Function()? onActivated,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          OfferPurchaseSheet(offer: offer, onActivated: onActivated),
    );
  }

  @override
  State<OfferPurchaseSheet> createState() => _OfferPurchaseSheetState();
}

class _OfferPurchaseSheetState extends State<OfferPurchaseSheet> {
  final _codeController = TextEditingController();
  bool _paying = false;
  bool _redeeming = false;
  String? _feedbackMessage;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _payOnline() async {
    if (_paying) {
      AppLogger.authLog('[PAYMENT] Ignored duplicate pay tap');
      return;
    }
    setState(() {
      _paying = true;
      _feedbackMessage = null;
    });
    try {
      final user = Supabase.instance.client.auth.currentUser;
      final metadata = user?.userMetadata ?? const <String, dynamic>{};
      AppLogger.authLog(
        '[PAYMENT] Online payment button pressed',
        data: {
          'offerId': widget.offer.id,
          'offerTitle': widget.offer.title,
          'amount': widget.offer.offerPrice,
          'studentId': user?.id,
        },
      );
      final response = await FawaterkPaymentService.createInvoice(
        lectureId: widget.offer.id,
        lectureTitle: widget.offer.title,
        amount: widget.offer.offerPrice,
        studentName: metadata['name'] as String? ?? 'طالب Q360',
        studentPhone: metadata['phone'] as String? ?? user?.phone ?? '',
        paymentMethod: FawaterkPaymentMethod.card,
        itemLabel: 'عرض',
        offerId: widget.offer.isDirectPurchase ? null : widget.offer.id,
        itemType: widget.offer.isDirectPurchase
            ? widget.offer.items.first.itemType
            : null,
        itemId: widget.offer.isDirectPurchase
            ? widget.offer.items.first.itemId
            : null,
      );
      AppLogger.authLog(
        '[PAYMENT] Invoice response received',
        data: {
          'success': response.isSuccess,
          'invoiceId': response.invoiceId,
          'hasPaymentUrl': response.paymentUrl?.isNotEmpty == true,
          'message': response.message,
        },
      );
      if (!response.isSuccess) {
        throw StateError(response.message ?? 'فشل إنشاء فاتورة الدفع');
      }
      final attemptId = response.attemptId;
      if (attemptId == null || attemptId.isEmpty) {
        throw StateError('لم تُرجع خدمة الدفع رقم محاولة صالحًا');
      }
      if (!mounted) return;
      final url = response.paymentUrl;
      if (url == null || url.isEmpty) {
        AppLogger.authLog('[PAYMENT] Invoice has no payment URL');
        _showMessage(response.message ?? 'تعذر فتح صفحة الدفع');
        return;
      }
      final navigator = Navigator.of(context);
      final messenger = ScaffoldMessenger.of(context);
      navigator.pop();
      AppLogger.authLog(
        '[PAYMENT] Navigating to checkout WebView',
        data: {'attemptId': attemptId, 'url': url},
      );
      final paid = await navigator.push<bool>(
        MaterialPageRoute(
          builder: (_) => OfferPaymentScreen(
            paymentUrl: url,
            attemptId: attemptId,
            title: 'الدفع الإلكتروني - ${widget.offer.title}',
          ),
        ),
      );
      AppLogger.authLog(
        '[PAYMENT] Checkout returned to app',
        data: {'attemptId': attemptId, 'paid': paid},
      );
      if (paid == true) {
        await widget.onActivated?.call();
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text('تم شراء ${widget.offer.title} وفتح المحتوى بنجاح'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: const Color(0xFF16A34A),
            ),
          );
      } else if (paid == false) {
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text('لم تكتمل عملية الدفع. حاول مرة أخرى.'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: AppColors.error,
            ),
          );
      }
    } catch (error, stackTrace) {
      AppLogger.authLog(
        '[PAYMENT] Failed to start/finish checkout',
        data: {'offerId': widget.offer.id},
        error: error,
        stackTrace: stackTrace,
      );
      if (mounted) _showMessage('تعذر بدء الدفع: $error');
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  Future<void> _redeemCode() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      AppLogger.authLog('[OFFER_CODE] Redeem pressed with an empty code');
      _showMessage('اكتب كود التفعيل أولاً');
      return;
    }
    if (_redeeming) {
      AppLogger.authLog('[OFFER_CODE] Ignored duplicate redeem tap');
      return;
    }
    setState(() {
      _redeeming = true;
      _feedbackMessage = null;
    });
    AppLogger.authLog(
      '[OFFER_CODE] Redeem button pressed',
      data: {
        'code': code.toUpperCase(),
        'displayedOfferId': widget.offer.id,
        'studentId': Supabase.instance.client.auth.currentUser?.id,
      },
    );
    try {
      final count = await CommerceOfferService.instance.redeemCode(code);
      if (!mounted) return;
      final navigator = Navigator.of(context);
      final messenger = ScaffoldMessenger.of(context);
      navigator.pop();
      await widget.onActivated?.call();
      messenger.showSnackBar(
        SnackBar(
          content: Text('تم تفعيل العرض بنجاح ($count محتوى)'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on PostgrestException catch (error) {
      AppLogger.authLog(
        '[OFFER_CODE] Supabase rejected code',
        data: {'code': code.toUpperCase(), 'details': error.details},
        error: error,
      );
      if (mounted) _showMessage(_friendlyCodeError(error.message));
    } catch (error, stackTrace) {
      AppLogger.authLog(
        '[OFFER_CODE] Unexpected redeem failure',
        data: {'code': code.toUpperCase()},
        error: error,
        stackTrace: stackTrace,
      );
      if (mounted) _showMessage('تعذر تفعيل الكود: $error');
    } finally {
      if (mounted) setState(() => _redeeming = false);
    }
  }

  String _friendlyCodeError(String message) {
    if (message.contains('code_not_assigned_to_student')) {
      return 'هذا الكود مخصص لطالب آخر';
    }
    if (message.contains('code_expired')) return 'انتهت صلاحية هذا الكود';
    if (message.contains('code_already_used')) return 'تم استخدام هذا الكود';
    if (message.contains('offer_not_available')) return 'العرض غير متاح الآن';
    if (message.contains('offer_has_no_items')) {
      return 'العرض لا يحتوي على حصص أو كورسات';
    }
    if (message.contains('redeem_student_access_code')) {
      return 'دالة تفعيل الكود غير مثبّتة في قاعدة البيانات';
    }
    return 'الكود غير صحيح أو غير متاح';
  }

  void _showMessage(String message) {
    if (!mounted) return;
    setState(() => _feedbackMessage = message);
  }

  @override
  Widget build(BuildContext context) {
    final offer = widget.offer;
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .88,
      ),
      padding: EdgeInsets.only(
        left: 20.w,
        right: 20.w,
        top: 12.h,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 20.h,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26.r)),
      ),
      child: SingleChildScrollView(
        child: Column(
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
            SizedBox(height: 16.h),
            if (offer.badgeText?.isNotEmpty == true)
              Align(
                alignment: Alignment.centerRight,
                child: Chip(label: Text(offer.badgeText!)),
              ),
            Text(
              offer.title,
              style: TextStyle(
                fontSize: 20.sp,
                fontWeight: FontWeight.w900,
                fontFamily: 'IBM',
              ),
              textAlign: TextAlign.right,
            ),
            if (offer.description.isNotEmpty) ...[
              SizedBox(height: 6.h),
              Text(
                offer.description,
                style: TextStyle(
                  fontSize: 13.sp,
                  color: AppColors.textSecondary,
                  fontFamily: 'IBM',
                ),
                textAlign: TextAlign.right,
              ),
            ],
            SizedBox(height: 16.h),
            Text(
              'المحتوى المتاح',
              style: TextStyle(
                fontSize: 15.sp,
                fontWeight: FontWeight.w800,
                fontFamily: 'IBM',
              ),
            ),
            SizedBox(height: 8.h),
            ...offer.items.map(
              (item) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      item.itemType == 'course'
                          ? Icons.school_rounded
                          : Icons.play_circle_fill_rounded,
                      color: AppColors.primary,
                    ),
                    title: Text(
                      item.title,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontFamily: 'IBM',
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: Text(
                      item.itemType == 'course'
                          ? '${item.includedLectureTitles.length} حصة • ${item.accessLabel}'
                          : item.accessLabel,
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontFamily: 'IBM'),
                    ),
                  ),
                  if (item.includedLectureTitles.isNotEmpty)
                    Container(
                      margin: EdgeInsets.only(bottom: 8.h),
                      padding: EdgeInsets.all(10.w),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: item.includedLectureTitles
                            .asMap()
                            .entries
                            .map(
                              (entry) => Padding(
                                padding: EdgeInsets.symmetric(vertical: 3.h),
                                child: Text(
                                  '${entry.key + 1}. ${entry.value}',
                                  textAlign: TextAlign.right,
                                  style: TextStyle(
                                    fontFamily: 'IBM',
                                    fontSize: 12.sp,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                ],
              ),
            ),
            if (offer.items.isEmpty)
              Container(
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: const Text(
                  'لم يتم ربط حصص أو كورسات بهذا العرض بعد.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'IBM',
                    color: AppColors.error,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            SizedBox(height: 10.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (offer.hasDiscount)
                  Text(
                    '${offer.originalPrice!.toStringAsFixed(0)} ج.م',
                    style: TextStyle(
                      decoration: TextDecoration.lineThrough,
                      color: AppColors.textMuted,
                      fontSize: 14.sp,
                    ),
                  ),
                SizedBox(width: 10.w),
                Text(
                  '${offer.offerPrice.toStringAsFixed(0)} ج.م',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w900,
                    fontSize: 22.sp,
                    fontFamily: 'IBM',
                  ),
                ),
              ],
            ),
            SizedBox(height: 14.h),
            if (_feedbackMessage != null) ...[
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(color: const Color(0xFFFCA5A5)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      color: AppColors.error,
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Text(
                        _feedbackMessage!,
                        style: TextStyle(
                          color: AppColors.error,
                          fontSize: 12.5.sp,
                          fontFamily: 'IBM',
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 10.h),
            ],
            ElevatedButton.icon(
              onPressed: _paying ? null : _payOnline,
              icon: _paying
                  ? SizedBox(
                      width: 18.w,
                      height: 18.w,
                      child: const CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.credit_card_rounded),
              label: const Text(
                'الدفع أونلاين',
                style: TextStyle(
                  fontFamily: 'IBM',
                  fontWeight: FontWeight.w800,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 13.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14.r),
                ),
              ),
            ),
            SizedBox(height: 14.h),
            Row(
              children: [
                Expanded(child: Divider(color: AppColors.border)),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10.w),
                  child: const Text(
                    'أو كود دفع من المدرس',
                    style: TextStyle(fontFamily: 'IBM'),
                  ),
                ),
                Expanded(child: Divider(color: AppColors.border)),
              ],
            ),
            SizedBox(height: 10.h),
            TextField(
              controller: _codeController,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                hintText: 'اكتب كود التفعيل',
                prefixIcon: const Icon(Icons.key_rounded),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14.r),
                ),
              ),
            ),
            SizedBox(height: 10.h),
            OutlinedButton(
              onPressed: _redeeming ? null : _redeemCode,
              child: _redeeming
                  ? const CircularProgressIndicator()
                  : const Text(
                      'تفعيل الكود',
                      style: TextStyle(
                        fontFamily: 'IBM',
                        fontWeight: FontWeight.w800,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
