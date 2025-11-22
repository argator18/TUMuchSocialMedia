import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

class ReasonPage extends StatefulWidget {
  /// Optionally pass the app name, e.g. ReasonPage(appName: 'Instagram')
  final String appName;

  const ReasonPage({super.key, this.appName = 'Instagram'});

  @override
  State<ReasonPage> createState() => _ReasonPageState();
}

class _ReasonPageState extends State<ReasonPage> {
  final TextEditingController _reasonController = TextEditingController();
  final AudioRecorder _recorder = AudioRecorder();

  bool _isRecording = false;
  String? _audioPath;

  // Quick suggestions INCLUDING specific time requests
    final List<String> _quickSuggestions = [
      'Ich möchte __APP__ 5 Minuten lang nutzen, um auf wichtige Nachrichten zu antworten.',
      'Ich möchte __APP__ 3 Minuten lang nutzen, um etwas Wichtiges zu posten.',
      'Ich möchte __APP__ 2 Minuten lang nutzen, um kurz zu scrollen und dann zurück zur Aufgabe zu gehen.',
    ];

  // API response state
  bool _isSubmitting = false;
  bool? _allowResult;
  int? _allowedMinutes;
  String? _replyMessage;

  @override
  void initState() {
      super.initState();

      // Replace placeholder with real app name
      for (var i = 0; i < _quickSuggestions.length; i++) {
        _quickSuggestions[i] =
            _quickSuggestions[i].replaceAll('__APP__', widget.appName);
      }
    }


  @override
  void dispose() {
    _reasonController.dispose();
    _recorder.dispose();
    super.dispose();
  }

  // ---------------- API CALL ----------------

  Future<void> _sendToBackend(String text) async {
    if (text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bitte gib einen Grund an.')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
      _allowResult = null;
      _allowedMinutes = null;
      _replyMessage = null;
    });

    final uri = Uri.parse('http://3.74.158.108:8000/echo');
    final payload = {
      // simplest: encode app + reason together
      'text': '[${widget.appName}] $text',
    };

    try {
      final resp = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final allow = data['allow'] as bool?;
        final time = (data['time'] as num?)?.toInt();
        final reply = data['reply'] as String?;

        setState(() {
          _allowResult = allow;
          _allowedMinutes = time;
          _replyMessage = reply;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Serverfehler: ${resp.statusCode}'),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Netzwerkfehler: $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  // ---------------- TEXT SUBMIT ----------------

  Future<void> _submitText() async {
    final textReason = _reasonController.text.trim();
    if (textReason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Bitte gib zuerst einen Text ein – auch mit gewünschter Nutzungsdauer (z.B. 5 Minuten).'),
        ),
      );
      return;
    }

    await _sendToBackend(textReason);
  }

  // ---------------- VOICE RECORDING ----------------

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      // Stop recording -> auto send
      final path = await _recorder.stop();
      setState(() {
        _isRecording = false;
        _audioPath = path;
      });

      if (path != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Aufnahme beendet – wird jetzt ausgewertet.'),
            duration: Duration(seconds: 1),
          ),
        );

        // For now: send the file path as part of text.
        // Later you could upload the actual file.
        final voiceText =
            'Sprachnachricht zu __APP__ gespeichert unter: $path (inkl. gewünschter Zeit bitte beim nächsten Mal nennen).'
                .replaceAll('__APP__', widget.appName);
        await _sendToBackend(voiceText);
      }
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
      final filePath =
          '${dir.path}/reason_${DateTime.now().millisecondsSinceEpoch}.m4a';

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

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Aufnahme gestartet...'),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  // ---------------- UI ----------------

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('Warum ${widget.appName}?'),
        backgroundColor: colorScheme.inversePrimary,
      ),
      body: SafeArea(
        child: Padding(
          // etwas Platz unten für den FAB
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Warum möchtest du gerade ${widget.appName} öffnen – und wie lange?',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'Formuliere kurz, warum du die App jetzt nutzen möchtest '
                'und wie viel Zeit du dir geben willst (z.B. 5 Minuten, 3 Minuten).',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),

              // Textfeld + "WhatsApp-style" send button
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _reasonController,
                      maxLines: 1,
                      decoration: InputDecoration(
                        labelText: 'Grund + gewünschte Zeit',
                        border: const OutlineInputBorder(),
                        hintText:
                            'z.B. 5 Minuten Nachrichten checken und dann zurück zur Aufgabe',
                        suffixIcon: _isSubmitting
                            ? const Padding(
                                padding: EdgeInsets.all(12.0),
                                child: SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              )
                            : IconButton(
                                icon: const Icon(Icons.send),
                                onPressed: _submitText,
                              ),
                      ),
                      onSubmitted: (_) => _submitText(),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Quick suggestion buttons WITH requested time in the text
              Wrap(
                spacing: 8.0,
                runSpacing: 4.0,
                children: _quickSuggestions.map((suggestion) {
                  return OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _reasonController.text = suggestion;
                        _reasonController.selection =
                            TextSelection.fromPosition(
                          TextPosition(offset: suggestion.length),
                        );
                      });
                    },
                    child: Text(
                      suggestion,
                      textAlign: TextAlign.center,
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 16),

              // Anzeige der letzten Aufnahme (optional, aber ohne "oder Stimme"-Block)
              if (_audioPath != null || _isRecording) ...[
                Text(
                  _isRecording
                      ? 'Aufnahme läuft ...'
                      : 'Letzte Aufnahme: ${File(_audioPath!).uri.pathSegments.last}',
                  style: Theme.of(context).textTheme.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 16),
              ],

              // API Response card (green arrow / red cross)
              if (_allowResult != null && _replyMessage != null)
                Card(
                  color: _allowResult!
                      ? Colors.green.shade50
                      : Colors.red.shade50,
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          _allowResult! ? Icons.arrow_circle_up : Icons.close,
                          color: _allowResult! ? Colors.green : Colors.red,
                          size: 56,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _allowResult!
                                    ? 'Go for it – aber bewusst!'
                                    : 'Heute lieber nicht.',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      color: _allowResult!
                                          ? Colors.green.shade800
                                          : Colors.red.shade800,
                                    ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _replyMessage!,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              if (_allowedMinutes != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Text(
                                    'Erlaubte Zeit: $_allowedMinutes Minuten.',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelLarge
                                        ?.copyWith(
                                          color: _allowResult!
                                              ? Colors.green.shade800
                                              : Colors.red.shade800,
                                        ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              const Spacer(),
            ],
          ),
        ),
      ),

      // Mic FAB in the middle bottom (behaviour unchanged)
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FloatingActionButton(
        onPressed: _isSubmitting ? null : _toggleRecording,
        backgroundColor:
            _isRecording ? Colors.red.shade600 : colorScheme.primary,
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

