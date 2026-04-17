import 'package:flutter/material.dart';
import 'screens/input_screen/input_view.dart';

void main() {
  runApp(const AslRetailApp());
}

class AslRetailApp extends StatelessWidget {
  const AslRetailApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Maneora ASL Desk',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        fontFamily: 'Helvetica', // Clean, premium font
      ),
      home: const InputView(),
    );
  }
}