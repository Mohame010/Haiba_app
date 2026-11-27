import '../../../core/network/api_result.dart';
import '../entities/otp_response_entity.dart';
import '../repositories/auth_repository.dart';
import '../entities/register_params.dart';

class SendResetPasswordOtpUseCase {
  final AuthRepository _repository;

  const SendResetPasswordOtpUseCase(this._repository);

  Future<ApiResult<OtpResponseEntity>> call(
    String identifier, {
    OtpDeliveryChannel channel = OtpDeliveryChannel.whatsapp,
  }) {
    return _repository.sendResetPasswordOtp(identifier, channel: channel);
  }
}
