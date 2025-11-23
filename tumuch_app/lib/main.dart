import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// ACHTUNG: Das Paket shared_preferences wurde entfernt, da es in dieser Umgebung fehlt.
// In einem realen Projekt muss 'package:shared_preferences/shared_preferences.dart' importiert werden!

// Die folgenden Imports müssen in Ihrer Umgebung existieren, um die App vollständig lauffähig zu machen.
import 'home_page.dart'; // WIEDER FUNKTIONAL
import 'reason_page.dart'; // WIEDER FUNKTIONAL
import 'app_configs.dart'; // WIEDER FUNKTIONAL
import 'onboarding_page.dart'; 

// Die MethodChannel-Definition für die Kommunikation mit nativem Code
const MethodChannel _channel = MethodChannel('app.channel.main');
// Konstante für den SharedPreferences-Schlüssel (aus OnboardingPage übernommen)
const String onboardingCompleteKey = 'onboarding_complete';

// Initialisierungsvariablen
String initialRoute = '/';
bool _onboardingCompleted = false;

// DUMMY-Implementierung für die SharedPreferences-Prüfung (Wird in echtem Projekt ersetzt!)
class DummySharedPreferences {
  // Simuliert das Verhalten von getBool. Gibt immer 'false' zurück, um das Onboarding zu starten.
  // Setzen Sie dies auf 'true', wenn das Onboarding NICHT jedes Mal neu gestartet werden soll.
  bool getBool(String key) => false; 
}

Future<void> _getInitialRoute() async {
  try {
    // Fragt den nativen Code ab, ob eine bestimmte Seite angezeigt werden soll.
    final String? route = await _channel.invokeMethod<String>('getInitialRoute');
    if (route != null && route.isNotEmpty) {
      initialRoute = route;
    }
  } on PlatformException catch (e) {
    debugPrint("Fehler beim Abrufen der Initialroute: ${e.message}");
    // Fallback auf Home-Route bei Fehler.
    initialRoute = '/home';
  }
}

// Hauptfunktion der App
void main() async {
  // Stellt sicher, dass die Flutter-Bindings initialisiert sind, bevor native
  // oder SharedPreferences-Aufrufe erfolgen.
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Prüfen, ob das Onboarding abgeschlossen ist
  // Wegen des fehlenden Pakets wird die Dummy-Klasse verwendet:
  final prefs = DummySharedPreferences(); 
  // In einem echten Projekt: final prefs = await SharedPreferences.getInstance();
  
  // Die getBool-Methode der Dummy-Klasse wird aufgerufen
  _onboardingCompleted = prefs.getBool(onboardingCompleteKey); 

  // 2. Initialroute setzen (Onboarding hat Vorrang)
  if (_onboardingCompleted) {
    // Wenn Onboarding abgeschlossen, normale Routenlogik prüfen
    await _getInitialRoute(); 
  } else {
    // Wenn Onboarding NICHT abgeschlossen, starte mit der Onboarding-Seite
    initialRoute = '/onboarding'; 
  }
  
  runApp(const MyApp());
}


class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Digital Balance',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF3070B3), // ← TUM BLUE
            primary: const Color(0xFF3070B3),
            secondary: const Color(0xFF3070B3),
          ),
          useMaterial3: true,
        ),
      // Die durch main() gesetzte Route verwenden
      initialRoute: initialRoute, 
      
      // *** HIER WERDEN DIE ECHTEN WIDGETS DEN ROUTEN ZUGEWIESEN ***
      routes: {
        // Die Basisroute und die /home Route verwenden jetzt die tatsächliche HomePage
        '/': (context) => const HomePage(), 
        '/home': (context) => const HomePage(),
        
        // Die /reason Route verwendet jetzt die tatsächliche ReasonPage
        '/reason': (context) => const ReasonPage(),
        
        '/goals': (context) => const AppConfigs(),
        '/onboarding': (context) => const OnboardingPage(), // Onboarding-Route
      },
      
      // Definiert die Navigation, falls eine nicht registrierte Route aufgerufen wird (z.B. von nativem Code)
      onGenerateRoute: (settings) {
        if (settings.name == '/home') {
          return MaterialPageRoute(builder: (context) => const HomePage());
        }
        if (settings.name == '/reason') {
          return MaterialPageRoute(builder: (context) => const ReasonPage());
        }
        if (settings.name == '/goals') {
          return MaterialPageRoute(builder: (context) => const AppConfigs());
        }
        if (settings.name == '/onboarding') {
          return MaterialPageRoute(builder: (context) => const OnboardingPage());
        }
        // Fallback zur Home-Seite
        return MaterialPageRoute(builder: (context) => const HomePage());
      },
    );
  }
}
