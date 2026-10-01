enum SimulationMode { normal, alert, alertMedium, paralysis }

abstract class TransmitterState {
  final double multiplier;
  final SimulationMode simulationMode;
  const TransmitterState(this.multiplier, this.simulationMode);
}

class TransmitterInitial extends TransmitterState {
  const TransmitterInitial() : super(1.0, SimulationMode.normal);
}

class TransmitterRunning extends TransmitterState {
  final double currentMagnitude;

  const TransmitterRunning({
    required this.currentMagnitude,
    required double multiplier,
    required SimulationMode simulationMode,
  }) : super(multiplier, simulationMode);
}

class TransmitterStopped extends TransmitterState {
  const TransmitterStopped({
    required double multiplier,
    required SimulationMode simulationMode,
  }) : super(multiplier, simulationMode);
}
