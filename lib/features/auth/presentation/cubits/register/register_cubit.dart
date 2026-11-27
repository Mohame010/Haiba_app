import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/helpers/app_logger.dart';
import '../../../../core/network/api_result.dart';
import '../../../domain/entities/register_params.dart';
import '../../../domain/usecases/send_otp_usecase.dart';
import 'register_state.dart';

class RegisterCubit extends Cubit<RegisterState> {
  final SendOtpUseCase _sendOtpUseCase;

  RegisterCubit(this._sendOtpUseCase) : super(const RegisterInitial());

  void reset() => emit(const RegisterInitial());

  Future<void> submitRegistration(RegisterParams params) async {
    final maskedPhone = AppLogger.maskedPhone(params.phone);
    AppLogger.authLog(
      '[OTP][RegisterCubit] submitRegistration started',
      data: {'phone': maskedPhone},
    );
    emit(const RegisterLoading());

    final result = await _sendOtpUseCase(
      params.phone,
      registrationParams: params,
    );

    switch (result) {
      case ApiSuccess(:final data):
        AppLogger.authLog(
          '[OTP][RegisterCubit] use case returned ApiSuccess',
          data: {
            'phone': maskedPhone,
            'otpSuccess': data.success,
            'message': data.message,
            'phoneAlreadyRegistered': data.isPhoneAlreadyRegistered,
          },
        );
        if (data.isPhoneAlreadyRegistered) {
          AppLogger.authLog(
            '[OTP][RegisterCubit] emitting RegisterPhoneAlreadyRegistered',
          );
          emit(const RegisterPhoneAlreadyRegistered());
        } else if (data.isEmailAlreadyRegistered) {
          emit(RegisterEmailAlreadyRegistered(params.email ?? ''));
        } else if (data.isRateLimited) {
          emit(RegisterOtpRateLimited(supportPhone: data.supportPhone));
        } else if (data.success) {
          AppLogger.authLog('[OTP][RegisterCubit] emitting RegisterOtpSent');
          emit(RegisterOtpSent(params));
        } else {
          final message = data.message ?? 'فشل إرسال كود التحقق';
          AppLogger.authLog(
            '[OTP][RegisterCubit] emitting RegisterError from response',
            error: message,
          );
          emit(RegisterError(message));
        }
      case ApiError(:final failure):
        AppLogger.authLog(
          '[OTP][RegisterCubit] emitting RegisterError from ApiError',
          data: {'failureType': failure.runtimeType.toString()},
          error: failure.message,
        );
        emit(RegisterError(failure.message));
    }
  }
}
