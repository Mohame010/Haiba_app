import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/network/api_result.dart';
import '../../domain/entities/notification_entity.dart';
import '../../domain/usecases/get_notifications_use_case.dart';
import '../../domain/usecases/get_unread_count_use_case.dart';
import '../../domain/usecases/mark_all_as_read_use_case.dart';
import '../../domain/usecases/mark_as_read_use_case.dart';
import 'notifications_state.dart';

class NotificationsCubit extends Cubit<NotificationsState> {
  final GetNotificationsUseCase _getNotificationsUseCase;
  final MarkAsReadUseCase _markAsReadUseCase;
  final MarkAllAsReadUseCase _markAllAsReadUseCase;
  final GetUnreadCountUseCase _getUnreadCountUseCase;

  NotificationsCubit({
    required GetNotificationsUseCase getNotificationsUseCase,
    required MarkAsReadUseCase markAsReadUseCase,
    required MarkAllAsReadUseCase markAllAsReadUseCase,
    required GetUnreadCountUseCase getUnreadCountUseCase,
  }) : _getNotificationsUseCase = getNotificationsUseCase,
       _markAsReadUseCase = markAsReadUseCase,
       _markAllAsReadUseCase = markAllAsReadUseCase,
       _getUnreadCountUseCase = getUnreadCountUseCase,
       super(const NotificationsInitial());

  Future<void> loadNotifications() async {
    emit(const NotificationsLoading());

    final result = await _getNotificationsUseCase();

    switch (result) {
      case ApiSuccess<List<NotificationEntity>>(:final data):
        final unread = data.where((n) => !n.isRead).length;
        emit(NotificationsLoaded(notifications: data, unreadCount: unread));
      case ApiError<List<NotificationEntity>>(:final failure):
        emit(NotificationsError(failure.message));
    }
  }

  Future<void> markAsRead(String notificationId) async {
    final currentState = state;
    if (currentState is! NotificationsLoaded) return;

    // Optimistic UI update
    final updatedList = currentState.notifications.map((n) {
      if (n.id == notificationId) {
        return n.copyWith(isRead: true);
      }
      return n;
    }).toList();

    final unread = updatedList.where((n) => !n.isRead).length;
    emit(
      currentState.copyWith(notifications: updatedList, unreadCount: unread),
    );

    await _markAsReadUseCase(notificationId);
  }

  Future<void> markAllAsRead() async {
    final currentState = state;
    if (currentState is! NotificationsLoaded) return;

    final updatedList = currentState.notifications
        .map((n) => n.copyWith(isRead: true))
        .toList();
    emit(currentState.copyWith(notifications: updatedList, unreadCount: 0));

    await _markAllAsReadUseCase();
  }

  Future<void> refreshUnreadCount() async {
    final result = await _getUnreadCountUseCase();
    if (result is ApiSuccess<int>) {
      if (state is NotificationsLoaded) {
        emit((state as NotificationsLoaded).copyWith(unreadCount: result.data));
      }
    }
  }
}
