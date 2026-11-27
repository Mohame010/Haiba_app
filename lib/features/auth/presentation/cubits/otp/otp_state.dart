sealed class OtpState {
  const OtpState();
}

final class OtpInitial extends OtpState {
  const OtpInitial();
}

final class OtpSending extends OtpState {
  const OtpSending();
}

final class OtpVerifying extends OtpState {
  const OtpVerifying();
}

final class OtpReady extends OtpState {
  final DateTime? expiresAt;
  final DateTime? nextResendAt;
  final bool isHourBlocked;
  final int attemptsLeft;
  final int maxAttempts;
  final bool isVerifyBlocked;
  final DateTime? verifyBlockedUntil;
  final String? errorMessage;
  final String? infoMessage;

  const OtpReady({
    this.expiresAt,
    this.nextResendAt,
    this.isHourBlocked = false,
    this.attemptsLeft = 2,
    this.maxAttempts = 2,
    this.isVerifyBlocked = false,
    this.verifyBlockedUntil,
    this.errorMessage,
    this.infoMessage,
  });

  OtpReady copyWith({
    DateTime? expiresAt,
    DateTime? nextResendAt,
    bool? isHourBlocked,
    int? attemptsLeft,
    int? maxAttempts,
    bool? isVerifyBlocked,
    DateTime? verifyBlockedUntil,
    String? errorMessage,
    String? infoMessage,
  }) {
    return OtpReady(
      expiresAt: expiresAt ?? this.expiresAt,
      nextResendAt: nextResendAt ?? this.nextResendAt,
      isHourBlocked: isHourBlocked ?? this.isHourBlocked,
      attemptsLeft: attemptsLeft ?? this.attemptsLeft,
      maxAttempts: maxAttempts ?? this.maxAttempts,
      isVerifyBlocked: isVerifyBlocked ?? this.isVerifyBlocked,
      verifyBlockedUntil: verifyBlockedUntil ?? this.verifyBlockedUntil,
      errorMessage: errorMessage,
      infoMessage: infoMessage,
    );
  }
}

final class OtpSuccess extends OtpState {
  final String message;
  const OtpSuccess(this.message);
}

final class OtpVerifiedForPasswordReset extends OtpState {
  final String phone;
  const OtpVerifiedForPasswordReset(this.phone);
}

final class OtpPhoneAlreadyRegistered extends OtpState {
  const OtpPhoneAlreadyRegistered();
}

final class OtpRateLimited extends OtpState {
  final String? supportPhone;

  const OtpRateLimited({this.supportPhone});
}

final class OtpError extends OtpState {
  final String message;
  const OtpError(this.message);
}
