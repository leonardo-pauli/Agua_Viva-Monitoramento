import '../../domain/entities/vibration_entity.dart';

enum HistoryFilter { all, alerts }

abstract class HistoryState {
  final List<VibrationEntity> data;
  final HistoryFilter filter;

  const HistoryState({
    required this.data,
    this.filter = HistoryFilter.all,
  });
}

class HistoryLoading extends HistoryState {
  const HistoryLoading() : super(data: const []);
}

class HistoryLoaded extends HistoryState {
  const HistoryLoaded({
    required super.data,
    super.filter = HistoryFilter.all,
  });

  HistoryLoaded copyWith({
    List<VibrationEntity>? data,
    HistoryFilter? filter,
  }) {
    return HistoryLoaded(
      data: data ?? this.data,
      filter: filter ?? this.filter,
    );
  }
}

class HistoryError extends HistoryState {
  final String message;
  const HistoryError(this.message) : super(data: const []);
}
