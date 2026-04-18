import 'package:flutter/material.dart';
import 'screens/login_screen.dart'; // This brings in your new start screen!

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
        fontFamily: 'Helvetica', 
      ),
      // This is the magic line. It tells the app to boot into the Login Screen!
      home: const LoginScreen(), 
    );
  }
}