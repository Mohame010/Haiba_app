import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/helpers/app_logger.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/auth_app_bar.dart';
import '../../domain/entities/register_params.dart';
import '../cubits/register/register_cubit.dart';
import '../cubits/register/register_state.dart';
import '../routing/pending_registration_store.dart';
import '../validation/auth_field_rules.dart';
import '../widgets/auth_header_widget.dart';
import '../widgets/auth_illustrations.dart';
import '../widgets/auth_text_form_field.dart';
import '../widgets/birth_date_picker_sheet.dart';
import '../widgets/education_stage_selector.dart';
import '../widgets/grade_dropdown_field.dart';
import '../widgets/otp_rate_limit_dialog.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _OtpRequestSelection {
  final String phone;
  final OtpDeliveryChannel channel;
  final String? email;

  const _OtpRequestSelection({
    required this.phone,
    required this.channel,
    this.email,
  });
}

class _OtpConfirmationSheet extends StatefulWidget {
  final String initialPhone;

  const _OtpConfirmationSheet({required this.initialPhone});

  @override
  State<_OtpConfirmationSheet> createState() => _OtpConfirmationSheetState();
}

class _OtpConfirmationSheetState extends State<_OtpConfirmationSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  bool _isEditingPhone = false;
  OtpDeliveryChannel _channel = OtpDeliveryChannel.whatsapp;

  @override
  void initState() {
    super.initState();
    _phoneController = TextEditingController(text: widget.initialPhone);
    _emailController = TextEditingController();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    FocusScope.of(context).unfocus();
    Navigator.of(context).pop(
      _OtpRequestSelection(
        phone: _phoneController.text.trim(),
        channel: _channel,
        email: _channel == OtpDeliveryChannel.email
            ? _emailController.text.trim().toLowerCase()
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(24.w, 24.h, 24.w, 24.h + bottomInset),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 64.w,
                  height: 6.w,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.all(Radius.circular(16)),
                    color: AppColors.navyDark.withValues(alpha: 0.2),
                    shape: BoxShape.rectangle,
                  ),
                ),
              ),
              SizedBox(height: 30.h),
              Text(
                'اختار طريقة استلام كود التفعيل',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20.sp,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'IBM',
                  color: const Color(0xFF1E1B4B),
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                'هنبعتلك رمز تفعيل الحساب. اختار الطريقة الأنسب لك:',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14.sp,
                  height: 1.5,
                  fontFamily: 'IBM',
                  color: const Color(0xFF6B7280),
                ),
              ),
              SizedBox(height: 16.h),
              _ChannelOption(
                selected: _channel == OtpDeliveryChannel.whatsapp,
                icon: Icons.chat_rounded,
                color: const Color(0xFF20A85A),
                title: 'واتساب',
                subtitle: 'استلام الكود في رسالة على واتساب',
                onTap: () =>
                    setState(() => _channel = OtpDeliveryChannel.whatsapp),
              ),
              // SizedBox(height: 12.h),
              // _ChannelOption(
              //   selected: _channel == OtpDeliveryChannel.sms,
              //   icon: Icons.sms_rounded,
              //   color: const Color(0xFF2563EB),
              //   title: 'رسالة SMS',
              //   subtitle: 'استلام الكود في رسالة نصية عادية',
              //   onTap: () => setState(() => _channel = OtpDeliveryChannel.sms),
              // ),
              SizedBox(height: 12.h),
              _ChannelOption(
                selected: _channel == OtpDeliveryChannel.email,
                icon: Icons.email_rounded,
                color: const Color(0xFF7C3AED),
                title: 'البريد الإلكتروني',
                subtitle: 'استلام الرمز في رسالة على بريدك الإلكتروني',
                onTap: () =>
                    setState(() => _channel = OtpDeliveryChannel.email),
              ),
              SizedBox(height: 16.h),
              if (_channel == OtpDeliveryChannel.email)
                AuthTextFormField(
                  controller: _emailController,
                  label: 'البريد الإلكتروني',
                  hintText: 'name@gmail.com',
                  keyboardType: TextInputType.emailAddress,
                  inputFormatters: AuthFieldRules.emailInputFormatters,
                  prefixIcon: const Icon(
                    Icons.email_outlined,
                    color: Color(0xFF9CA3AF),
                    size: 20,
                  ),
                  validator: AuthFieldRules.validateEmail,
                )
              else if (_isEditingPhone)
                AuthTextFormField(
                  controller: _phoneController,
                  label: 'رقم الهاتف',
                  hintText: '01xxxxxxxxx',
                  keyboardType: TextInputType.phone,
                  inputFormatters: AuthFieldRules.phoneInputFormatters,
                  prefixIcon: const Icon(
                    Icons.phone_outlined,
                    color: Color(0xFF9CA3AF),
                    size: 20,
                  ),
                  validator: AuthFieldRules.validatePhone,
                )
              else
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 16.w,
                    vertical: 12.h,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14.r),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Directionality(
                    textDirection: TextDirection.ltr,
                    child: Text(
                      _phoneController.text,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'IBM',
                        color: const Color(0xFF1E1B4B),
                      ),
                    ),
                  ),
                ),
              SizedBox(height: 20.h),
              FilledButton(
                onPressed: _submit,
                style: FilledButton.styleFrom(
                  minimumSize: Size.fromHeight(52.h),
                  backgroundColor: const Color(0xFF7C3AED),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14.r),
                  ),
                ),
                child: Text(
                  _channel == OtpDeliveryChannel.email
                      ? 'إرسال الرمز على البريد'
                      : (_isEditingPhone
                            ? 'إرسال الكود للرقم ده'
                            : 'إرسال الكود'),
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'IBM',
                  ),
                ),
              ),
              SizedBox(height: 8.h),
              TextButton(
                onPressed: () {
                  setState(() {
                    if (_isEditingPhone) {
                      _phoneController.text = widget.initialPhone;
                    }
                    _isEditingPhone = !_isEditingPhone;
                  });
                },
                child: Text(
                  _isEditingPhone ? 'العودة للرقم الحالي' : 'تغيير الرقم',
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontFamily: 'IBM',
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChannelOption extends StatelessWidget {
  final bool selected;
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ChannelOption({
    required this.selected,
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16.r),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.08) : Colors.white,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(
            color: selected ? color : const Color(0xFFE5E7EB),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22.r,
              backgroundColor: color.withValues(alpha: 0.12),
              child: Icon(icon, color: color, size: 22),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'IBM',
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12.5.sp,
                      height: 1.4,
                      color: const Color(0xFF6B7280),
                      fontFamily: 'IBM',
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected ? color : const Color(0xFF9CA3AF),
            ),
          ],
        ),
      ),
    );
  }
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _passwordController;
  late final TextEditingController _confirmPasswordController;
  late final TextEditingController _birthDateController;
  late final ScrollController _scrollController;
  late final FocusNode _nameFocusNode;
  late final FocusNode _phoneFocusNode;
  late final FocusNode _passwordFocusNode;
  late final FocusNode _confirmPasswordFocusNode;

  final _nameFieldKey = GlobalKey();
  final _phoneFieldKey = GlobalKey();
  final _gradeFieldKey = GlobalKey();
  final _passwordFieldKey = GlobalKey();
  final _confirmPasswordFieldKey = GlobalKey();
  final _termsFieldKey = GlobalKey();

  String _selectedStage = 'إعدادي';
  String? _selectedGrade;
  String? _gradeErrorText;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _agreedToTerms = false;
  bool _termsError = false;
  bool _isConfirmingOtp = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _phoneController = TextEditingController();
    _passwordController = TextEditingController();
    _confirmPasswordController = TextEditingController();
    _birthDateController = TextEditingController();
    _scrollController = ScrollController();
    _nameFocusNode = FocusNode();
    _phoneFocusNode = FocusNode();
    _passwordFocusNode = FocusNode();
    _confirmPasswordFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _birthDateController.dispose();
    _scrollController.dispose();
    _nameFocusNode.dispose();
    _phoneFocusNode.dispose();
    _passwordFocusNode.dispose();
    _confirmPasswordFocusNode.dispose();
    super.dispose();
  }

  void _onStageChanged(String stage) {
    setState(() {
      _selectedStage = stage;
      _selectedGrade = null;
      _gradeErrorText = null;
    });
  }

  Future<void> _selectBirthDate() async {
    final now = DateTime.now();
    final initialDate = DateTime(2006, 12, 12);
    final pickedDate = await showBirthDatePickerBottomSheet(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1990),
      lastDate: now,
    );

    if (pickedDate != null) {
      final formatted =
          '${pickedDate.year}-${pickedDate.month.toString().padLeft(2, '0')}-${pickedDate.day.toString().padLeft(2, '0')}';
      setState(() {
        _birthDateController.text = formatted;
      });
    }
  }

  void _showAlreadyRegisteredDialog(
    BuildContext context, {
    String identifier = 'رقم الهاتف',
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.r),
        ),
        title: Row(
          children: [
            const Icon(
              Icons.info_outline_rounded,
              color: Color(0xFF7C3AED),
              size: 26,
            ),
            SizedBox(width: 10.w),
            Text(
              '$identifier مسجل مسبقاً',
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1E1B4B),
                fontFamily: 'IBM',
              ),
            ),
          ],
        ),
        content: Text(
          'يوجد حساب مرتبط بهذا $identifier بالفعل.\nيمكنك تسجيل الدخول أو تعديل البيانات والمحاولة مرة أخرى.',
          style: TextStyle(fontSize: 14.sp, height: 1.6, fontFamily: 'IBM'),
          textAlign: TextAlign.right,
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogCtx).pop();
              context.read<RegisterCubit>().reset();
            },
            child: Text(
              identifier == 'البريد الإلكتروني'
                  ? 'تعديل الإيميل'
                  : 'تعديل الرقم',
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(dialogCtx).pop();
              context.pushReplacement(AppRoutes.login);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7C3AED),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
            ),
            child: const Text('تسجيل الدخول'),
          ),
        ],
      ),
    );
  }

  void _revealValidationField(GlobalKey fieldKey, [FocusNode? focusNode]) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final target = fieldKey.currentContext;
      if (target != null) {
        Scrollable.ensureVisible(
          target,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOut,
          alignment: 0.15,
        );
      }
      focusNode?.requestFocus();
    });
  }

  void _revealFirstInvalidField() {
    if (AuthFieldRules.validateName(_nameController.text) != null) {
      _revealValidationField(_nameFieldKey, _nameFocusNode);
    } else if (AuthFieldRules.validatePhone(_phoneController.text) != null) {
      _revealValidationField(_phoneFieldKey, _phoneFocusNode);
    } else if (_selectedGrade == null || _selectedGrade!.isEmpty) {
      _revealValidationField(_gradeFieldKey);
    } else if (AuthFieldRules.validatePassword(_passwordController.text) !=
        null) {
      _revealValidationField(_passwordFieldKey, _passwordFocusNode);
    } else if (_confirmPasswordController.text.isEmpty ||
        _confirmPasswordController.text != _passwordController.text) {
      _revealValidationField(
        _confirmPasswordFieldKey,
        _confirmPasswordFocusNode,
      );
    } else if (!_agreedToTerms) {
      _revealValidationField(_termsFieldKey);
    }
  }

  void _openTerms() {
    context.push(AppRoutes.terms);
  }

  void _openPrivacyPolicy() {
    context.push(AppRoutes.privacyPolicy);
  }

  Future<void> _submitForm() async {
    if (_isConfirmingOtp) return;
    bool hasError = false;

    if (_selectedGrade == null || _selectedGrade!.isEmpty) {
      setState(() {
        _gradeErrorText = _selectedStage == AppConstants.stageUniversity
            ? 'يرجى اختيار الفرقة الدراسية'
            : 'يرجى اختيار الصف الدراسي';
      });
      hasError = true;
    } else {
      setState(() {
        _gradeErrorText = null;
      });
    }

    if (!_agreedToTerms) {
      setState(() {
        _termsError = true;
      });
      hasError = true;
    } else {
      setState(() {
        _termsError = false;
      });
    }

    final isFormValid = _formKey.currentState?.validate() ?? false;
    if (!isFormValid || hasError) {
      _revealFirstInvalidField();
      return;
    }

    setState(() => _isConfirmingOtp = true);
    try {
      final otpSelection = await _showOtpConfirmationSheet(
        _phoneController.text.trim(),
      );
      if (!mounted || otpSelection == null) return;

      _phoneController.text = otpSelection.phone;
      if (!(_formKey.currentState?.validate() ?? false)) {
        _revealFirstInvalidField();
        return;
      }

      final params = RegisterParams(
        name: _nameController.text.trim(),
        phone: otpSelection.phone,
        educationLevel: _selectedStage,
        grade: _selectedGrade!,
        password: _passwordController.text,
        birthDate: _birthDateController.text.trim(),
        otpChannel: otpSelection.channel,
        email: otpSelection.email,
      );

      AppLogger.authLog(
        '[OTP][RegisterScreen] confirmed phone; requesting OTP',
        data: {
          'phone': AppLogger.maskedPhone(params.phone),
          'channel': params.otpChannel.name,
        },
      );
      context.read<RegisterCubit>().submitRegistration(params);
    } finally {
      if (mounted) setState(() => _isConfirmingOtp = false);
    }
  }

  Future<_OtpRequestSelection?> _showOtpConfirmationSheet(String phone) async {
    return showModalBottomSheet<_OtpRequestSelection>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: const Color(0xFFFBFBFE),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      builder: (_) => _OtpConfirmationSheet(initialPhone: phone),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBFBFE),
      appBar: const AuthAppBar(),
      body: SafeArea(
        child: BlocConsumer<RegisterCubit, RegisterState>(
          listener: (context, state) {
            AppLogger.authLog(
              '[OTP][RegisterScreen] listener received state',
              data: {'state': state.runtimeType.toString()},
            );
            switch (state) {
              case RegisterOtpSent(:final params):
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'تم إرسال كود التحقق عبر ${params.otpChannel == OtpDeliveryChannel.sms ? 'رسالة SMS' : 'واتساب'}',
                    ),
                    backgroundColor: Color(0xFF22C55E),
                  ),
                );
                context.push(
                  AppRoutes.otpVerification,
                  extra: {
                    'phone': params.otpChannel == OtpDeliveryChannel.email
                        ? params.email
                        : params.phone,
                    'registrationKey': PendingRegistrationStore.save(params),
                    'isPasswordReset': false,
                  },
                );
              case RegisterPhoneAlreadyRegistered():
                _showAlreadyRegisteredDialog(context);
              case RegisterEmailAlreadyRegistered():
                _showAlreadyRegisteredDialog(
                  context,
                  identifier: 'البريد الإلكتروني',
                );
              case RegisterOtpRateLimited(:final supportPhone):
                unawaited(
                  showOtpRateLimitDialog(context, supportPhone: supportPhone),
                );
              case RegisterError(:final message):
                AppLogger.authLog(
                  '[OTP][RegisterScreen] showing error SnackBar',
                  error: message,
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(message),
                    backgroundColor: const Color(0xFFEF4444),
                  ),
                );
              default:
                break;
            }
          },
          builder: (context, state) {
            final isLoading = state is RegisterLoading || _isConfirmingOtp;

            return SingleChildScrollView(
              controller: _scrollController,
              padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 8.h),
              physics: const BouncingScrollPhysics(),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const AuthHeaderWidget(
                      title: 'إنشاء حساب',
                      subtitle: 'إنشاء حساب جديد للطالب',
                      illustration: RegisterIllustration(),
                    ),
                    SizedBox(height: 24.h),

                    // Student Name
                    AuthTextFormField(
                      key: _nameFieldKey,
                      controller: _nameController,
                      focusNode: _nameFocusNode,
                      label: 'اسم الطالب',
                      hintText: 'الاسم ثلاثي (مثال: أحمد محمد علي)',
                      keyboardType: TextInputType.name,
                      inputFormatters: AuthFieldRules.nameInputFormatters,
                      prefixIcon: const Icon(
                        Icons.person_outline_rounded,
                        color: Color(0xFF9CA3AF),
                        size: 20,
                      ),
                      validator: AuthFieldRules.validateName,
                    ),
                    SizedBox(height: 16.h),

                    // Phone Number
                    AuthTextFormField(
                      key: _phoneFieldKey,
                      controller: _phoneController,
                      focusNode: _phoneFocusNode,
                      label: 'رقم الهاتف',
                      hintText: '01xxxxxxxxx',
                      keyboardType: TextInputType.phone,
                      inputFormatters: AuthFieldRules.phoneInputFormatters,
                      prefixIcon: const Icon(
                        Icons.phone_outlined,
                        color: Color(0xFF9CA3AF),
                        size: 20,
                      ),
                      validator: AuthFieldRules.validatePhone,
                    ),
                    SizedBox(height: 16.h),

                    // Education Stage
                    EducationStageSelector(
                      selectedStage: _selectedStage,
                      onStageChanged: _onStageChanged,
                    ),
                    SizedBox(height: 16.h),

                    // Grade Dropdown
                    KeyedSubtree(
                      key: _gradeFieldKey,
                      child: GradeDropdownField(
                        stage: _selectedStage,
                        selectedGrade: _selectedGrade,
                        errorText: _gradeErrorText,
                        onGradeSelected: (grade) {
                          setState(() {
                            _selectedGrade = grade;
                            _gradeErrorText = null;
                          });
                        },
                      ),
                    ),
                    SizedBox(height: 16.h),

                    // Password
                    AuthTextFormField(
                      key: _passwordFieldKey,
                      controller: _passwordController,
                      focusNode: _passwordFocusNode,
                      label: 'كلمة المرور',
                      hintText: '6 أحرف على الأقل',
                      obscureText: _obscurePassword,
                      inputFormatters: AuthFieldRules.passwordInputFormatters,
                      prefixIcon: const Icon(
                        Icons.lock_outline_rounded,
                        color: Color(0xFF9CA3AF),
                        size: 20,
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: const Color(0xFF9CA3AF),
                          size: 20,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                      validator: AuthFieldRules.validatePassword,
                    ),
                    SizedBox(height: 16.h),

                    // Confirm Password
                    AuthTextFormField(
                      key: _confirmPasswordFieldKey,
                      controller: _confirmPasswordController,
                      focusNode: _confirmPasswordFocusNode,
                      label: 'تأكيد كلمة المرور',
                      hintText: 'اكتب كلمة المرور مرة أخرى',
                      obscureText: _obscureConfirmPassword,
                      inputFormatters: AuthFieldRules.passwordInputFormatters,
                      prefixIcon: const Icon(
                        Icons.lock_reset_rounded,
                        color: Color(0xFF9CA3AF),
                        size: 20,
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirmPassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: const Color(0xFF9CA3AF),
                          size: 20,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscureConfirmPassword = !_obscureConfirmPassword;
                          });
                        },
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'يرجى تأكيد كلمة المرور';
                        }
                        if (value != _passwordController.text) {
                          return 'كلمتا المرور غير متطابقتين';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 16.h),

                    // Date of Birth
                    AuthTextFormField(
                      controller: _birthDateController,
                      label: 'تاريخ ميلاد الطالب',
                      hintText: 'اختر تاريخ الميلاد',
                      readOnly: true,
                      onTap: _selectBirthDate,
                      prefixIcon: const Icon(
                        Icons.calendar_today_outlined,
                        color: Color(0xFF9CA3AF),
                        size: 20,
                      ),
                    ),
                    SizedBox(height: 14.h),

                    // Terms and Conditions Checkbox
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 24.w,
                          height: 24.h,
                          child: Checkbox(
                            value: _agreedToTerms,
                            activeColor: const Color(0xFF7C3AED),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(5.r),
                            ),
                            side: BorderSide(
                              color: _termsError
                                  ? const Color(0xFFEF4444)
                                  : const Color(0xFF9CA3AF),
                              width: 1.5,
                            ),
                            onChanged: (val) {
                              setState(() {
                                _agreedToTerms = val ?? false;
                                if (_agreedToTerms) _termsError = false;
                              });
                            },
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                'أوافق على ',
                                style: TextStyle(
                                  fontSize: 13.sp,
                                  fontFamily: 'IBM',
                                  color: _termsError
                                      ? const Color(0xFFEF4444)
                                      : const Color(0xFF6B7280),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              GestureDetector(
                                onTap: _openTerms,
                                child: Text(
                                  'الشروط والأحكام',
                                  style: TextStyle(
                                    fontSize: 13.sp,
                                    fontFamily: 'IBM',
                                    color: const Color(0xFF7C3AED),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              Text(
                                ' و ',
                                style: TextStyle(
                                  fontSize: 13.sp,
                                  fontFamily: 'IBM',
                                  color: const Color(0xFF6B7280),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              GestureDetector(
                                onTap: _openPrivacyPolicy,
                                child: Text(
                                  'سياسة الخصوصية',
                                  style: TextStyle(
                                    fontSize: 13.sp,
                                    fontFamily: 'IBM',
                                    color: const Color(0xFF7C3AED),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 18.h),

                    // Submit Button
                    SizedBox(
                      height: 52.h,
                      child: ElevatedButton(
                        onPressed: isLoading ? null : _submitForm,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF7C3AED),
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: const Color(0xFFA78BFA),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14.r),
                          ),
                          elevation: 0,
                        ),
                        child: isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                'إنشاء حساب',
                                style: TextStyle(
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.w700,
                                  fontFamily: 'IBM',
                                ),
                              ),
                      ),
                    ),
                    SizedBox(height: 20.h),

                    // Switch to Login Link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'لديك حساب بالفعل؟ ',
                          style: TextStyle(
                            fontSize: 13.5.sp,
                            color: const Color(0xFF6B7280),
                            fontFamily: 'IBM',
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            context.pushReplacement(AppRoutes.login);
                          },
                          child: Text(
                            'تسجيل الدخول',
                            style: TextStyle(
                              fontSize: 13.5.sp,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF7C3AED),
                              fontFamily: 'IBM',
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16.h),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
