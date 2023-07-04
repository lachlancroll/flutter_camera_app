/*import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:video_player/video_player.dart';
import 'dart:io';

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

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: widget.imagePath != null
            ? Image.file(
                File(widget.imagePath ?? ""),
                fit: BoxFit.cover,
              )
            : AspectRatio(
                aspectRatio: controller!.value.aspectRatio,
                child: VideoPlayer(controller!),
              ),
      ),
    );
  }
}*/
/* import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter_tflite/flutter_tflite.dart';
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

  @override
  void initState() {
    super.initState();
    loadModel().then((value) {
      // Handle the case where the model loading completed - e.g., show a notification
    });
  }

  Future loadModel() async {
    var res = await Tflite.loadModel(
      model: "assets/your_model.tflite",
      // labels: "assets/labels.txt",   // if needed
    );
    print(res);
  }

  Future<List<dynamic>> predictImage(String path) async {
    img.Image? image = img.decodeImage(File(path).readAsBytesSync());

    if (image != null) {
      print('Original image size: ${File(path).lengthSync()} bytes');

      // Resize the image
      img.Image resizedImage = img.copyResize(image, width: 90, height: 160);
      print('Resized image size: ${resizedImage.length} bytes');

      var output = await Tflite.runModelOnBinary(
          binary: imageToByteListFloat32(
              resizedImage, 90, 160, 127.5, 127.5), // required
          numResults: 8, // defaults to 5
          threshold: 0.05, // defaults to 0.1
          asynch: true // defaults to true
          );

      // Instead of returning the output as is, now you should cast the output to List<dynamic>
      return List<dynamic>.from(output ?? []);
    } else {
      return []; // Return an empty list if the image is null
    }
  }

  Uint8List imageToByteListFloat32(
      img.Image image, int width, int height, double mean, double std) {
    var convertedBytes = Float32List(1 * width * height * 3);
    var buffer = Float32List.view(convertedBytes.buffer);
    int pixelIndex = 0;
    for (var i = 0; i < height; i++) {
      for (var j = 0; j < width; j++) {
        var pixel = image.getPixel(j, i);
        buffer[pixelIndex++] = (img.getRed(pixel) - mean) / std;
        buffer[pixelIndex++] = (img.getGreen(pixel) - mean) / std;
        buffer[pixelIndex++] = (img.getBlue(pixel) - mean) / std;
      }
    }
    return convertedBytes.buffer.asUint8List();
  }

  Uint8List imageToByteListUint8(img.Image image, int width, int height) {
    var convertedBytes = Uint8List(1 * width * height * 3);
    var buffer = Uint8List.view(convertedBytes.buffer);
    int pixelIndex = 0;
    for (var i = 0; i < height; i++) {
      for (var j = 0; j < width; j++) {
        var pixel = image.getPixel(j, i);
        buffer[pixelIndex++] = img.getRed(pixel);
        buffer[pixelIndex++] = img.getGreen(pixel);
        buffer[pixelIndex++] = img.getBlue(pixel);
      }
    }
    return convertedBytes.buffer.asUint8List();
  }

  @override
  void dispose() {
    Tflite.close();
    super.dispose();
  }

  @override
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
  }
}
 */
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

  @override
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
  }
}
