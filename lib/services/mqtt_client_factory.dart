import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

MqttClient createMqttClient({
  required String broker,
  required String clientId,
  required int portTls,
  required int portWss,
}) {
  final c = MqttServerClient(broker, clientId);
  c.secure = true;
  c.port = portTls; // 8883
  return c;
}
