import 'package:flutter/material.dart';

// NOTE: Die DummySharedPreferences Klasse und die Schlüssel/Präfixe
// werden hier dupliziert.
class DummySharedPreferences {
  // Simuliert das Speichern. Verwenden Sie ein statisches Map, damit die Werte über Instanzen hinweg erhalten bleiben.
  static final Map<String, dynamic> _storage = {
    // Simulierte Startwerte für Impact Scores
    'impact_score_Stresslevel': 75.0, 
    'impact_score_Sozialer Vergleich': 85.0,
    'impact_score_Zeitverschwendung': 40.0,
    'impact_score_FOMO (Fear of Missing Out)': 90.0,
    // Simulierte Startwerte für kontrollierte Apps
    'controlled_apps': ['Instagram', 'TikTok', 'YouTube'], 
  }; 

  Future<double?> getDouble(String key) async {
    return _storage.containsKey(key) && _storage[key] is double ? _storage[key] : null;
  }
  
  Future<List<String>?> getStringList(String key) async {
    // StringList muss von dynamic nach List<String> gecastet werden
    final dynamic value = _storage.containsKey(key) ? _storage[key] : null;
    return value is List ? List<String>.from(value) : null;
  }
  
  Future<void> setDouble(String key, double value) async {
    _storage[key] = value;
    debugPrint('DUMMY: Speichere double: $key = $value');
  }
  
  Future<void> setStringList(String key, List<String> value) async {
    _storage[key] = value;
    debugPrint('DUMMY: Speichere StringList: $key = $value');
  }


  static Future<DummySharedPreferences> getInstance() async {
    return DummySharedPreferences();
  }
}
const String impactScorePrefix = 'impact_score_';
const String controlledAppsKey = 'controlled_apps';

// ************************************************************
// AppConfigs: Kombinierte Seite für Limits, Apps und anpassbare Impact-Scores
// ************************************************************
class AppConfigs extends StatefulWidget {
  const AppConfigs({super.key});

  @override
  State<AppConfigs> createState() => _AppConfigsState();
}

class _AppConfigsState extends State<AppConfigs> {
  // Zustand für die anpassbaren Impact Scores
  Map<String, double> _loadedImpactScores = {};
  List<String> _controlledApps = [];
  bool _isLoading = true;
  bool _isSaving = false;
  
  // Die festen Kategorien aus OnboardingPage
  final List<String> _categories = [
    'Stresslevel',
    'Sozialer Vergleich',
    'Zeitverschwendung',
    'FOMO (Fear of Missing Out)',
  ];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  // Lade Impact Scores und kontrollierte Apps aus dem Speicher
  Future<void> _loadSettings() async {
    final prefs = await DummySharedPreferences.getInstance();
    final Map<String, double> scores = {};
    
    // Impact Scores laden
    for (final category in _categories) {
      final key = '$impactScorePrefix$category';
      final score = await prefs.getDouble(key);
      // Wenn der Score nicht gefunden wird, verwende 50.0 als Standard
      scores[category] = score ?? 50.0;
    }
    
    // Kontrollierte Apps laden
    final apps = await prefs.getStringList(controlledAppsKey);

    setState(() {
      _loadedImpactScores = scores;
      _controlledApps = apps ?? [];
      _isLoading = false;
    });
  }
  
  // Speichere die Impact Scores im Speicher
  Future<void> _saveImpactScores() async {
    setState(() { _isSaving = true; });
    final prefs = await DummySharedPreferences.getInstance();

    // 1. Speichere Impact Scores
    for (final entry in _loadedImpactScores.entries) {
      await prefs.setDouble('$impactScorePrefix${entry.key}', entry.value);
    }
    
    // 2. Simulierte Speicherung der App Limits und kontrollierten Apps
    // Hier müsste die Logik für die App Limits und das Speichern der kontrollierten Apps folgen.

    // Zeige eine kurze Bestätigung 
    if(mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Einstellungen erfolgreich gespeichert!'), duration: Duration(seconds: 2)),
      );
    }

    setState(() { _isSaving = false; });
  }
  
  // Callback für den Schieberegler
  void _updateImpactScore(String category, double newValue) {
    setState(() {
      _loadedImpactScores[category] = newValue;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ziele, Apps & Einblicke'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // --- 1. App-Limits (Ziele setzen) ---
            Text(
              '1. App-Nutzungslimits',
              style: Theme.of(context).textTheme.headlineSmall!.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text('Legen Sie Ihre maximal zulässige tägliche Nutzungszeit für Ablenkungs-Apps fest.'),
            const SizedBox(height: 15),
            Center(
              child: Text(
                'Konfigurations-UI für Limits folgt hier.',
                style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey.shade600),
              ),
            ),
            
            const Divider(height: 40),
            
            // --- 2. Kontrollierte Apps ---
            Text(
              '2. Kontrollierte Apps',
              style: Theme.of(context).textTheme.headlineSmall!.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text('Apps, die überwacht werden und zu Ihrem "Naughty Score" beitragen:'),
            const SizedBox(height: 15),
            
            // HIER IST DIE KORRIGIERTE LISTENAUSGABE
            Wrap(
              spacing: 8.0, 
              runSpacing: 4.0, 
              children: List<Widget>.generate(_controlledApps.length, (index) {
                final app = _controlledApps[index];
                return Chip(
                  label: Text(app),
                  backgroundColor: Colors.deepPurple.shade50,
                  labelStyle: TextStyle(color: Colors.deepPurple.shade700),
                );
              }),
            ),
            
            const Divider(height: 40),
            
            // --- 3. Ihre Motivation (Einblicke bearbeiten) ---
            Text(
              '3. Ihre Motivation (Einblicke bearbeiten)',
              style: Theme.of(context).textTheme.headlineSmall!.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text('Passen Sie Ihre ursprüngliche Selbsteinschätzung an, um Ihre Motivation zu reflektieren. Diese Werte beeinflussen die App-Meldungen.'),
            const SizedBox(height: 30),

            // Schieberegler-Liste
            ..._loadedImpactScores.keys.map((category) {
              final score = _loadedImpactScores[category]!;
              return Padding(
                padding: const EdgeInsets.only(bottom: 25.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          category,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          '${score.round()}%',
                          style: Theme.of(context).textTheme.titleMedium!.copyWith(fontWeight: FontWeight.bold, color: Colors.deepPurple),
                        ),
                      ],
                    ),
                    Slider(
                      value: score,
                      min: 0,
                      max: 100,
                      divisions: 20,
                      label: score.round().toString(),
                      onChanged: (double newValue) {
                        _updateImpactScore(category, newValue);
                      },
                    ),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Geringer Einfluss', style: TextStyle(fontSize: 12, color: Colors.black54)),
                        Text('Hoher Einfluss', style: TextStyle(fontSize: 12, color: Colors.black54)),
                      ],
                    ),
                  ],
                ),
              );
            }).toList(),

            const SizedBox(height: 20),
            
            // Speichern-Button
            Center(
              child: FilledButton.icon(
                onPressed: _isSaving ? null : _saveImpactScores,
                icon: _isSaving 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.save),
                label: Text(_isSaving ? 'Speichern...' : 'Änderungen speichern'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 15),
                  textStyle: const TextStyle(fontSize: 18),
                ),
              ),
            ),
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }
}