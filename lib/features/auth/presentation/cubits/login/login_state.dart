import '../../../domain/entities/student_profile_entity.dart';

sealed class LoginState {
  const LoginState();
}

final class LoginInitial extends LoginState {
  const LoginInitial();
}

final class LoginLoading extends LoginState {
  const LoginLoading();
}

final class LoginSuccess extends LoginState {
  final StudentProfileEntity studentProfile;
  const LoginSuccess(this.studentProfile);
}

final class LoginError extends LoginState {
  final String message;
  const LoginError(this.message);
}
