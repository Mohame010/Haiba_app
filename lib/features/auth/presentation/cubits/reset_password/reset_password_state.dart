import '../../../domain/entities/register_params.dart';

sealed class ResetPasswordState {
  const ResetPasswordState();
}

final class ResetPasswordInitial extends ResetPasswordState {
  const ResetPasswordInitial();
}

final class ResetPasswordLoading extends ResetPasswordState {
  const ResetPasswordLoading();
}

final class ResetPasswordOtpSent extends ResetPasswordState {
  final String identifier;
  final OtpDeliveryChannel channel;
  const ResetPasswordOtpSent(this.identifier, this.channel);
}

final class ResetPasswordRateLimited extends ResetPasswordState {
  final String? supportPhone;
  const ResetPasswordRateLimited({this.supportPhone});
}

final class ResetPasswordSuccess extends ResetPasswordState {
  final String message;
  const ResetPasswordSuccess(this.message);
}

final class ResetPasswordError extends ResetPasswordState {
  final String message;
  const ResetPasswordError(this.message);
}
