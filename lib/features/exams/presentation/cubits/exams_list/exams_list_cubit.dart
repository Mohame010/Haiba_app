import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/network/api_result.dart';
import '../../../domain/usecases/get_exams_usecase.dart';
import 'exams_list_state.dart';

class ExamsListCubit extends Cubit<ExamsListState> {
  final GetExamsUseCase _getExamsUseCase;

  ExamsListCubit(this._getExamsUseCase) : super(const ExamsListInitial());

  Future<void> loadExams() async {
    emit(const ExamsListLoading());
    final result = await _getExamsUseCase();

    switch (result) {
      case ApiSuccess(:final data):
        emit(ExamsListLoaded(data));
      case ApiError(:final failure):
        emit(ExamsListError(failure.message));
    }
  }
}
