import '../../../core/network/api_result.dart';
import '../entities/otp_response_entity.dart';
import '../repositories/auth_repository.dart';
import '../entities/register_params.dart';

class VerifyOtpUseCase {
  final AuthRepository _repository;

  const VerifyOtpUseCase(this._repository);

  Future<ApiResult<OtpResponseEntity>> call({
    required String phone,
    required String code,
    OtpDeliveryChannel channel = OtpDeliveryChannel.whatsapp,
    bool isPasswordReset = false,
  }) {
    return _repository.verifyOtp(
      phone: phone,
      code: code,
      channel: channel,
      isPasswordReset: isPasswordReset,
    );
  }
}
