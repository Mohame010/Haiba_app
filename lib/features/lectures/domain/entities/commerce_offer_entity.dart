class CommerceOfferItemEntity {
  final String id;
  final String itemType;
  final String itemId;
  final String title;
  final int? accessDurationDays;
  final int? viewLimit;
  final List<String> includedLectureTitles;

  const CommerceOfferItemEntity({
    required this.id,
    required this.itemType,
    required this.itemId,
    required this.title,
    this.accessDurationDays,
    this.viewLimit,
    this.includedLectureTitles = const [],
  });

  int get contentCount =>
      itemType == 'course' ? includedLectureTitles.length : 1;

  String get accessLabel {
    final parts = <String>[];
    if (accessDurationDays != null) {
      parts.add('$accessDurationDays يوم');
    }
    if (viewLimit != null) {
      parts.add(viewLimit == 1 ? 'مشاهدة واحدة' : '$viewLimit مشاهدات');
    }
    return parts.isEmpty ? 'صلاحية كاملة' : parts.join(' • ');
  }
}

class CommerceOfferEntity {
  final String id;
  final String title;
  final String description;
  final String? badgeText;
  final String? imageUrl;
  final double? originalPrice;
  final double offerPrice;
  final String currency;
  final DateTime? endsAt;
  final List<CommerceOfferItemEntity> items;
  final bool isDirectPurchase;
  final bool isPurchased;

  const CommerceOfferEntity({
    required this.id,
    required this.title,
    required this.description,
    this.badgeText,
    this.imageUrl,
    this.originalPrice,
    required this.offerPrice,
    required this.currency,
    this.endsAt,
    this.items = const [],
    this.isDirectPurchase = false,
    this.isPurchased = false,
  });

  bool get hasDiscount => originalPrice != null && originalPrice! > offerPrice;

  int get contentCount {
    return items.fold<int>(0, (total, item) => total + item.contentCount);
  }

  factory CommerceOfferEntity.direct({
    required String itemType,
    required String itemId,
    required String title,
    required String description,
    required double price,
  }) {
    return CommerceOfferEntity(
      id: itemId,
      title: title,
      description: description,
      offerPrice: price,
      currency: 'EGP',
      isDirectPurchase: true,
      isPurchased: false,
      items: [
        CommerceOfferItemEntity(
          id: itemId,
          itemType: itemType,
          itemId: itemId,
          title: title,
        ),
      ],
    );
  }
}
