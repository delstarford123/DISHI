import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'main.dart'; // Imports the DISHIApp

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Note: Ensure firebase_options.dart is restored before uncommenting
  // await Firebase.initializeApp(
  //   options: DefaultFirebaseOptions.currentPlatform,
  // );

  // Flavor specific setup for Student App can go here
  
  runApp(const DISHIApp());
}
