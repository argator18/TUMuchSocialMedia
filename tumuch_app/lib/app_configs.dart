// app_configs.dart
import 'package:flutter/material.dart';
<<<<<<< HEAD

import 'app_storage.dart';
const String API_BASE = "http://172.20.10.3:8000";

=======
import 'dart:convert';
import 'package:http/http.dart' as http;


// Konstanten für den Backend-Zugriff
const String API_BASE = 'http://3.74.158.108:8000';
// ZENTRALISIERUNG: Wir verwenden nur den existierenden Endpunkt
const String centralEndpoint = '/echo'; 
const String demoUserId = 'DEMO_USER_12345'; // Wir simulieren eine User-ID ohne Firebase Auth

// Konstanten für die Datenstruktur
const String impactScorePrefix = 'impact_score_';
const String controlledAppsKey = 'controlled_apps';

// ************************************************************
// AppConfigs: Kombinierte Seite für Limits, Apps und anpassbare Impact-Scores
// ************************************************************
>>>>>>> 2b7966ef79491b7ddc41bb54b64a81448931bc34
class AppConfigs extends StatefulWidget {
  const AppConfigs({super.key});

  @override
  State<AppConfigs> createState() => _AppConfigsState();
}

class _AppConfigsState extends State<AppConfigs> {
  // Same categories as in onboarding_page.dart
  final List<String> _categories = const [
    'After waking up',
    'During work/uni',
    'In the evening',
    'Before going to bed',
  ];

  // Same app list as onboarding
  final List<String> _availableApps = const [
    'Instagram',
    'TikTok',
    'YouTube',
    'Facebook',
    'Twitter/X',
    'Reddit',
    'Snapchat',
  ];

  Map<String, double> _loadedImpactScores = {};
  List<String> _controlledApps = [];

  bool _isLoading = true;
  bool _isSaving = false;
<<<<<<< HEAD

=======
  
  // Die festen Kategorien (für die wir Werte laden/speichern)
  final List<String> _categories = [
    'Stresslevel',
    'Sozialer Vergleich',
    'Zeitverschwendung',
    'FOMO (Fear of Missing Out)',
  ];
  
>>>>>>> 2b7966ef79491b7ddc41bb54b64a81448931bc34
  @override
  void initState() {
    super.initState();
    _loadSettingsFromBackend();
  }

<<<<<<< HEAD
  Future<void> _loadSettings() async {
    final prefs = await AppPrefs.getInstance();
    final Map<String, double> scores = {};

    // Load impact scores (time-of-day sliders)
    for (final category in _categories) {
      final key = '$impactScorePrefix$category';
      final score = await prefs.getDouble(key);
      // Default: middle value 5 if nothing stored yet
      scores[category] = score ?? 5.0;
    }

    // Load controlled apps
    final apps = await prefs.getStringList(controlledAppsKey);

    setState(() {
      _loadedImpactScores = scores;
      _controlledApps = apps ??
          [
            // default selection if nothing stored yet
            'Instagram',
            'TikTok',
          ];
=======
  // --- Daten aus dem Custom Backend laden (Simulierte POST-Anfrage an /echo) ---
  Future<void> _loadSettingsFromBackend() async {
    setState(() { _isLoading = true; });

    final uri = Uri.parse('$API_BASE$centralEndpoint');

    // Wir senden die User ID und eine "action", damit der Backend-Server weiß,
    // dass er die gespeicherten Konfigurationen zurückgeben soll.
    try {
      final resp = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': demoUserId,
          'action': 'load_settings'
        }),
      );

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final Map<String, double> scores = {};
        
        // Impact Scores extrahieren
        for (final category in _categories) {
          final key = '$impactScorePrefix$category';
          // Versuche, den Score als double zu laden, sonst verwende 50.0 als Fallback
          scores[category] = (data[key] as num?)?.toDouble() ?? 50.0;
        }
        
        // Kontrollierte Apps extrahieren
        final apps = (data[controlledAppsKey] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];

        setState(() {
          _loadedImpactScores = scores;
          _controlledApps = apps.isNotEmpty ? apps : ['Ladefehler/Standard-App'];
          _isLoading = false;
        });
        debugPrint('Einstellungen erfolgreich von $centralEndpoint geladen.');

      } else {
        debugPrint('Backend-Fehler beim Laden (${resp.statusCode}): ${resp.body}');
        // Fallback-Werte laden
        _loadFallbackSettings();
      }
    } catch (e) {
      debugPrint('Netzwerkfehler beim Laden: $e');
      // Fallback-Werte laden
      _loadFallbackSettings();
    }
  }
  
  void _loadFallbackSettings() {
     setState(() {
      for (final category in _categories) {
        _loadedImpactScores[category] = 50.0;
      }
      _controlledApps = ['Standard App (Ladefehler)'];
>>>>>>> 2b7966ef79491b7ddc41bb54b64a81448931bc34
      _isLoading = false;
    });
  }

<<<<<<< HEAD
  Future<void> _saveSettings() async {
    setState(() {
      _isSaving = true;
    });

    final prefs = await AppPrefs.getInstance();

    // Save impact scores
    for (final entry in _loadedImpactScores.entries) {
      await prefs.setDouble('$impactScorePrefix${entry.key}', entry.value);
    }

    // Save controlled apps
    await prefs.setStringList(controlledAppsKey, _controlledApps);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Einstellungen erfolgreich gespeichert!'),
          duration: Duration(seconds: 2),
        ),
      );
=======
  // Speichere die Impact Scores im Custom Backend über /echo
  Future<void> _saveImpactScores() async {
    if (_isSaving) return;

    setState(() { _isSaving = true; });
    
    final Map<String, dynamic> dataToSave = {};
    for (final entry in _loadedImpactScores.entries) {
      // Speichere die aktuellen Impact Scores
      dataToSave['$impactScorePrefix${entry.key}'] = entry.value;
>>>>>>> 2b7966ef79491b7ddc41bb54b64a81448931bc34
    }
    dataToSave['userId'] = demoUserId; // User ID senden
    dataToSave['action'] = 'save_impact_scores'; // Spezifische Aktion für den Server

<<<<<<< HEAD
    if (mounted) {
      setState(() {
        _isSaving = false;
      });
=======
    final uri = Uri.parse('$API_BASE$centralEndpoint');

    try {
      final resp = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(dataToSave),
      );
      
      if (resp.statusCode == 200) {
        debugPrint('Impact Scores erfolgreich im Backend gespeichert!');
        if(mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Einstellungen erfolgreich gespeichert!'), duration: Duration(seconds: 2)),
          );
        }
      } else {
        debugPrint('Backend-Fehler beim Speichern (${resp.statusCode}): ${resp.body}');
        if(mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Fehler beim Speichern: ${resp.statusCode}'), duration: const Duration(seconds: 4)),
          );
        }
      }

    } catch (e) {
      debugPrint('Netzwerkfehler beim Speichern: $e');
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Netzwerkfehler: $e'), duration: const Duration(seconds: 4)),
        );
      }
    } finally {
      if (mounted) {
        setState(() { _isSaving = false; });
      }
>>>>>>> 2b7966ef79491b7ddc41bb54b64a81448931bc34
    }
  }

  void _updateImpactScore(String category, double value) {
    setState(() {
      _loadedImpactScores[category] = value;
    });
  }

  void _toggleApp(String app, bool isSelected) {
    setState(() {
      if (isSelected) {
        if (!_controlledApps.contains(app)) {
          _controlledApps.add(app);
        }
      } else {
        _controlledApps.remove(app);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // 1. Controlled Apps (same as onboarding app selection)
            Text(
              '1. Apps you want us to watch',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall!
                  .copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              'Choose which apps should count towards your "naughty score".',
            ),
<<<<<<< HEAD
            const SizedBox(height: 15),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _availableApps.length,
              itemBuilder: (context, index) {
                final app = _availableApps[index];
                final isSelected = _controlledApps.contains(app);
                return CheckboxListTile(
                  title: Text(app),
                  value: isSelected,
                  onChanged: (bool? value) {
                    _toggleApp(app, value ?? false);
                  },
=======
            
            const Divider(height: 40),
            
            // --- 2. Kontrollierte Apps ---
            Text(
              '2. Kontrollierte Apps (geladen von $API_BASE$centralEndpoint)',
              style: Theme.of(context).textTheme.headlineSmall!.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text('Apps, die überwacht werden und zu Ihrem "Naughty Score" beitragen:'),
            const SizedBox(height: 15),
            
            // Anzeige der aus dem Backend geladenen Apps
            Wrap(
              spacing: 8.0, 
              runSpacing: 4.0, 
              children: List<Widget>.generate(_controlledApps.length, (index) {
                final app = _controlledApps[index];
                return Chip(
                  label: Text(app),
                  backgroundColor: Colors.deepPurple.shade50,
                  labelStyle: TextStyle(color: Colors.deepPurple.shade700),
>>>>>>> 2b7966ef79491b7ddc41bb54b64a81448931bc34
                );
              },
            ),
            const SizedBox(height: 10),
<<<<<<< HEAD
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: _controlledApps
                  .map(
                    (app) => Chip(
                      label: Text(app),
                      backgroundColor: Colors.deepPurple.shade50,
                      labelStyle:
                          TextStyle(color: Colors.deepPurple.shade700),
                    ),
                  )
                  .toList(),
            ),
            const Divider(height: 40),

            // 2. Time-of-day impact scores (same as onboarding sliders)
            Text(
              '2. How strongly should we intervene at different times?',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall!
                  .copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              'Adjust how important mindful usage is for you during each time of day. '
              'This directly comes from your onboarding answers.',
            ),
            const SizedBox(height: 30),
            ..._categories.map((category) {
              final value = _loadedImpactScores[category] ?? 5.0;
=======
            const Text('Passen Sie Ihre ursprüngliche Selbsteinschätzung an, um Ihre Motivation zu reflektieren.'),
            const SizedBox(height: 30),

            // Schieberegler-Liste mit den aus dem Backend geladenen Werten
            ..._loadedImpactScores.keys.map((category) {
              final score = _loadedImpactScores[category]!;
>>>>>>> 2b7966ef79491b7ddc41bb54b64a81448931bc34
              return Padding(
                padding: const EdgeInsets.only(bottom: 25.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$category: ${value.round()}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Slider(
                      value: value,
                      min: 0,
                      max: 10,
                      divisions: 10,
                      label: value.round().toString(),
                      onChanged: (double newValue) {
                        _updateImpactScore(category, newValue);
                      },
                    ),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Not at all',
                          style: TextStyle(fontSize: 12, color: Colors.black54),
                        ),
                        Text(
                          'Very strongly',
                          style: TextStyle(fontSize: 12, color: Colors.black54),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }).toList(),

            const SizedBox(height: 20),
            Center(
              child: FilledButton.icon(
                onPressed: _isSaving ? null : _saveSettings,
                icon: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.save),
                label: Text(_isSaving ? 'Speichern...' : 'Änderungen speichern'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 25, vertical: 15),
                  textStyle: const TextStyle(fontSize: 18),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

