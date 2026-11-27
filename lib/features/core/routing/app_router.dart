import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

// Auth
import '../../auth/domain/entities/register_params.dart';
import '../../auth/presentation/cubits/login/login_cubit.dart';
import '../../auth/presentation/cubits/otp/otp_cubit.dart';
import '../../auth/presentation/cubits/register/register_cubit.dart';
import '../../auth/presentation/cubits/reset_password/reset_password_cubit.dart';
import '../../auth/presentation/routing/pending_registration_store.dart';
import '../../auth/presentation/screens/forgot_password_screen.dart';
import '../../auth/presentation/screens/login_screen.dart';
import '../../auth/presentation/screens/legal_document_screen.dart';
import '../../auth/presentation/screens/otp_verification_screen.dart';
import '../../auth/presentation/screens/register_screen.dart';
import '../../auth/presentation/screens/reset_password_screen.dart';

// Abu Al Areef offline game
import '../../abu_al_areef/domain/abu_al_areef_question.dart';
import '../../abu_al_areef/presentation/screens/abu_al_areef_game_screen.dart';
import '../../abu_al_areef/presentation/screens/abu_al_areef_setup_screen.dart';

// Home
import '../../home/presentation/cubits/home/home_cubit.dart';
import '../../home/presentation/cubits/leaderboard/leaderboard_cubit.dart';
import '../../home/presentation/screens/home_screen.dart';
import '../../home/presentation/screens/leaderboard_screen.dart';
import '../../home/presentation/screens/main_screen.dart';
import '../../study/presentation/screens/study_environment_screen.dart';

// Level assessment
import '../../level_assessment/presentation/screens/level_assessment_intro_screen.dart';
import '../../level_assessment/presentation/screens/level_assessment_screen.dart';

// Lectures
import '../../lectures/presentation/cubits/lecture_details/lecture_details_cubit.dart';
import '../../lectures/presentation/cubits/lectures_list/lectures_list_cubit.dart';
import '../../lectures/presentation/screens/lecture_details_screen.dart';
import '../../lectures/presentation/screens/lectures_list_screen.dart';
import '../../lectures/presentation/screens/lesson_resources_screen.dart';
import '../../lectures/presentation/screens/recommended_courses_screen.dart';

// English reading novels & poetry
import '../../novels/presentation/screens/novels_list_screen.dart';
import '../../novels/presentation/screens/novel_reader_screen.dart';
import '../../poetry/presentation/screens/poetry_list_screen.dart';

// Exams
import '../../exams/domain/entities/exam_entity.dart';
import '../../exams/domain/entities/exam_submission_entity.dart';
import '../../exams/presentation/cubits/exam_session/exam_session_cubit.dart';
import '../../exams/presentation/cubits/exams_list/exams_list_cubit.dart';
import '../../exams/presentation/screens/exam_details_screen.dart';
import '../../exams/presentation/screens/exam_result_screen.dart';
import '../../exams/presentation/screens/exam_screen.dart';
import '../../exams/presentation/screens/exams_list_screen.dart';

// Notifications
import '../../notifications/presentation/cubits/notifications_cubit.dart';
import '../../notifications/presentation/screens/notifications_screen.dart';

// Onboarding
import '../../onboarding/presentation/cubit/onboarding_cubit.dart';
import '../../onboarding/presentation/screens/onboarding_screen.dart';
import '../../onboarding/presentation/screens/splash_screen.dart';
import '../../what_to_expect/data/repositories/reels_repository.dart';
import '../../what_to_expect/presentation/cubit/reels_cubit.dart';
import '../../what_to_expect/presentation/screens/what_to_expect_screen.dart';

// Teacher administration
import '../../teacher_admin/presentation/screens/teacher_dashboard_screen.dart';
import '../../teacher_admin/presentation/screens/teacher_login_screen.dart';

import '../di/dependency_injection.dart';
import 'app_routes.dart';
import 'notification_destination.dart';

final class AppRouter {
  const AppRouter._();

  static final GlobalKey<NavigatorState> rootNavigatorKey =
      GlobalKey<NavigatorState>();

  /// Opens login as a fresh root route and removes every authenticated route.
  static void pushLoginAndClearStack() {
    router.go(AppRoutes.login);
  }

  static void openNotificationDestination({
    required String route,
    String? actionId,
  }) {
    final safeRoute = NotificationDestination.isAllowed(route)
        ? route
        : AppRoutes.notifications;
    if (NotificationDestination.requiresId(safeRoute)) {
      if (actionId == null || actionId.isEmpty) {
        router.push(AppRoutes.notifications);
        return;
      }
      router.push(safeRoute, extra: actionId);
      return;
    }
    if (safeRoute == AppRoutes.main) {
      router.go(safeRoute);
    } else {
      router.push(safeRoute);
    }
  }

  static final GoRouter router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: true,
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (context, state) => BlocProvider(
          create: (_) => OnboardingCubit(),
          child: const OnboardingScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.whatToExpect,
        builder: (context, state) {
          final firstVisit = state.extra as bool? ?? false;
          return BlocProvider(
            create: (_) =>
                ReelsCubit(getIt<ReelsRepository>(), firstVisit: firstVisit),
            child: WhatToExpectScreen(firstVisit: firstVisit),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => BlocProvider(
          create: (_) => getIt<LoginCubit>(),
          child: const LoginScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.teacherLogin,
        builder: (context, state) => const TeacherLoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.teacherDashboard,
        builder: (context, state) => const TeacherDashboardScreen(),
      ),
      GoRoute(
        path: AppRoutes.register,
        builder: (context, state) => BlocProvider(
          create: (_) => getIt<RegisterCubit>(),
          child: const RegisterScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.terms,
        builder: (context, state) => const LegalDocumentScreen(
          type: LegalDocumentType.terms,
        ),
      ),
      GoRoute(
        path: AppRoutes.privacyPolicy,
        builder: (context, state) => const LegalDocumentScreen(
          type: LegalDocumentType.privacy,
        ),
      ),
      GoRoute(
        path: AppRoutes.otpVerification,
        builder: (context, state) {
          String phone = '01033912891';
          RegisterParams? registerParams;
          bool isPasswordReset = false;
          OtpDeliveryChannel channel = OtpDeliveryChannel.whatsapp;

          if (state.extra is Map<String, dynamic>) {
            final map = state.extra as Map<String, dynamic>;
            phone = map['phone'] as String? ?? phone;
            final registrationKey = map['registrationKey'] as String?;
            if (registrationKey != null) {
              registerParams = PendingRegistrationStore.take(registrationKey);
            }
            isPasswordReset = map['isPasswordReset'] == true;
            final channelName = map['channel'] as String?;
            channel = OtpDeliveryChannel.values.firstWhere(
              (value) => value.name == channelName,
              orElse: () => OtpDeliveryChannel.whatsapp,
            );
          } else if (state.extra is String) {
            phone = state.extra as String;
          }

          return BlocProvider(
            create: (_) => getIt<OtpCubit>(),
            child: OtpVerificationScreen(
              phone: phone,
              registerParams: registerParams,
              isPasswordReset: isPasswordReset,
              channel: registerParams?.otpChannel ?? channel,
            ),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        builder: (context, state) => BlocProvider(
          create: (_) => getIt<ResetPasswordCubit>(),
          child: const ForgotPasswordScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.resetPassword,
        builder: (context, state) {
          final extra = state.extra;
          final identifier = extra is Map<String, dynamic>
              ? extra['identifier'] as String? ?? ''
              : extra as String? ?? '';
          final channelValue = extra is Map<String, dynamic>
              ? extra['channel']
              : null;
          final channel = switch (channelValue) {
            OtpDeliveryChannel value => value,
            String name => OtpDeliveryChannel.values.firstWhere(
              (value) => value.name == name,
              orElse: () => OtpDeliveryChannel.whatsapp,
            ),
            _ => OtpDeliveryChannel.whatsapp,
          };
          return BlocProvider(
            create: (_) => getIt<ResetPasswordCubit>(),
            child: ResetPasswordScreen(
              identifier: identifier,
              channel: channel,
            ),
          );
        },
      ),

      // ==================== MAIN & HOME ====================
      GoRoute(
        path: AppRoutes.main,
        builder: (context, state) {
          return MultiBlocProvider(
            providers: [
              BlocProvider(create: (_) => getIt<HomeCubit>()),
              BlocProvider(create: (_) => getIt<LecturesListCubit>()),
              BlocProvider(create: (_) => getIt<ExamsListCubit>()),
              BlocProvider(create: (_) => getIt<LeaderboardCubit>()),
            ],
            child: MainScreen(initialIndex: state.extra as int? ?? 0),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => BlocProvider(
          create: (_) => getIt<HomeCubit>(),
          child: const HomeScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.levelAssessmentIntro,
        builder: (context, state) => LevelAssessmentIntroScreen(
          firstLogin: state.extra as bool? ?? false,
        ),
      ),
      GoRoute(
        path: AppRoutes.levelAssessment,
        builder: (context, state) => const LevelAssessmentScreen(),
      ),
      GoRoute(
        path: AppRoutes.abuAlAreef,
        builder: (context, state) => const AbuAlAreefSetupScreen(),
      ),
      GoRoute(
        path: AppRoutes.abuAlAreefGame,
        builder: (context, state) => AbuAlAreefGameScreen(
          config:
              state.extra as AbuAlAreefConfig? ??
              const AbuAlAreefConfig(
                multiplayer: false,
                firstPlayer: 'اللاعب الأول',
              ),
        ),
      ),
      GoRoute(
        path: AppRoutes.leaderboard,
        builder: (context, state) {
          String? examId;
          String? initialGrade;
          List<String>? teacherGrades;
          if (state.extra is Map<String, dynamic>) {
            final map = state.extra as Map<String, dynamic>;
            examId = map['examId'] as String?;
            initialGrade = map['grade'] as String?;
            if (map['teacherGrades'] is List) {
              teacherGrades = (map['teacherGrades'] as List)
                  .map((e) => e.toString())
                  .toList();
            }
          } else if (state.extra is String) {
            final extraStr = state.extra as String;
            if (extraStr.startsWith('الصف') ||
                extraStr.startsWith('بكالوريا') ||
                extraStr.startsWith('الفرقة')) {
              initialGrade = extraStr;
            } else {
              examId = extraStr;
            }
          }
          return BlocProvider(
            create: (_) => getIt<LeaderboardCubit>(),
            child: LeaderboardScreen(
              examId: examId,
              initialGrade: initialGrade,
              teacherGrades: teacherGrades,
            ),
          );
        },
      ),

      // ==================== LECTURES ====================
      GoRoute(
        path: AppRoutes.lectures,
        builder: (context, state) => BlocProvider(
          create: (_) => getIt<LecturesListCubit>(),
          child: const LecturesListScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.recommendedCourses,
        builder: (context, state) => const RecommendedCoursesScreen(),
      ),
      GoRoute(
        path: AppRoutes.novels,
        builder: (context, state) => const NovelsListScreen(),
      ),
      GoRoute(
        path: AppRoutes.poetry,
        builder: (context, state) => const PoetryListScreen(),
      ),
      GoRoute(
        path: AppRoutes.novelReader,
        builder: (context, state) =>
            NovelReaderScreen(novelId: state.extra as String? ?? ''),
      ),
      GoRoute(
        path: AppRoutes.studyEnvironment,
        builder: (context, state) => const StudyEnvironmentScreen(),
      ),
      GoRoute(
        path: AppRoutes.lectureDetails,
        builder: (context, state) {
          final lectureId =
              (state.extra as String?) ??
              '22222222-2222-2222-2222-222222222222';
          return BlocProvider(
            create: (_) => getIt<LectureDetailsCubit>(),
            child: LectureDetailsScreen(lectureId: lectureId),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.lessonResources,
        builder: (context, state) {
          final lectureId =
              (state.extra as String?) ??
              '22222222-2222-2222-2222-222222222222';
          return BlocProvider(
            create: (_) => getIt<LectureDetailsCubit>(),
            child: LessonResourcesScreen(lectureId: lectureId),
          );
        },
      ),

      // ==================== EXAMS ====================
      GoRoute(
        path: AppRoutes.allExams,
        builder: (context, state) => BlocProvider(
          create: (_) => getIt<ExamsListCubit>(),
          child: const ExamsListScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.examDetails,
        builder: (context, state) {
          final examId =
              (state.extra as String?) ??
              '44444444-4444-4444-4444-444444444444';
          return ExamDetailsScreen(examId: examId);
        },
      ),
      GoRoute(
        path: AppRoutes.examScreen,
        builder: (context, state) {
          final examId =
              (state.extra as String?) ??
              '44444444-4444-4444-4444-444444444444';
          return BlocProvider(
            create: (_) => getIt<ExamSessionCubit>(),
            child: ExamScreen(examId: examId),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.examResult,
        builder: (context, state) {
          final extraMap = state.extra as Map<String, dynamic>;
          final submission = extraMap['submission'] as ExamSubmissionEntity;
          final exam = extraMap['exam'] as ExamEntity;
          return ExamResultScreen(submission: submission, exam: exam);
        },
      ),

      // ==================== NOTIFICATIONS ====================
      GoRoute(
        path: AppRoutes.notifications,
        builder: (context, state) => BlocProvider(
          create: (_) => getIt<NotificationsCubit>(),
          child: const NotificationsScreen(),
        ),
      ),
    ],
  );
}
