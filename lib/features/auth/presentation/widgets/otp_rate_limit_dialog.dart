import 'package:material_ui/material_ui.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> showOtpRateLimitDialog(
  BuildContext context, {
  required String? supportPhone,
}) {
  final normalizedSupportPhone = _normalizeWhatsAppPhone(supportPhone);

  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
      icon: Container(
        width: 56.w,
        height: 56.w,
        decoration: const BoxDecoration(
          color: Color(0xFFFFF3E0),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.hourglass_top_rounded,
          color: Color(0xFFB45309),
        ),
      ),
      title: Text(
        'إيقاف مؤقت لإرسال الأكواد',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 18.sp,
          fontWeight: FontWeight.w700,
          fontFamily: 'IBM',
          color: const Color(0xFF1E1B4B),
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'تم الوصول للحد المسموح: 3 أكواد خلال 24 ساعة. '
            'لن نتمكن من إرسال كود جديد لهذا الرقم لمدة 24 ساعة.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14.sp,
              height: 1.5,
              fontFamily: 'IBM',
              color: const Color(0xFF4B5563),
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            normalizedSupportPhone == null
                ? 'حاول لاحقًا أو تواصل مع الدعم.'
                : 'حاول لاحقًا أو تواصل مع الدعم على الرقم:',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.sp,
              height: 1.5,
              fontFamily: 'IBM',
              color: const Color(0xFF6B7280),
            ),
          ),
          if (supportPhone?.trim().isNotEmpty == true) ...[
            SizedBox(height: 4.h),
            Directionality(
              textDirection: TextDirection.ltr,
              child: SelectableText(
                supportPhone!.trim(),
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'IBM',
                  color: const Color(0xFF1E1B4B),
                ),
              ),
            ),
          ],
        ],
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('حسنًا'),
        ),
        if (normalizedSupportPhone != null)
          FilledButton.icon(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              final launched = await launchUrl(
                Uri.parse('https://wa.me/$normalizedSupportPhone'),
                mode: LaunchMode.externalApplication,
              );
              if (!launched && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('تعذر فتح واتساب. يمكنك الاتصال برقم الدعم.'),
                  ),
                );
              }
            },
            icon: const Icon(Icons.chat_rounded, size: 18),
            label: const Text('تواصل مع الدعم'),
          ),
      ],
    ),
  );
}

String? _normalizeWhatsAppPhone(String? phone) {
  if (phone == null || phone.trim().isEmpty) return null;
  final trimmed = phone.trim();
  final digits = trimmed.replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty) return null;
  if (trimmed.startsWith('+')) return digits;
  if (digits.startsWith('00')) return digits.substring(2);
  if (digits.startsWith('20')) return digits;
  if (digits.startsWith('0')) return '2$digits';
  return '20$digits';
}
