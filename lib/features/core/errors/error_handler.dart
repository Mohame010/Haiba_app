class ErrorHandler {
  const ErrorHandler._();

  static String mapAuthErrorMessage(String rawMessage) {
    final lower = rawMessage.toLowerCase();

    if (lower.contains('invalid login credentials') ||
        lower.contains('invalid_credentials') ||
        lower.contains('invalid_grant')) {
      return 'رقم الهاتف أو كلمة المرور غير صحيحة';
    }

    if (lower.contains('user already registered') ||
        lower.contains('email already exists') ||
        lower.contains('already_exists')) {
      return 'هذا الرقم مسجل بالفعل في التطبيق، يمكنك تسجيل الدخول مباشرة';
    }

    if (lower.contains('password should be at least') ||
        lower.contains('weak_password')) {
      return 'كلمة المرور يجب ألا تقل عن 6 أحرف أو أرقام';
    }

    if (lower.contains('different from the old password')) {
      return 'كلمة المرور الجديدة يجب أن تكون مختلفة عن كلمة المرور السابقة';
    }

    if (lower.contains('rate limit') ||
        lower.contains('over_email_send_rate_limit') ||
        lower.contains('too many requests')) {
      return 'تم تجاوز الحد الأقصى للمحاولات، يرجى الانتظار قليلاً ثم المحاولة مرة أخرى';
    }

    if (lower.contains('user not found') || lower.contains('not_found')) {
      return 'هذا الحساب غير موجود، يرجى إنشاء حساب جديد';
    }

    if (lower.contains('لا يتوفر اتصال') ||
        lower.contains('network') ||
        lower.contains('socketexception') ||
        lower.contains('failed host lookup') ||
        lower.contains('connection refused') ||
        lower.contains('connection timed out')) {
      return 'لا يتوفر اتصال بالإنترنت';
    }

    if (lower.contains('token has expired') || lower.contains('expired')) {
      return 'انتهت جلستك، أعد تسجيل الدخول مرة أخرى';
    }

    // Return the original message if it is already in Arabic
    if (RegExp(r'[\u0600-\u06FF]').hasMatch(rawMessage)) {
      return rawMessage;
    }

    return 'حدث خطأ أثناء العملية، يرجى المحاولة مرة أخرى';
  }
}
