import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/helpers/app_logger.dart';
import '../../../../core/network/api_result.dart';
import '../../../domain/entities/register_params.dart';
import '../../../domain/usecases/register_student_usecase.dart';
import '../../../domain/usecases/resend_otp_usecase.dart';
import '../../../domain/usecases/send_otp_usecase.dart';
import '../../../domain/usecases/verify_otp_usecase.dart';
import 'otp_state.dart';

class OtpCubit extends Cubit<OtpState> {
  final SendOtpUseCase _sendOtpUseCase;
  final VerifyOtpUseCase _verifyOtpUseCase;
  final ResendOtpUseCase _resendOtpUseCase;
  final RegisterStudentUseCase _registerStudentUseCase;

  OtpCubit({
    required SendOtpUseCase sendOtpUseCase,
    required VerifyOtpUseCase verifyOtpUseCase,
    required ResendOtpUseCase resendOtpUseCase,
    required RegisterStudentUseCase registerStudentUseCase,
  }) : _sendOtpUseCase = sendOtpUseCase,
       _verifyOtpUseCase = verifyOtpUseCase,
       _resendOtpUseCase = resendOtpUseCase,
       _registerStudentUseCase = registerStudentUseCase,
       super(const OtpInitial());

  Future<void> sendOtp(String phone) async {
    AppLogger.authLog(
      '[OTP][OtpCubit] sendOtp started',
      data: {'phone': AppLogger.maskedPhone(phone)},
    );
    emit(const OtpSending());
    final result = await _sendOtpUseCase(phone);

    switch (result) {
      case ApiSuccess(:final data):
        AppLogger.authLog(
          '[OTP][OtpCubit] sendOtp ApiSuccess',
          data: {'otpSuccess': data.success, 'message': data.message},
        );
        if (data.isPhoneAlreadyRegistered) {
          emit(const OtpPhoneAlreadyRegistered());
        } else if (data.isRateLimited) {
          emit(OtpRateLimited(supportPhone: data.supportPhone));
        } else if (data.success) {
          emit(
            OtpReady(
              expiresAt: data.expiresAt,
              nextResendAt: data.nextResendAt,
              isHourBlocked: data.isHourBlocked,
              attemptsLeft: data.attemptsLeft,
              maxAttempts: data.maxAttempts,
              infoMessage: data.message,
            ),
          );
        } else {
          emit(
            OtpReady(
              nextResendAt: data.nextResendAt,
              isHourBlocked: data.isHourBlocked,
              isVerifyBlocked: data.isVerifyBlocked,
              verifyBlockedUntil: data.verifyBlockedUntil,
              errorMessage: data.message ?? 'فشل إرسال كود التحقق',
            ),
          );
        }
      case ApiError(:final failure):
        AppLogger.authLog(
          '[OTP][OtpCubit] sendOtp ApiError',
          data: {'failureType': failure.runtimeType.toString()},
          error: failure.message,
        );
        emit(OtpError(failure.message));
    }
  }

  Future<void> resendOtp(
    String phone, {
    OtpDeliveryChannel channel = OtpDeliveryChannel.whatsapp,
    bool isPasswordReset = false,
    RegisterParams? registrationParams,
  }) async {
    AppLogger.authLog(
      '[OTP][OtpCubit] resendOtp started',
      data: {'phone': AppLogger.maskedPhone(phone)},
    );
    emit(const OtpSending());
    final result = await _resendOtpUseCase(
      phone,
      channel: channel,
      isPasswordReset: isPasswordReset,
      registrationParams: registrationParams,
    );

    switch (result) {
      case ApiSuccess(:final data):
        if (data.isRateLimited) {
          emit(OtpRateLimited(supportPhone: data.supportPhone));
        } else if (data.success) {
          emit(
            OtpReady(
              expiresAt: data.expiresAt,
              nextResendAt: data.nextResendAt,
              isHourBlocked: data.isHourBlocked,
              attemptsLeft: data.attemptsLeft,
              maxAttempts: data.maxAttempts,
              infoMessage: data.message,
            ),
          );
        } else {
          emit(
            OtpReady(
              nextResendAt: data.nextResendAt,
              isHourBlocked: data.isHourBlocked,
              isVerifyBlocked: data.isVerifyBlocked,
              verifyBlockedUntil: data.verifyBlockedUntil,
              errorMessage: data.message ?? 'تعذر إعادة إرسال الكود',
            ),
          );
        }
      case ApiError(:final failure):
        emit(OtpError(failure.message));
    }
  }

  Future<void> verifyOtp({
    required String phone,
    required String code,
    RegisterParams? registerParams,
    bool isPasswordReset = false,
    OtpDeliveryChannel channel = OtpDeliveryChannel.whatsapp,
  }) async {
    AppLogger.authLog(
      '[OTP][OtpCubit] verifyOtp started',
      data: {
        'phone': AppLogger.maskedPhone(phone),
        'codeLength': code.length,
        'hasRegistrationParams': registerParams != null,
        'isPasswordReset': isPasswordReset,
      },
    );
    final current = state is OtpReady ? state as OtpReady : null;
    emit(const OtpVerifying());

    final verifyResult = await _verifyOtpUseCase(
      phone: phone,
      code: code,
      channel: registerParams?.otpChannel ?? channel,
      isPasswordReset: isPasswordReset,
    );

    switch (verifyResult) {
      case ApiSuccess(:final data):
        AppLogger.authLog(
          '[OTP][OtpCubit] verifyOtp ApiSuccess',
          data: {'otpSuccess': data.success, 'message': data.message},
        );
        if (data.success) {
          if (isPasswordReset) {
            emit(OtpVerifiedForPasswordReset(phone));
            return;
          }

          if (registerParams != null) {
            // Create user in Supabase Auth & DB
            final registerResult = await _registerStudentUseCase(
              registerParams,
            );
            switch (registerResult) {
              case ApiSuccess():
                emit(const OtpSuccess('تم إنشاء الحساب وتأكيده بنجاح!'));
              case ApiError(:final failure):
                emit(OtpError(failure.message));
            }
            return;
          }

          emit(OtpSuccess(data.message ?? 'تم التحقق بنجاح'));
        } else {
          emit(
            OtpReady(
              expiresAt: current?.expiresAt,
              nextResendAt: current?.nextResendAt,
              attemptsLeft: data.attemptsLeft,
              maxAttempts: current?.maxAttempts ?? 2,
              isVerifyBlocked: data.isVerifyBlocked,
              verifyBlockedUntil: data.verifyBlockedUntil,
              errorMessage: data.message ?? 'رمز التحقق غير صحيح',
            ),
          );
        }
      case ApiError(:final failure):
        AppLogger.authLog(
          '[OTP][OtpCubit] verifyOtp ApiError',
          data: {'failureType': failure.runtimeType.toString()},
          error: failure.message,
        );
        emit(
          current?.copyWith(errorMessage: failure.message) ??
              OtpError(failure.message),
        );
    }
  }
}
