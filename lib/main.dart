import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:tflite_flutter/tflite_flutter.dart' as tflite;
import 'dart:typed_data';
import 'dart:io';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';
import 'dart:isolate';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final cameras = await availableCameras();
  runApp(MyApp(cameras: cameras));
}

void isolateFunction(SendPort initialReplyTo) async {
  final port = ReceivePort();
  initialReplyTo.send(port.sendPort);

  await for (final message in port) {
    final data = message[0] as img.Image;
    final sendPort = message[1] as SendPort;
    img.Image resizedImage = img.copyResize(data, width: 90, height: 160);
    sendPort.send(resizedImage); // Send back the data
  }
}

class MyApp extends StatelessWidget {
  final List<CameraDescription> cameras;

  MyApp({Key? key, required this.cameras}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData.dark(),
      home: HomePage(cameras: cameras),
    );
  }
}

class HomePage extends StatefulWidget {
  final List<CameraDescription> cameras;

  HomePage({Key? key, required this.cameras}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late CameraController cameraController;
  late CameraImage cameraImage;
  tflite.Interpreter? interpreter;
  int frameCount = 0;
  int processEveryNFrames = 10;
  bool predicting = false;
  List<dynamic> keypoints = [];

  void initCamera() {
    cameraController =
        CameraController(widget.cameras[0], ResolutionPreset.medium);
    cameraController.initialize().then((_) {
      if (!mounted) {
        return;
      }
      setState(() {
        print('Camera Initialized');
        cameraController.startImageStream((image) {
          frameCount++;
          if (frameCount % processEveryNFrames == 0 && !predicting) {
            processCameraImage(image);
            print("Processing frame...");
          }
        }).onError((error, stackTrace) {
          print('Error in image stream: $error');
        });
      });
    });
  }

  @override
  void dispose() {
    interpreter?.close();
    cameraController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    loadModel();
    initCamera();
  }

  void processCameraImage(CameraImage image) async {
    setState(() {
      predicting = true;
    });
    img.Image? convertedImage = convertYUV420toImageColor(image);

    if (convertedImage != null) {
      var result = await predictImage(convertedImage);
      // handle the result
      print("NOOOOO");
      setState(() {
        keypoints = result;
      });
      //print(result);
    }
    setState(() {
      predicting = false;
    });
  }

  Future<img.Image> predict(img.Image image) async {
    final receivePort = ReceivePort();
    await Isolate.spawn(isolateFunction, receivePort.sendPort);

    final sendPort = await receivePort.first;
    final answerPort = ReceivePort();

    sendPort.send([image, answerPort.sendPort]); // send a number 42

    final response = await answerPort.first;
    //print('Response: $response'); // prints "Response: 42"
    return (response);
  }

  Future<img.Image> convertImage(CameraImage image) async {
    return convertYUV420toImageColor(image);
  }

  img.Image convertYUV420toImageColor(CameraImage image) {
    final int width = image.width;
    final int height = image.height;

    var imglib = img.Image(width, height); // Create an empty image.

    final Plane planeY = image.planes[0];
    final Plane planeU = image.planes[1];
    final Plane planeV = image.planes[2];

    final int yRowStride = planeY.bytesPerRow;
    final int uvRowStride = planeU.bytesPerRow;
    final int uvPixelStride = planeU.bytesPerPixel ?? 1;

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final int uvIndex =
            uvRowStride * (y / 2).floor() + uvPixelStride * (x / 2).floor();
        final int indexY = yRowStride * y + x;

        final int yp = planeY.bytes[indexY];
        final int up = planeU.bytes[uvIndex];
        final int vp = planeV.bytes[uvIndex];

        // Calculate pixel color
        int r = (yp + vp * 1436 / 1024 - 179).round().clamp(0, 255);
        int g = (yp - up * 46549 / 131072 + 44 - vp * 93604 / 131072 + 91)
            .round()
            .clamp(0, 255);
        int b = (yp + up * 1814 / 1024 - 227).round().clamp(0, 255);

        imglib.setPixelRgba(x, y, r, g, b);
      }
    }
    return imglib;
  }

  Future loadModel() async {
    try {
      interpreter = await tflite.Interpreter.fromAsset(
          'assets/your_model.tflite',
          options: InterpreterOptions()..threads = 4);
      print('Model loaded successfully');
    } catch (e) {
      print('Failed to load model.');
      print(e);
    }
  }

  Future<List<dynamic>> predictImage(img.Image image) async {
    // Use the image argument directly instead of loading it from a path.
    //img.Image resizedImage = img.copyResize(image, width: 90, height: 160);

    img.Image resizedImage = await predict(image);
    Uint8List input = imageToByteListFloat32(resizedImage, 90, 160);
    List<int> outputShape = [1, 8]; // adjust this to your needs
    var output = List<double>.generate(
        outputShape.reduce((value, element) => value * element),
        (index) => 1).reshape(outputShape);

    // Assuming 'interpreter' is your instance of Interpreter
    var inputTensor = interpreter?.getInputTensor(0);

    print('Shape: ${inputTensor?.shape}');
    print('Type: ${inputTensor?.type}');

    try {
      print('Running the model...');
      interpreter?.run(input, output);
      print('Model run successfully.');
    } catch (e) {
      print('Failed to run model: $e');
    }
    print(output);
    return output;
  }

  Uint8List imageToByteListFloat32(img.Image image, int width, int height) {
    var convertedBytes = Float32List(1 * width * height * 3);
    var buffer = Float32List.view(convertedBytes.buffer);
    int pixelIndex = 0;
    for (var i = 0; i < height; i++) {
      for (var j = 0; j < width; j++) {
        var pixel = image.getPixel(j, i);
        buffer[pixelIndex++] = img.getRed(pixel) / 255.0;
        buffer[pixelIndex++] = img.getGreen(pixel) / 255.0;
        buffer[pixelIndex++] = img.getBlue(pixel) / 255.0;
      }
    }
    return convertedBytes.buffer.asUint8List();
  }

  /*@override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    List<Widget> list = [];

    list.add(
      Positioned(
        top: 0.0,
        left: 0.0,
        width: size.width,
        height: size.height - 100,
        child: Container(
          height: size.height - 100,
          child: (!cameraController.value.isInitialized)
              ? new Container()
              : AspectRatio(
                  aspectRatio: cameraController.value.aspectRatio,
                  child: CameraPreview(cameraController),
                ),
        ),
      ),
    );

    return SafeArea(
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Container(
          margin: EdgeInsets.only(top: 50),
          color: Colors.black,
          child: Stack(
            children: list,
          ),
        ),
      ),
    );
  }*/
  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;

    return SafeArea(
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Container(
          margin: EdgeInsets.only(top: 50),
          color: Colors.black,
          child: Stack(
            children: [
              Positioned(
                top: 0.0,
                left: 0.0,
                width: size.width,
                height: size.height - 100,
                child: Container(
                  height: size.height - 100,
                  child: (!cameraController.value.isInitialized)
                      ? new Container()
                      : AspectRatio(
                          aspectRatio: cameraController.value.aspectRatio,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              CameraPreview(cameraController),
                              KeypointsOverlay(
                                  keypoints: keypoints,
                                  previewSize: Size(
                                      cameraController
                                          .value.previewSize!.height,
                                      cameraController.value.previewSize!
                                          .width)), // Add the keypoints overlay here
                            ],
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class KeypointsOverlay extends CustomPaint {
  final List<dynamic> keypoints;
  final Size previewSize;

  KeypointsOverlay({required this.keypoints, required this.previewSize})
      : super(
            painter: _KeypointsPainter(
                keypoints: keypoints, previewSize: previewSize));
}

class _KeypointsPainter extends CustomPainter {
  final List<dynamic> keypoints;
  final Size previewSize;

  _KeypointsPainter({required this.keypoints, required this.previewSize});

  @override
  void paint(Canvas canvas, Size size) {
    // Adjust the keypoints to the size of the preview
    final double scaleX = previewSize.width / 720;
    final double scaleY = previewSize.height / 1280;

    print("HHHEEEEE");
    print(previewSize.width);
    print(previewSize.height);

    //List<double> flatKeypoints = keypoints.expand((k) => k).toList();
    //List<double> doubleKeypoints = keypoints.map((item) => double.parse(item.toString())).toList();


    ///////////TTTTTTTOOOOOOOO DDDDDDDOOOOOOOOO:::::
    ///fix the keypoints
    ///fix the isolates being respawned

    /*List<double> doubleKeypoints = [
      10.0,
      10.0,
      20.0,
      20.0,
      30.0,
      30.0,
      40.0,
      40.0
    ];*/
    List<double> doubleKeypoints = keypoints
        .expand((list) => list)
        .map<double>((value) => value.toDouble())
        .toList();

    // Draw the keypoints
    final Paint paint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.fill;
    for (var i = 0; i < doubleKeypoints.length; i += 2) {
      double x = doubleKeypoints[i] * scaleX;
      double y = doubleKeypoints[i + 1] * scaleY;
      canvas.drawCircle(Offset(x, y), 6.0, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _KeypointsPainter oldDelegate) {
    return keypoints != oldDelegate.keypoints;
  }
}
