import 'package:flutter/material.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Image.network(
              'http://0.0.0.0:8181/ssr?width=$width&height=$height'),
        ),
      ),
    );
  }
}
