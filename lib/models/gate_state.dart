// lib/models/gate_state.dart

enum GateState {
  open,
  closed,
  moving,
  unknown;

  static GateState fromString(String raw) {
    final s = raw.trim().toLowerCase();
    switch (s) {
      case 'open':
      case 'opened':
        return GateState.open;
      case 'closed':
      case 'close':
        return GateState.closed;
      case 'moving':
      case 'opening':
      case 'closing':
        return GateState.moving;
      default:
        return GateState.unknown;
    }
  }

  String get label {
    switch (this) {
      case GateState.open:
        return 'Otvorená';
      case GateState.closed:
        return 'Zatvorená';
      case GateState.moving:
        return 'Prebieha pohyb';
      case GateState.unknown:
        return 'Neznámy';
    }
  }
}
