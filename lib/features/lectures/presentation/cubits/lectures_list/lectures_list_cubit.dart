import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/network/api_result.dart';
import '../../../domain/usecases/get_student_lectures_usecase.dart';
import 'lectures_list_state.dart';

class LecturesListCubit extends Cubit<LecturesListState> {
  final GetStudentLecturesUseCase _getStudentLecturesUseCase;

  LecturesListCubit(this._getStudentLecturesUseCase) : super(const LecturesListInitial());

  Future<void> loadLectures() async {
    debugPrint('[Q360-CUBIT] LecturesListCubit: Loading student lectures...');
    emit(const LecturesListLoading());
    final result = await _getStudentLecturesUseCase();

    switch (result) {
      case ApiSuccess(:final data):
        debugPrint('[Q360-CUBIT] LecturesListCubit: Successfully loaded ${data.length} lectures');
        emit(LecturesListLoaded(data));
      case ApiError(:final failure):
        debugPrint('[Q360-CUBIT] LecturesListCubit: Error loading lectures: ${failure.message}');
        emit(LecturesListError(failure.message));
    }
  }
}
