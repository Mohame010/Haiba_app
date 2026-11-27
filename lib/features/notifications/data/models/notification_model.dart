import '../../domain/entities/notification_entity.dart';

class NotificationModel {
  final String id;
  final String? studentId;
  final String title;
  final String body;
  final String actionRoute;
  final String? actionId;
  final Map<String, dynamic> data;
  final bool isRead;
  final DateTime createdAt;

  const NotificationModel({
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

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    DateTime parsedDate = DateTime.now();
    if (json['created_at'] != null) {
      parsedDate =
          DateTime.tryParse(json['created_at'] as String) ?? DateTime.now();
    }

    return NotificationModel(
      id: json['id'] as String? ?? '',
      studentId: json['student_id'] as String?,
      title: json['title'] as String? ?? 'إشعار جديد',
      body: json['body'] as String? ?? '',
      actionRoute: json['action_route'] as String? ?? '/notifications',
      actionId: json['action_id'] as String?,
      data: json['data'] is Map
          ? Map<String, dynamic>.from(json['data'] as Map)
          : const {},
      isRead: json['is_read'] as bool? ?? false,
      createdAt: parsedDate,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'student_id': studentId,
      'title': title,
      'body': body,
      'action_route': actionRoute,
      'action_id': actionId,
      'data': data,
      'is_read': isRead,
      'created_at': createdAt.toIso8601String(),
    };
  }

  NotificationEntity toEntity() {
    return NotificationEntity(
      id: id,
      studentId: studentId,
      title: title,
      body: body,
      actionRoute: actionRoute,
      actionId: actionId,
      data: data,
      isRead: isRead,
      createdAt: createdAt,
    );
  }
}
