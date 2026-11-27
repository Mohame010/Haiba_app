import '../../domain/entities/teacher_entity.dart';

class TeacherModel extends TeacherEntity {
  const TeacherModel({
    required super.id,
    required super.name,
    required super.title,
    super.subject,
    super.avatarUrl,
    super.phone,
    super.stages,
    super.grades,
  });

  factory TeacherModel.fromJson(Map<String, dynamic> json) {
    List<String> parseStringList(dynamic value) {
      if (value == null) return [];
      if (value is List) {
        return value.map((e) => e.toString()).toList();
      }
      return [];
    }

    return TeacherModel(
      id: json['id'] as String? ?? '11111111-1111-1111-1111-111111111111',
      name: json['name'] as String? ?? 'أ / محمد سعيد',
      title: json['title'] as String? ?? 'كبير معلمي مادة الفيزياء',
      subject: json['subject'] as String? ?? 'الفيزياء',
      avatarUrl: json['avatar_url'] as String?,
      phone: json['phone'] as String?,
      stages: parseStringList(json['stages']),
      grades: parseStringList(json['grades']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'title': title,
      'subject': subject,
      'avatar_url': avatarUrl,
      'phone': phone,
      'stages': stages,
      'grades': grades,
    };
  }
}
