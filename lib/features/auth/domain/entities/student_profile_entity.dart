class StudentProfileEntity {
  final String id;
  final String name;
  final String phone;
  final String educationLevel;
  final String grade;
  final String? birthDate;
  final int points;
  final List<dynamic> relatedExams;
  final List<dynamic> relatedLectures;
  final String? teacherId;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? studentCode;
  final String? parentPhone;
  final String? status;
  final String? groupName;
  final String? paymentStatus;
  final String? groupId;

  const StudentProfileEntity({
    required this.id,
    required this.name,
    required this.phone,
    required this.educationLevel,
    required this.grade,
    this.birthDate,
    this.points = 0,
    this.relatedExams = const [],
    this.relatedLectures = const [],
    this.teacherId,
    this.createdAt,
    this.updatedAt,
    this.studentCode,
    this.parentPhone,
    this.status = 'active',
    this.groupName,
    this.paymentStatus = 'pending',
    this.groupId,
  });
}
