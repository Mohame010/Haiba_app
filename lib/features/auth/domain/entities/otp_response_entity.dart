class OtpResponseEntity {
  final bool success;
  final String? message;
  final DateTime? expiresAt;
  final DateTime? nextResendAt;
  final int resendCount;
  final int maxResends;
  final bool isHourBlocked;
  final int attemptsLeft;
  final int maxAttempts;
  final bool isVerifyBlocked;
  final DateTime? verifyBlockedUntil;
  final bool isPhoneAlreadyRegistered;
  final bool isEmailAlreadyRegistered;
  final int? cooldownSeconds;
  final bool isRateLimited;
  final String? supportPhone;

  const OtpResponseEntity({
    this.success = false,
    this.message,
    this.expiresAt,
    this.nextResendAt,
    this.resendCount = 1,
    this.maxResends = 3,
    this.isHourBlocked = false,
    this.attemptsLeft = 2,
    this.maxAttempts = 2,
    this.isVerifyBlocked = false,
    this.verifyBlockedUntil,
    this.isPhoneAlreadyRegistered = false,
    this.isEmailAlreadyRegistered = false,
    this.cooldownSeconds,
    this.isRateLimited = false,
    this.supportPhone,
  });
}
