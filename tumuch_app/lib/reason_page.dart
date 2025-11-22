import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

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
    } else {
      // Check & request permission
      final hasPermission = await _recorder.hasPermission();
      if (!hasPermission) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No microphone permission.'),
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
        path: filePath, // <- satisfies "required named parameter 'path'"
      );

      setState(() {
        _isRecording = true;
        _audioPath = null;
      });
    }
  }

  void _submit() {
    final textReason = _reasonController.text.trim();
    final hasText = textReason.isNotEmpty;
    final hasVoice = _audioPath != null;

    if (!hasText && !hasVoice) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please type a reason or record a voice message.'),
        ),
      );
      return;
    }

    debugPrint('Text reason: $textReason');
    debugPrint('Recorded audio path: $_audioPath');

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Thanks! Your input is captured (locally for now).'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Welcome'),
        backgroundColor: colorScheme.inversePrimary,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Why do you want to use this app?',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'You can either type your reason or record a short voice message.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),

              TextField(
                controller: _reasonController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Type your reason',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                  hintText: 'e.g. I want to focus better, track my usage, ...',
                ),
              ),

              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: Divider(color: Colors.grey.shade400),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8.0),
                    child: Text('or'),
                  ),
                  Expanded(
                    child: Divider(color: Colors.grey.shade400),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: _toggleRecording,
                    icon: Icon(_isRecording ? Icons.stop : Icons.mic),
                    label:
                        Text(_isRecording ? 'Stop recording' : 'Record voice'),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _isRecording
                          ? 'Recording...'
                          : (_audioPath != null
                              ? 'Recorded file: $_audioPath'
                              : 'No voice message recorded'),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),

              const Spacer(),

              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _submit,
                  child: const Text('Continue'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

