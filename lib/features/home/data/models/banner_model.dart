import '../../domain/entities/banner_entity.dart';

class BannerModel {
  final String id;
  final String title;
  final String subtitle;
  final String buttonText;
  final String? imageUrl;
  final String? actionRoute;
  final String? offerId;

  const BannerModel({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.buttonText,
    this.imageUrl,
    this.actionRoute,
    this.offerId,
  });

  factory BannerModel.fromJson(Map<String, dynamic> json) {
    return BannerModel(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      subtitle: json['subtitle'] as String? ?? '',
      buttonText: json['button_text'] as String? ?? 'عرض الجدول',
      imageUrl: json['image_url'] as String?,
      actionRoute: json['action_route'] as String?,
      offerId: json['offer_id'] as String?,
    );
  }

  BannerEntity toEntity() {
    return BannerEntity(
      id: id,
      title: title,
      subtitle: subtitle,
      buttonText: buttonText,
      imageUrl: imageUrl,
      actionRoute: actionRoute,
      offerId: offerId,
    );
  }
}
