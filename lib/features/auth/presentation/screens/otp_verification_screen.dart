import 'dart:async';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../../core/helpers/app_logger.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/widgets/auth_app_bar.dart';
import '../../domain/entities/register_params.dart';
import '../cubits/otp/otp_cubit.dart';
import '../cubits/otp/otp_state.dart';
import '../widgets/auth_header_widget.dart';
import '../widgets/auth_illustrations.dart';
import '../widgets/otp_boxes_widget.dart';
import '../widgets/otp_rate_limit_dialog.dart';

class OtpVerificationScreen extends StatefulWidget {
  final String phone;
  final RegisterParams? registerParams;
  final bool isPasswordReset;
  final OtpDeliveryChannel channel;

  const OtpVerificationScreen({
    super.key,
    required this.phone,
    this.registerParams,
    this.isPasswordReset = false,
    this.channel = OtpDeliveryChannel.whatsapp,
  });

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  late final TextEditingController _otpTextController;
  late final FocusNode _focusNode;

  Timer? _countdownTimer;
  int _remainingSeconds = 60;
  bool _canResend = false;

  @override
  void initState() {
    super.initState();
    _otpTextController = TextEditingController();
    _focusNode = FocusNode();
    _startTimer(60);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
      // If entered from forgot password or other paths, ensure OTP is sent
      if (widget.registerParams == null && !widget.isPasswordReset) {
        context.read<OtpCubit>().sendOtp(widget.phone);
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _otpTextController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _startTimer(int seconds) {
    _countdownTimer?.cancel();
    setState(() {
      _remainingSeconds = seconds;
      _canResend = false;
    });

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_remainingSeconds > 0) {
        setState(() {
          _remainingSeconds--;
        });
      } else {
        setState(() {
          _canResend = true;
        });
        timer.cancel();
      }
    });
  }

  String _formatTimer(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String get _channelLabel =>
      switch (widget.registerParams?.otpChannel ?? widget.channel) {
        OtpDeliveryChannel.whatsapp => 'واتساب',
        OtpDeliveryChannel.sms => 'رسالة SMS',
        OtpDeliveryChannel.email => 'البريد الإلكتروني',
      };

  void _onCodeChanged(String value) {
    setState(() {});

    if (value.length == 6) {
      context.read<OtpCubit>().verifyOtp(
        phone: widget.phone,
        code: value,
        registerParams: widget.registerParams,
        isPasswordReset: widget.isPasswordReset,
        channel: widget.registerParams?.otpChannel ?? widget.channel,
      );
    }
  }

  void _onResendOtp() {
    if (_canResend) {
      _otpTextController.clear();
      setState(() {});
      _startTimer(60);
      _focusNode.requestFocus();
      context.read<OtpCubit>().resendOtp(
        widget.phone,
        channel: widget.registerParams?.otpChannel ?? widget.channel,
        isPasswordReset: widget.isPasswordReset,
        registrationParams: widget.registerParams,
      );
    }
  }

  void _showAlreadyRegisteredDialog(BuildContext context) {
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
              'رقم مسجل مسبقاً',
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
          'هذا الرقم مسجل بالفعل في التطبيق.\nهل تريد تسجيل الدخول بدلاً من ذلك؟',
          style: TextStyle(fontSize: 14.sp, height: 1.6, fontFamily: 'IBM'),
          textAlign: TextAlign.right,
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogCtx).pop();
              context.pop();
            },
            child: const Text('تعديل الرقم'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(dialogCtx).pop();
              context.go(AppRoutes.login);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBFBFE),
      appBar: const AuthAppBar(),
      body: SafeArea(
        child: BlocConsumer<OtpCubit, OtpState>(
          listener: (context, state) {
            AppLogger.authLog(
              '[OTP][OtpScreen] listener received state',
              data: {'state': state.runtimeType.toString()},
            );
            switch (state) {
              case OtpSuccess(:final message):
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(message),
                    backgroundColor: const Color(0xFF22C55E),
                  ),
                );
                if (widget.registerParams != null) {
                  context.go(AppRoutes.levelAssessmentIntro, extra: true);
                } else {
                  context.go(AppRoutes.main);
                }
              case OtpVerifiedForPasswordReset(:final phone):
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('تم التحقق من الرمز بنجاح'),
                    backgroundColor: Color(0xFF22C55E),
                  ),
                );
                context.pushReplacement(
                  AppRoutes.resetPassword,
                  extra: {
                    'identifier': phone,
                    'channel':
                        (widget.registerParams?.otpChannel ?? widget.channel)
                            .name,
                  },
                );
              case OtpPhoneAlreadyRegistered():
                _showAlreadyRegisteredDialog(context);
              case OtpRateLimited(:final supportPhone):
                unawaited(
                  showOtpRateLimitDialog(context, supportPhone: supportPhone),
                );
              case OtpError(:final message):
                AppLogger.authLog(
                  '[OTP][OtpScreen] showing OtpError SnackBar',
                  error: message,
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(message),
                    backgroundColor: const Color(0xFFEF4444),
                  ),
                );
                _otpTextController.clear();
                setState(() {});
              case OtpReady(:final errorMessage) when errorMessage != null:
                AppLogger.authLog(
                  '[OTP][OtpScreen] showing OtpReady error SnackBar',
                  error: errorMessage,
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(errorMessage),
                    backgroundColor: const Color(0xFFEF4444),
                  ),
                );
                _otpTextController.clear();
                setState(() {});
              default:
                break;
            }
          },
          builder: (context, state) {
            final isVerifying = state is OtpVerifying;
            final hasError =
                state is OtpError ||
                (state is OtpReady && state.errorMessage != null);

            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 8.h),
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  AuthHeaderWidget(
                    title: widget.isPasswordReset
                        ? 'التحقق لتغيير كلمة المرور'
                        : 'تفعيل الحساب',
                    subtitle: 'لقد أرسلنا رمز التحقق عبر $_channelLabel إلى',
                    illustration: OtpIllustration(),
                  ),
                  SizedBox(height: 6.h),
                  Text(
                    widget.phone,
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF7C3AED),
                      letterSpacing: 1.1,
                      fontFamily: 'IBM',
                    ),
                  ),
                  SizedBox(height: 36.h),

                  // Stack with Hidden input capturing system numeric keyboard and visually displaying OtpBoxesWidget
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      _focusNode.requestFocus();
                    },
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Visual 6-pin boxes
                        OtpBoxesWidget(
                          code: _otpTextController.text,
                          length: 6,
                          hasError: hasError,
                        ),

                        // Hidden TextField strictly taking 6 numeric digits
                        Opacity(
                          opacity: 0.0,
                          child: SizedBox(
                            width: 300.w,
                            height: 60.h,
                            child: TextField(
                              controller: _otpTextController,
                              focusNode: _focusNode,
                              keyboardType: TextInputType.number,
                              autofocus: true,
                              enableInteractiveSelection: false,
                              showCursor: false,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(6),
                              ],
                              onChanged: _onCodeChanged,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 28.h),

                  if (isVerifying)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.0),
                      child: CircularProgressIndicator(
                        color: Color(0xFF7C3AED),
                      ),
                    )
                  else ...[
                    // Resend Code Timer Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'لم تستلم الكود؟ ',
                          style: TextStyle(
                            fontSize: 13.5.sp,
                            color: const Color(0xFF6B7280),
                            fontFamily: 'IBM',
                          ),
                        ),
                        GestureDetector(
                          onTap: _canResend ? _onResendOtp : null,
                          child: Text(
                            _canResend
                                ? 'إعادة إرسال الكود'
                                : 'إعادة إرسال الكود (${_formatTimer(_remainingSeconds)})',
                            style: TextStyle(
                              fontSize: 13.5.sp,
                              fontWeight: FontWeight.w700,
                              color: _canResend
                                  ? const Color(0xFF7C3AED)
                                  : const Color(0xFFA78BFA),
                              fontFamily: 'IBM',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  SizedBox(height: 24.h),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
