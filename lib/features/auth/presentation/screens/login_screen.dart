import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/services/app_preferences.dart';
import '../../../core/widgets/auth_app_bar.dart';
import '../cubits/login/login_cubit.dart';
import '../cubits/login/login_state.dart';
import '../validation/auth_field_rules.dart';
import '../widgets/auth_header_widget.dart';
import '../widgets/auth_illustrations.dart';
import '../widgets/auth_text_form_field.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _phoneController;
  late final TextEditingController _passwordController;
  late final ScrollController _scrollController;
  late final FocusNode _phoneFocusNode;
  late final FocusNode _passwordFocusNode;

  final _phoneFieldKey = GlobalKey();
  final _passwordFieldKey = GlobalKey();

  bool _obscurePassword = true;
  bool _isEmailIdentifier = false;

  @override
  void initState() {
    super.initState();
    _phoneController = TextEditingController();
    _passwordController = TextEditingController();
    _scrollController = ScrollController();
    _phoneFocusNode = FocusNode();
    _passwordFocusNode = FocusNode();
    _showForcedLogoutNotice();
  }

  Future<void> _showForcedLogoutNotice() async {
    final message = await AppPreferences.takeForcedLogoutMessage();
    if (!mounted || message == null || message.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    });
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    _scrollController.dispose();
    _phoneFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  void _submitLogin() {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) {
      final identifierError = _validateIdentifier(_phoneController.text);
      _revealField(
        identifierError == null ? _passwordFieldKey : _phoneFieldKey,
        identifierError == null ? _passwordFocusNode : _phoneFocusNode,
      );
      return;
    }

    final identifier = _phoneController.text.trim();
    final password = _passwordController.text;

    context.read<LoginCubit>().login(phone: identifier, password: password);
  }

  String? _validateIdentifier(String? value) {
    final identifier = value?.trim() ?? '';
    final looksLikeEmail =
        identifier.contains('@') || RegExp(r'[A-Za-z]').hasMatch(identifier);
    return looksLikeEmail
        ? AuthFieldRules.validateEmail(identifier)
        : AuthFieldRules.validatePhone(identifier);
  }

  void _revealField(GlobalKey fieldKey, FocusNode focusNode) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final target = fieldKey.currentContext;
      if (target != null) {
        Scrollable.ensureVisible(
          target,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOut,
          alignment: 0.18,
        );
      }
      focusNode.requestFocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBFBFE),
      appBar: const AuthAppBar(),
      body: SafeArea(
        child: BlocConsumer<LoginCubit, LoginState>(
          listener: (context, state) {
            switch (state) {
              case LoginSuccess():
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('تم تسجيل الدخول بنجاح!'),
                    backgroundColor: Color(0xFF22C55E),
                  ),
                );
                context.go(AppRoutes.main);
              case LoginError(:final message):
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
            final isLoading = state is LoginLoading;

            return Center(
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
                physics: const BouncingScrollPhysics(),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AuthHeaderWidget(
                        title: 'تسجيل الدخول',
                        subtitle: 'مرحباً بعودتك! ادخل إلى حسابك',
                        illustration: const LoginIllustration(),
                        onBack: () {
                          if (context.canPop()) {
                            context.pop();
                          } else {
                            context.go(AppRoutes.onboarding);
                          }
                        },
                      ),
                      SizedBox(height: 32.h),

                      // Phone Number
                      AuthTextFormField(
                        key: _phoneFieldKey,
                        controller: _phoneController,
                        focusNode: _phoneFocusNode,
                        label: 'البريد الإلكتروني أو رقم الهاتف',
                        hintText: '01xxxxxxxxx أو name@gmail.com',
                        keyboardType: TextInputType.emailAddress,
                        inputFormatters:
                            AuthFieldRules.identifierInputFormatters,
                        prefixIcon: const Icon(
                          Icons.phone_outlined,
                          color: Color(0xFF9CA3AF),
                          size: 20,
                        ),
                        validator: _validateIdentifier,
                        onChanged: (value) {
                          final nextIsEmail =
                              value.contains('@') ||
                              RegExp(r'[A-Za-z]').hasMatch(value);
                          if (nextIsEmail != _isEmailIdentifier) {
                            setState(() => _isEmailIdentifier = nextIsEmail);
                          }
                        },
                      ),
                      SizedBox(height: 20.h),

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

                      // Forgot Password Link
                      SizedBox(height: 4.h),

                      Align(
                        alignment: AlignmentDirectional.topEnd,
                        child: TextButton(
                          onPressed: isLoading
                              ? null
                              : () => context.push(AppRoutes.forgotPassword),
                          style: TextButton.styleFrom(
                            minimumSize: Size(48.w, 48.h),
                            padding: EdgeInsets.symmetric(horizontal: 4.w),
                          ),
                          child: Text(
                            'نسيت كلمة المرور؟',
                            style: TextStyle(
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF7C3AED),
                              fontFamily: 'IBM',
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 18.h),

                      // Login Button
                      SizedBox(
                        height: 52.h,
                        child: ElevatedButton(
                          onPressed: isLoading ? null : _submitLogin,
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
                                  'تسجيل الدخول',
                                  style: TextStyle(
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.w700,
                                    fontFamily: 'IBM',
                                  ),
                                ),
                        ),
                      ),
                      SizedBox(height: 18.h),

                      // "أو" Divider
                      Row(
                        children: [
                          const Expanded(
                            child: Divider(
                              color: Color(0xFFE5E7EB),
                              thickness: 1,
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16.w),
                            child: Text(
                              'أو',
                              style: TextStyle(
                                fontSize: 13.sp,
                                color: const Color(0xFF9CA3AF),
                                fontFamily: 'IBM',
                              ),
                            ),
                          ),
                          const Expanded(
                            child: Divider(
                              color: Color(0xFFE5E7EB),
                              thickness: 1,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 18.h),

                      // Teacher Dashboard Button
                      // SizedBox(
                      //   height: 52.h,
                      //   child: OutlinedButton.icon(
                      //     onPressed: () {
                      //       context.push(AppRoutes.teacherLogin);
                      //     },
                      //     icon: const Icon(
                      //       Icons.admin_panel_settings_outlined,
                      //       color: Color(0xFF7C3AED),
                      //       size: 22,
                      //     ),
                      //     label: Text(
                      //       'لوحة تحكم المعلم',
                      //       style: TextStyle(
                      //         fontSize: 14.5.sp,
                      //         fontWeight: FontWeight.w600,
                      //         color: const Color(0xFF7C3AED),
                      //         fontFamily: 'IBM',
                      //       ),
                      //     ),
                      //     style: OutlinedButton.styleFrom(
                      //       side: const BorderSide(
                      //         color: Color(0xFF7C3AED),
                      //         width: 1.2,
                      //       ),
                      //       shape: RoundedRectangleBorder(
                      //         borderRadius: BorderRadius.circular(14.r),
                      //       ),
                      //       backgroundColor: Colors.white,
                      //     ),
                      //   ),
                      // ),
                      // SizedBox(height: 28.h),

                      // Switch to Register Link
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'ليس لديك حساب؟ ',
                            style: TextStyle(
                              fontSize: 13.5.sp,
                              color: const Color(0xFF6B7280),
                              fontFamily: 'IBM',
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              context.push(AppRoutes.register);
                            },
                            child: Text(
                              'إنشاء حساب',
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
                      SizedBox(height: 12.h),

                      SizedBox(height: 16.h),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
