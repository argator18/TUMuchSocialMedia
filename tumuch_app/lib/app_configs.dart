import 'package:flutter/material.dart';
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
  
  // Die festen Kategorien (für die wir Werte laden/speichern)
  final List<String> _categories = [
    'Stresslevel',
    'Sozialer Vergleich',
    'Zeitverschwendung',
    'FOMO (Fear of Missing Out)',
  ];
  
  @override
  void initState() {
    super.initState();
    _loadSettingsFromBackend();
  }

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
      _isLoading = false;
    });
  }

  // Speichere die Impact Scores im Custom Backend über /echo
  Future<void> _saveImpactScores() async {
    if (_isSaving) return;

    setState(() { _isSaving = true; });
    
    final Map<String, dynamic> dataToSave = {};
    for (final entry in _loadedImpactScores.entries) {
      // Speichere die aktuellen Impact Scores
      dataToSave['$impactScorePrefix${entry.key}'] = entry.value;
    }
    dataToSave['userId'] = demoUserId; // User ID senden
    dataToSave['action'] = 'save_impact_scores'; // Spezifische Aktion für den Server

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
    }
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
            const Text('Passen Sie Ihre ursprüngliche Selbsteinschätzung an, um Ihre Motivation zu reflektieren.'),
            const SizedBox(height: 30),

            // Schieberegler-Liste mit den aus dem Backend geladenen Werten
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