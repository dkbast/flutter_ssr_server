// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:screenshot/screenshot.dart';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart' as shelf_router;

/// singleton which can request a screenshot from the flutter app and returns
/// an image to an enpoint
class ImageService {
  Future<Uint8List> Function(String text)? renderWidgetCallback;

  Future<Uint8List?> renderWidget(String text) async {
    final result = await renderWidgetCallback?.call(text);
    return result;
  }
}

final imageService = ImageService();

void main() async {
  final cascade = Cascade()
      // If a corresponding file is not found, send requests to a `Router`
      .add(_router.call);

  final server = await shelf_io.serve(
    logRequests().addHandler(cascade.handler),
    InternetAddress.anyIPv4, // Allows external connections
    8081,
  );

  print('Serving at http://${server.address.host}:${server.port}/ssr?text=42');

  runApp(const MaterialApp(home: Material(child: MainApp())));
}

// Router instance to handler requests.
final _router = shelf_router.Router()..get('/ssr', _ssrHandler);

Future<Response> _ssrHandler(Request request) async {
  final text = request.url.queryParameters['text'] ?? 'default';
  final Uint8List? testImg = await imageService.renderWidget(text);

  if (testImg == null) return Response.internalServerError();

  final response = Response(
    200,
    headers: {
      'Content-Type': 'image/png',
      'Content-Length': testImg.length.toString(),
    },
    body: testImg,
  );
  return response;
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  ScreenshotController screenshotController = ScreenshotController();
  @override
  void initState() {
    super.initState();
    imageService.renderWidgetCallback = (String text) async {
      return await screenshotController.captureFromWidget(
        InheritedTheme.captureAll(context, DemoWidget(text: text)),
      );
    };
  }

  @override
  Widget build(BuildContext context) {
    return const Text('The rendering is done in the background');
  }
}

class DemoWidget extends StatelessWidget {
  const DemoWidget({
    super.key,
    required this.text,
  });

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
        padding: const EdgeInsets.all(30.0),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.blueAccent, width: 5.0),
          color: Colors.redAccent,
        ),
        child: Text("This is an invisible widget $text"));
  }
}
