import '../../domain/entities/student_profile_entity.dart';

class StudentProfileModel {
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

  const StudentProfileModel({
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

  factory StudentProfileModel.fromJson(Map<String, dynamic> json) {
    return StudentProfileModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      educationLevel: json['education_level'] as String? ?? 'ثانوي',
      grade: json['grade'] as String? ?? 'الصف الأول الثانوي',
      birthDate: json['birth_date'] as String?,
      points: (json['points'] as num?)?.toInt() ?? 0,
      relatedExams: json['related_exams'] as List<dynamic>? ?? const [],
      relatedLectures: json['related_lectures'] as List<dynamic>? ?? const [],
      teacherId: json['teacher_id'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
      studentCode: json['student_code'] as String?,
      parentPhone: json['parent_phone'] as String?,
      status: json['status'] as String? ?? 'active',
      groupName: json['group_name'] as String?,
      paymentStatus: json['payment_status'] as String? ?? 'pending',
      groupId: json['group_id'] as String?,
    );
  }

  /// Maps strictly to the public.students table columns in Supabase
  Map<String, dynamic> toDatabaseJson() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'education_level': educationLevel,
      'grade': grade,
      if (birthDate != null && birthDate!.isNotEmpty) 'birth_date': birthDate,
      'points': points,
      if (studentCode != null && studentCode!.isNotEmpty)
        'student_code': studentCode,
      if (parentPhone != null && parentPhone!.isNotEmpty)
        'parent_phone': parentPhone,
      'status': status ?? 'active',
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'education_level': educationLevel,
      'grade': grade,
      'birth_date': birthDate,
      'points': points,
      'student_code': studentCode,
      'parent_phone': parentPhone,
      'status': status,
      if (createdAt != null) 'created_at': createdAt?.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt?.toIso8601String(),
    };
  }

  StudentProfileEntity toEntity() {
    return StudentProfileEntity(
      id: id,
      name: name,
      phone: phone,
      educationLevel: educationLevel,
      grade: grade,
      birthDate: birthDate,
      points: points,
      relatedExams: relatedExams,
      relatedLectures: relatedLectures,
      teacherId: teacherId,
      createdAt: createdAt,
      updatedAt: updatedAt,
      studentCode: studentCode,
      parentPhone: parentPhone,
      status: status,
      groupName: groupName,
      paymentStatus: paymentStatus,
      groupId: groupId,
    );
  }
}
