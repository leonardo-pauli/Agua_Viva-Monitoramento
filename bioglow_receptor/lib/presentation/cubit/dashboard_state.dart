import '../../domain/entities/vibration_entity.dart';

abstract class DashboardState {
  final List<VibrationEntity> chartData;
  const DashboardState({this.chartData = const []});
}

class DashboardLoading extends DashboardState {}

class DashboardNormalState extends DashboardState {
  const DashboardNormalState({super.chartData});
}

class DashboardAlertState extends DashboardState {
  const DashboardAlertState({super.chartData});
}

class DashboardErrorState extends DashboardState {
  final String message;
  const DashboardErrorState(this.message) : super();
}

class DashboardWarningState extends DashboardState {
  const DashboardWarningState({super.chartData});
}

class DashboardFaultState extends DashboardState {
  const DashboardFaultState({super.chartData});
}

