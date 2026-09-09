import 'package:flutter/material.dart';

// Update these imports to match exactly what your files are named
import 'views/factory_assistant_view.dart';
import 'controllers/InventoryController.dart'; // We need to import the controller now!

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    
    // 1. We create the controller here
    final myController = InventoryController();

    return MaterialApp(
      title: 'AMIC Factory Assistant',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF121212),
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.yellowAccent,
          brightness: Brightness.dark,
          primary: Colors.yellowAccent,
        ),
        useMaterial3: true,
      ),
      
      // 2. We remove 'const' and pass the controller into the view!
      home: FactoryAssistantView(controller: myController), 
    );
  }
}