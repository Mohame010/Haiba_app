import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/errors/error_handler.dart';
import '../../../core/helpers/app_logger.dart';
import '../../domain/entities/register_params.dart';
import '../models/otp_response_model.dart';
import '../models/student_profile_model.dart';

abstract class AuthRemoteDataSource {
  User? get currentUser;

  Future<StudentProfileModel> loginWithPhone({
    required String phone,
    required String password,
  });

  Future<StudentProfileModel> registerStudent(RegisterParams params);

  Future<OtpResponseModel> sendOtp(
    String phone, {
    RegisterParams? registrationParams,
  });

  Future<OtpResponseModel> verifyOtp({
    required String phone,
    required String code,
    OtpDeliveryChannel channel = OtpDeliveryChannel.whatsapp,
    bool isPasswordReset = false,
  });

  Future<OtpResponseModel> resendOtp(
    String phone, {
    OtpDeliveryChannel channel = OtpDeliveryChannel.whatsapp,
    bool isPasswordReset = false,
    RegisterParams? registrationParams,
  });

  Future<OtpResponseModel> sendResetPasswordOtp(
    String identifier, {
    OtpDeliveryChannel channel = OtpDeliveryChannel.whatsapp,
  });

  Future<void> resetPassword({
    required String identifier,
    required String newPassword,
    OtpDeliveryChannel channel = OtpDeliveryChannel.whatsapp,
  });

  Future<StudentProfileModel> getStudentProfile(String userId);

  Future<void> signOut();
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final SupabaseClient _supabaseClient;

  AuthRemoteDataSourceImpl(this._supabaseClient);

  @override
  User? get currentUser => _supabaseClient.auth.currentUser;

  /// Helper to convert user phone into international E.164 format
  static String formatPhone(String phone) {
    final digits = phone.trim().replaceAll(RegExp(r'[^\d]'), '');
    if (phone.trim().startsWith('+')) {
      return '+$digits';
    }
    if (digits.startsWith('0')) {
      return '+2$digits';
    }
    return '+20$digits';
  }

  /// Helper to convert user phone into email format fallback
  static String phoneToEmail(String phone) {
    final digits = phone.trim().replaceAll(RegExp(r'[^\d]'), '');
    return '$digits@qimma.com';
  }

  Future<OtpResponseModel> _invokeStudentOtp({
    required String action,
    required String phone,
    String? password,
    Map<String, dynamic>? data,
    OtpDeliveryChannel channel = OtpDeliveryChannel.whatsapp,
  }) async {
    final response = await _supabaseClient.functions.invoke(
      'send-student-otp',
      body: {
        'action': action,
        'phone': phone,
        'password': ?password,
        'data': ?data,
        'channel': channel.name,
      },
    );
    if (response.data is! Map) {
      throw StateError('Invalid send-student-otp response');
    }
    return OtpResponseModel.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<OtpResponseModel> _invokeEmailOtp({
    required String action,
    required String email,
    String? password,
    String? code,
    String? purpose,
    Map<String, dynamic>? data,
  }) async {
    try {
      final response = await _supabaseClient.functions.invoke(
        'send-email-otp',
        body: {
          'action': action,
          'email': email,
          'password': ?password,
          'code': ?code,
          'purpose': ?purpose,
          'data': ?data,
        },
      );
      if (response.data is! Map) {
        throw StateError('Invalid send-email-otp response');
      }
      return OtpResponseModel.fromJson(
        Map<String, dynamic>.from(response.data as Map),
      );
    } on FunctionException catch (e, stackTrace) {
      AppLogger.authLog(
        '[OTP][DataSource] email OTP FunctionException',
        data: {'action': action, 'status': e.status, 'details': e.details},
        error: e.reasonPhrase,
        stackTrace: stackTrace,
      );

      final details = e.details;
      if (details is Map) {
        return OtpResponseModel.fromJson(Map<String, dynamic>.from(details));
      }

      return OtpResponseModel(
        success: false,
        message: e.status == 0
            ? 'تعذر الاتصال بخدمة البريد. تحقق من الإنترنت وحاول مرة أخرى.'
            : 'تعذر إرسال رمز التحقق إلى البريد الإلكتروني. حاول مرة أخرى لاحقًا.',
      );
    }
  }

  Future<User> _completeVerifiedPhoneSignup({
    required String phone,
    required String password,
    required Map<String, dynamic> metadata,
  }) async {
    final response = await _supabaseClient.functions.invoke(
      'complete-phone-signup',
      body: {'phone': phone, 'password': password, 'data': metadata},
    );
    final responseData = response.data is Map
        ? Map<String, dynamic>.from(response.data as Map)
        : <String, dynamic>{};
    if (responseData['success'] != true) {
      throw AuthException(
        responseData['message'] as String? ??
            'تعذر إنشاء الحساب بعد التحقق من الرمز',
      );
    }
    final loginResponse = await _supabaseClient.auth.signInWithPassword(
      phone: phone,
      password: password,
    );
    final user = loginResponse.user;
    if (user == null) {
      throw const AuthException('تعذر بدء جلسة الحساب الجديد');
    }
    return user;
  }

  @override
  Future<StudentProfileModel> loginWithPhone({
    required String phone,
    required String password,
  }) async {
    final cleanPhone = phone.trim().replaceAll(RegExp(r'\s+'), '');
    final isEmail = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(cleanPhone);
    if (isEmail) {
      try {
        final authResponse = await _supabaseClient.auth.signInWithPassword(
          email: cleanPhone.toLowerCase(),
          password: password,
        );
        final user = authResponse.user;
        if (user == null) {
          throw const AuthException(
            'البريد الإلكتروني أو كلمة المرور غير صحيحة',
          );
        }
        AppLogger.authLog(
          'Supabase email sign in successful',
          data: {'userId': user.id, 'email': user.email},
        );
        return await getStudentProfile(user.id);
      } on AuthException catch (e) {
        final arabicMessage = ErrorHandler.mapAuthErrorMessage(e.message);
        throw AuthException(arabicMessage, statusCode: e.statusCode);
      }
    }
    final formattedPhone = formatPhone(cleanPhone);
    final email = phoneToEmail(cleanPhone);

    AppLogger.authLog(
      'Signing in via Supabase Auth',
      data: {'phone': phone, 'formattedPhone': formattedPhone, 'email': email},
    );

    try {
      AuthResponse authResponse;

      try {
        // Attempt native Supabase phone sign-in first
        authResponse = await _supabaseClient.auth.signInWithPassword(
          phone: formattedPhone,
          password: password,
        );
      } on AuthException catch (e) {
        // Fallback to email format if phone login provider is disabled in Supabase dashboard
        if (e.code == 'phone_provider_disabled' ||
            e.message.toLowerCase().contains('phone logins are disabled') ||
            e.message.toLowerCase().contains('invalid phone')) {
          authResponse = await _supabaseClient.auth.signInWithPassword(
            email: email,
            password: password,
          );
        } else {
          rethrow;
        }
      }

      final user = authResponse.user;
      if (user == null) {
        throw const AuthException('رقم الهاتف أو كلمة المرور غير صحيحة');
      }

      AppLogger.authLog(
        'Supabase sign in successful',
        data: {'userId': user.id, 'email': user.email},
      );

      return await getStudentProfile(user.id);
    } on AuthException catch (e) {
      final arabicMessage = ErrorHandler.mapAuthErrorMessage(e.message);
      AppLogger.authLog('Supabase AuthException', error: e.message);
      throw AuthException(arabicMessage, statusCode: e.statusCode);
    } catch (e) {
      AppLogger.authLog('Supabase Sign In error', error: e.toString());
      rethrow;
    }
  }

  @override
  Future<StudentProfileModel> registerStudent(RegisterParams params) async {
    final cleanPhone = params.phone.trim().replaceAll(RegExp(r'\s+'), '');
    final formattedPhone = formatPhone(cleanPhone);
    final email = params.otpChannel == OtpDeliveryChannel.email
        ? (params.email?.trim().toLowerCase() ?? phoneToEmail(cleanPhone))
        : phoneToEmail(cleanPhone);

    AppLogger.authLog(
      'Signing up via Supabase Auth',
      data: {
        'name': params.name,
        'phone': params.phone,
        'formattedPhone': formattedPhone,
        'email': email,
        'stage': params.educationLevel,
        'grade': params.grade,
      },
    );

    try {
      final metadata = {
        'name': params.name,
        'phone': params.phone,
        'education_level': params.educationLevel,
        'grade': params.grade,
        if (params.birthDate != null && params.birthDate!.isNotEmpty)
          'birth_date': params.birthDate,
        'points': 0,
        if (params.parentPhone != null && params.parentPhone!.isNotEmpty)
          'parent_phone': params.parentPhone,
        'status': 'active',
        if (params.email != null && params.email!.isNotEmpty)
          'email': params.email!.trim().toLowerCase(),
      };

      if (params.otpChannel == OtpDeliveryChannel.email &&
          _supabaseClient.auth.currentUser == null) {
        final registrationEmail = params.email?.trim().toLowerCase();
        if (registrationEmail == null || registrationEmail.isEmpty) {
          throw const AuthException('البريد الإلكتروني مطلوب لإكمال التسجيل');
        }
        final response = await _supabaseClient.functions.invoke(
          'complete-email-signup',
          body: {
            'email': registrationEmail,
            'password': params.password,
            'data': metadata,
          },
        );
        final responseData = response.data is Map
            ? Map<String, dynamic>.from(response.data as Map)
            : <String, dynamic>{};
        if (responseData['success'] != true) {
          // If already registered from an earlier interrupted step, try logging in
          if (responseData['email_registered'] == true) {
            await _supabaseClient.auth.signInWithPassword(
              email: registrationEmail,
              password: params.password,
            );
          } else {
            throw AuthException(
              responseData['message'] as String? ?? 'تعذر إنشاء الحساب',
            );
          }
        } else {
          await _supabaseClient.auth.signInWithPassword(
            email: registrationEmail,
            password: params.password,
          );
        }
      }

      // Verifying a phone OTP creates an authenticated Supabase session. In
      // that case the Auth user already exists, so finish registration by
      // setting the password/metadata instead of trying to sign up again.
      final otpUser = _supabaseClient.auth.currentUser;
      final isPhoneVerified = otpUser?.phone == formattedPhone;
      final isEmailVerified =
          params.otpChannel == OtpDeliveryChannel.email &&
          otpUser?.email?.toLowerCase() == email;
      if (otpUser != null && (isPhoneVerified || isEmailVerified)) {
        var user = otpUser;
        if (isPhoneVerified) {
          try {
            final updatedUser = await _supabaseClient.auth.updateUser(
              UserAttributes(password: params.password, data: metadata),
            );
            user = updatedUser.user ?? otpUser;
          } on AuthException catch (updateErr) {
            if (!updateErr.message.toLowerCase().contains(
              'different from the old password',
            )) {
              rethrow;
            }
          }
        } else if (isEmailVerified) {
          // For email signup, complete-email-signup already set the password and metadata.
          // Do not send password here to prevent 'New password should be different from the old password'.
          try {
            final updatedUser = await _supabaseClient.auth.updateUser(
              UserAttributes(data: metadata),
            );
            user = updatedUser.user ?? otpUser;
          } catch (_) {}
        }
        AppLogger.authLog(
          'Completing OTP-verified registration user',
          data: {'userId': user.id, 'phone': formattedPhone},
        );

        final randomSuffix =
            (DateTime.now().millisecondsSinceEpoch % 900000) + 100000;
        final studentData = {
          'id': user.id,
          'name': params.name,
          'phone': params.phone,
          'education_level': params.educationLevel,
          'grade': params.grade,
          'birth_date':
              (params.birthDate != null && params.birthDate!.isNotEmpty)
              ? params.birthDate
              : null,
          'points': 0,
          'student_code': 'STD-$randomSuffix',
          if (params.parentPhone != null && params.parentPhone!.isNotEmpty)
            'parent_phone': params.parentPhone,
          'status': 'active',
          'teacher_id': AppConstants.activeTeacherId,
          'updated_at': DateTime.now().toIso8601String(),
        };

        final savedStudent = await _supabaseClient
            .from('students')
            .upsert(studentData)
            .select()
            .single();
        return StudentProfileModel.fromJson(savedStudent);
      }

      if (params.otpChannel == OtpDeliveryChannel.email) {
        throw const AuthException('تعذر بدء جلسة الحساب بعد التحقق من البريد');
      }
      final user = await _completeVerifiedPhoneSignup(
        phone: formattedPhone,
        password: params.password,
        metadata: metadata,
      );
      AppLogger.authLog(
        'Verified phone registration completed',
        data: {'userId': user.id, 'phone': formattedPhone},
      );

      final randomSuffix =
          (DateTime.now().millisecondsSinceEpoch % 900000) + 100000;
      final generatedCode = 'STD-$randomSuffix';

      // Insert/upsert into public.students table matching exact schema
      final studentData = {
        'id': user.id,
        'name': params.name,
        'phone': params.phone,
        'education_level': params.educationLevel,
        'grade': params.grade,
        'birth_date': (params.birthDate != null && params.birthDate!.isNotEmpty)
            ? params.birthDate
            : null,
        'points': 0,
        'student_code': generatedCode,
        if (params.parentPhone != null && params.parentPhone!.isNotEmpty)
          'parent_phone': params.parentPhone,
        'status': 'active',
        'teacher_id': AppConstants.activeTeacherId,
        'updated_at': DateTime.now().toIso8601String(),
      };

      try {
        final insertResult = await _supabaseClient
            .from('students')
            .upsert(studentData)
            .select()
            .maybeSingle();

        if (insertResult != null) {
          AppLogger.authLog(
            'Student profile saved to public.students table',
            data: insertResult,
          );
          return StudentProfileModel.fromJson(insertResult);
        }
      } catch (dbError) {
        AppLogger.authLog('Failed to upsert in students table', error: dbError);
      }

      return await getStudentProfile(user.id);
    } on AuthException catch (e) {
      AppLogger.authLog(
        'Supabase AuthException during signUp',
        error: e.message,
      );

      // If user already exists, sign in and ensure student record exists
      if (e.message.toLowerCase().contains('already') ||
          e.message.toLowerCase().contains('exists')) {
        try {
          return await loginWithPhone(
            phone: params.phone,
            password: params.password,
          );
        } catch (signInErr) {
          AppLogger.authLog('Sign in fallback failed', error: signInErr);
        }
      }

      final arabicMessage = ErrorHandler.mapAuthErrorMessage(e.message);
      throw AuthException(arabicMessage, statusCode: e.statusCode);
    } catch (e) {
      AppLogger.authLog('Supabase SignUp error', error: e.toString());
      rethrow;
    }
  }

  @override
  Future<OtpResponseModel> sendOtp(
    String phone, {
    RegisterParams? registrationParams,
  }) async {
    if (registrationParams != null) {
      if (registrationParams.otpChannel == OtpDeliveryChannel.email) {
        return _startEmailRegistration(registrationParams);
      }
      final formattedPhone = formatPhone(phone);
      return _startPhoneRegistration(
        formattedPhone: formattedPhone,
        params: registrationParams,
      );
    }
    final formattedPhone = formatPhone(phone);
    return _requestPhoneOtp(formattedPhone);
  }

  Future<OtpResponseModel> _startEmailRegistration(
    RegisterParams params,
  ) async {
    final email = params.email?.trim().toLowerCase();
    if (email == null || email.isEmpty) {
      return const OtpResponseModel(
        success: false,
        message: 'يرجى إدخال البريد الإلكتروني',
      );
    }
    try {
      return await _invokeEmailOtp(
        action: 'signup',
        email: email,
        password: params.password,
        data: {
          'name': params.name,
          'phone': params.phone,
          'education_level': params.educationLevel,
          'grade': params.grade,
        },
      );
    } on FunctionException catch (e) {
      return OtpResponseModel(
        success: false,
        message: e.status == 429
            ? 'محاولات كثيرة، يرجى الانتظار قليلًا'
            : 'تعذر إرسال رمز التحقق إلى البريد الإلكتروني. حاول مرة أخرى لاحقًا.',
      );
    } catch (_) {
      return const OtpResponseModel(
        success: false,
        message: 'حدث خطأ، جرّب استخدام طريقة إرسال أخرى',
      );
    }
  }

  Future<OtpResponseModel> _startPhoneRegistration({
    required String formattedPhone,
    required RegisterParams params,
  }) async {
    final maskedPhone = AppLogger.maskedPhone(formattedPhone);
    try {
      AppLogger.authLog(
        '[OTP][DataSource] phone is new; requesting server-guarded signup OTP',
        data: {'phone': maskedPhone},
      );
      final response = await _invokeStudentOtp(
        action: 'signup',
        phone: formattedPhone,
        password: params.password,
        data: {
          'name': params.name,
          'phone': params.phone,
          'education_level': params.educationLevel,
          'grade': params.grade,
          if (params.birthDate != null && params.birthDate!.isNotEmpty)
            'birth_date': params.birthDate,
          if (params.parentPhone != null && params.parentPhone!.isNotEmpty)
            'parent_phone': params.parentPhone,
          'points': 0,
          'status': 'active',
        },
        channel: params.otpChannel,
      );
      if (!response.success) return response;
      AppLogger.authLog(
        '[OTP][DataSource] server accepted signup OTP request',
        data: {'phone': maskedPhone},
      );
      return response;
    } on FunctionException catch (e) {
      AppLogger.authLog(
        '[OTP][DataSource] guarded signup OTP FunctionException',
        data: {'phone': maskedPhone, 'status': e.status, 'details': e.details},
        error: e.reasonPhrase,
      );
      return OtpResponseModel(
        success: false,
        message: e.status == 429
            ? 'محاولات كثيرة، يرجى الانتظار قليلًا ثم المحاولة'
            : 'حدث خطأ، جرّب إرسال الرمز بطريقة أخرى أو على رقم هاتف آخر',
      );
    } on AuthException catch (e) {
      final isExistingPhone =
          e.code == 'user_already_exists' ||
          e.code == 'phone_exists' ||
          e.message.toLowerCase().contains('already registered') ||
          e.message.toLowerCase().contains('already exists');
      AppLogger.authLog(
        '[OTP][DataSource] phone signup AuthException',
        data: {
          'phone': maskedPhone,
          'code': e.code,
          'status': e.statusCode,
          'isExistingPhone': isExistingPhone,
        },
        error: e.message,
      );
      if (isExistingPhone) {
        return const OtpResponseModel(
          success: false,
          isPhoneAlreadyRegistered: true,
          message: 'رقم الهاتف مسجل بالفعل، يمكنك تسجيل الدخول',
        );
      }
      return OtpResponseModel(
        success: false,
        message: ErrorHandler.mapAuthErrorMessage(e.message),
      );
    } catch (e, stackTrace) {
      AppLogger.authLog(
        '[OTP][DataSource] phone signup unexpected error',
        data: {'phone': maskedPhone, 'type': e.runtimeType.toString()},
        error: e,
        stackTrace: stackTrace,
      );
      return const OtpResponseModel(
        success: false,
        message: 'تعذر بدء إنشاء الحساب، يرجى المحاولة مرة أخرى',
      );
    }
  }

  Future<OtpResponseModel> _requestPhoneOtp(
    String formattedPhone, {
    OtpDeliveryChannel channel = OtpDeliveryChannel.whatsapp,
    String action = 'otp',
  }) async {
    final maskedPhone = AppLogger.maskedPhone(formattedPhone);
    AppLogger.authLog(
      '[OTP][DataSource] requesting WhatsApp OTP through guarded endpoint',
      data: {'phone': maskedPhone},
    );

    try {
      final response = await _invokeStudentOtp(
        action: action,
        phone: formattedPhone,
        channel: channel,
      );
      AppLogger.authLog(
        '[OTP][DataSource] guarded OTP response received',
        data: {
          'phone': maskedPhone,
          'success': response.success,
          'isRateLimited': response.isRateLimited,
        },
      );
      return response;
    } on FunctionException catch (e) {
      return OtpResponseModel(
        success: false,
        message: e.status == 404 && action == 'reset'
            ? 'لا يوجد حساب مرتبط بهذا الرقم. استخدم رقمًا آخر أو جرّب البريد الإلكتروني.'
            : e.status == 429
            ? 'محاولات كثيرة، يرجى الانتظار قليلًا'
            : 'حدث خطأ، جرّب إرسال الرمز بطريقة أخرى أو على رقم هاتف آخر',
      );
    } on AuthException catch (e) {
      final message = ErrorHandler.mapAuthErrorMessage(e.message);
      // AppLogger.authLog(
      //   '[OTP][DataSource] sendOtp AuthException',
      //   data: {
      //     'phone': maskedPhone,
      //     'code': e.code,
      //     'status': e.statusCode,
      //     'mappedMessage': message,
      //   },
      //   error: e.message,
      // );

      AppLogger.log(message);
      AppLogger.log(e.statusCode.toString());
      return OtpResponseModel(success: false, message: message);
    } catch (e, stackTrace) {
      AppLogger.authLog(
        '[OTP][DataSource] sendOtp unexpected error',
        // data: {'phone': maskedPhone, 'type': e.runtimeType.toString()},
        error: e,
        stackTrace: stackTrace,
      );
      return const OtpResponseModel(
        success: false,
        message: 'حدث خطأ، جرّب إرسال الرمز بطريقة أخرى أو على رقم هاتف آخر',
      );
    }
  }

  @override
  Future<OtpResponseModel> verifyOtp({
    required String phone,
    required String code,
    OtpDeliveryChannel channel = OtpDeliveryChannel.whatsapp,
    bool isPasswordReset = false,
  }) async {
    final formattedPhone = formatPhone(phone);
    final maskedPhone = AppLogger.maskedPhone(formattedPhone);
    AppLogger.authLog(
      '[OTP][DataSource] verifying OTP through guarded endpoint',
      data: {'phone': maskedPhone, 'codeLength': code.length},
    );

    try {
      if (channel == OtpDeliveryChannel.email) {
        return await _invokeEmailOtp(
          action: 'verify',
          email: phone.trim().toLowerCase(),
          code: code,
          purpose: isPasswordReset ? 'reset' : 'signup',
        );
      }

      if (channel == OtpDeliveryChannel.sms) {
        final response = await _invokeStudentOtp(
          action: 'verify-sms',
          phone: formattedPhone,
          data: {'code': code, 'purpose': isPasswordReset ? 'reset' : 'signup'},
          channel: channel,
        );
        return response;
      }

      return await _invokeStudentOtp(
        action: 'verify-whatsapp',
        phone: formattedPhone,
        data: {'code': code, 'purpose': isPasswordReset ? 'reset' : 'signup'},
        channel: channel,
      );
    } on AuthException catch (e) {
      final message = ErrorHandler.mapAuthErrorMessage(e.message);
      AppLogger.authLog(
        '[OTP][DataSource] verifyOtp AuthException',
        data: {
          'phone': maskedPhone,
          'code': e.code,
          'status': e.statusCode,
          'mappedMessage': message,
        },
        error: e.message,
      );
      return OtpResponseModel(success: false, message: message);
    } catch (e, stackTrace) {
      AppLogger.authLog(
        '[OTP][DataSource] verifyOtp unexpected error',
        data: {'phone': maskedPhone, 'type': e.runtimeType.toString()},
        error: e,
        stackTrace: stackTrace,
      );
      return const OtpResponseModel(
        success: false,
        message: 'حدث خطأ أثناء التحقق من الكود',
      );
    }
  }

  @override
  Future<OtpResponseModel> resendOtp(
    String phone, {
    OtpDeliveryChannel channel = OtpDeliveryChannel.whatsapp,
    bool isPasswordReset = false,
    RegisterParams? registrationParams,
  }) async {
    if (channel == OtpDeliveryChannel.email) {
      final email = registrationParams?.email ?? phone;
      return _invokeEmailOtp(
        action: isPasswordReset ? 'reset' : 'signup',
        email: email.trim().toLowerCase(),
        password: registrationParams?.password,
        data: registrationParams == null
            ? null
            : {
                'phone': registrationParams.phone,
                'name': registrationParams.name,
              },
      );
    }
    final formattedPhone = formatPhone(phone);
    final maskedPhone = AppLogger.maskedPhone(formattedPhone);
    AppLogger.authLog(
      '[OTP][DataSource] resending OTP through guarded endpoint',
      data: {'phone': maskedPhone},
    );
    try {
      final response = await _invokeStudentOtp(
        action: 'resend',
        phone: formattedPhone,
        data: {'purpose': isPasswordReset ? 'reset' : 'signup'},
        channel: channel,
      );
      if (!response.success) return response;
      AppLogger.authLog(
        '[OTP][DataSource] guarded resend request accepted',
        data: {'phone': maskedPhone},
      );
      return response;
    } on AuthException catch (e) {
      final message = ErrorHandler.mapAuthErrorMessage(e.message);
      AppLogger.authLog(
        '[OTP][DataSource] resendOtp AuthException',
        data: {
          'phone': maskedPhone,
          'code': e.code,
          'status': e.statusCode,
          'mappedMessage': message,
        },
        error: e.message,
      );
      return OtpResponseModel(success: false, message: message);
    } catch (e, stackTrace) {
      AppLogger.authLog(
        '[OTP][DataSource] resendOtp unexpected error',
        data: {'phone': maskedPhone, 'type': e.runtimeType.toString()},
        error: e,
        stackTrace: stackTrace,
      );
      return const OtpResponseModel(
        success: false,
        message: 'تعذر إعادة إرسال كود التحقق',
      );
    }
  }

  @override
  Future<OtpResponseModel> sendResetPasswordOtp(
    String identifier, {
    OtpDeliveryChannel channel = OtpDeliveryChannel.whatsapp,
  }) async {
    if (channel == OtpDeliveryChannel.email) {
      try {
        return await _invokeEmailOtp(
          action: 'reset',
          email: identifier.trim().toLowerCase(),
        );
      } on FunctionException catch (e) {
        return OtpResponseModel(
          success: false,
          message: e.status == 404
              ? 'لا يوجد حساب مرتبط بهذا البريد الإلكتروني. استخدم بريدًا آخر أو جرّب رقم الهاتف.'
              : e.status == 429
              ? 'محاولات كثيرة، يرجى الانتظار قليلًا'
              : 'حدث خطأ، جرّب إرسال الرمز على رقم الهاتف',
        );
      } catch (_) {
        return const OtpResponseModel(
          success: false,
          message: 'حدث خطأ، جرّب استخدام طريقة إرسال أخرى',
        );
      }
    }
    return _requestPhoneOtp(
      formatPhone(identifier),
      channel: channel,
      action: 'reset',
    );
  }

  @override
  Future<void> resetPassword({
    required String identifier,
    required String newPassword,
    OtpDeliveryChannel channel = OtpDeliveryChannel.whatsapp,
  }) async {
    final email = channel == OtpDeliveryChannel.email
        ? identifier.trim().toLowerCase()
        : phoneToEmail(identifier);
    AppLogger.authLog(
      'Resetting password via Supabase Auth',
      data: {'identifier': identifier, 'email': email},
    );

    try {
      // 1. If currently signed in, use updateUser directly
      if (_supabaseClient.auth.currentUser != null) {
        await _supabaseClient.auth.updateUser(
          UserAttributes(password: newPassword),
        );
        AppLogger.authLog('Password updated for current session');
        return;
      }

      // 2. Invoke reset-password edge function
      await _supabaseClient.functions.invoke(
        'reset-password',
        body: {'phone': identifier, 'email': email, 'password': newPassword},
      );
      AppLogger.authLog('Password reset via Supabase Edge Function completed');
    } on AuthException catch (e) {
      final arabicMessage = ErrorHandler.mapAuthErrorMessage(e.message);
      AppLogger.authLog('Password reset AuthException', error: e.message);
      throw AuthException(arabicMessage, statusCode: e.statusCode);
    } catch (e) {
      AppLogger.authLog('Password reset error', error: e.toString());
      throw const AuthException(
        'فشل تعيين كلمة المرور الجديدة، يرجى المحاولة لاحقاً',
      );
    }
  }

  @override
  Future<StudentProfileModel> getStudentProfile(String userId) async {
    AppLogger.authLog(
      'Fetching profile from public.students',
      data: {'userId': userId},
    );
    final data = await _supabaseClient
        .from('students')
        .select()
        .eq('id', userId)
        .maybeSingle();

    if (data == null) {
      // Check if user is authenticated in current session and recover basic student profile
      final user = _supabaseClient.auth.currentUser;
      if (user != null && user.id == userId) {
        final meta = user.userMetadata ?? {};
        final fallbackStudent = {
          'id': userId,
          'name': meta['name'] as String? ?? 'طالب جديد',
          'phone': user.phone ?? meta['phone'] as String? ?? '',
          'education_level': meta['education_level'] as String? ?? 'ثانوي',
          'grade': meta['grade'] as String? ?? 'الصف الأول الثانوي',
          'birth_date': meta['birth_date'] as String?,
          'points': (meta['points'] as num?)?.toInt() ?? 0,
          'student_code':
              'STD-${(DateTime.now().millisecondsSinceEpoch % 900000) + 100000}',
          'parent_phone': meta['parent_phone'] as String?,
          'status': 'active',
          'teacher_id': AppConstants.activeTeacherId,
          'updated_at': DateTime.now().toIso8601String(),
        };

        try {
          final inserted = await _supabaseClient
              .from('students')
              .upsert(fallbackStudent)
              .select()
              .maybeSingle();
          if (inserted != null) {
            return StudentProfileModel.fromJson(inserted);
          }
        } catch (dbErr) {
          AppLogger.authLog('Student recovery upsert failed', error: dbErr);
        }

        return StudentProfileModel.fromJson(fallbackStudent);
      }

      throw const AuthException(
        'لم يتم العثور على بيانات الطالب في قاعدة البيانات',
      );
    }

    AppLogger.authLog('Profile fetched from Supabase', data: data);
    return StudentProfileModel.fromJson(data);
  }

  @override
  Future<void> signOut() async {
    AppLogger.authLog('Signing out from Supabase Auth');
    await _supabaseClient.auth.signOut();
  }
}
