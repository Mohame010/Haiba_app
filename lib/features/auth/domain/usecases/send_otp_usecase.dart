import '../../../core/network/api_result.dart';
import '../entities/otp_response_entity.dart';
import '../entities/register_params.dart';
import '../repositories/auth_repository.dart';

class SendOtpUseCase {
  final AuthRepository _repository;

  const SendOtpUseCase(this._repository);

  Future<ApiResult<OtpResponseEntity>> call(
    String phone, {
    RegisterParams? registrationParams,
  }) {
    return _repository.sendOtp(phone, registrationParams: registrationParams);
  }
}
