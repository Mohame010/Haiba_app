import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/network/api_result.dart';
import '../../../domain/usecases/login_with_phone_usecase.dart';
import 'login_state.dart';

class LoginCubit extends Cubit<LoginState> {
  final LoginWithPhoneUseCase _loginWithPhoneUseCase;

  LoginCubit(this._loginWithPhoneUseCase) : super(const LoginInitial());

  Future<void> login({required String phone, required String password}) async {
    emit(const LoginLoading());

    final result = await _loginWithPhoneUseCase(
      phone: phone,
      password: password,
    );

    switch (result) {
      case ApiSuccess(:final data):
        emit(LoginSuccess(data));
      case ApiError(:final failure):
        emit(LoginError(failure.message));
    }
  }
}
