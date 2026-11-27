import 'lecture_content_entity.dart';

class LectureEntity {
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
  final List<LectureContentEntity> contents;
  final String? attachedExamId;
  final String? attachedExamTitle;
  final int attachedExamDuration;
  final int attachedExamScore;
  final int enrolledStudentsCount;
  final int centerStudentsCount;
  final int onlineStudentsCount;

  const LectureEntity({
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

  /// The effective price for the current student based on whether they attended in center
  double get effectivePrice => isCenterStudent ? centerPrice : price;
}
