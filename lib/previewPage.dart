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
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter_tflite/flutter_tflite.dart';
import 'package:video_player/video_player.dart';
import 'dart:io';
import 'package:image/image.dart' as img;

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

    File resizedFile; // Define here

    if (image != null) {
      // Resize the image
      img.Image resizedImg = img.copyResize(image, width: 90, height: 160);

      // Create a new file with the resized image
      resizedFile = File('$path-resized.jpg') // Assign here
        ..writeAsBytesSync(img.encodeJpg(resizedImg));
    } else {
      return []; // Return an empty list if image is null
    }

    var output = await Tflite.runModelOnImage(
      path: resizedFile.path, // feed resized image
      numResults: 2, // adjust based on your model
      threshold: 0.2, // adjust based on your model
      imageMean: 127.5, // pre-processing parameters used during model training
      imageStd: 127.5, // pre-processing parameters used during model training
    );

    // If the output is null, return an empty list
    return output ?? [];
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
