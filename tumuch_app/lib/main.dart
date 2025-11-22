import 'package:flutter/material.dart';
// Importieren der nächsten Seite, die nach der ReasonPage kommt
import 'app_configs.dart'; 
import 'reason_page.dart';
import 'home_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Reason App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      // **AKTUALISIERT:** App startet jetzt mit der LongTermGoalsPage
      home: const HomePage(), 
      // Routen (jetzt umgekehrt)
      routes: {
        '/goals': (context) => const AppConfigs(), // goals bleibt als Route, falls benötigt
        '/reason': (context) => const ReasonPage(),
      },
    );
  }
}
