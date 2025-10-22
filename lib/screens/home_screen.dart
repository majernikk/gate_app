// lib/screens/home_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/mqtt_service.dart';
import '../models/gate_state.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final MqttService _mqtt;
  late StreamSubscription<GateState> _stateSub;
  late StreamSubscription<bool> _connSub;

  GateState _state = GateState.unknown;
  bool _connected = false;
  bool _waitingForOpen = false;
  bool _waitingForClose = false;

  @override
  void initState() {
    super.initState();
    _mqtt = MqttService()..onStateUpdate = _onState;
    _mqtt.connect();

    _stateSub = _mqtt.state$.listen(_onState);
    _connSub = _mqtt.connected$.listen((c) {
      setState(() => _connected = c);
    });
  }

  void _onState(GateState s) {
    setState(() => _state = s);
    final messenger = ScaffoldMessenger.of(context);

    if (_waitingForOpen && s == GateState.open) {
      _waitingForOpen = false;
      messenger.clearSnackBars();
      messenger.showSnackBar(const SnackBar(content: Text('Brána je otvorená.')));
    }

    if (_waitingForClose && s == GateState.closed) {
      _waitingForClose = false;
      messenger.clearSnackBars();
      messenger.showSnackBar(const SnackBar(content: Text('Brána je zatvorená.')));
    }
  }

  @override
  void dispose() {
    _stateSub.cancel();
    _connSub.cancel();
    _mqtt.disconnect();
    super.dispose();
  }

  void _openGate() {
    if (!_mqtt.canOpen) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bránu už nie je možné otvoriť.')),
      );
      return;
    }
    _waitingForOpen = true;
    _showProgress('Brána sa otvára…');
    _mqtt.sendOpenCommand();
  }

  void _closeGate() {
    if (!_mqtt.canClose) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bránu už nie je možné zatvoriť.')),
      );
      return;
    }
    _waitingForClose = true;
    _showProgress('Brána sa zatvára…');
    _mqtt.sendCloseCommand();
  }

  void _showProgress(String text) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        duration: const Duration(days: 1),
        content: Row(
          children: [
            const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
            const SizedBox(width: 12),
            Text(text),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthService>();
    final canOpen = _mqtt.canOpen;
    final canClose = _mqtt.canClose;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Garážová brána'),
        actions: [
          IconButton(onPressed: auth.logout, icon: const Icon(Icons.logout), tooltip: 'Odhlásiť'),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(_connected ? Icons.wifi : Icons.wifi_off),
                  const SizedBox(width: 8),
                  Text(_connected ? 'Pripojené' : 'Nepripojené'),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Stav brány: ${_state.label}',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: [
                  FilledButton.icon(
                    onPressed: canOpen ? _openGate : null,
                    icon: const Icon(Icons.garage_outlined),
                    label: const Text('Otvoriť'),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: canClose ? _closeGate : null,
                    icon: const Icon(Icons.garage),
                    label: const Text('Zavrieť'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (_mqtt.isMoving)
                const Padding(
                  padding: EdgeInsets.only(top: 8.0),
                  child: Text('Prebieha pohyb…', style: TextStyle(fontStyle: FontStyle.italic)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
