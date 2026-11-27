import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/widgets/auth_app_bar.dart';
import '../cubits/reset_password/reset_password_cubit.dart';
import '../cubits/reset_password/reset_password_state.dart';
import '../../domain/entities/register_params.dart';
import '../validation/auth_field_rules.dart';
import '../widgets/auth_header_widget.dart';
import '../widgets/auth_illustrations.dart';
import '../widgets/auth_text_form_field.dart';
import '../widgets/otp_rate_limit_dialog.dart';

class _ResetChannelOption extends StatelessWidget {
  final bool selected;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ResetChannelOption({
    required this.selected,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = const Color(0xFF7C3AED);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14.r),
      child: Container(
        padding: EdgeInsets.all(14.w),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.08) : Colors.white,
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(color: selected ? color : const Color(0xFFE5E7EB)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'IBM',
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: const Color(0xFF6B7280),
                      fontFamily: 'IBM',
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: color,
            ),
          ],
        ),
      ),
    );
  }
}

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  OtpDeliveryChannel _channel = OtpDeliveryChannel.whatsapp;

  @override
  void initState() {
    super.initState();
    _phoneController = TextEditingController();
    _emailController = TextEditingController();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final identifier = _channel == OtpDeliveryChannel.email
        ? _emailController.text.trim().toLowerCase()
        : _phoneController.text.trim();
    context.read<ResetPasswordCubit>().sendResetOtp(identifier, _channel);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBFBFE),
      appBar: const AuthAppBar(),
      body: SafeArea(
        child: BlocConsumer<ResetPasswordCubit, ResetPasswordState>(
          listener: (context, state) {
            switch (state) {
              case ResetPasswordOtpSent(:final identifier, :final channel):
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'تم إرسال رمز التحقق عبر ${channel == OtpDeliveryChannel.email ? 'البريد الإلكتروني' : 'الهاتف'}',
                    ),
                    backgroundColor: Color(0xFF22C55E),
                  ),
                );
                context.push(
                  AppRoutes.otpVerification,
                  extra: {
                    'phone': identifier,
                    'isPasswordReset': true,
                    'channel': channel.name,
                  },
                );
              case ResetPasswordError(:final message):
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(message),
                    backgroundColor: const Color(0xFFEF4444),
                  ),
                );
              case ResetPasswordRateLimited(:final supportPhone):
                unawaited(
                  showOtpRateLimitDialog(context, supportPhone: supportPhone),
                );
              default:
                break;
            }
          },
          builder: (context, state) {
            final isLoading = state is ResetPasswordLoading;

            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
              physics: const BouncingScrollPhysics(),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const AuthHeaderWidget(
                      title: 'نسيت كلمة المرور',
                      subtitle:
                          'اختار طريقة استلام رمز التحقق لتغيير كلمة المرور',
                      illustration: LoginIllustration(),
                    ),
                    SizedBox(height: 32.h),

                    _ResetChannelOption(
                      selected: _channel == OtpDeliveryChannel.whatsapp,
                      icon: Icons.chat_rounded,
                      title: 'واتساب',
                      subtitle: 'استلام الرمز على واتساب',
                      onTap: () => setState(
                        () => _channel = OtpDeliveryChannel.whatsapp,
                      ),
                    ),
                    SizedBox(height: 10.h),
                    // _ResetChannelOption(
                    //   selected: _channel == OtpDeliveryChannel.sms,
                    //   icon: Icons.sms_rounded,
                    //   title: 'رسالة SMS',
                    //   subtitle: 'استلام الرمز في رسالة نصية',
                    //   onTap: () =>
                    //       setState(() => _channel = OtpDeliveryChannel.sms),
                    // ),
                    // SizedBox(height: 10.h),
                    _ResetChannelOption(
                      selected: _channel == OtpDeliveryChannel.email,
                      icon: Icons.email_rounded,
                      title: 'البريد الإلكتروني',
                      subtitle: 'استلام الرمز على بريدك الإلكتروني',
                      onTap: () =>
                          setState(() => _channel = OtpDeliveryChannel.email),
                    ),
                    SizedBox(height: 20.h),
                    if (_channel == OtpDeliveryChannel.email)
                      AuthTextFormField(
                        controller: _emailController,
                        label: 'البريد الإلكتروني',
                        hintText: 'name@example.com',
                        keyboardType: TextInputType.emailAddress,
                        inputFormatters: AuthFieldRules.emailInputFormatters,
                        prefixIcon: const Icon(
                          Icons.email_outlined,
                          color: Color(0xFF9CA3AF),
                          size: 20,
                        ),
                        validator: AuthFieldRules.validateEmail,
                      )
                    else
                      AuthTextFormField(
                        controller: _phoneController,
                        label: 'رقم الهاتف',
                        hintText: '01xxxxxxxxx',
                        keyboardType: TextInputType.phone,
                        prefixIcon: const Icon(
                          Icons.phone_outlined,
                          color: Color(0xFF9CA3AF),
                          size: 20,
                        ),
                        validator: AuthFieldRules.validatePhone,
                      ),
                    SizedBox(height: 28.h),

                    SizedBox(
                      height: 52.h,
                      child: ElevatedButton(
                        onPressed: isLoading ? null : _submit,
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
                                'إرسال كود التحقق',
                                style: TextStyle(
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.w700,
                                  fontFamily: 'IBM',
                                ),
                              ),
                      ),
                    ),
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
