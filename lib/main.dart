import 'package:flutter/material.dart';
import 'widgets/osm_picker.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Color.fromRGBO(0, 0, 0, 0.2),
        systemNavigationBarColor: Color.fromRGBO(0, 0, 0, 0.2),
      ),
    );
    return MaterialApp(
      title: 'Flutter Stolpersteine',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const Material(child: OpenStreetMapSearchAndPick()),
    );
  }
}
