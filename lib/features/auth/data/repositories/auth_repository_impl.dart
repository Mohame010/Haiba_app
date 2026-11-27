import 'dart:async';
import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/errors/error_handler.dart';
import '../../../core/errors/failure.dart';
import '../../../core/helpers/app_logger.dart';
import '../../../core/network/api_result.dart';
import '../../../core/services/device_session_service.dart';
import '../../../core/services/notifcations/firebase_messaging_service.dart';
import '../../domain/entities/otp_response_entity.dart';
import '../../domain/entities/register_params.dart';
import '../../domain/entities/student_profile_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_data_source.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource _remoteDataSource;
  final DeviceSessionService _deviceSessionService;

  AuthRepositoryImpl(this._remoteDataSource, this._deviceSessionService);

  @override
  Future<ApiResult<StudentProfileEntity>> loginWithPhone({
    required String phone,
    required String password,
  }) async {
    try {
      final model = await _remoteDataSource.loginWithPhone(
        phone: phone,
        password: password,
      );
      await _deviceSessionService.registerCurrentDevice();
      unawaited(FirebaseMessagingService.instance.syncCurrentDevice());
      return ApiResult.success(model.toEntity());
    } on AuthException catch (e) {
      final message = ErrorHandler.mapAuthErrorMessage(e.message);
      return ApiResult.failure(
        AuthFailure(
          message,
          e.statusCode != null ? int.tryParse(e.statusCode!) : null,
        ),
      );
    } on PostgrestException catch (e) {
      final message = ErrorHandler.mapAuthErrorMessage(e.message);
      return ApiResult.failure(
        ServerFailure(message, int.tryParse(e.code ?? '')),
      );
    } on SocketException {
      return const ApiResult.failure(NetworkFailure());
    } catch (e) {
      final message = ErrorHandler.mapAuthErrorMessage(e.toString());
      return ApiResult.failure(AuthFailure(message));
    }
  }

  @override
  Future<ApiResult<StudentProfileEntity>> registerStudent(
    RegisterParams params,
  ) async {
    try {
      final model = await _remoteDataSource.registerStudent(params);
      await _deviceSessionService.registerCurrentDevice();
      unawaited(FirebaseMessagingService.instance.syncCurrentDevice());
      return ApiResult.success(model.toEntity());
    } on AuthException catch (e) {
      final message = ErrorHandler.mapAuthErrorMessage(e.message);
      return ApiResult.failure(
        AuthFailure(
          message,
          e.statusCode != null ? int.tryParse(e.statusCode!) : null,
        ),
      );
    } on PostgrestException catch (e) {
      final message = ErrorHandler.mapAuthErrorMessage(e.message);
      return ApiResult.failure(
        ServerFailure(message, int.tryParse(e.code ?? '')),
      );
    } on SocketException {
      return const ApiResult.failure(NetworkFailure());
    } catch (e) {
      final message = ErrorHandler.mapAuthErrorMessage(e.toString());
      return ApiResult.failure(AuthFailure(message));
    }
  }

  @override
  Future<ApiResult<OtpResponseEntity>> sendOtp(
    String phone, {
    RegisterParams? registrationParams,
  }) async {
    final maskedPhone = AppLogger.maskedPhone(phone);
    AppLogger.authLog(
      '[OTP][Repository] sendOtp started',
      data: {'phone': maskedPhone},
    );
    try {
      final model = await _remoteDataSource.sendOtp(
        phone,
        registrationParams: registrationParams,
      );
      AppLogger.authLog(
        '[OTP][Repository] sendOtp data source response',
        data: {
          'phone': maskedPhone,
          'success': model.success,
          'message': model.message,
          'cooldownSeconds': model.cooldownSeconds,
        },
      );
      return ApiResult.success(model.toEntity());
    } on AuthException catch (e) {
      final message = ErrorHandler.mapAuthErrorMessage(e.message);
      AppLogger.authLog(
        '[OTP][Repository] sendOtp AuthException',
        data: {'phone': maskedPhone, 'code': e.code, 'status': e.statusCode},
        error: e.message,
      );
      return ApiResult.failure(AuthFailure(message));
    } on SocketException catch (e, stackTrace) {
      AppLogger.authLog(
        '[OTP][Repository] sendOtp SocketException',
        data: {'phone': maskedPhone},
        error: e,
        stackTrace: stackTrace,
      );
      return const ApiResult.failure(NetworkFailure());
    } catch (e, stackTrace) {
      final message = ErrorHandler.mapAuthErrorMessage(e.toString());
      AppLogger.authLog(
        '[OTP][Repository] sendOtp unexpected exception',
        data: {'phone': maskedPhone},
        error: e,
        stackTrace: stackTrace,
      );
      return ApiResult.failure(ServerFailure(message));
    }
  }

  @override
  Future<ApiResult<OtpResponseEntity>> verifyOtp({
    required String phone,
    required String code,
    OtpDeliveryChannel channel = OtpDeliveryChannel.whatsapp,
    bool isPasswordReset = false,
  }) async {
    final maskedPhone = AppLogger.maskedPhone(phone);
    AppLogger.authLog(
      '[OTP][Repository] verifyOtp started',
      data: {'phone': maskedPhone, 'codeLength': code.length},
    );
    try {
      final model = await _remoteDataSource.verifyOtp(
        phone: phone,
        code: code,
        channel: channel,
        isPasswordReset: isPasswordReset,
      );
      AppLogger.authLog(
        '[OTP][Repository] verifyOtp data source response',
        data: {
          'phone': maskedPhone,
          'success': model.success,
          'message': model.message,
        },
      );
      return ApiResult.success(model.toEntity());
    } on AuthException catch (e) {
      final message = ErrorHandler.mapAuthErrorMessage(e.message);
      return ApiResult.failure(AuthFailure(message));
    } on SocketException {
      return const ApiResult.failure(NetworkFailure());
    } catch (e) {
      final message = ErrorHandler.mapAuthErrorMessage(e.toString());
      return ApiResult.failure(ServerFailure(message));
    }
  }

  @override
  Future<ApiResult<OtpResponseEntity>> resendOtp(
    String phone, {
    OtpDeliveryChannel channel = OtpDeliveryChannel.whatsapp,
    bool isPasswordReset = false,
    RegisterParams? registrationParams,
  }) async {
    final maskedPhone = AppLogger.maskedPhone(phone);
    AppLogger.authLog(
      '[OTP][Repository] resendOtp started',
      data: {'phone': maskedPhone},
    );
    try {
      final model = await _remoteDataSource.resendOtp(
        phone,
        channel: channel,
        isPasswordReset: isPasswordReset,
        registrationParams: registrationParams,
      );
      AppLogger.authLog(
        '[OTP][Repository] resendOtp data source response',
        data: {
          'phone': maskedPhone,
          'success': model.success,
          'message': model.message,
        },
      );
      return ApiResult.success(model.toEntity());
    } on AuthException catch (e) {
      final message = ErrorHandler.mapAuthErrorMessage(e.message);
      return ApiResult.failure(AuthFailure(message));
    } on SocketException {
      return const ApiResult.failure(NetworkFailure());
    } catch (e) {
      final message = ErrorHandler.mapAuthErrorMessage(e.toString());
      return ApiResult.failure(ServerFailure(message));
    }
  }

  @override
  Future<ApiResult<OtpResponseEntity>> sendResetPasswordOtp(
    String identifier, {
    OtpDeliveryChannel channel = OtpDeliveryChannel.whatsapp,
  }) async {
    try {
      final model = await _remoteDataSource.sendResetPasswordOtp(
        identifier,
        channel: channel,
      );
      return ApiResult.success(model.toEntity());
    } on AuthException catch (e) {
      final message = ErrorHandler.mapAuthErrorMessage(e.message);
      return ApiResult.failure(AuthFailure(message));
    } on SocketException {
      return const ApiResult.failure(NetworkFailure());
    } catch (e) {
      final message = ErrorHandler.mapAuthErrorMessage(e.toString());
      return ApiResult.failure(ServerFailure(message));
    }
  }

  @override
  Future<ApiResult<void>> resetPassword({
    required String identifier,
    required String newPassword,
    OtpDeliveryChannel channel = OtpDeliveryChannel.whatsapp,
  }) async {
    try {
      await _remoteDataSource.resetPassword(
        identifier: identifier,
        newPassword: newPassword,
        channel: channel,
      );
      return const ApiResult.success(null);
    } on AuthException catch (e) {
      final message = ErrorHandler.mapAuthErrorMessage(e.message);
      return ApiResult.failure(AuthFailure(message));
    } on SocketException {
      return const ApiResult.failure(NetworkFailure());
    } catch (e) {
      final message = ErrorHandler.mapAuthErrorMessage(e.toString());
      return ApiResult.failure(ServerFailure(message));
    }
  }

  @override
  Future<ApiResult<StudentProfileEntity>> getStudentProfile(
    String userId,
  ) async {
    try {
      final model = await _remoteDataSource.getStudentProfile(userId);
      return ApiResult.success(model.toEntity());
    } on AuthException catch (e) {
      final message = ErrorHandler.mapAuthErrorMessage(e.message);
      return ApiResult.failure(AuthFailure(message));
    } on PostgrestException catch (e) {
      final message = ErrorHandler.mapAuthErrorMessage(e.message);
      return ApiResult.failure(ServerFailure(message));
    } on SocketException {
      return const ApiResult.failure(NetworkFailure());
    } catch (e) {
      final message = ErrorHandler.mapAuthErrorMessage(e.toString());
      return ApiResult.failure(ServerFailure(message));
    }
  }
}
