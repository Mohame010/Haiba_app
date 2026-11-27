import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/helpers/app_logger.dart';
import '../../domain/entities/commerce_offer_entity.dart';

class CommerceOfferService {
  CommerceOfferService._();

  static final CommerceOfferService instance = CommerceOfferService._();

  SupabaseClient get _client => Supabase.instance.client;

  Future<List<CommerceOfferEntity>> getActiveOffers() async {
    final List<dynamic> rows = await _client
        .from('commerce_offers')
        .select('*, commerce_offer_items(*, lectures(title), courses(title))')
        .eq('teacher_id', AppConstants.activeTeacherId)
        .eq('is_active', true)
        .order('sort_order');

    final courseIds = <String>{};
    for (final rawRow in rows) {
      final row = Map<String, dynamic>.from(rawRow as Map);
      for (final rawItem
          in row['commerce_offer_items'] as List<dynamic>? ?? const []) {
        final item = Map<String, dynamic>.from(rawItem as Map);
        if (item['item_type'] == 'course' && item['course_id'] is String) {
          courseIds.add(item['course_id'] as String);
        }
      }
    }

    final courseLectures = <String, Map<String, String>>{};
    if (courseIds.isNotEmpty) {
      final List<dynamic> directRows = await _client
          .from('lectures')
          .select('id, course_id, title, is_published')
          .inFilter('course_id', courseIds.toList())
          .eq('is_published', true)
          .order('created_at');
      for (final raw in directRows) {
        final lecture = Map<String, dynamic>.from(raw as Map);
        final courseId = lecture['course_id'] as String?;
        final lectureId = lecture['id'] as String?;
        if (courseId != null && lectureId != null) {
          courseLectures.putIfAbsent(
            courseId,
            () => <String, String>{},
          )[lectureId] = lecture['title'] as String? ?? 'حصة';
        }
      }

      final List<dynamic> mappingRows = await _client
          .from('course_lectures')
          .select('course_id, lecture_id, lectures(title, is_published)')
          .inFilter('course_id', courseIds.toList())
          .order('sort_order');
      for (final raw in mappingRows) {
        final mapping = Map<String, dynamic>.from(raw as Map);
        final courseId = mapping['course_id'] as String?;
        final lectureId = mapping['lecture_id'] as String?;
        final lecture = mapping['lectures'];
        if (courseId != null &&
            lectureId != null &&
            lecture is Map &&
            lecture['is_published'] != false) {
          courseLectures.putIfAbsent(
            courseId,
            () => <String, String>{},
          )[lectureId] = lecture['title'] as String? ?? 'حصة';
        }
      }
    }

    final ownedItems = <String>{};
    if (_client.auth.currentUser != null) {
      final List<dynamic> entitlementRows = await _client
          .from('student_entitlements')
          .select('item_type, lecture_id, course_id')
          .eq('is_active', true);
      for (final raw in entitlementRows) {
        final entitlement = Map<String, dynamic>.from(raw as Map);
        final itemType = entitlement['item_type'] as String?;
        final itemId =
            entitlement[itemType == 'course' ? 'course_id' : 'lecture_id']
                as String?;
        if (itemType != null && itemId != null) {
          ownedItems.add('$itemType:$itemId');
        }
      }
    }

    return rows
        .map(
          (row) => _fromJson(
            Map<String, dynamic>.from(row as Map),
            courseLectures: courseLectures,
            ownedItems: ownedItems,
          ),
        )
        .toList();
  }

  Future<String> recordPaymentAttempt({
    required CommerceOfferEntity offer,
    required String? invoiceId,
    required String? paymentReference,
  }) async {
    final studentId = _client.auth.currentUser?.id;
    if (studentId == null) throw StateError('يجب تسجيل الدخول أولاً');
    AppLogger.authLog(
      '[PAYMENT] Creating payment attempt through RPC',
      data: {
        'studentId': studentId,
        'offerId': offer.isDirectPurchase ? null : offer.id,
        'itemType': offer.isDirectPurchase ? offer.items.first.itemType : null,
        'itemId': offer.isDirectPurchase ? offer.items.first.itemId : null,
        'amount': offer.offerPrice,
        'invoiceId': invoiceId,
      },
    );
    final result = await _client.rpc(
      'create_offer_payment_attempt',
      params: {
        'p_offer_id': offer.isDirectPurchase ? null : offer.id,
        'p_item_type': offer.isDirectPurchase
            ? offer.items.first.itemType
            : null,
        'p_item_id': offer.isDirectPurchase ? offer.items.first.itemId : null,
        'p_amount': offer.offerPrice,
        'p_provider_invoice_id': invoiceId,
        'p_payment_reference': paymentReference,
      },
    );
    final attemptId = result?.toString() ?? '';
    if (attemptId.isEmpty) {
      throw StateError('تعذر إنشاء محاولة الدفع');
    }
    AppLogger.authLog(
      '[PAYMENT] Payment attempt created',
      data: {'attemptId': attemptId},
    );
    return attemptId;
  }

  Future<String> getPaymentStatus(String attemptId) async {
    AppLogger.authLog(
      '[PAYMENT] Checking payment status',
      data: {'attemptId': attemptId},
    );
    final response = await _client.functions.invoke(
      'fawaterak-check-status',
      body: {'attempt_id': attemptId},
    );
    final data = response.data;
    if (response.status < 200 || response.status >= 300 || data is! Map) {
      throw StateError('تعذر التحقق من حالة الدفع: $data');
    }
    final status = data['is_paid'] == true
        ? 'paid'
        : data['status']?.toString() ?? 'pending';
    AppLogger.authLog(
      '[PAYMENT] Payment status response',
      data: {'attemptId': attemptId, 'status': status},
    );
    return status;
  }

  Future<int> redeemCode(String code) async {
    AppLogger.authLog(
      '[OFFER_CODE] Redeeming code',
      data: {
        'code': code.trim().toUpperCase(),
        'studentId': _client.auth.currentUser?.id,
      },
    );
    final result = await _client.rpc(
      'redeem_student_access_code',
      params: {'p_code': code.trim().toUpperCase()},
    );
    if (result is Map) {
      final count = (result['items_unlocked'] as num?)?.toInt() ?? 0;
      AppLogger.authLog(
        '[OFFER_CODE] Code redeemed successfully',
        data: {'itemsUnlocked': count, 'response': result},
      );
      return count;
    }
    AppLogger.authLog(
      '[OFFER_CODE] Unexpected redeem response',
      data: {'response': result},
    );
    return 0;
  }

  CommerceOfferEntity _fromJson(
    Map<String, dynamic> json, {
    required Map<String, Map<String, String>> courseLectures,
    required Set<String> ownedItems,
  }) {
    final rawItems = json['commerce_offer_items'] as List<dynamic>? ?? const [];
    final items = rawItems.map((raw) {
      final item = Map<String, dynamic>.from(raw as Map);
      final type = item['item_type'] as String? ?? 'lecture';
      final target = item[type == 'course' ? 'courses' : 'lectures'];
      final title = target is Map ? target['title'] as String? : null;
      final itemId =
          item[type == 'course' ? 'course_id' : 'lecture_id'] as String? ?? '';
      return CommerceOfferItemEntity(
        id: item['id'] as String? ?? '',
        itemType: type,
        itemId: itemId,
        title: title ?? (type == 'course' ? 'كورس' : 'حصة'),
        accessDurationDays: (item['access_duration_days'] as num?)?.toInt(),
        viewLimit: (item['view_limit'] as num?)?.toInt(),
        includedLectureTitles: type == 'course'
            ? courseLectures[itemId]?.values.toList() ?? const []
            : const [],
      );
    }).toList()..sort((a, b) => a.id.compareTo(b.id));

    final isPurchased =
        items.isNotEmpty &&
        items.every(
          (item) => ownedItems.contains('${item.itemType}:${item.itemId}'),
        );

    return CommerceOfferEntity(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      badgeText: json['badge_text'] as String?,
      imageUrl: json['image_url'] as String?,
      originalPrice: (json['original_price'] as num?)?.toDouble(),
      offerPrice: (json['offer_price'] as num?)?.toDouble() ?? 0,
      currency: json['currency'] as String? ?? 'EGP',
      endsAt: DateTime.tryParse(json['ends_at'] as String? ?? ''),
      items: items,
      isPurchased: isPurchased,
    );
  }
}
