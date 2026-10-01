import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/vibration_entity.dart';
import '../../domain/repositories/vibration_repository.dart';
import '../../domain/usecases/export_history_usecase.dart';
import 'history_state.dart';

class HistoryCubit extends Cubit<HistoryState> {
  final VibrationRepository _repository;
  final ExportHistoryUseCase _exportUseCase;
  StreamSubscription? _subscription;
  
  static const double thresholdWarning = 15.0;
  static const double thresholdAlert = 25.0;

  HistoryCubit(this._repository, this._exportUseCase) : super(const HistoryLoading()) {
    _startListening();
  }

  void _startListening() {
    _subscription = _repository.getVibrationStream().listen(
      (vibrations) {
        if (state is HistoryLoaded) {
          emit((state as HistoryLoaded).copyWith(data: vibrations));
        } else {
          emit(HistoryLoaded(data: vibrations, filter: HistoryFilter.all));
        }
      },
      onError: (error) {
        emit(HistoryError(error.toString()));
      },
    );
  }

  void changeFilter(HistoryFilter newFilter) {
    if (state is HistoryLoaded) {
      emit((state as HistoryLoaded).copyWith(filter: newFilter));
    }
  }

  // Lógica de filtragem limpa e centralizada no Cubit
  List<VibrationEntity> get filteredData {
    if (state.filter == HistoryFilter.alerts) {
      return state.data.where((v) => v.magnitude > thresholdWarning).toList();
    }
    return state.data;
  }

  Future<String> exportReport() async {
    try {
      // Exporta sempre do mais recente para o mais antigo, usando a lista filtrada
      final path = await _exportUseCase(filteredData.reversed.toList());
      return path;
    } catch (e) {
      throw Exception('Falha ao exportar: $e');
    }
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}
