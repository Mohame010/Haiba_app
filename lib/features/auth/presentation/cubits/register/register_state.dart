import '../../../domain/entities/register_params.dart';

sealed class RegisterState {
  const RegisterState();
}

final class RegisterInitial extends RegisterState {
  const RegisterInitial();
}

final class RegisterLoading extends RegisterState {
  const RegisterLoading();
}

final class RegisterOtpSent extends RegisterState {
  final RegisterParams params;
  const RegisterOtpSent(this.params);
}

final class RegisterPhoneAlreadyRegistered extends RegisterState {
  const RegisterPhoneAlreadyRegistered();
}

final class RegisterEmailAlreadyRegistered extends RegisterState {
  final String email;
  const RegisterEmailAlreadyRegistered(this.email);
}

final class RegisterOtpRateLimited extends RegisterState {
  final String? supportPhone;

  const RegisterOtpRateLimited({this.supportPhone});
}

final class RegisterError extends RegisterState {
  final String message;
  const RegisterError(this.message);
}
