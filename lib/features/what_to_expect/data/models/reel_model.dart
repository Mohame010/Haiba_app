import '../../domain/entities/reel_entity.dart';

class ReelModel {
  final String id;
  final int sequenceId;
  final String title;
  final String description;
  final String videoUrl;
  final String? thumbnailUrl;
  final int durationSeconds;
  final int likesCount;

  const ReelModel({
    required this.id,
    required this.sequenceId,
    required this.title,
    required this.description,
    required this.videoUrl,
    required this.thumbnailUrl,
    required this.durationSeconds,
    required this.likesCount,
  });

  factory ReelModel.fromJson(Map<String, dynamic> json) => ReelModel(
    id: json['id'] as String? ?? '',
    sequenceId: (json['sequence_id'] as num?)?.toInt() ?? 0,
    title: json['title'] as String? ?? '',
    description: json['description'] as String? ?? '',
    videoUrl: json['video_url'] as String? ?? '',
    thumbnailUrl: json['thumbnail_url'] as String?,
    durationSeconds: (json['duration_seconds'] as num?)?.toInt() ?? 0,
    likesCount: (json['likes_count'] as num?)?.toInt() ?? 0,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'sequence_id': sequenceId,
    'title': title,
    'description': description,
    'video_url': videoUrl,
    'thumbnail_url': thumbnailUrl,
    'duration_seconds': durationSeconds,
    'likes_count': likesCount,
  };

  ReelEntity toEntity({bool isLiked = false}) => ReelEntity(
    id: id,
    sequenceId: sequenceId,
    title: title,
    description: description,
    videoUrl: videoUrl,
    thumbnailUrl: thumbnailUrl,
    durationSeconds: durationSeconds,
    likesCount: likesCount,
    isLiked: isLiked,
  );
}
