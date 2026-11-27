class NotificationEntity {
  final String id;
  final String? studentId;
  final String title;
  final String body;
  final String actionRoute;
  final String? actionId;
  final Map<String, dynamic> data;
  final bool isRead;
  final DateTime createdAt;

  const NotificationEntity({
    required this.id,
    this.studentId,
    required this.title,
    required this.body,
    required this.actionRoute,
    this.actionId,
    this.data = const {},
    required this.isRead,
    required this.createdAt,
  });

  NotificationEntity copyWith({
    String? id,
    String? studentId,
    String? title,
    String? body,
    String? actionRoute,
    String? actionId,
    Map<String, dynamic>? data,
    bool? isRead,
    DateTime? createdAt,
  }) {
    return NotificationEntity(
      id: id ?? this.id,
      studentId: studentId ?? this.studentId,
      title: title ?? this.title,
      body: body ?? this.body,
      actionRoute: actionRoute ?? this.actionRoute,
      actionId: actionId ?? this.actionId,
      data: data ?? this.data,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
