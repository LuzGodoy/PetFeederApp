import 'dart:async';
import 'dart:core';

import 'package:flutter/material.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

class AppProvider extends ChangeNotifier {
  final MqttServerClient client = MqttServerClient(
    'test.mosquitto.org',
    'arquitectura_avanzada_2024',
  );

  final _mqttStream = StreamController<bool>();
  final senderEmail = 'petfeeder.bot@gmail.com';
  final senderPassword = 'wffu rjjj plvc gocv';
  String? configuredEmail;

  Stream<bool> get mqttConnectedStream => _mqttStream.stream;

  Future<void> connectMqttClient() async {
    MqttClientConnectionStatus? status;
    try {
      print('Connecting');
      status = await client.connect();
    } catch (e) {
      print('Exception: $e');
    }
    if (status?.state == MqttConnectionState.connected) {
      print('Connected!');
      _mqttStream.add(true);
    } else {
      _mqttStream.add(false);
      print('Not conected');
    }
  }
}
