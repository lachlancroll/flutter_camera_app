import 'package:flutter/material.dart';
import 'splashPage.dart';

void main() {
  runApp(const MyApp());
}

// class MyApp extends StatelessWidget {
//   const MyApp({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: 'Flutter Camera App',
//       themeMode: ThemeMode.dark,
//       theme: ThemeData.dark(),
//       debugShowCheckedModeBanner: false,
//       home: const CameraPage(),
//     );
//   }
// }


class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Camera App',
      themeMode: ThemeMode.dark,
      theme: ThemeData.dark(),
      debugShowCheckedModeBanner: false,
      home: const MySplashPage(), // Change this line
    );
  }
}

