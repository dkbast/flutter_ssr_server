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
  // If the "PORT" environment variable is set, listen to it. Otherwise, 8080.
  // https://cloud.google.com/run/docs/reference/container-contract#port
  final port = int.parse(Platform.environment['PORT'] ?? '8081');

  // See https://pub.dev/documentation/shelf/latest/shelf/Cascade-class.html
  final cascade = Cascade()
      // If a corresponding file is not found, send requests to a `Router`
      .add(_router.call);

  // See https://pub.dev/documentation/shelf/latest/shelf_io/serve.html
  final server = await shelf_io.serve(
    // See https://pub.dev/documentation/shelf/latest/shelf/logRequests.html
    logRequests()
        // See https://pub.dev/documentation/shelf/latest/shelf/MiddlewareExtensions/addHandler.html
        .addHandler(cascade.handler),
    InternetAddress.anyIPv4, // Allows external connections
    port,
  );

  print('Serving at http://${server.address.host}:${server.port}');

  // Used for tracking uptime of the demo server.
  _watch.start();

  runApp(MaterialApp(home: Scaffold(body: const MainApp())));
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  //Create an instance of ScreenshotController
  ScreenshotController screenshotController = ScreenshotController();
  @override
  void initState() {
    super.initState();
    imageService.renderWidgetCallback = (String text) async {
      final result = await screenshotController.captureFromWidget(
          InheritedTheme.captureAll(context, DemoWidget(text: text)));
      return result;
    };
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: DemoWidget(text: '42'),
    );
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

// Router instance to handler requests.
final _router = shelf_router.Router()..get('/ssr', _ssrHandler);

final _watch = Stopwatch();

Future<Response> _ssrHandler(Request request) async {
  final Uint8List? testImg = await imageService.renderWidget('42');

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
