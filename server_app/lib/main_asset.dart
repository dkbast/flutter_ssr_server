import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
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

  runApp(const MaterialApp(home: Scaffold(body: MainApp())));
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

GlobalKey key = GlobalKey();

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
      /*
       *final result = await screenshotController.captureFromWidget(
       *    InheritedTheme.captureAll(context, DemoWidget(text: text)));
       *return result;
       */
    };
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width.toDouble(),
      height: height.toDouble(),
      child: Screenshot(
        controller: screenshotController,
        child: DemoWidget(key: key, text: '42'),
      ),
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
  final height = request.url.queryParameters['width'] ?? '800';
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
