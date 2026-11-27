import 'app_routes.dart';

/// Closed allow-list for destinations accepted from remote payloads.
abstract final class NotificationDestination {
  const NotificationDestination._();

  static const allowedRoutes = <String>{
    AppRoutes.main,
    AppRoutes.lectures,
    AppRoutes.lectureDetails,
    AppRoutes.allExams,
    AppRoutes.examDetails,
    AppRoutes.leaderboard,
    AppRoutes.notifications,
  };

  static bool isAllowed(String route) => allowedRoutes.contains(route);

  static bool requiresId(String route) =>
      route == AppRoutes.lectureDetails || route == AppRoutes.examDetails;
}
