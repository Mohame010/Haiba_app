import '../../../core/network/api_result.dart';
import '../entities/register_params.dart';
import '../repositories/auth_repository.dart';

class ResetPasswordUseCase {
  final AuthRepository _repository;

  const ResetPasswordUseCase(this._repository);

  Future<ApiResult<void>> call({
    required String identifier,
    required String newPassword,
    OtpDeliveryChannel channel = OtpDeliveryChannel.whatsapp,
  }) {
    return _repository.resetPassword(
      identifier: identifier,
      newPassword: newPassword,
      channel: channel,
    );
  }
}
