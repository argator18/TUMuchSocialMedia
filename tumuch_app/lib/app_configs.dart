import 'package:flutter/material.dart';

// Die Hauptkonfigurationsseite für Limits und Ziele.
class AppConfigs extends StatefulWidget {
  const AppConfigs({super.key});

  @override
  State<AppConfigs> createState() => _AppConfigsState();
}

class _AppConfigsState extends State<AppConfigs> {
  // 1. Controller für die gewünschte Zeit in Minuten
  final TextEditingController _timeLimitController = TextEditingController(text: '60');
  
  // 2. Liste aller wählbaren Apps
  final List<String> _availableApps = [
    'Facebook',
    'Instagram',
    'TikTok',
    'Twitter (X)',
    'Reddit',
    'YouTube (Feed)',
    'Snapchat',
  ];
  
  // Set zur Speicherung der ausgewählten Apps
  Set<String> _selectedApps = {'Instagram', 'TikTok'};
  
  // 3. Zustand für die Browser-Nutzung
  bool _includeBrowser = false;

  @override
  void dispose() {
    _timeLimitController.dispose();
    super.dispose();
  }

  void _submitGoals() {
    final timeLimitString = _timeLimitController.text.trim();
    // Konvertiere Eingabe in Minuten
    final timeLimitMinutes = int.tryParse(timeLimitString) ?? 0;
    
    if (timeLimitMinutes <= 0 || _selectedApps.isEmpty) {
       ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bitte geben Sie eine gültige Zeit an (>0) und wählen Sie mindestens eine App aus.'),
        ),
      );
      return;
    }

    // Konsolidierte Ziele speichern/anzeigen (Simulierte Speicherung)
    debugPrint('--- Neue Ziele ---');
    debugPrint('Tägliches Limit: $timeLimitMinutes Minuten');
    debugPrint('Überwachte Apps: ${_selectedApps.join(', ')}');
    debugPrint('Browser-Nutzung inkludiert: $_includeBrowser');
    debugPrint('------------------');
    
    // AKTUALISIERT: Navigieren Sie zur Homepage und ersetzen Sie den Navigationsstapel.
    Navigator.pushReplacementNamed(context, '/home');
  }

  // Funktion zum Öffnen des App-Auswahldialogs
  void _openAppSelectionDialog() async {
    final List<String>? results = await showDialog<List<String>>(
      context: context,
      builder: (BuildContext context) {
        // Temporäre Kopie der Auswahl für den Dialog
        Set<String> tempSelected = Set.from(_selectedApps);
        
        return StatefulBuilder(
          builder: (context, setStateInDialog) {
            return AlertDialog(
              title: const Text('Apps auswählen'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: _availableApps.map((app) {
                    return CheckboxListTile(
                      title: Text(app),
                      value: tempSelected.contains(app),
                      onChanged: (bool? isChecked) {
                        setStateInDialog(() {
                          if (isChecked == true) {
                            tempSelected.add(app);
                          } else {
                            tempSelected.remove(app);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text('Abbrechen'),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
                ElevatedButton(
                  child: const Text('Bestätigen'),
                  onPressed: () {
                    Navigator.of(context).pop(tempSelected.toList());
                  },
                ),
              ],
            );
          },
        );
      },
    );
    
    if (results != null) {
      setState(() {
        _selectedApps = Set.from(results);
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ihre Social Media Limits'),
        backgroundColor: colorScheme.inversePrimary,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Definieren Sie Ihre täglichen Nutzungslimits.',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 20),

              // 1. Zeitlimit-Eingabefeld
              TextField(
                controller: _timeLimitController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Erlaubte Social Media Zeit pro Tag (Minuten)',
                  border: OutlineInputBorder(),
                  suffixText: 'Minuten',
                  hintText: 'z.B. 60',
                ),
              ),
              
              const SizedBox(height: 30),

              // 2. App-Auswahl
              Text(
                'Überwachte Apps',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),

              // Ausgewählte Apps als Chips anzeigen
              Wrap(
                spacing: 8.0,
                runSpacing: 4.0,
                children: _selectedApps.map((app) {
                  return Chip(
                    label: Text(app),
                    onDeleted: () {
                      setState(() {
                        _selectedApps.remove(app);
                      });
                    },
                  );
                }).toList(),
              ),

              const SizedBox(height: 10),
              
              // Button zum Öffnen des App-Auswahl-Dialogs
              OutlinedButton.icon(
                onPressed: _openAppSelectionDialog,
                icon: const Icon(Icons.apps),
                label: Text(
                  _selectedApps.isEmpty 
                  ? 'Apps hinzufügen' 
                  : 'Apps bearbeiten (${_selectedApps.length} ausgewählt)'
                ),
              ),

              const SizedBox(height: 30),
              
              // 3. Browser-Checkbox
              SwitchListTile(
                title: const Text('Social Media Nutzung im Browser einschließen'),
                subtitle: const Text('Aktivieren Sie dies, um auch die Zeit über Chrome, Safari, etc. zu erfassen.'),
                value: _includeBrowser,
                onChanged: (bool value) {
                  setState(() {
                    _includeBrowser = value;
                  });
                },
                secondary: const Icon(Icons.language),
              ),
              
              const Spacer(),

              // Button zum Speichern
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _submitGoals,
                  icon: const Icon(Icons.save),
                  label: const Text('Save'), // AKTUALISIERT
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    textStyle: const TextStyle(fontSize: 18),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}