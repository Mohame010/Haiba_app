class BannerEntity {
  final String id;
  final String title;
  final String subtitle;
  final String buttonText;
  final String? imageUrl;
  final String? actionRoute;
  final String? offerId;

  const BannerEntity({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.buttonText,
    this.imageUrl,
    this.actionRoute,
    this.offerId,
  });
}
