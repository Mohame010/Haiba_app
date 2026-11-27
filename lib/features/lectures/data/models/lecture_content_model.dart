import '../../domain/entities/lecture_content_entity.dart';

class LectureContentModel {
  final String id;
  final String lectureId;
  final String contentType;
  final String title;
  final String? subtitle;
  final String fileUrl;
  final int durationSeconds;
  final int sortOrder;

  const LectureContentModel({
    required this.id,
    required this.lectureId,
    required this.contentType,
    required this.title,
    this.subtitle,
    required this.fileUrl,
    this.durationSeconds = 0,
    this.sortOrder = 0,
  });

  factory LectureContentModel.fromJson(Map<String, dynamic> json) {
    final rawType =
        (json['content_type'] as String? ??
                (json.containsKey('video_url') ? 'video' : 'video'))
            .toLowerCase();
    final fileUrl =
        json['file_url'] as String? ??
        json['video_url'] as String? ??
        json['url'] as String? ??
        '';
    final title =
        json['title'] as String? ??
        switch (rawType) {
          'video' => 'فيديو الدرس',
          'pdf' => 'ملف PDF',
          'audio' => 'ملف صوتي',
          'image' => 'صورة مرفقة',
          'link' => 'رابط مرفق',
          _ => 'ملخص الدرس',
        };
    final sortOrder =
        (json['sort_order'] as num?)?.toInt() ??
        (json['order_index'] as num?)?.toInt() ??
        0;

    return LectureContentModel(
      id: json['id'] as String? ?? '',
      lectureId: json['lecture_id'] as String? ?? '',
      contentType: rawType,
      title: title,
      subtitle: json['subtitle'] as String?,
      fileUrl: fileUrl,
      durationSeconds: (json['duration_seconds'] as num?)?.toInt() ?? 0,
      sortOrder: sortOrder,
    );
  }

  LectureContentEntity toEntity() {
    ContentType type;
    switch (contentType.toLowerCase()) {
      case 'pdf':
        type = ContentType.pdf;
        break;
      case 'audio':
        type = ContentType.audio;
        break;
      case 'image':
        type = ContentType.image;
        break;
      case 'link':
        type = ContentType.link;
        break;
      case 'summary':
        type = ContentType.summary;
        break;
      case 'video':
      default:
        type = ContentType.video;
        break;
    }

    return LectureContentEntity(
      id: id,
      lectureId: lectureId,
      contentType: type,
      title: title,
      subtitle: subtitle,
      fileUrl: fileUrl,
      durationSeconds: durationSeconds,
      sortOrder: sortOrder,
    );
  }
}

class VideoNoteModel {
  final String id;
  final String lectureId;
  final int timestampSeconds;
  final String noteText;
  final String createdAt;

  const VideoNoteModel({
    required this.id,
    required this.lectureId,
    required this.timestampSeconds,
    required this.noteText,
    required this.createdAt,
  });

  factory VideoNoteModel.fromJson(Map<String, dynamic> json) {
    return VideoNoteModel(
      id: json['id'] as String? ?? '',
      lectureId: json['lecture_id'] as String? ?? '',
      timestampSeconds: (json['timestamp_seconds'] as num?)?.toInt() ?? 0,
      noteText: json['note_text'] as String? ?? '',
      createdAt:
          json['created_at'] as String? ?? DateTime.now().toIso8601String(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'lecture_id': lectureId,
      'timestamp_seconds': timestampSeconds,
      'note_text': noteText,
      'created_at': createdAt,
    };
  }

  VideoNoteEntity toEntity() {
    return VideoNoteEntity(
      id: id,
      lectureId: lectureId,
      timestampSeconds: timestampSeconds,
      noteText: noteText,
      createdAt: DateTime.tryParse(createdAt) ?? DateTime.now(),
    );
  }

  factory VideoNoteModel.fromEntity(VideoNoteEntity entity) {
    return VideoNoteModel(
      id: entity.id,
      lectureId: entity.lectureId,
      timestampSeconds: entity.timestampSeconds,
      noteText: entity.noteText,
      createdAt: entity.createdAt.toIso8601String(),
    );
  }
}
