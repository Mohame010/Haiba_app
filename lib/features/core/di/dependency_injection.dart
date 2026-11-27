import 'package:get_it/get_it.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Auth
import '../../auth/data/datasources/auth_remote_data_source.dart';
import '../../auth/data/repositories/auth_repository_impl.dart';
import '../../auth/domain/repositories/auth_repository.dart';
import '../../auth/domain/usecases/login_with_phone_usecase.dart';
import '../../auth/domain/usecases/register_student_usecase.dart';
import '../../auth/domain/usecases/resend_otp_usecase.dart';
import '../../auth/domain/usecases/reset_password_usecase.dart';
import '../../auth/domain/usecases/send_otp_usecase.dart';
import '../../auth/domain/usecases/send_reset_password_otp_usecase.dart';
import '../../auth/domain/usecases/verify_otp_usecase.dart';
import '../../auth/presentation/cubits/login/login_cubit.dart';
import '../../auth/presentation/cubits/otp/otp_cubit.dart';
import '../../auth/presentation/cubits/register/register_cubit.dart';
import '../../auth/presentation/cubits/reset_password/reset_password_cubit.dart';

// Home
import '../../exams/presentation/cubits/exam_session/exam_session_cubit.dart';
import '../../home/data/datasources/home_remote_data_source.dart';
import '../../home/data/repositories/home_repository_impl.dart';
import '../../home/domain/repositories/home_repository.dart';
import '../../home/domain/usecases/get_home_summary_usecase.dart';
import '../../home/domain/usecases/get_leaderboard_usecase.dart';
import '../../home/presentation/cubits/home/home_cubit.dart';
import '../../home/presentation/cubits/leaderboard/leaderboard_cubit.dart';

// Lectures
import '../../lectures/data/datasources/lectures_remote_data_source.dart';
import '../../lectures/data/datasources/notes_local_data_source.dart';
import '../../lectures/data/repositories/lectures_repository_impl.dart';
import '../../lectures/domain/repositories/lectures_repository.dart';
import '../../lectures/domain/usecases/get_lecture_details_usecase.dart';
import '../../lectures/domain/usecases/get_student_lectures_usecase.dart';
import '../../lectures/domain/usecases/save_video_note_usecase.dart';
import '../../lectures/presentation/cubits/lecture_details/lecture_details_cubit.dart';
import '../../lectures/presentation/cubits/lectures_list/lectures_list_cubit.dart';

// Exams
import '../../exams/data/datasources/exams_remote_data_source.dart';
import '../../exams/data/repositories/exams_repository_impl.dart';
import '../../exams/domain/repositories/exams_repository.dart';
import '../../exams/domain/usecases/get_exam_details_usecase.dart';
import '../../exams/domain/usecases/get_exams_usecase.dart';
import '../../exams/presentation/cubits/exams_list/exams_list_cubit.dart';

// Notifications
import '../../notifications/data/datasources/notifications_remote_data_source.dart';
import '../../notifications/data/repositories/notifications_repository_impl.dart';
import '../../notifications/domain/repositories/notifications_repository.dart';
import '../../notifications/domain/usecases/get_notifications_use_case.dart';
import '../../notifications/domain/usecases/get_unread_count_use_case.dart';
import '../../notifications/domain/usecases/mark_all_as_read_use_case.dart';
import '../../notifications/domain/usecases/mark_as_read_use_case.dart';
import '../../notifications/presentation/cubits/notifications_cubit.dart';
import '../../what_to_expect/data/repositories/reels_repository.dart';
import '../services/device_session_service.dart';

final getIt = GetIt.instance;

Future<void> setupDependencyInjection() async {
  // Supabase Client
  getIt.registerLazySingleton<SupabaseClient>(() => Supabase.instance.client);
  getIt.registerLazySingleton<DeviceSessionService>(
    () => DeviceSessionService(getIt<SupabaseClient>()),
  );
  getIt.registerLazySingleton<ReelsRepository>(
    () => ReelsRepository(getIt<SupabaseClient>()),
  );

  // ==================== NOTIFICATIONS ====================
  getIt.registerLazySingleton<NotificationsRemoteDataSource>(
    () => NotificationsRemoteDataSourceImpl(getIt<SupabaseClient>()),
  );
  getIt.registerLazySingleton<NotificationsRepository>(
    () => NotificationsRepositoryImpl(getIt<NotificationsRemoteDataSource>()),
  );
  getIt.registerLazySingleton<GetNotificationsUseCase>(
    () => GetNotificationsUseCase(getIt<NotificationsRepository>()),
  );
  getIt.registerLazySingleton<MarkAsReadUseCase>(
    () => MarkAsReadUseCase(getIt<NotificationsRepository>()),
  );
  getIt.registerLazySingleton<MarkAllAsReadUseCase>(
    () => MarkAllAsReadUseCase(getIt<NotificationsRepository>()),
  );
  getIt.registerLazySingleton<GetUnreadCountUseCase>(
    () => GetUnreadCountUseCase(getIt<NotificationsRepository>()),
  );
  getIt.registerFactory<NotificationsCubit>(
    () => NotificationsCubit(
      getNotificationsUseCase: getIt<GetNotificationsUseCase>(),
      markAsReadUseCase: getIt<MarkAsReadUseCase>(),
      markAllAsReadUseCase: getIt<MarkAllAsReadUseCase>(),
      getUnreadCountUseCase: getIt<GetUnreadCountUseCase>(),
    ),
  );

  // ==================== AUTH ====================
  getIt.registerLazySingleton<AuthRemoteDataSource>(
    () => AuthRemoteDataSourceImpl(getIt<SupabaseClient>()),
  );
  getIt.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(
      getIt<AuthRemoteDataSource>(),
      getIt<DeviceSessionService>(),
    ),
  );
  getIt.registerLazySingleton<LoginWithPhoneUseCase>(
    () => LoginWithPhoneUseCase(getIt<AuthRepository>()),
  );
  getIt.registerLazySingleton<RegisterStudentUseCase>(
    () => RegisterStudentUseCase(getIt<AuthRepository>()),
  );
  getIt.registerLazySingleton<SendOtpUseCase>(
    () => SendOtpUseCase(getIt<AuthRepository>()),
  );
  getIt.registerLazySingleton<VerifyOtpUseCase>(
    () => VerifyOtpUseCase(getIt<AuthRepository>()),
  );
  getIt.registerLazySingleton<ResendOtpUseCase>(
    () => ResendOtpUseCase(getIt<AuthRepository>()),
  );
  getIt.registerLazySingleton<SendResetPasswordOtpUseCase>(
    () => SendResetPasswordOtpUseCase(getIt<AuthRepository>()),
  );
  getIt.registerLazySingleton<ResetPasswordUseCase>(
    () => ResetPasswordUseCase(getIt<AuthRepository>()),
  );
  getIt.registerFactory<LoginCubit>(
    () => LoginCubit(getIt<LoginWithPhoneUseCase>()),
  );
  getIt.registerFactory<RegisterCubit>(
    () => RegisterCubit(getIt<SendOtpUseCase>()),
  );
  getIt.registerFactory<OtpCubit>(
    () => OtpCubit(
      sendOtpUseCase: getIt<SendOtpUseCase>(),
      verifyOtpUseCase: getIt<VerifyOtpUseCase>(),
      resendOtpUseCase: getIt<ResendOtpUseCase>(),
      registerStudentUseCase: getIt<RegisterStudentUseCase>(),
    ),
  );
  getIt.registerFactory<ResetPasswordCubit>(
    () => ResetPasswordCubit(
      sendResetPasswordOtpUseCase: getIt<SendResetPasswordOtpUseCase>(),
      resetPasswordUseCase: getIt<ResetPasswordUseCase>(),
    ),
  );

  // ==================== HOME ====================
  getIt.registerLazySingleton<HomeRemoteDataSource>(
    () => HomeRemoteDataSourceImpl(getIt<SupabaseClient>()),
  );
  getIt.registerLazySingleton<HomeRepository>(
    () => HomeRepositoryImpl(getIt<HomeRemoteDataSource>()),
  );
  getIt.registerLazySingleton<GetHomeSummaryUseCase>(
    () => GetHomeSummaryUseCase(getIt<HomeRepository>()),
  );
  getIt.registerLazySingleton<GetLeaderboardUseCase>(
    () => GetLeaderboardUseCase(getIt<HomeRepository>()),
  );
  getIt.registerFactory<HomeCubit>(
    () => HomeCubit(getIt<GetHomeSummaryUseCase>()),
  );
  getIt.registerFactory<LeaderboardCubit>(
    () => LeaderboardCubit(getIt<GetLeaderboardUseCase>()),
  );

  // ==================== LECTURES ====================
  getIt.registerLazySingleton<NotesLocalDataSource>(
    () => NotesLocalDataSourceImpl(),
  );
  getIt.registerLazySingleton<LecturesRemoteDataSource>(
    () => LecturesRemoteDataSourceImpl(getIt<SupabaseClient>()),
  );
  getIt.registerLazySingleton<LecturesRepository>(
    () => LecturesRepositoryImpl(
      remoteDataSource: getIt<LecturesRemoteDataSource>(),
      localDataSource: getIt<NotesLocalDataSource>(),
    ),
  );
  getIt.registerLazySingleton<GetStudentLecturesUseCase>(
    () => GetStudentLecturesUseCase(getIt<LecturesRepository>()),
  );
  getIt.registerLazySingleton<GetLectureDetailsUseCase>(
    () => GetLectureDetailsUseCase(getIt<LecturesRepository>()),
  );
  getIt.registerLazySingleton<SaveVideoNoteUseCase>(
    () => SaveVideoNoteUseCase(getIt<LecturesRepository>()),
  );
  getIt.registerLazySingleton<GetVideoNotesUseCase>(
    () => GetVideoNotesUseCase(getIt<LecturesRepository>()),
  );
  getIt.registerFactory<LecturesListCubit>(
    () => LecturesListCubit(getIt<GetStudentLecturesUseCase>()),
  );
  getIt.registerFactory<LectureDetailsCubit>(
    () => LectureDetailsCubit(
      getLectureDetailsUseCase: getIt<GetLectureDetailsUseCase>(),
      getStudentLecturesUseCase: getIt<GetStudentLecturesUseCase>(),
      getVideoNotesUseCase: getIt<GetVideoNotesUseCase>(),
      saveVideoNoteUseCase: getIt<SaveVideoNoteUseCase>(),
    ),
  );

  // ==================== EXAMS ====================
  getIt.registerLazySingleton<ExamsRemoteDataSource>(
    () => ExamsRemoteDataSourceImpl(getIt<SupabaseClient>()),
  );
  getIt.registerLazySingleton<ExamsRepository>(
    () => ExamsRepositoryImpl(getIt<ExamsRemoteDataSource>()),
  );
  getIt.registerLazySingleton<GetExamsUseCase>(
    () => GetExamsUseCase(getIt<ExamsRepository>()),
  );
  getIt.registerLazySingleton<GetExamDetailsUseCase>(
    () => GetExamDetailsUseCase(getIt<ExamsRepository>()),
  );
  getIt.registerLazySingleton<SubmitExamUseCase>(
    () => SubmitExamUseCase(getIt<ExamsRepository>()),
  );
  getIt.registerFactory<ExamsListCubit>(
    () => ExamsListCubit(getIt<GetExamsUseCase>()),
  );
  getIt.registerFactory<ExamSessionCubit>(
    () => ExamSessionCubit(
      getExamDetailsUseCase: getIt<GetExamDetailsUseCase>(),
      submitExamUseCase: getIt<SubmitExamUseCase>(),
    ),
  );
}
