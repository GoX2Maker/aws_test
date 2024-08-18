import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  TextEditingController controller = TextEditingController();
  String sendData = 'Hello World';

  @override
  void initState() {
    super.initState();
    controller.text = sendData;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: SafeArea(
        bottom: false,
        child: Scaffold(
          body: Column(
            children: [
              Center(
                child: TextField(
                  controller: controller,
                  decoration: const InputDecoration(
                    hintText: 'Enter your name',
                  ),
                  onChanged: (value) {
                    setState(() {
                      sendData = value;
                    });
                  },
                ),
              ),
              TextButton(onPressed: () {}, child: const Text('Send Data')),
            ],
          ),
        ),
      ),
    );
  }
}
