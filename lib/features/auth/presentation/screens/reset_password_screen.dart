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

class ResetPasswordScreen extends StatefulWidget {
  final String identifier;
  final OtpDeliveryChannel channel;

  const ResetPasswordScreen({
    super.key,
    required this.identifier,
    required this.channel,
  });

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _passwordController;
  late final TextEditingController _confirmPasswordController;

  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  void initState() {
    super.initState();
    _passwordController = TextEditingController();
    _confirmPasswordController = TextEditingController();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final newPassword = _passwordController.text;
    context.read<ResetPasswordCubit>().resetPassword(
      identifier: widget.identifier,
      newPassword: newPassword,
      channel: widget.channel,
    );
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
              case ResetPasswordSuccess(:final message):
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(message),
                    backgroundColor: const Color(0xFF22C55E),
                  ),
                );
                context.go(AppRoutes.login);
              case ResetPasswordError(:final message):
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
                      title: 'تعيين كلمة المرور الجديدة',
                      subtitle: 'أدخل كلمة المرور الجديدة لحسابك',
                      illustration: LoginIllustration(),
                    ),
                    SizedBox(height: 32.h),

                    // New Password
                    AuthTextFormField(
                      controller: _passwordController,
                      label: 'كلمة المرور الجديدة',
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
                    SizedBox(height: 20.h),

                    // Confirm Password
                    AuthTextFormField(
                      controller: _confirmPasswordController,
                      label: 'تأكيد كلمة المرور الجديدة',
                      hintText: 'أعد إدخال كلمة المرور',
                      obscureText: _obscureConfirm,
                      inputFormatters: AuthFieldRules.passwordInputFormatters,
                      prefixIcon: const Icon(
                        Icons.lock_outline_rounded,
                        color: Color(0xFF9CA3AF),
                        size: 20,
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirm
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: const Color(0xFF9CA3AF),
                          size: 20,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscureConfirm = !_obscureConfirm;
                          });
                        },
                      ),
                      validator: (val) {
                        if (val == null || val.isEmpty) {
                          return 'يرجى تأكيد كلمة المرور';
                        }
                        if (val != _passwordController.text) {
                          return 'كلمتا المرور غير متطابقتين';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 32.h),

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
                                'حفظ كلمة المرور',
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
