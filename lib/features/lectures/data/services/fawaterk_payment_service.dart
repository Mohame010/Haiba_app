import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/helpers/app_logger.dart';

enum FawaterkPaymentMethod {
  card, // Visa / MasterCard (1)
  wallet, // Mobile Wallets: Vodafone Cash, InstaPay, Orange, Etisalat, WE (3)
  fawry, // Fawry Pay Code (2)
}

class FawaterkPaymentResponse {
  final bool isSuccess;
  final String? invoiceId;
  final String? invoiceKey;
  final String? attemptId;
  final String? paymentUrl;
  final String? fawryCode;
  final String? expireDate;
  final String? message;

  const FawaterkPaymentResponse({
    required this.isSuccess,
    this.invoiceId,
    this.invoiceKey,
    this.attemptId,
    this.paymentUrl,
    this.fawryCode,
    this.expireDate,
    this.message,
  });
}

class FawaterkPaymentService {
  /// Creates the invoice through a Supabase Edge Function. Fawaterak secrets
  /// must never be bundled inside the Flutter application.
  static Future<FawaterkPaymentResponse> createInvoice({
    required String lectureId,
    required String lectureTitle,
    required double amount,
    required String studentName,
    required String studentPhone,
    required FawaterkPaymentMethod paymentMethod,
    String itemLabel = 'حصة',
    String? offerId,
    String? itemType,
    String? itemId,
  }) async {
    AppLogger.authLog(
      '[FAWATERK] Requesting invoice for: $lectureTitle',
      data: {
        'amount': amount,
        'studentPhone': AppLogger.maskedPhone(studentPhone),
        'method': paymentMethod.name,
      },
    );

    try {
      final response = await Supabase.instance.client.functions.invoke(
        'fawaterak-create-invoice',
        body: {
          if (offerId != null) 'offer_id': offerId,
          if (offerId == null) 'item_type': itemType ?? 'lecture',
          if (offerId == null) 'item_id': itemId ?? lectureId,
          'amount': amount,
          'student_name': studentName,
          'student_phone': studentPhone,
          'payment_method': paymentMethod.name,
          'item_label': itemLabel,
        },
      );
      final data = response.data;
      AppLogger.authLog(
        '[FAWATERK] Edge Function response',
        data: {'httpStatus': response.status, 'body': data},
      );
      if (response.status >= 200 &&
          response.status < 300 &&
          data is Map &&
          data['success'] == true) {
        return FawaterkPaymentResponse(
          isSuccess: true,
          invoiceId: data['invoice_id']?.toString(),
          invoiceKey: data['invoice_key']?.toString(),
          attemptId: data['attempt_id']?.toString(),
          paymentUrl: data['payment_url']?.toString(),
          message: 'تم إنشاء الفاتورة بنجاح عبر فواتيرك',
        );
      }
      final message = data is Map
          ? (data['details'] ?? data['error'])?.toString()
          : data?.toString();
      throw StateError(message ?? 'تعذر إنشاء فاتورة فواتيرك');
    } catch (e, stackTrace) {
      AppLogger.authLog(
        '[FAWATERK] Edge Function request failed',
        error: e,
        stackTrace: stackTrace,
      );
      final message = e.toString().contains('invalid_payment_target')
          ? 'هدف الدفع غير مدعوم حاليًا. حدّث Edge Function الخاصة بفواتيرك.'
          : e.toString();
      return FawaterkPaymentResponse(isSuccess: false, message: message);
    }
  }
}
