import '../../../core/network/api_result.dart';
import '../entities/otp_response_entity.dart';
import '../entities/register_params.dart';
import '../entities/student_profile_entity.dart';

abstract class AuthRepository {
  Future<ApiResult<StudentProfileEntity>> loginWithPhone({
    required String phone,
    required String password,
  });

  Future<ApiResult<StudentProfileEntity>> registerStudent(
    RegisterParams params,
  );

  Future<ApiResult<OtpResponseEntity>> sendOtp(
    String phone, {
    RegisterParams? registrationParams,
  });

  Future<ApiResult<OtpResponseEntity>> verifyOtp({
    required String phone,
    required String code,
    OtpDeliveryChannel channel = OtpDeliveryChannel.whatsapp,
    bool isPasswordReset = false,
  });

  Future<ApiResult<OtpResponseEntity>> resendOtp(
    String phone, {
    OtpDeliveryChannel channel = OtpDeliveryChannel.whatsapp,
    bool isPasswordReset = false,
    RegisterParams? registrationParams,
  });

  Future<ApiResult<OtpResponseEntity>> sendResetPasswordOtp(
    String identifier, {
    OtpDeliveryChannel channel = OtpDeliveryChannel.whatsapp,
  });

  Future<ApiResult<void>> resetPassword({
    required String identifier,
    required String newPassword,
    OtpDeliveryChannel channel = OtpDeliveryChannel.whatsapp,
  });

  Future<ApiResult<StudentProfileEntity>> getStudentProfile(String userId);
}
