import 'package:material_ui/material_ui.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/constants/app_images.dart';

class RegisterIllustration extends StatelessWidget {
  const RegisterIllustration({super.key});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      AppImages.signupIcon,
      width: 512.w,
      height: 160.h,
      fit: BoxFit.cover,
    );
  }
}

class LoginIllustration extends StatelessWidget {
  const LoginIllustration({super.key});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      AppImages.loginIcon,
      width: 512.w,
      height: 160.h,
      fit: BoxFit.cover,
    );
  }
}

class OtpIllustration extends StatelessWidget {
  const OtpIllustration({super.key});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      AppImages.otpIcon,
      width: 512.w,
      height: 160.h,
      fit: BoxFit.cover,
    );
  }
}
