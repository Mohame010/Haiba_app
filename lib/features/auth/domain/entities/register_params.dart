enum OtpDeliveryChannel { whatsapp, sms, email }

class RegisterParams {
  final String name;
  final String phone;
  final String educationLevel;
  final String grade;
  final String password;
  final String? birthDate;
  final String? parentPhone;
  final String? email;
  final OtpDeliveryChannel otpChannel;

  const RegisterParams({
    required this.name,
    required this.phone,
    required this.educationLevel,
    required this.grade,
    required this.password,
    this.birthDate,
    this.parentPhone,
    this.email,
    this.otpChannel = OtpDeliveryChannel.whatsapp,
  });
}
