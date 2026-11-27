import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/network/api_result.dart';
import '../../../domain/entities/register_params.dart';
import '../../../domain/usecases/reset_password_usecase.dart';
import '../../../domain/usecases/send_reset_password_otp_usecase.dart';
import 'reset_password_state.dart';

class ResetPasswordCubit extends Cubit<ResetPasswordState> {
  final SendResetPasswordOtpUseCase _sendResetPasswordOtpUseCase;
  final ResetPasswordUseCase _resetPasswordUseCase;

  ResetPasswordCubit({
    required SendResetPasswordOtpUseCase sendResetPasswordOtpUseCase,
    required ResetPasswordUseCase resetPasswordUseCase,
  }) : _sendResetPasswordOtpUseCase = sendResetPasswordOtpUseCase,
       _resetPasswordUseCase = resetPasswordUseCase,
       super(const ResetPasswordInitial());

  Future<void> sendResetOtp(
    String identifier,
    OtpDeliveryChannel channel,
  ) async {
    emit(const ResetPasswordLoading());

    final result = await _sendResetPasswordOtpUseCase(
      identifier,
      channel: channel,
    );

    switch (result) {
      case ApiSuccess(:final data):
        if (data.isRateLimited) {
          emit(ResetPasswordRateLimited(supportPhone: data.supportPhone));
        } else if (data.success) {
          emit(ResetPasswordOtpSent(identifier, channel));
        } else {
          emit(ResetPasswordError(data.message ?? 'فشل إرسال كود التحقق'));
        }
      case ApiError(:final failure):
        emit(ResetPasswordError(failure.message));
    }
  }

  Future<void> resetPassword({
    required String identifier,
    required String newPassword,
    OtpDeliveryChannel channel = OtpDeliveryChannel.whatsapp,
  }) async {
    emit(const ResetPasswordLoading());

    final result = await _resetPasswordUseCase(
      identifier: identifier,
      newPassword: newPassword,
      channel: channel,
    );

    switch (result) {
      case ApiSuccess():
        emit(const ResetPasswordSuccess('تم تغيير كلمة المرور بنجاح!'));
      case ApiError(:final failure):
        emit(ResetPasswordError(failure.message));
    }
  }
}
