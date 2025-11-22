import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'home_page.dart'; // Import der HomePage

class ReasonPage extends StatefulWidget {
  const ReasonPage({super.key});

  @override
  State<ReasonPage> createState() => _ReasonPageState();
}

class _ReasonPageState extends State<ReasonPage> {
  final TextEditingController _reasonController = TextEditingController();
  final AudioRecorder _recorder = AudioRecorder();

  bool _isRecording = false;
  String? _audioPath;

  // Optionen für das Dropdown-Menü (neu)
  final List<String> _learnedReasons = [
    'Gelernter Grund 1; 3 Minuten',
    'Gelernter Grund 2; 1 Minute',
    'Gelernter Grund 3; 30 Sekunden',
  ];
  
  // Aktuell ausgewählter Wert
  String? _selectedLearnedReason; 

  @override
  void initState() {
    super.initState();
    // Setze den initialen Wert auf den ersten Eintrag
    _selectedLearnedReason = _learnedReasons.first;
  }

  @override
  void dispose() {
    _reasonController.dispose();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      // Stop recording
      final path = await _recorder.stop();
      setState(() {
        _isRecording = false;
        _audioPath = path;
      });
      // Kurze Bestätigung anzeigen
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Aufnahme beendet und gespeichert.'),
          duration: Duration(seconds: 1),
        ),
      );
    } else {
      // Check & request permission
      final hasPermission = await _recorder.hasPermission();
      if (!hasPermission) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Keine Mikrofonberechtigung.'),
          ),
        );
        return;
      }

      // Build a file path to store the recording
      final dir = await getApplicationDocumentsDirectory();
      final filePath = '${dir.path}/reason_${DateTime.now().millisecondsSinceEpoch}.m4a';

      // Start recording
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: filePath,
      );

      setState(() {
        _isRecording = true;
        _audioPath = null;
      });
      // Visuelles Feedback für Start der Aufnahme
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Aufnahme gestartet...'),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  void _submit() {
    final textReason = _reasonController.text.trim();
    final hasText = textReason.isNotEmpty;
    final hasVoice = _audioPath != null;
    
    // Dropdown-Grund wird immer als ausgewählt betrachtet, da er einen Initialwert hat
    final learnedReason = _selectedLearnedReason;

    // Nur prüfen, ob das Textfeld leer ist UND keine Sprachaufnahme existiert.
    if (!hasText && !hasVoice) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bitte geben Sie einen Grund ein, nehmen Sie eine Sprachnachricht auf oder wählen Sie einen gelernten Grund.'),
        ),
      );
      return;
    }

    // Grund wurde erfasst (hier würden Sie ihn in der Datenbank speichern)
    debugPrint('Text reason: $textReason');
    debugPrint('Recorded audio path: $_audioPath');
    debugPrint('Selected learned reason: $learnedReason');

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Grund erfasst! Sie werden zum Haupt-Dashboard weitergeleitet.'),
        duration: Duration(seconds: 1),
      ),
    );
    
    // Navigiere zum Home-Dashboard und ersetze den Navigationsstapel.
    Navigator.pushReplacementNamed(context, '/home'); 
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mein Grund'), 
        backgroundColor: colorScheme.inversePrimary,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Warum möchten Sie Ihre Social Media-Nutzung reduzieren?',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'Notieren Sie Ihren Grund, sprechen Sie ihn ein oder wählen Sie einen gelernten Grund aus.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),

              // NEUE ZEILE: Textfeld und Dropdown in einer Row
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _reasonController,
                      maxLines: 1, // Reduziert auf eine Zeile (neu)
                      decoration: const InputDecoration(
                        labelText: 'Grund eingeben',
                        border: OutlineInputBorder(),
                        hintText: 'z.B. Mehr Fokus, mehr Zeit für Hobbys',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  
                  // NEU: Dropdown-Menü
                  DropdownButton<String>(
                    value: _selectedLearnedReason,
                    items: _learnedReasons.map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value, style: const TextStyle(fontSize: 14)),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      setState(() {
                        _selectedLearnedReason = newValue;
                      });
                    },
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),

              // Visuelle Trennlinie
              Row(
                children: [
                  Expanded(
                    child: Divider(color: Colors.grey.shade400),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8.0),
                    child: Text('oder'),
                  ),
                  Expanded(
                    child: Divider(color: Colors.grey.shade400),
                  ),
                ],
              ),

              const SizedBox(height: 16),
              
              // Anzeige für aufgenommene Datei
              Text(
                _audioPath != null
                    ? 'Gespeicherte Aufnahme: ${File(_audioPath!).uri.pathSegments.last}'
                    : 'Es wurde noch keine Sprachaufnahme erstellt.',
                style: TextStyle(fontStyle: _audioPath != null ? FontStyle.normal : FontStyle.italic),
                overflow: TextOverflow.ellipsis,
              ),

              const Spacer(),

              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _submit,
                  child: const Text('Bestätigen und abschließen'),
                ),
              ),
            ],
          ),
        ),
      ),
      // NEU: Floating Action Button in der Mitte unten
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FloatingActionButton(
        onPressed: _toggleRecording,
        backgroundColor: _isRecording ? Colors.red.shade600 : colorScheme.primary,
        tooltip: _isRecording ? 'Aufnahme stoppen' : 'Sprachaufnahme starten',
        elevation: 4,
        child: Icon(
          _isRecording ? Icons.stop : Icons.mic, 
          size: 32,
          color: Colors.white,
        ),
      ),
    );
  }
}