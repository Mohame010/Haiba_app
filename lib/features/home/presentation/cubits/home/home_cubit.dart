import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/network/api_result.dart';
import '../../../domain/usecases/get_home_summary_usecase.dart';
import 'home_state.dart';

class HomeCubit extends Cubit<HomeState> {
  final GetHomeSummaryUseCase _getHomeSummaryUseCase;

  HomeCubit(this._getHomeSummaryUseCase) : super(const HomeInitial());

  Future<void> loadHomeData({bool showLoading = true}) async {
    if (showLoading || state is! HomeLoaded) {
      emit(const HomeLoading());
    }
    final result = await _getHomeSummaryUseCase();

    switch (result) {
      case ApiSuccess(:final data):
        emit(HomeLoaded(data));
      case ApiError(:final failure):
        if (state is! HomeLoaded) {
          emit(HomeError(failure.message));
        }
    }
  }
}
