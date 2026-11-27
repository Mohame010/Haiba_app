class TeacherEntity {
  final String id;
  final String name;
  final String title;
  final String? subject;
  final String? avatarUrl;
  final String? phone;
  final List<String> stages;
  final List<String> grades;

  const TeacherEntity({
    required this.id,
    required this.name,
    required this.title,
    this.subject,
    this.avatarUrl,
    this.phone,
    this.stages = const [],
    this.grades = const [],
  });
}
