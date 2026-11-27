import '../../../core/network/api_result.dart';
import '../entities/otp_response_entity.dart';
import '../repositories/auth_repository.dart';
import '../entities/register_params.dart';

class ResendOtpUseCase {
  final AuthRepository _repository;

  const ResendOtpUseCase(this._repository);

  Future<ApiResult<OtpResponseEntity>> call(
    String phone, {
    OtpDeliveryChannel channel = OtpDeliveryChannel.whatsapp,
    bool isPasswordReset = false,
    RegisterParams? registrationParams,
  }) {
    return _repository.resendOtp(
      phone,
      channel: channel,
      isPasswordReset: isPasswordReset,
      registrationParams: registrationParams,
    );
  }
}
