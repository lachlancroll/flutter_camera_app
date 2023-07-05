import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'dart:io';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart' as tflite;

class PreviewPage extends StatefulWidget {
  final String? imagePath;
  final String? videoPath;

  const PreviewPage({Key? key, this.imagePath, this.videoPath})
      : super(key: key);

  @override
  State<PreviewPage> createState() => _PreviewPageState();
}

class _PreviewPageState extends State<PreviewPage> {
  VideoPlayerController? controller;
  tflite.Interpreter? interpreter;

  @override
  void initState() {
    super.initState();
    loadModel().then((value) {
      // Handle the case where the model loading completed - e.g., show a notification
    });
  }

  Future loadModel() async {
    try {
      interpreter =
          await tflite.Interpreter.fromAsset('assets/your_model.tflite');
      print('Model loaded successfully');
    } catch (e) {
      print('Failed to load model.');
      print(e);
    }
  }

  Future<List<dynamic>> predictImage(String path) async {
    img.Image? image = img.decodeImage(File(path).readAsBytesSync());

    if (image != null) {
      // Resize the image
      img.Image resizedImage = img.copyResize(image, width: 90, height: 160);

      Uint8List input = imageToByteListFloat32(resizedImage, 90, 160);
      List<int> outputShape = [1, 8]; // adjust this to your needs
      var output = List<double>.generate(
          outputShape.reduce((value, element) => value * element),
          (index) => 1).reshape(outputShape);

      // Assuming 'interpreter' is your instance of Interpreter
      await loadModel();
      var inputTensor = interpreter?.getInputTensor(0);

      //var inputTensor = interpreter?.getInputTensor(0);

      print('Shape: ${inputTensor?.shape}');
      print('Type: ${inputTensor?.type}');

      try {
        print('Running the model...');
        interpreter?.run(input, output);
        print('Model run successfully.');
      } catch (e) {
        print('Failed to run model: $e');
      }

      return output;
    } else {
      return []; // Return an empty list if the image is null
    }
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

  @override
  void dispose() {
    interpreter?.close();
    super.dispose();
  }

  /*@override
  Widget build(BuildContext context) {
    // First, get the prediction
    Future<List> prediction = predictImage(widget.imagePath ?? "");

    // Next, use a FutureBuilder to display the prediction once it's available
    return FutureBuilder<List>(
      future: prediction,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          // snapshot.data will contain your prediction
          return Text("Prediction: ${snapshot.data.toString()}");
        } else if (snapshot.hasError) {
          return Text("${snapshot.error}");
        }
        return CircularProgressIndicator();
      },
    );
  }*/
  @override
  Widget build(BuildContext context) {
    // First, get the prediction
    Future<List> prediction = predictImage(widget.imagePath ?? "");
    print('hello');
    print('hello');
    print('hello');

    // Next, use a FutureBuilder to display the prediction once it's available
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        // This will get you the actual width and height of the Image widget
        double imageDisplayWidth = constraints.maxWidth;
        double imageDisplayHeight = constraints.maxHeight;
        // You can print these values to verify that they match your expectations
        print('Width: $imageDisplayWidth, Height: $imageDisplayHeight');

        return FutureBuilder<List>(
          future: prediction,
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              List<dynamic>? data = (snapshot.data as List<dynamic>)[0];
              List<Offset> keypoints = [];

              if (data != null) {
                for (int i = 0; i < data.length; i += 2) {
                  // Ensure the data contains numbers before casting to double
                  if (data[i] is num && data[i + 1] is num) {
                    double x = (data[i] as num).toDouble();
                    double y = (data[i + 1] as num).toDouble();

                    // Normalize the keypoints
                    double normalizedX = (x / 720) * imageDisplayWidth;
                    double normalizedY = (y / 1280) * imageDisplayHeight;
                    keypoints.add(Offset(normalizedX, normalizedY));
                  }
                }
              }

              return Stack(
                alignment: Alignment.center,
                children: [
                  Image.file(File(widget.imagePath ?? "")),
                  CustomPaint(
                    painter: KeyPointsPainter(keypoints),
                    child: Container(),
                  ),
                ],
              );
            } else if (snapshot.hasError) {
              return Text("${snapshot.error}");
            }
            return CircularProgressIndicator();
          },
        );
      },
    );
  }
}

class KeyPointsPainter extends CustomPainter {
  final List<Offset> points;

  KeyPointsPainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.fill;

    for (var point in points) {
      canvas.drawCircle(point, 10, paint);
    }
  }

  @override
  bool shouldRepaint(KeyPointsPainter oldDelegate) {
    return oldDelegate.points != points;
  }
}
