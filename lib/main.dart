import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AWS IoT MQTT Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'IoT MQTT Example'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  Map<String, String> payload = {
    "SID": "12341",
    "event": "lock",
  };

  void log(s) {
    debugPrint(s);
  }

  late MqttServerClient mqttClient;
  String inTopic = 'msg/${Config.clientId}/in';
  String inMsg = '';

  // MQTT 라이브러리 초기화
  void initMqttClient() {
    //AWS IoT Core URL, 장치 명, 포트
    mqttClient =
        MqttServerClient.withPort(Config.url, Config.clientId, Config.port);

    // Set secure
    mqttClient.secure = true;
    // Set Keep-Alive
    mqttClient.keepAlivePeriod = 20;
    // Set the protocol to V3.1.1 for AWS IoT Core, if you fail to do this you will not receive a connect ack with the response code
    mqttClient.setProtocolV311();
    // logging if you wish
    mqttClient.logging(on: false);
  }

  //연결 완료 콜백 함수
  void onConnected() {
    setState(() {});
    log('connected');
  }

  // 연결해제 콜백 함수
  void onDisconnected() {
    setState(() {});
    log('onDisconnected');
  }

  // 연결 및 연결 해제 함수
  Future<bool> connect() async {
    // 이미 연결된 상태라면  연결 해제
    if (mqttClient.connectionStatus!.state == MqttConnectionState.connected) {
      // 구독(subscribe) 해제
      mqttClient.unsubscribe(inTopic);
      // 연결 해제
      mqttClient.disconnect();
      return true;
    }

    final context = SecurityContext.defaultContext;

    // 인증 정보 설정
    context.setClientAuthoritiesBytes(Config.awsRootCA.codeUnits);
    context.useCertificateChainBytes(Config.certificatePem.codeUnits);
    context.usePrivateKeyBytes(Config.privateKey.codeUnits);

    mqttClient.securityContext = context;

    // Setup the connection Message
    final connMess =
        MqttConnectMessage().withClientIdentifier(Config.clientId).startClean();
    mqttClient.connectionMessage = connMess;
    mqttClient.onConnected = onConnected;
    mqttClient.onDisconnected = onDisconnected;

    // Connect the client
    try {
      log('MQTT client connecting to AWS IoT using certificates....');
      await mqttClient.connect();
      if (mqttClient.connectionStatus!.state != MqttConnectionState.connected) {
        return false;
      }
      log('subscribe topic $inTopic');

      // 받을 토픽 구독 설정
      mqttClient.subscribe(inTopic, MqttQos.atLeastOnce);

      // 구독한 토픽 메시지 처리 부분
      mqttClient.updates!.listen((List<MqttReceivedMessage<MqttMessage>> c) {
        final recMess = c[0].payload as MqttPublishMessage;
        final pt =
            MqttPublishPayload.bytesToStringAsString(recMess.payload.message);
        log('Received topic is ${c[0].topic} payload is <-- $pt -->');

        setState(() {
          inMsg += '[${DateTime.now().toString()}]\n$pt\n';
        });
      });
      return true;
    } on Exception catch (e) {
      log('MQTT client exception - $e');
      mqttClient.unsubscribe(inTopic);
      mqttClient.disconnect();
      return false;
    }
  }

  // 메시지 전송 함수
  Future<void> send() async {
    // 서버와 연결이 되어있는지 확인
    if (mqttClient.connectionStatus!.state != MqttConnectionState.connected) {
      return;
    }
    // 전송용 토픽!
    String topic = 'msg/${Config.clientId}/out';
    log('publish topic $topic');

    // 메시지 전송용 변수
    final builder = MqttClientPayloadBuilder();
    // 보낼 데이터 출력
    log(json.encode(payload));
    // json 형태 보낼 메시지 데이터를 문자열로 변환해 payload로 추가
    builder.addString(json.encode(payload));

    // MQTT 전송 Publish
    mqttClient.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);
  }

  @override
  void initState() {
    initMqttClient();
    super.initState();
  }

  void clearLog() {
    setState(() {
      inMsg = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    Color textColor = const Color(0xFF373737);
    String connnectBtnTxt =
        mqttClient.connectionStatus!.state != MqttConnectionState.connected
            ? "Connect"
            : "Disconnect";
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFE31A22),
        title: Text(widget.title, style: const TextStyle(color: Colors.white)),
      ),
      body: Center(
        child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const Expanded(
                flex: 1,
                child: SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: SizedBox(
                    width: double.infinity,
                    child: Text("Subscribe"),
                  ),
                ),
              ),
              Expanded(
                flex: 14,
                child: SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: SizedBox(
                    width: double.infinity,
                    child: Text(inMsg),
                  ),
                ),
              ),
            ]),
      ),
      floatingActionButton: FloatingActionButton(
          onPressed: clearLog, child: const Icon(Icons.cleaning_services)),
      bottomNavigationBar: BottomAppBar(
        surfaceTintColor: Colors.white,
        shadowColor: Colors.white,
        color: Colors.white60,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: <Widget>[
            BottomItem(
              icon: Icon(Icons.connect_without_contact_outlined,
                  color: textColor),
              title: Text(connnectBtnTxt, style: TextStyle(color: textColor)),
              onTap: () async {
                await connect();
                setState(() {});
              },
            ),
            BottomItem(
                icon: Icon(Icons.send_sharp, color: textColor),
                title: Text('Send', style: TextStyle(color: textColor)),
                onTap: send),
          ],
        ),
      ),
    );
  }
}

class Config {
  static const String awsRootCA =
      "-----BEGIN CERTIFICATE-----\nMIIDQTCCAimgAwIBAgITBmyfz5m/jAo54vB4ikPmljZbyjANBgkqhkiG9w0BAQsF\nADA5MQswCQYDVQQGEwJVUzEPMA0GA1UEChMGQW1hem9uMRkwFwYDVQQDExBBbWF6\nb24gUm9vdCBDQSAxMB4XDTE1MDUyNjAwMDAwMFoXDTM4MDExNzAwMDAwMFowOTEL\nMAkGA1UEBhMCVVMxDzANBgNVBAoTBkFtYXpvbjEZMBcGA1UEAxMQQW1hem9uIFJv\nb3QgQ0EgMTCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBALJ4gHHKeNXj\nca9HgFB0fW7Y14h29Jlo91ghYPl0hAEvrAIthtOgQ3pOsqTQNroBvo3bSMgHFzZM\n9O6II8c+6zf1tRn4SWiw3te5djgdYZ6k/oI2peVKVuRF4fn9tBb6dNqcmzU5L/qw\nIFAGbHrQgLKm+a/sRxmPUDgH3KKHOVj4utWp+UhnMJbulHheb4mjUcAwhmahRWa6\nVOujw5H5SNz/0egwLX0tdHA114gk957EWW67c4cX8jJGKLhD+rcdqsq08p8kDi1L\n93FcXmn/6pUCyziKrlA4b9v7LWIbxcceVOF34GfID5yHI9Y/QCB/IIDEgEw+OyQm\njgSubJrIqg0CAwEAAaNCMEAwDwYDVR0TAQH/BAUwAwEB/zAOBgNVHQ8BAf8EBAMC\nAYYwHQYDVR0OBBYEFIQYzIU07LwMlJQuCFmcx7IQTgoIMA0GCSqGSIb3DQEBCwUA\nA4IBAQCY8jdaQZChGsV2USggNiMOruYou6r4lK5IpDB/G/wkjUu0yKGX9rbxenDI\nU5PMCCjjmCXPI6T53iHTfIUJrU6adTrCC2qJeHZERxhlbI1Bjjt/msv0tadQ1wUs\nN+gDS63pYaACbvXy8MWy7Vu33PqUXHeeE6V/Uq2V8viTO96LXFvKWlJbYK8U90vv\no/ufQJVtMVT8QtPHRh8jrdkPSHCa2XV4cdFyQzR1bldZwgJcJmApzyMZFo6IQ6XU\n5MsI+yMRQ+hDKXJioaldXgjUkK642M4UwtBV8ob2xJNDd2ZhwLnoQdeXeGADbkpy\nrqXRfboQnoZsG4q5WTP468SQvvG5\n-----END CERTIFICATE-----";
  static const String privateKey =
      "-----BEGIN RSA PRIVATE KEY-----\nMIIEpAIBAAKCAQEAsCW8xkGOSxzsDNMrunKtnNkknp6p05yalxjXSZMRS7hIElmr\n/e06G6DRmV4yLSLAe24Q26qXsdx4aZFvupR7oWPUF8+3F7rdku/uNEdE2F9wJAfn\n4/keGBN3KbrUBEXRHtgbuipQVYopFhnAlLoGb/ZsH4a4BqZ7pNk5nPwgIOUlGxl/\nR8Co/Y7FOe6Gb5CQcMwDGuQlEbmjLBeMB1I43MPcwSYT87jMx/2DQvalEFrByhGQ\nO7CWTAzwYBd+eMgQI7baG6D7a1SGs8KblCztDZH7XotKskalV49/+oOcnnPMTL2R\nLzinr9uEGi7J+NeA9evwZaPZMRUVxG6zL7ODrQIDAQABAoIBAEIu667SEtTGGSr4\nbQWw8Opt7ARtOQH5ZVxASSOrzmPU6b97UdQmvh6DXj1x1wh+djPqNwtSHY0GeXew\n3XoNMCaDi70mnnScEYSUAbxCyutBcLEZB1fw0g3Zwnw7Zk30rY4ZRNG99FEviCB1\nrJY1DxYiUJ3H0H0vMGXP+IWzdZ7l2mTfTz2vuINF17LRi3wOd3tjGclN6jaEz64J\nULg4DYSaqzWAJuAsEVxt4+6XgNrcJRsYplVkmT8uAsZysf53KhmOel4mjBpS1Q8b\n+6g4F6tQnN9TGdS2lr54y/8qeYRVA5rJmr+Rr3qvBD6fsES4eJQh5zK/vW3Cgo3b\nkTcxLAECgYEA1vKTgFQhUnhrbxu2jPGPTAnFbjG4qEcNOY/uWwuDJ3zYJlptTX57\nEuesR2OARQ4nOXoqZpSIvfXQZfS6fNjOVetkWV6T04Wty9SQykI2untAZVJ5BWTy\nTG9QnFY9UiOH0cN1Ggz2xQeXARKkbYE2uLPiRvtAmNWLHhgQfGYZNnECgYEA0cob\nU/vIsU/CaVLaV4AQXhU963InypfzCxkoCjXFXENkJVl2cUmhBCSGdaFMS9tO+q4T\nZQ6sRGtz6YVBeOFAqpOOAy98KmIWBN+uy3RbAHeeLz+jOb5FbHuhFqA3EEXfwNFW\ni/9c17drnQDYjaibp1uLn42UfJlrMOQcr1tLFv0CgYEAiY3rPvCX8oMFnbEKfeAI\naAzIv+Ap3+a4W+H0E2emoxqN6N1tnW4XrN19rqHKcGbCS1IW2Fatu4MXvmeDAGpu\ngSWGrnqL941Qz2RU1FrTUzuU1kKVGBKlzKxf1eyKiYobXO3MfsNVGHnm9NTNTRan\nwkO7xtj7WdMumC+mPTXJZMECgYEAy9hWNYSxvZiCj1SyU9NcFA8P23dQsspynpYT\nEditrLjO1nvXWrzwd9YF0MaqHAs88teygL+BI/pE5uNUeuBktVoq422AeK5WNuYi\nMg8dXZbdXYu4TqNTUdXO8O08k9NRV0oRjnbS/8h6CFSKFxt+I2AQizhGz8tDHH6K\nYNmUXQECgYBC0cGlFdvnVN8eoNwMMG7Y1xcdIoXET00LdcDdoYL5mq16AuYVPIaF\n9g+QWXIT+DeZHOY3A+jzEWg3mtbeSx4j9Q2rH6IudHJkj7CDK+MIXiYMdEh1YBXe\neS/j05f6KjMz1RB1fEyb7DR2kJ6/+GCt8aWnP35I/KcK0TR9HKkTrA==\n-----END RSA PRIVATE KEY-----";
  static const String certificatePem =
      "-----BEGIN CERTIFICATE-----\nMIIDWjCCAkKgAwIBAgIVAPaxfs4HntRns87SB0kcwFveJAlPMA0GCSqGSIb3DQEB\nCwUAME0xSzBJBgNVBAsMQkFtYXpvbiBXZWIgU2VydmljZXMgTz1BbWF6b24uY29t\nIEluYy4gTD1TZWF0dGxlIFNUPVdhc2hpbmd0b24gQz1VUzAeFw0yNDA4MTgwMTQ1\nMTFaFw00OTEyMzEyMzU5NTlaMB4xHDAaBgNVBAMME0FXUyBJb1QgQ2VydGlmaWNh\ndGUwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQCwJbzGQY5LHOwM0yu6\ncq2c2SSenqnTnJqXGNdJkxFLuEgSWav97ToboNGZXjItIsB7bhDbqpex3HhpkW+6\nlHuhY9QXz7cXut2S7+40R0TYX3AkB+fj+R4YE3cputQERdEe2Bu6KlBViikWGcCU\nugZv9mwfhrgGpnuk2Tmc/CAg5SUbGX9HwKj9jsU57oZvkJBwzAMa5CURuaMsF4wH\nUjjcw9zBJhPzuMzH/YNC9qUQWsHKEZA7sJZMDPBgF354yBAjttoboPtrVIazwpuU\nLO0Nkftei0qyRqVXj3/6g5yec8xMvZEvOKev24QaLsn414D16/Blo9kxFRXEbrMv\ns4OtAgMBAAGjYDBeMB8GA1UdIwQYMBaAFBCp4tFw9/pRRgoCmKqIKy+31vQIMB0G\nA1UdDgQWBBQDafNMMb6bhtX/QgHyRp9BO9nbhTAMBgNVHRMBAf8EAjAAMA4GA1Ud\nDwEB/wQEAwIHgDANBgkqhkiG9w0BAQsFAAOCAQEAjS/WgqR6ZOkQ8FrxoPMYw+tQ\nssW7qfvwASUWyLuBn//XqWfYnaSmetoTg8Hu8o6Q1tDU2G/NO4M2ddLSdmUhj/rF\nQiFvTDIathV+3ldDiZVARYXFVQ5tLaUwo2uGf0FkHvddaiXMkoaN3r5sym79mRxu\nucsBxLsB1gU1ChygFm6UKgFB/D+YaVDgcileSqTNUeNGOVENJLi+mNIQtidyjbKP\nF9t2c5ittMKEr2b7d7JChJG83nyIsPS1GC1+6Wp70CxCYLrLMdUsWNBrs+cp8FCC\nOadlHJQirj2TAi0NIxTSrWj9Vqv7kwaiEOfoGLgZiG2Sdl9v/YcL4t0QeTQ0Dw==\n-----END CERTIFICATE-----";
  static const String url =
      'aeok7kh8f0w9l-ats.iot.ap-northeast-1.amazonaws.com';
  static const int port = 8883;
  static const String clientId = 'flutter_iot_client';
}

// 바닥쪽 버튼 위젯 클래스
class BottomItem extends StatelessWidget {
  final icon;
  final title;
  final onTap;
  const BottomItem({super.key, this.icon, this.title, this.onTap});
  @override
  Widget build(BuildContext context) {
    return Container(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          highlightColor: Colors.transparent,
          child: Container(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                icon,
                title,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
