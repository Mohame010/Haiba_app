import '../../../core/network/api_result.dart';
import '../entities/register_params.dart';
import '../entities/student_profile_entity.dart';
import '../repositories/auth_repository.dart';

class RegisterStudentUseCase {
  final AuthRepository _repository;

  const RegisterStudentUseCase(this._repository);

  Future<ApiResult<StudentProfileEntity>> call(RegisterParams params) {
    return _repository.registerStudent(params);
  }
}
