abstract class Failure {
  final String message;
  final int? statusCode;

  const Failure(this.message, [this.statusCode]);
}

class ServerFailure extends Failure {
  const ServerFailure(super.message, [super.statusCode]);
}

class AuthFailure extends Failure {
  const AuthFailure(super.message, [super.statusCode]);
}

class NetworkFailure extends Failure {
  const NetworkFailure([super.message = 'لا يتوفر اتصال بالإنترنت']);
}

class ValidationFailure extends Failure {
  const ValidationFailure(super.message);
}
