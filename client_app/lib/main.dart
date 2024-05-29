import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  Uint8List? image;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      refreshImage();
    });
  }

  Future<void> refreshImage() async {
    final response = await http
        .get(Uri.parse('http://0.0.0.0:8181/ssr?width=$width&height=$height'));
    if (response.statusCode == 200) {
      setState(() {
        image = response.bodyBytes;
      });
    }
  }

  Future<void> tap(double x, double y) async {
    final response = await http.get(Uri.parse(
        'http://0.0.0.0:8181/ssr?width=$width&height=$height&x=$x&y=$y'));
    if (response.statusCode == 200) {
      setState(() {
        image = response.bodyBytes;
      });
    }
  }

  double width = 0;
  double height = 0;

  @override
  Widget build(BuildContext context) {
    width = MediaQuery.of(context).size.width;
    height = MediaQuery.of(context).size.height;

    return GestureDetector(
        onTapUp: (details) {
          var position = details.globalPosition;
          print('tap at $position');
          tap(position.dx, position.dy);
        },
        child: image == null
            ? const CircularProgressIndicator()
            : Image.memory(image!));
  }
}
