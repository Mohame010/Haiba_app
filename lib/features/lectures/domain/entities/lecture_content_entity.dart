enum ContentType { video, pdf, audio, image, link, summary }

class LectureContentEntity {
  final String id;
  final String lectureId;
  final ContentType contentType;
  final String title;
  final String? subtitle;
  final String fileUrl;
  final int durationSeconds;
  final int sortOrder;

  const LectureContentEntity({
    required this.id,
    required this.lectureId,
    required this.contentType,
    required this.title,
    this.subtitle,
    required this.fileUrl,
    this.durationSeconds = 0,
    this.sortOrder = 0,
  });
}

class VideoNoteEntity {
  final String id;
  final String lectureId;
  final int timestampSeconds;
  final String noteText;
  final DateTime createdAt;

  const VideoNoteEntity({
    required this.id,
    required this.lectureId,
    required this.timestampSeconds,
    required this.noteText,
    required this.createdAt,
  });
}
