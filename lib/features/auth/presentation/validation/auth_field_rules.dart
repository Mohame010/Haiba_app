import 'package:flutter/services.dart';

class AuthFieldRules {
  AuthFieldRules._();

  static const nameMinLength = 2;
  static const nameMaxLength = 50;
  static const nameMinParts = 3;
  static const namePartMinLength = 3;
  static const phoneMinLength = 10;
  static const phoneMaxLength = 11;
  static const passwordMinLength = 6;
  static const passwordMaxLength = 50;

  static final RegExp _nameCharacters = RegExp(
    r'[a-zA-Z\u0621-\u063A\u0641-\u064A ]',
  );
  static final RegExp _validName = RegExp(
    r'^[a-zA-Z\u0621-\u063A\u0641-\u064A ]+$',
  );
  static final RegExp _digits = RegExp(r'^\d+$');
  static final RegExp _emailCharacters = RegExp(r'[a-zA-Z0-9@._%+\-]');
  static final RegExp _validEmail = RegExp(
    r"^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)+$",
  );

  static List<TextInputFormatter> get nameInputFormatters => [
    FilteringTextInputFormatter.allow(_nameCharacters),
    LengthLimitingTextInputFormatter(nameMaxLength),
  ];

  static List<TextInputFormatter> get phoneInputFormatters => [
    FilteringTextInputFormatter.digitsOnly,
    LengthLimitingTextInputFormatter(phoneMaxLength),
  ];

  static List<TextInputFormatter> get identifierInputFormatters => [
    FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9@._%+\-]')),
    LengthLimitingTextInputFormatter(254),
  ];

  static List<TextInputFormatter> get passwordInputFormatters => [
    LengthLimitingTextInputFormatter(passwordMaxLength),
  ];

  static List<TextInputFormatter> get emailInputFormatters => [
    FilteringTextInputFormatter.allow(_emailCharacters),
    LengthLimitingTextInputFormatter(254),
  ];

  static String? validateEmail(String? value, {bool required = true}) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return required ? 'يرجى إدخال البريد الإلكتروني' : null;
    if (!_validEmail.hasMatch(email) || email.contains('..')) {
      return 'يرجى إدخال بريد إلكتروني صحيح مثل name@example.com';
    }
    return null;
  }

  static String? validateName(String? value) {
    final name = value?.trim() ?? '';
    if (name.isEmpty) {
      return 'يرجى إدخال اسم الطالب';
    }
    if (!_validName.hasMatch(name)) {
      return 'الاسم يجب أن يحتوي على حروف فقط';
    }
    if (name.length > nameMaxLength) {
      return 'الاسم يجب ألا يزيد عن $nameMaxLength حرفاً';
    }

    final parts = name
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();

    if (parts.length < nameMinParts) {
      return 'يرجى إدخال اسم الطالب ثلاثياً على الأقل';
    }

    for (final part in parts) {
      if (part.length < namePartMinLength) {
        return 'كل مقطع في الاسم يجب ألا يقل عن $namePartMinLength أحرف';
      }
    }

    return null;
  }

  static String? validatePhone(String? value) {
    final phone = value?.trim() ?? '';
    if (phone.isEmpty) {
      return 'يرجى إدخال رقم الهاتف';
    }
    if (!_digits.hasMatch(phone)) {
      return 'رقم الهاتف يجب أن يحتوي على أرقام فقط';
    }
    if (phone.length < phoneMinLength || phone.length > phoneMaxLength) {
      return 'رقم الهاتف يجب أن يتكون من 10 أو 11 رقماً';
    }
    return null;
  }

  static String? validatePassword(String? value) {
    final password = value ?? '';
    if (password.isEmpty) {
      return 'يرجى إدخال كلمة المرور';
    }
    if (password.length < passwordMinLength) {
      return 'كلمة المرور يجب ألا تقل عن $passwordMinLength أحرف';
    }
    if (password.length > passwordMaxLength) {
      return 'كلمة المرور يجب ألا تزيد عن $passwordMaxLength حرفاً';
    }
    if (password == '123456') {
      return 'كلمة المرور 123456 ضعيفة جداً، اختر كلمة أخرى';
    }
    if (password.contains(RegExp(r'\s'))) {
      return 'كلمة المرور يجب ألا تحتوي على مسافات';
    }
    return null;
  }
}
