import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:mailer/smtp_server/gmail.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:pet_feeder/provider.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const mainColor = Color.fromARGB(255, 0, 169, 181);
  static const feedTopic = 'pet-feeder/feed/';
  static const statusTopic = 'pet-feeder/check-status/';
  static const calendarTopic = 'pet-feeder/setCalendar/';
  static const alertTopic = 'pet-feeder/sendAlert/';

  late final AppProvider _provider;
  late final MqttServerClient _mqttClient;
  final subscriptions = [];
  final List<String> _days = [
    'Domingo',
    'Lunes',
    'Martes',
    'Miercoles',
    'Jueves',
    'Viernes',
    'Sabado'
  ];
  final List<bool> _selectedCheckBoxes = [];

  bool connectionError = false;
  bool loading = true;
  double _foodLevel = 0;
  TimeOfDay? _selectedHour;

  @override
  void initState() {
    super.initState();
    _provider = context.read<AppProvider>();
    for (var i = 0; i < 7; i++) {
      _selectedCheckBoxes.add(false);
    }

    _provider.connectMqttClient();
    _mqttClient = _provider.client;
    _provider.mqttConnectedStream.listen(
      (bool isClientConnected) {
        if (isClientConnected) {
          _mqttClient.subscribe(statusTopic, MqttQos.exactlyOnce);
          _mqttClient.subscribe(alertTopic, MqttQos.exactlyOnce);
          subscriptions.add(
            _mqttClient.updates?.listen(
              (eventList) async {
                final message = eventList.first.payload as MqttPublishMessage;
                final topic = eventList.first.topic;
                if (topic == statusTopic) {
                  final payload = double.tryParse(
                        MqttPublishPayload.bytesToStringAsString(
                          message.payload.message,
                        ),
                      ) ??
                      _foodLevel;
                  if (_foodLevel - 3 > payload || payload > _foodLevel + 3) {
                    _foodLevel = payload;
                    if (mounted) {
                      setState(() {});
                    }
                  }
                } else if (topic == alertTopic) {
                  _sendEmail();
                }
              },
            ),
          );
        } else {
          connectionError = true;
        }

        loading = false;
        if (mounted) {
          setState(() {});
        }
      },
    );
  }

  @override
  void dispose() {
    super.dispose();
    subscriptions.forEach(
      (subscription) => subscription.close(),
    );
  }

  Future<void> _sendEmail() async {
    if (_provider.configuredEmail != null) {
      final smtpServer = gmail(
        _provider.senderEmail,
        _provider.senderPassword,
      );

      final message = Message()
        ..from = Address(_provider.senderEmail, 'Pet Feeder')
        ..recipients = [_provider.configuredEmail]
        ..subject = 'Alerta: Rellena el Pet Feeder'
        ..text =
            'Querido dueño:\nYa no hay alimento en el pet feeder. Recorda rellenarlo.\nAtte. Tu Amigo Peludo.';
      try {
        await send(message, smtpServer);
      } catch (e) {
        print(e);
      }
    }
  }

  String _getSelectedHourString() {
    final int selectedHour = _selectedHour?.hour ?? 0;
    final String hour =
        selectedHour < 10 ? '0$selectedHour' : selectedHour.toString();
    final int selectedMinute = _selectedHour?.minute ?? 0;
    final String minute =
        selectedMinute < 10 ? '0$selectedMinute' : selectedMinute.toString();

    return '$hour:$minute';
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: mainColor,
      title: const Row(
        children: [
          Padding(
            padding: EdgeInsets.only(right: 2.0),
            child: Icon(
              Icons.pets_rounded,
              color: Colors.white,
            ),
          ),
          Text(
            'Pet Feeder',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 24.0,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          onPressed: () async {
            final controller = TextEditingController();

            await showDialog(
              context: context,
              builder: (_) => Dialog(
                child: _buildDialog(controller),
              ),
            );
          },
          icon: const Icon(
            Icons.email_outlined,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildCalendar() {
    return Container(
      height: 580,
      margin: const EdgeInsets.only(bottom: 100.0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16.0),
        color: mainColor,
      ),
      width: double.infinity,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Configurar calendario',
              style: TextStyle(
                fontSize: 20.0,
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Text(
              'Elegí los días y el horario para alimentar a tu amigo peludo!',
              style: TextStyle(
                fontSize: 12.0,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16.0),
            Expanded(
              child: ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                itemCount: 7,
                itemBuilder: (context, i) {
                  return Row(
                    children: [
                      Checkbox(
                        checkColor: Colors.white,
                        activeColor: Colors.amber,
                        side: const BorderSide(color: Colors.white, width: 2.0),
                        value: _selectedCheckBoxes[i],
                        onChanged: (status) {
                          _selectedCheckBoxes[i] = status!;

                          if (mounted) {
                            setState(() {});
                          }
                        },
                      ),
                      const SizedBox(width: 8.0),
                      Text(
                        _days[i],
                        style: const TextStyle(
                          fontSize: 16.0,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            const Text(
              'Seleccioná la hora',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16.0,
                fontWeight: FontWeight.bold,
              ),
            ),
            FilledButton(
              style: const ButtonStyle(
                  backgroundColor: WidgetStatePropertyAll(
                Colors.white,
              )),
              onPressed: () async {
                final TimeOfDay? newTime = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay(
                    hour: _selectedHour?.hour ?? 0,
                    minute: _selectedHour?.minute ?? 0,
                  ),
                  initialEntryMode: TimePickerEntryMode.input,
                );
                if (newTime != null) {
                  _selectedHour = newTime;
                  if (mounted) {
                    setState(() {});
                  }
                }
              },
              child: Text(
                _getSelectedHourString(),
                style: TextStyle(color: Colors.black),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                FilledButton(
                  style: const ButtonStyle(
                    backgroundColor: WidgetStatePropertyAll(Colors.amber),
                    padding: WidgetStatePropertyAll(
                      EdgeInsets.symmetric(
                        horizontal: 24.0,
                        vertical: 16.0,
                      ),
                    ),
                  ),
                  child: const Text(
                    'Guardar configuración',
                    style: TextStyle(
                      fontSize: 16.0,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onPressed: () {
                    // TODO: send mqtt message
                    //{"Domingo":true,"Lunes":true,"Martes":true,"Miercoles":true,"Jueves":true,"Sabado":true,"Viernes":false,"Hora":"1970-01-02T02:24:00.000Z"}
                    final Map<String, dynamic> body = {};
                    for (var i = 0; i < 7; i++) {
                      final day = _days[i];
                      final isSelected = _selectedCheckBoxes[i];
                      body[day] = isSelected;
                    }
                    final time = _getSelectedHourString();
                    body['Hora'] = '1970-01-02T$time:00.000Z';
                    final payload = jsonEncode(body);
                    final builder = MqttClientPayloadBuilder();
                    builder.addString(payload);
                    _mqttClient.publishMessage(
                      calendarTopic,
                      MqttQos.atLeastOnce,
                      builder.payload!,
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDialog(TextEditingController controller) {
    return SizedBox(
      height: 300.0,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16.0),
        child: Scaffold(
          appBar: AppBar(
            leading: const CloseButton(
              color: Colors.white,
            ),
            title: const Text(
              'Email',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            centerTitle: true,
            backgroundColor: mainColor,
            elevation: 5.0,
          ),
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: SingleChildScrollView(
              controller: ScrollController(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(
                    height: 10.0,
                  ),
                  const Text(
                    'Configura un email para enviar alertas',
                    style: TextStyle(
                      fontSize: 16.0,
                    ),
                  ),
                  const SizedBox(
                    height: 20.0,
                  ),
                  TextFormField(
                    decoration: const InputDecoration(
                      hintText: 'Email',
                    ),
                    controller: controller,
                    onChanged: (value) {
                      if (mounted) {
                        setState(() {});
                      }
                    },
                  ),
                  const SizedBox(
                    height: 60.0,
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      FilledButton(
                        style: const ButtonStyle(
                          backgroundColor: WidgetStatePropertyAll(mainColor),
                        ),
                        onPressed: () {
                          if (controller.text.isNotEmpty) {
                            _provider.configuredEmail = controller.text;
                            Navigator.of(context).pop();
                          }
                        },
                        child: const Text(
                          'Guardar',
                        ),
                      ),
                    ],
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFoodLevel() {
    return Container(
      decoration: const BoxDecoration(
        color: mainColor,
        shape: BoxShape.circle,
      ),
      height: 250.0,
      width: 250.0,
      child: SfRadialGauge(
        axes: [
          RadialAxis(
            annotations: <GaugeAnnotation>[
              GaugeAnnotation(
                angle: 90,
                widget: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Nivel de comida',
                      style: TextStyle(fontSize: 16.0, color: Colors.white),
                    ),
                    Text(
                      '${_foodLevel.toStringAsFixed(0)}%',
                      style: const TextStyle(
                        fontSize: 40.0,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            minimum: 0,
            maximum: 100,
            showLabels: false,
            showTicks: false,
            startAngle: 270,
            endAngle: 270,
            axisLineStyle: const AxisLineStyle(
              thickness: 0.15,
              color: Color.fromARGB(255, 138, 228, 235),
              thicknessUnit: GaugeSizeUnit.factor,
            ),
            pointers: <GaugePointer>[
              RangePointer(
                value: _foodLevel,
                width: 0.15,
                color: Colors.white,
                cornerStyle: CornerStyle.bothCurve,
                sizeUnit: GaugeSizeUnit.factor,
              )
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeedButton() {
    return FilledButton(
      style: const ButtonStyle(
        backgroundColor: WidgetStatePropertyAll(Colors.amber),
        padding: WidgetStatePropertyAll(
          EdgeInsets.symmetric(
            horizontal: 24.0,
            vertical: 16.0,
          ),
        ),
      ),
      child: const Text(
        'Servir alimento',
        style: TextStyle(
          fontSize: 20.0,
          fontWeight: FontWeight.bold,
        ),
      ),
      onPressed: () {
        final builder = MqttClientPayloadBuilder();
        builder.addString('Hello MQTT');
        _mqttClient.publishMessage(
          feedTopic,
          MqttQos.atLeastOnce,
          builder.payload!,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('asset/background3.jpg'),
            fit: BoxFit.cover,
          ),
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
          child: Center(
            child: loading
                ? const CircularProgressIndicator()
                : SingleChildScrollView(
                    controller: ScrollController(),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Column(
                        children: [
                          const SizedBox(height: 30.0),
                          _buildFoodLevel(),
                          const SizedBox(height: 30.0),
                          _buildFeedButton(),
                          const SizedBox(height: 30.0),
                          _buildCalendar(),
                        ],
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
