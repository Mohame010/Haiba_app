import '../../domain/entities/lecture_entity.dart';
import 'lecture_content_model.dart';

class LectureModel {
  final String id;
  final String? courseId;
  final int? courseSortOrder;
  final String teacherId;
  final String teacherName;
  final String teacherTitle;
  final String? teacherAvatarUrl;
  final String title;
  final String description;
  final String stage;
  final String grade;
  final String subject;
  final String chapter;
  final String lessonNumber;
  final double price;
  final double centerPrice;
  final bool isCenterStudent;
  final String? thumbnailUrl;
  final bool hasAccess;
  final List<LectureContentModel> contents;
  final String? attachedExamId;
  final String? attachedExamTitle;
  final int attachedExamDuration;
  final int attachedExamScore;
  final int enrolledStudentsCount;
  final int centerStudentsCount;
  final int onlineStudentsCount;

  const LectureModel({
    required this.id,
    this.courseId,
    this.courseSortOrder,
    required this.teacherId,
    required this.teacherName,
    this.teacherTitle = 'مدرس المادة',
    this.teacherAvatarUrl,
    required this.title,
    required this.description,
    required this.stage,
    required this.grade,
    this.subject = 'الفيزياء',
    this.chapter = 'الفصل الثالث',
    this.lessonNumber = 'الدرس 3',
    this.price = 0,
    this.centerPrice = 10,
    this.isCenterStudent = false,
    this.thumbnailUrl,
    this.hasAccess = true,
    this.contents = const [],
    this.attachedExamId,
    this.attachedExamTitle,
    this.attachedExamDuration = 45,
    this.attachedExamScore = 20,
    this.enrolledStudentsCount = 0,
    this.centerStudentsCount = 0,
    this.onlineStudentsCount = 0,
  });

  factory LectureModel.fromJson(
    Map<String, dynamic> json, {
    bool hasAccess = true,
    bool isCenterStudent = false,
    int enrolledCount = 0,
    int centerCount = 0,
    int onlineCount = 0,
    List<dynamic>? additionalVideos,
  }) {
    final teacherRaw = json['teachers'];
    final teacher = teacherRaw is Map<String, dynamic>
        ? teacherRaw
        : (teacherRaw is List && teacherRaw.isNotEmpty
              ? teacherRaw.first as Map<String, dynamic>
              : null);

    // 1. First parse videos from lecture_videos table (if any)
    final List<LectureContentModel> contentsList = [];
    final Set<String> seenUrls = {};

    final videosRaw =
        (additionalVideos ?? json['lecture_videos'] as List<dynamic>?) ?? [];
    for (var v in videosRaw) {
      if (v is Map<String, dynamic>) {
        final videoModel = LectureContentModel.fromJson(v);
        if (videoModel.fileUrl.isNotEmpty &&
            !seenUrls.contains(videoModel.fileUrl)) {
          contentsList.add(videoModel);
          seenUrls.add(videoModel.fileUrl);
        }
      }
    }

    // 2. Then parse contents from lecture_contents
    final contentsRaw = json['lecture_contents'] as List<dynamic>? ?? [];
    for (var c in contentsRaw) {
      if (c is Map<String, dynamic>) {
        final contentModel = LectureContentModel.fromJson(c);
        final rawType = (c['content_type'] as String? ?? 'video').toLowerCase();
        if (rawType == 'video') {
          if (contentModel.fileUrl.isNotEmpty &&
              !seenUrls.contains(contentModel.fileUrl)) {
            contentsList.add(contentModel);
            seenUrls.add(contentModel.fileUrl);
          }
        } else {
          contentsList.add(contentModel);
        }
      }
    }

    contentsList.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    final examsRaw = json['exams'];
    final exam = examsRaw is Map<String, dynamic>
        ? examsRaw
        : (examsRaw is List && examsRaw.isNotEmpty
              ? examsRaw.first as Map<String, dynamic>
              : null);

    final examId =
        exam?['id'] as String? ?? json['attached_exam_id'] as String?;
    final examTitle =
        exam?['title'] as String? ?? json['attached_exam_title'] as String?;
    final examDuration =
        (exam?['duration_minutes'] as num?)?.toInt() ??
        (json['attached_exam_duration'] as num?)?.toInt() ??
        45;
    final examScore =
        (exam?['total_score'] as num?)?.toInt() ??
        (json['attached_exam_score'] as num?)?.toInt() ??
        20;

    return LectureModel(
      id: json['id'] as String? ?? '',
      courseId: json['course_id'] as String?,
      courseSortOrder: (json['_course_sort_order'] as num?)?.toInt(),
      teacherId:
          json['teacher_id'] as String? ?? teacher?['id'] as String? ?? '',
      teacherName:
          teacher?['name'] as String? ??
          json['teacher_name'] as String? ??
          'أ / محمد سعيد',
      teacherTitle:
          teacher?['title'] as String? ??
          json['teacher_title'] as String? ??
          'كبير معلمي مادة الفيزياء',
      teacherAvatarUrl:
          teacher?['avatar_url'] as String? ??
          json['teacher_avatar_url'] as String?,
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      stage: json['stage'] as String? ?? 'ثانوي',
      grade: json['grade'] as String? ?? 'الصف الأول الثانوي',
      subject: json['subject'] as String? ?? 'الفيزياء',
      chapter: json['chapter'] as String? ?? 'الفصل الثالث',
      lessonNumber: json['lesson_number'] as String? ?? 'الدرس 3',
      price:
          (json['online_price'] as num?)?.toDouble() ??
          (json['price'] as num?)?.toDouble() ??
          0.0,
      centerPrice: (json['center_price'] as num?)?.toDouble() ?? 10.0,
      isCenterStudent: isCenterStudent,
      thumbnailUrl: json['thumbnail_url'] as String?,
      hasAccess: hasAccess,
      contents: contentsList,
      attachedExamId: examId,
      attachedExamTitle: examTitle,
      attachedExamDuration: examDuration,
      attachedExamScore: examScore,
      enrolledStudentsCount: enrolledCount,
      centerStudentsCount: centerCount,
      onlineStudentsCount: onlineCount,
    );
  }

  LectureEntity toEntity() {
    return LectureEntity(
      id: id,
      courseId: courseId,
      courseSortOrder: courseSortOrder,
      teacherId: teacherId,
      teacherName: teacherName,
      teacherTitle: teacherTitle,
      teacherAvatarUrl: teacherAvatarUrl,
      title: title,
      description: description,
      stage: stage,
      grade: grade,
      subject: subject,
      chapter: chapter,
      lessonNumber: lessonNumber,
      price: price,
      centerPrice: centerPrice,
      isCenterStudent: isCenterStudent,
      thumbnailUrl: thumbnailUrl,
      hasAccess: hasAccess,
      contents: contents.map((e) => e.toEntity()).toList(),
      attachedExamId: attachedExamId,
      attachedExamTitle: attachedExamTitle,
      attachedExamDuration: attachedExamDuration,
      attachedExamScore: attachedExamScore,
      enrolledStudentsCount: enrolledStudentsCount,
      centerStudentsCount: centerStudentsCount,
      onlineStudentsCount: onlineStudentsCount,
    );
  }
}
