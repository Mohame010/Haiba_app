import '../../../core/network/api_result.dart';
import '../entities/student_profile_entity.dart';
import '../repositories/auth_repository.dart';

class LoginWithPhoneUseCase {
  final AuthRepository _repository;

  const LoginWithPhoneUseCase(this._repository);

  Future<ApiResult<StudentProfileEntity>> call({
    required String phone,
    required String password,
  }) {
    return _repository.loginWithPhone(phone: phone, password: password);
  }
}
