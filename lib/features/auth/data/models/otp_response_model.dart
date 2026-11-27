import '../../domain/entities/otp_response_entity.dart';

class OtpResponseModel {
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

  const OtpResponseModel({
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

  factory OtpResponseModel.fromJson(Map<String, dynamic> json) {
    return OtpResponseModel(
      success: json['success'] == true,
      message: json['message'] as String?,
      expiresAt: DateTime.tryParse(json['expires_at']?.toString() ?? ''),
      nextResendAt: DateTime.tryParse(json['next_resend_at']?.toString() ?? ''),
      resendCount: (json['resend_count'] as num?)?.toInt() ?? 1,
      maxResends: (json['max_resends'] as num?)?.toInt() ?? 3,
      isHourBlocked: json['is_hour_blocked'] == true,
      attemptsLeft: (json['attempts_left'] as num?)?.toInt() ?? 2,
      maxAttempts: (json['max_attempts'] as num?)?.toInt() ?? 2,
      isVerifyBlocked:
          json['is_blocked'] == true || json['is_verify_blocked'] == true,
      verifyBlockedUntil: DateTime.tryParse(
        json['blocked_until']?.toString() ?? '',
      ),
      isPhoneAlreadyRegistered: json['phone_registered'] == true,
      isEmailAlreadyRegistered: json['email_registered'] == true,
      cooldownSeconds: (json['cooldown_seconds'] as num?)?.toInt(),
      isRateLimited: json['is_rate_limited'] == true,
      supportPhone: json['support_phone'] as String?,
    );
  }

  OtpResponseEntity toEntity() {
    return OtpResponseEntity(
      success: success,
      message: message,
      expiresAt: expiresAt,
      nextResendAt: nextResendAt,
      resendCount: resendCount,
      maxResends: maxResends,
      isHourBlocked: isHourBlocked,
      attemptsLeft: attemptsLeft,
      maxAttempts: maxAttempts,
      isVerifyBlocked: isVerifyBlocked,
      verifyBlockedUntil: verifyBlockedUntil,
      isPhoneAlreadyRegistered: isPhoneAlreadyRegistered,
      isEmailAlreadyRegistered: isEmailAlreadyRegistered,
      cooldownSeconds: cooldownSeconds,
      isRateLimited: isRateLimited,
      supportPhone: supportPhone,
    );
  }
}
