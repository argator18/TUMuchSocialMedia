import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'home_page.dart';
import 'reason_page.dart';
import 'app_configs.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final String initialRoute = await _getInitialRoute();
  debugPrint('Initial route from Android: $initialRoute');

  runApp(MyApp(initialRoute: initialRoute));
}

Future<String> _getInitialRoute() async {
  const channel = MethodChannel('app.channel.route');
  try {
    final route = await channel.invokeMethod<String>('getInitialRoute');
    debugPrint('DART getInitialRoute -> $route');
    return route ?? '/';
  } catch (e) {
    debugPrint('DART getInitialRoute error: $e');
    return '/';
  }
}

class MyApp extends StatelessWidget {
  final String initialRoute;

  const MyApp({super.key, required this.initialRoute});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,

      /// Route, die von Android gesetzt wird:
      /// - normaler Start  -> '/'
      /// - über Accessibility-Service -> '/reason'
      initialRoute: initialRoute,

      /// Alle benutzten Routen HIER definieren:
      routes: {
<<<<<<< HEAD
        '/': (_) => const HomePage(),          // deine Hauptseite
        '/home': (_) => const HomePage(),      // Alias, falls du '/home' nutzt
        '/reason': (_) => const ReasonPage(),  // Seite nach Instagram-Block
        '/goals': (_) => const AppConfigs(),   // Ziel-/Limit-Seite
=======
        '/goals': (context) => const AppConfigs(), // goals bleibt als Route, falls benötigt
        '/reason': (context) => const ReasonPage(),
>>>>>>> da79e7431de9166243ae21def1aaeda909d976ce
      },
    );
  }
}

