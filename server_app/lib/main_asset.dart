import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:screenshot/screenshot.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_flutter_asset/shelf_flutter_asset.dart';

import 'package:shelf_router/shelf_router.dart' as shelf_router;

final imageService = ImageService();

final _router = shelf_router.Router()..get('/ssr', _ssrHandler);

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, DELETE, OPTIONS',
  'Access-Control-Allow-Headers': 'Origin, Content-Type',
};

void main() async {
  final assetHandler = createAssetHandler(defaultDocument: 'index.html');

  final webserver = await io.serve(
      assetHandler,
      InternetAddress.anyIPv4, // Allows external connections
      8080);

  const ssrPort = 8181;
  final cascade = Cascade()
      // If a corresponding file is not found, send requests to a `Router`
      .add(_router.call);
  final server = await io.serve(
    // See https://pub.dev/documentation/shelf/latest/shelf/logRequests.html
    logRequests()
        // See https://pub.dev/documentation/shelf/latest/shelf/MiddlewareExtensions/addHandler.html
        .addHandler(cascade.handler),
    InternetAddress.anyIPv4, // Allows external connections
    ssrPort,
  );

  print('Web at http://${webserver.address.host}:${webserver.port}');
  print('Api at http://${server.address.host}:${server.port}/ssr');

  runApp(const MaterialApp(home: Scaffold(body: Center(child: MainApp()))));
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
        child: Text("This is my demo widget $text"));
  }
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  int width = 800;
  int height = 800;

  //Create an instance of ScreenshotController
  ScreenshotController screenshotController = ScreenshotController();
  @override
  void initState() {
    super.initState();
    imageService.renderWidgetCallback = (int width, int height) async {
      setState(() {
        this.width = width;
        this.height = height;
      });
      final result = await screenshotController.capture();
      if (result == null) throw Exception('Failed to capture screenshot');
      return result;
    };
  }

  @override
  Widget build(BuildContext context) {
    return InteractiveViewer(
        constrained: false,
        child: Screenshot(
            controller: screenshotController,
            child: SizedBox(
                width: width.toDouble(),
                height: height.toDouble(),
                child: const Counter())));
  }
}

final counterKey = GlobalKey();

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: const Center(child: Text('42')),
    );
  }
}

/// singleton which can request a screenshot from the flutter app and returns
/// an image to an enpoint
class ImageService {
  Future<Uint8List> Function(int width, int height)? renderWidgetCallback;

  Future<Uint8List?> renderWidget(int width, int height) async {
    final result = await renderWidgetCallback?.call(width, height);
    return result;
  }
}

final _watch = Stopwatch();

Future<Response> _ssrHandler(Request request) async {
  final width = request.url.queryParameters['width'] ?? '800';
  final height = request.url.queryParameters['height'] ?? '800';
  final x = double.tryParse(request.url.queryParameters['x'] ?? '');
  final y = double.tryParse(request.url.queryParameters['y'] ?? '');

  print('SSR: $width x $height at $x, $y');

  if (x != null && y != null) {
    GestureBinding.instance.handlePointerEvent(PointerDownEvent(
      position: Offset(x, y),
    ));
    await Future.delayed(const Duration(milliseconds: 50));
    GestureBinding.instance.handlePointerEvent(PointerUpEvent(
      position: Offset(x, y),
    ));
  }

  WidgetsBinding.instance.drawFrame();

  final Uint8List? testImg =
      await imageService.renderWidget(int.parse(width), int.parse(height));

  if (testImg == null) return Response.internalServerError();

  final response = Response(
    200,
    headers: {
      'Content-Type': 'image/png',
      'Content-Length': testImg.length.toString(),
      ...corsHeaders,
    },
    body: testImg,
  );
  return response;
}

class Counter extends StatefulWidget {
  const Counter({
    super.key,
  });

  @override
  State<Counter> createState() => _CounterState();
}

class _CounterState extends State<Counter> {
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'You have pushed the button this many times:',
            ),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
    );
  }
}
