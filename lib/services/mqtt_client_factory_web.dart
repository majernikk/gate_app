import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_browser_client.dart';

MqttClient createMqttClient({
  required String broker,
  required String clientId,
  required int portTls,
  required int portWss,
}) {
  final url = 'wss://$broker/mqtt';
  final c = MqttBrowserClient.withPort(url, clientId, portWss); // 8884
  c.websocketProtocols = const ['mqtt'];
  return c;
}
