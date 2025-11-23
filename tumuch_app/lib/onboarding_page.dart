import 'package:flutter/material.dart';
// import 'package:shared_preferences/shared_preferences.dart'; // MUSS IM PROJEKT AKTIVIERT WERDEN!
import 'dart:math';

// DUMMY-Klasse, um den SharedPreferences-Fehler zu vermeiden
// NOTE: Diese Definitionen werden in app_configs.dart kopiert.
class DummySharedPreferences {
  // Simuliert das Speichern. Verwenden Sie ein statisches Map, damit die Werte über Instanzen hinweg erhalten bleiben.
  static final Map<String, dynamic> _storage = {}; 

  Future<void> setBool(String key, bool value) async {
    _storage[key] = value;
    debugPrint('DUMMY: Speichere bool: $key = $value');
  }
  Future<void> setDouble(String key, double value) async {
    _storage[key] = value;
    debugPrint('DUMMY: Speichere double: $key = $value');
  }
  
  // Neu: Speichere eine Liste von Strings (für Apps)
  Future<void> setStringList(String key, List<String> value) async {
    _storage[key] = value;
    debugPrint('DUMMY: Speichere StringList: $key = $value');
  }
  
  // Neu: Lade Double-Werte
  Future<double?> getDouble(String key) async {
    return _storage.containsKey(key) && _storage[key] is double ? _storage[key] : null;
  }
  
  // Neu: Lade StringList-Werte
  Future<List<String>?> getStringList(String key) async {
    final dynamic value = _storage.containsKey(key) ? _storage[key] : null;
    return value is List ? List<String>.from(value) : null;
  }

  static Future<DummySharedPreferences> getInstance() async {
    return DummySharedPreferences();
  }
}
// Definition des tatsächlichen Typs (Wenn SharedPreferences aktiviert ist)
// typedef SharedPreferences = DummySharedPreferences;


// Konstanten für den Speicher
const String onboardingCompleteKey = 'onboarding_complete';
const String impactScorePrefix = 'impact_score_';
const String controlledAppsKey = 'controlled_apps'; // Schlüssel für App-Liste

// Haupt-Widget für das Onboarding
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  
  // Speichert die SharedPreferences-Instanz einmalig (Best Practice)
  DummySharedPreferences? _prefs; 

  // Zustand für die Schieberegler auf Slide 4 (Schritt 3)
  Map<String, double> _impactScores = {
    'After waking up': 0,
    'During work/uni': 0,
    'In the evening': 0,
    'Before going to bed': 0,
  };
  
  // Zustand für die ausgewählten Apps
  final List<String> _availableApps = ['Instagram', 'TikTok', 'YouTube', 'Facebook', 'Twitter/X', 'Reddit', 'Snapchat'];
  List<String> _selectedApps = ['Instagram', 'TikTok']; // Standardauswahl

  // Callback für den Schieberegler
  void _updateImpactScore(String category, double newValue) {
    setState(() {
      _impactScores[category] = newValue;
    });
  }
  
  // Methode zum einmaligen Laden der Instanz
  Future<void> _loadPrefs() async {
    // Im echten Projekt: _prefs = await SharedPreferences.getInstance();
    _prefs = await DummySharedPreferences.getInstance();
  }

  // Navigiert zur nächsten Seite, oder beendet das Onboarding
  void _nextPage() async {
    // Falls _prefs noch nicht geladen ist (sollte nicht passieren, aber zur Sicherheit)
    if (_prefs == null) {
      await _loadPrefs();
      if (_prefs == null) return; 
    }
    
    // Navigations-Logik
    if (_currentPage < _slides.length - 1) { // Verwende die Länge der Slides
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeIn,
      );
    } else {
      // Onboarding beenden und Status speichern
      final prefs = _prefs!; 
      
      // 1. Speichere alle Impact Scores einzeln (Schritt 3)
      for (final entry in _impactScores.entries) {
        await prefs.setDouble('$impactScorePrefix${entry.key}', entry.value);
      }
      
      // 2. Speichere die Liste der kontrollierten Apps (Schritt 4)
      await prefs.setStringList(controlledAppsKey, _selectedApps);
      
      // 3. Speichere den Abschluss des Onboardings
      await prefs.setBool(onboardingCompleteKey, true);
      
      // Zur ReasonPage navigieren, wie gewünscht.
      Navigator.pushReplacementNamed(context, '/reason');
    }
  }

  // --- Die einzelnen Onboarding-Slides ---

  // Slide 1: Willkommen
  Widget _buildWelcomeSlide() {
    return const Padding(
      padding: EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Icon(Icons.spa, size: 80, color: Colors.green),
          SizedBox(height: 30),
          Text(
            'You are using TUMuch social media.',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 15),
          Text(
            'Let us help you be more mindful and use your time more consciously.',
            style: TextStyle(fontSize: 18, color: Colors.black54),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // Slide 2: Berechtigungen (Schritt 1)
  Widget _buildPermissionSlide() {
    return const Padding(
      padding: EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Icon(Icons.security, size: 80, color: Colors.blue),
          SizedBox(height: 30),
          Text(
            'System Permissions',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 15),
          Text(
            'Damit wir Ihre App-Nutzung überwachen können, sind spezielle Berechtigungen notwendig. Wir speichern Ihre Daten nur lokal.',
            style: TextStyle(fontSize: 18, color: Colors.black54),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // Slide 3: Systemnutzung der letzten Woche (Schritt 2)
  Widget _buildUsageSlide() {
    final List<int> weeklyUsageMinutes = List.generate(7, (index) => 30 + Random().nextInt(150));
    final double maxUsage = weeklyUsageMinutes.reduce(max).toDouble();
    final List<String> weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Last Week´s Social Media Usage ',
            style: Theme.of(context).textTheme.headlineMedium!.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          const Text(
            'Eine Darstellung Ihrer geschätzten App-Nutzung der letzten 7 Tage (in Minuten pro Tag).',
            style: TextStyle(fontSize: 16, color: Colors.black54),
          ),
          const SizedBox(height: 40),

          // Balkendiagramm
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: weeklyUsageMinutes.asMap().entries.map((entry) {
                final index = entry.key;
                final usage = entry.value.toDouble();
                
                final double barHeightRatio = usage / maxUsage;
                final double barHeight = barHeightRatio * 180; 
                
                return Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      '${usage.round()}',
                      style: const TextStyle(fontSize: 12, color: Colors.black87),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      height: barHeight,
                      width: 30,
                      decoration: BoxDecoration(
                        color: Colors.deepPurple.shade300,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(6),
                          topRight: Radius.circular(6),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      weekdays[index],
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // Slide 4: Kategorien mit Schiebereglern (Schritt 3)
  Widget _buildCategoriesSlide() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'During Which times during the day do you want to be specifically mindful about your usage?',
            style: Theme.of(context).textTheme.headlineMedium!.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          const Text(
            'Rate how strong you want us intervene during different times of the day.',
            style: TextStyle(fontSize: 16, color: Colors.black54),
          ),
          const SizedBox(height: 30),

          // Schieberegler-Liste
          Expanded(
            child: ListView(
              children: _impactScores.keys.map((category) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$category: ${_impactScores[category]!.round()}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Slider(
                        value: _impactScores[category]!,
                        min: 0,
                        max: 10,
                        divisions: 10,
                        label: _impactScores[category]!.round().toString(),
                        onChanged: (double newValue) {
                          _updateImpactScore(category, newValue);
                        },
                      ),
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Not at all', style: TextStyle(fontSize: 12, color: Colors.black54)),
                          Text('Very strongly', style: TextStyle(fontSize: 12, color: Colors.black54)),
                        ],
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
  
  // Slide 5: App-Auswahl (Schritt 4)
  Widget _buildAppSelectionSlide() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'On which do you waste time?',
            style: Theme.of(context).textTheme.headlineMedium!.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          const Text(
            'Choose for which apps you need us to help you change your habits. You can change this in the Settings later.s',
            style: TextStyle(fontSize: 16, color: Colors.black54),
          ),
          const SizedBox(height: 30),

          // Checkbox-Liste der Apps
          Expanded(
            child: ListView.builder(
              itemCount: _availableApps.length,
              itemBuilder: (context, index) {
                final app = _availableApps[index];
                return CheckboxListTile(
                  title: Text(app),
                  value: _selectedApps.contains(app),
                  onChanged: (bool? isSelected) {
                    setState(() {
                      if (isSelected == true) {
                        _selectedApps.add(app);
                      } else {
                        _selectedApps.remove(app);
                      }
                    });
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // Slide 6: Prinzip-Erklärung (Letzter Schritt)
  Widget _buildPrincipleSlide() {
    return const Padding(
      padding: EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Icon(Icons.lightbulb_outline, size: 80, color: Colors.orange),
          SizedBox(height: 30),
          Text(
            'Our goal: Change your digital habits in your favor.',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 15),
          Text(
            'We dont want to forbid you from using your Apps, we want to make conscious decisions about when and why you want to use your social media apps. We detect the moment you drift of and hope to get you back on track.',
            style: TextStyle(fontSize: 18, color: Colors.black54),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 15),
          Text(
            'So gewinnen Sie die Kontrolle über Ihre Zeit zurück.',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
  
  // Die Slides als Getter (Aktualisierte Reihenfolge)
  List<Widget> get _slides => [
    _buildWelcomeSlide(),
    _buildPermissionSlide(),
    _buildUsageSlide(),
    _buildCategoriesSlide(),
    _buildAppSelectionSlide(), // NEUE SLIDE
    _buildPrincipleSlide(),
  ];

  @override
  void initState() {
    super.initState();
    // Das Laden der SharedPreferences ist hier nicht erforderlich.
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadPrefs(); // Lade die Dummy-Instanz
  }

  @override
  Widget build(BuildContext context) {
    final slides = _slides;
    
    final double progress = (_currentPage + 1) / slides.length;
    final bool isLastPage = _currentPage == slides.length - 1;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: <Widget>[
            // Fortschrittsbalken
            LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey.shade300,
              color: Theme.of(context).colorScheme.primary,
            ),
            
            // Seiteninhalt
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(), // Scrollen deaktivieren
                onPageChanged: (int page) {
                  setState(() {
                    _currentPage = page;
                  });
                },
                children: slides,
              ),
            ),
            
            // Navigations-Buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  // Zurück-Button (ausblenden auf der ersten Seite)
                  _currentPage > 0
                      ? TextButton(
                          onPressed: () {
                            _pageController.previousPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeIn,
                            );
                          },
                          child: const Text('Zurück'),
                        )
                      : const SizedBox(width: 80), // Platzhalter
                  
                  // Überspringen-Button (nur auf erster Seite anzeigen)
                  _currentPage == 0
                      ? TextButton(
                          onPressed: () {
                            // Springe direkt zur letzten Seite (Prinzip-Erklärung)
                            _pageController.jumpToPage(slides.length - 1); 
                          },
                          child: const Text('Überspringen'),
                        )
                      : const SizedBox.shrink(),
                      
                  // Weiter/Start-Button
                  FilledButton(
                    onPressed: _nextPage,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 12),
                    ),
                    child: Text(isLastPage ? 'Starten' : 'Weiter'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}