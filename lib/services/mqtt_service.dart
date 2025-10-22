// lib/services/mqtt_service.dart

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import '../models/gate_state.dart';

typedef StateCallback = void Function(GateState state);

class MqttService {
  // ===== Konfigurácia MQTT =====
  static const String broker = '156487bb403d488faa726afdc377fd98.s1.eu.hivemq.cloud';
  static const int portTls = 8883; // Android/iOS/desktop
  static const int portWss = 8884; // Web (WSS)
  static const String username = 'application';
  static const String password = 'BranaApp!456';
  static const String deviceId = 'gate01';

  String get _topicState => 'gate/$deviceId/state';
  String get _topicCmd => 'gate/$deviceId/cmd';
  String get _topicClients => 'gate/$deviceId/clients';

  MqttServerClient? _client;

  bool get isConnected =>
      _client?.connectionStatus?.state == MqttConnectionState.connected;

  // ---- stav brány ----
  GateState _currentState = GateState.unknown;
  GateState get currentState => _currentState;

  final _stateCtl = StreamController<GateState>.broadcast();
  Stream<GateState> get state$ => _stateCtl.stream;

  final _connCtl = StreamController<bool>.broadcast();
  Stream<bool> get connected$ => _connCtl.stream;

  StateCallback? onStateUpdate;

  Timer? _reconnectTimer;
  bool _isConnecting = false;
  bool _explicitDisconnect = false;
  int _retry = 0;

  // === Public API ===
  Future<void> connect() async {
    if (isConnected || _isConnecting) return;
    _isConnecting = true;
    _explicitDisconnect = false;

    final client = MqttServerClient(broker, _newClientId());
    client.logging(on: false);
    client.keepAlivePeriod = 30;
    client.connectTimeoutPeriod = 8000;
    client.resubscribeOnAutoReconnect = true;
    client.onConnected = _onConnected;
    client.onDisconnected = _onDisconnected;

    if (kIsWeb) {
      client.useWebSocket = true;
      client.secure = true;
      client.port = portWss;
      client.websocketProtocols = ['mqtt'];
    } else {
      client.secure = true;
      client.port = portTls;
    }

    final willStr = jsonEncode({'client': client.clientIdentifier, 'status': 'offline'});
    client.connectionMessage = MqttConnectMessage()
        .withClientIdentifier(client.clientIdentifier)
        .withWillTopic(_topicClients)
        .withWillMessage(willStr)
        .withWillQos(MqttQos.atLeastOnce)
        .startClean()
        .authenticateAs(username, password);

    _client = client;

    try {
      final status = await client.connect();
      if (status?.state != MqttConnectionState.connected) {
        throw Exception('MQTT connect failed: ${status?.state}');
      }

      client.subscribe(_topicState, MqttQos.atLeastOnce);
      client.updates?.listen(_onMessage);
    } catch (e) {
      print('MQTT connection error: $e');
      _scheduleReconnect();
    } finally {
      _isConnecting = false;
    }
  }

  void disconnect() {
    _explicitDisconnect = true;
    _reconnectTimer?.cancel();
    try {
      _client?.disconnect();
    } catch (_) {}
    _client = null;
  }

  // ---- Guardy na príkazy ----
  bool get isMoving => _currentState == GateState.moving;
  bool get canOpen  => isConnected && !isMoving && _currentState != GateState.open && _currentState != GateState.unknown;
  bool get canClose => isConnected && !isMoving && _currentState != GateState.closed && _currentState != GateState.unknown;

  Future<void> sendOpenCommand() async {
    if (!canOpen) return;
    _publishCmd('open');
  }

  Future<void> sendCloseCommand() async {
    if (!canClose) return;
    _publishCmd('close');
  }

  Future<void> sendToggleCommand() async {
    if (!isConnected || isMoving) return;
    _publishCmd('toggle');
  }

  // === interné ===
  void _publishCmd(String cmd) {
    final c = _client;
    if (c == null || !isConnected) return;
    final b = MqttClientPayloadBuilder()..addUTF8String(jsonEncode({'cmd': cmd}));
    c.publishMessage(_topicCmd, MqttQos.atLeastOnce, b.payload!);
  }

  void _onMessage(List<MqttReceivedMessage<MqttMessage>> events) {
    for (final m in events) {
      final msg = m.payload;
      if (msg is! MqttPublishMessage) continue;
      final payload = MqttPublishPayload.bytesToStringAsString(msg.payload.message);

      String? stateStr;
      try {
        final d = jsonDecode(payload);
        if (d is Map && d['state'] is String) {
          stateStr = d['state'] as String;
        }
      } catch (_) {
        stateStr = payload;
      }

      if (stateStr != null) {
        final newState = GateState.fromString(stateStr);
        if (newState != _currentState) {
          _currentState = newState;
          _stateCtl.add(newState);
          onStateUpdate?.call(newState);
          print('📡 Stav brány: ${newState.label}');
        }
      }
    }
  }

  void _onConnected() {
    _retry = 0;
    _connCtl.add(true);
    print('✅ MQTT connected');

    try {
      _client?.subscribe(_topicState, MqttQos.atLeastOnce);
    } catch (e) {
      print('Error on connect callback: $e');
    }

    // Po pripojení sa spýtať na aktuálny stav
    Future.delayed(const Duration(seconds: 1), () {
      print('Requesting gate status...');
      _publishCmd('status');
    });
  }

  void _onDisconnected() {
    _connCtl.add(false);
    print('⚠️ MQTT disconnected');
    if (!_explicitDisconnect) _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_isConnecting) return;
    _retry = (_retry + 1).clamp(1, 6);
    final d = Duration(seconds: 1 << (_retry - 1));
    print('⏳ Reconnecting in ${d.inSeconds}s...');
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(d, connect);
  }

  String _newClientId() =>
      'flutter_${DateTime.now().millisecondsSinceEpoch}_${kIsWeb ? 'web' : 'app'}';
}
