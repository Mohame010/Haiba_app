import 'package:equatable/equatable.dart';

class ReelEntity extends Equatable {
  final String id;
  final int sequenceId;
  final String title;
  final String description;
  final String videoUrl;
  final String? thumbnailUrl;
  final int durationSeconds;
  final int likesCount;
  final bool isLiked;

  const ReelEntity({
    required this.id,
    required this.sequenceId,
    required this.title,
    required this.description,
    required this.videoUrl,
    required this.thumbnailUrl,
    required this.durationSeconds,
    required this.likesCount,
    required this.isLiked,
  });

  ReelEntity copyWith({int? likesCount, bool? isLiked}) => ReelEntity(
    id: id,
    sequenceId: sequenceId,
    title: title,
    description: description,
    videoUrl: videoUrl,
    thumbnailUrl: thumbnailUrl,
    durationSeconds: durationSeconds,
    likesCount: likesCount ?? this.likesCount,
    isLiked: isLiked ?? this.isLiked,
  );

  @override
  List<Object?> get props => [
    id,
    sequenceId,
    title,
    description,
    videoUrl,
    thumbnailUrl,
    durationSeconds,
    likesCount,
    isLiked,
  ];
}
