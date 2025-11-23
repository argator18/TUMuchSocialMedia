import 'dart:async'; // <-- for Timer
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart'; // for MediaType

import 'context_logger.dart';
import 'screen_capture_service.dart';
import 'app_configs.dart';
import 'usage_service.dart';
import 'app_storage.dart';

/// TUM corporate blue
const Color tumBlue = Color(0xFF0065BD);

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

  // API response state
  bool _isSubmitting = false;
  bool? _allowResult;
  int? _allowedMinutes;
  String? _replyMessage;

  // Cached future so we don't call /todays_count + usage on every rebuild
  late Future<Map<String, dynamic>> _todaySummaryFuture;

  // Cooldown state (for “you can’t ask again for 5 minutes”)
  Duration _cooldownRemaining = Duration.zero;
  Timer? _cooldownTimer;

  bool get _isInCooldown => _cooldownRemaining.inSeconds > 0;

  /// Remove heavy/icon fields from usage list before sending to backend.
  List<dynamic> _stripIconsFromUsage(List<dynamic> usage) {
    return usage.map((entry) {
      if (entry is Map) {
        // create a copy so we don't mutate the original list
        final copy = Map.of(entry);
        copy.remove('iconBase64');
        return copy;
      }
      return entry;
    }).toList();
  }

  @override
  void initState() {
    super.initState();

    // Cache today's summary once; can be refreshed explicitly if needed
    _todaySummaryFuture = _loadTodaySummary();

    // Log that this page was opened
    ContextLogger().log('open_page', {
      'page': 'ReasonPage',
      'appName': widget.appName,
    });
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _reasonController.dispose();
    _recorder.dispose();
    super.dispose();
  }

  /// Start a cooldown (e.g. 5 minutes) after a denied request
  void _startCooldown(Duration duration) {
    _cooldownTimer?.cancel();
    setState(() {
      _cooldownRemaining = duration;
    });

    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_cooldownRemaining.inSeconds <= 1) {
        timer.cancel();
        setState(() {
          _cooldownRemaining = Duration.zero;
        });
      } else {
        setState(() {
          _cooldownRemaining =
              _cooldownRemaining - const Duration(seconds: 1);
        });
      }
    });
  }

  String _formatCooldown(Duration d) {
    final totalSeconds = d.inSeconds;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    final mm = minutes.toString().padLeft(2, '0');
    final ss = seconds.toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  /// If you want to re-fetch the numbers (e.g. after a successful request),
  /// call this once instead of rebuilding the FutureBuilder every second.
  void _refreshTodaySummary() {
    setState(() {
      _todaySummaryFuture = _loadTodaySummary();
    });
  }

  // ---------------- HELPERS FOR TODAY'S SUMMARY ----------------

  /// Fetch request count from /todays_count endpoint for this user.
  Future<int> _fetchTodaysRequestCount(String? userId) async {
    debugPrint('[COUNT] fetch for userId="$userId"');

    if (userId == null) {
      debugPrint('[COUNT] userId is null → returning 0');
      return 0;
    }

    final uri = Uri.parse('$API_BASE/todays_count?user_id=$userId');
    debugPrint('[COUNT] GET $uri');

    try {
      final headers = await buildDefaultHeaders();
      debugPrint('[COUNT] headers=$headers');

      final resp = await http.get(uri, headers: headers);

      debugPrint('[COUNT] status=${resp.statusCode}');
      debugPrint('[COUNT] body=${resp.body}');

      if (resp.statusCode != 200) {
        debugPrint('[COUNT] Non-200 response → returning 0');
        return 0;
      }

      final data = jsonDecode(resp.body);
      debugPrint('[COUNT] decoded=$data');

      final n = (data['daily_count'] as num?)?.toInt();
      debugPrint('[COUNT] extracted daily_count=$n');

      return n ?? 0;
    } catch (e) {
      debugPrint('[COUNT] ERROR: $e');
      return 0;
    }
  }

  /// Load today's usage for the selected apps + request count from backend.
  Future<Map<String, dynamic>> _loadTodaySummary() async {
    final prefs = await AppPrefs.getInstance();

    // selected apps from onboarding/settings
    final selectedApps =
        await prefs.getStringList(controlledAppsKey) ?? <String>[];

    // full usage from native side
    final usageRaw = await UsageService.getUsageSummary();
    final entries = usageRaw
        .whereType<Map>()
        .map((m) => m.map((k, v) => MapEntry(k.toString(), v)))
        .toList();

    int totalMinutes = 0;

    for (final entry in entries) {
      final appName = entry['appName']?.toString() ??
          entry['packageName']?.toString() ??
          '';

      // convert to minutes; support both totalMinutes and totalTimeForeground
      final minutes = (entry['totalMinutes'] as num?)?.toInt() ??
          ((entry['totalTimeForeground'] as num?)?.toInt() ?? 0) ~/ 60000;

      // only count selected apps
      if (selectedApps.contains(appName)) {
        totalMinutes += minutes;
      }
    }

    final hours = totalMinutes / 60.0;

    // fetch todays_count from backend
    final userId = await prefs.getString(userIdKey);
    final requests = await _fetchTodaysRequestCount(userId);

    return {
      'hours': hours,
      'requests': requests,
    };
  }

  Widget _buildTodayUsage() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _todaySummaryFuture, // ⬅️ cached future, not a new call
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16.0),
            child: Center(
              child: SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: Text(
              'Could not load today\'s usage.',
              style: TextStyle(color: Colors.redAccent, fontSize: 12),
            ),
          );
        }

        final hours = (snapshot.data!['hours'] as num?)?.toDouble() ?? 0.0;
        final requests = (snapshot.data!['requests'] as int?) ?? 0;

        final hoursLabel = hours.toStringAsFixed(1);

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0),
          child: Row(
            children: [
              Expanded(
                child: Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 12.0,
                      horizontal: 8.0,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          hoursLabel,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'hours today\nin selected apps',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 12.0,
                      horizontal: 8.0,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$requests',
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'requests made\nso far today',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ---------------- API CALL: TEXT ----------------

  Future<void> _sendToBackend(String text) async {
    if (text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a reason.')),
      );
      return;
    }

    if (_isInCooldown) {
      final msg =
          'You need to wait ${_formatCooldown(_cooldownRemaining)} before asking again.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
      _allowResult = null;
      _allowedMinutes = null;
      _replyMessage = null;
    });

    // Usage from native side
    final usageRaw = await UsageService.getUsageSummary();
    final usage = _stripIconsFromUsage(usageRaw);

    // Load user_id from storage
    final prefs = await AppPrefs.getInstance();
    final userId = await prefs.getString(userIdKey);

    final uri = Uri.parse('$API_BASE/echo');
    debugPrint('Usage summary (text): $usage');
    debugPrint('Usage summary (text, JSON): ${jsonEncode(usage)}');

    final payload = {
      'user_id': userId,
      'text': '[${widget.appName}] $text',
      'usage': usage,
    };

    try {
      final headers = await buildDefaultHeaders();
      final resp = await http.post(
        uri,
        headers: headers,
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

        ContextLogger().log('api_decision', {
          'allow': allow,
          'time': time,
          'reply': reply,
          'appName': widget.appName,
        });

        // If denied → start 5 min cooldown
        if (allow == false) {
          _startCooldown(const Duration(minutes: 5));
        }

        // Refresh request counters after a decision
        _refreshTodaySummary();

        await ScreenCaptureService.captureAndSend();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Server error: ${resp.statusCode}'),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Network error: $e'),
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

  // ---------------- API CALL: VOICE (LIKE /text) ----------------

  Future<void> _sendVoiceToBackend(String path) async {
    if (_isInCooldown) {
      final msg =
          'You need to wait ${_formatCooldown(_cooldownRemaining)} before asking again.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
      return;
    }

    final file = File(path);
    if (!await file.exists()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Audio file not found.')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
      _allowResult = null;
      _allowedMinutes = null;
      _replyMessage = null;
    });

    // Usage from native side
    final usageRaw = await UsageService.getUsageSummary();
    final usage = _stripIconsFromUsage(usageRaw);

    // Load user_id from storage
    final prefs = await AppPrefs.getInstance();
    final userId = await prefs.getString(userIdKey);

    final uri = Uri.parse('$API_BASE/voice');

    try {
      // build headers like /text (includes X-User-Id if available)
      final headers = await buildDefaultHeaders();

      final request = http.MultipartRequest('POST', uri)
        ..files.add(
          await http.MultipartFile.fromPath(
            'file',
            file.path,
            contentType: MediaType('audio', 'm4a'),
          ),
        )
        // usage as JSON string – same key as /text payload
        ..fields['usage'] = jsonEncode(usage);

      // Add user_id as a field in the form body, like /text has in its JSON
      if (userId != null) {
        request.fields['user_id'] = userId;
      }

      // Add all default headers, but REMOVE Content-Type
      request.headers.addAll(headers);
      request.headers.remove('Content-Type');

      final streamed = await request.send();
      final resp = await http.Response.fromStream(streamed);

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

        ContextLogger().log('api_decision_voice', {
          'allow': allow,
          'time': time,
          'reply': reply,
          'appName': widget.appName,
        });

        // If denied → start 5 min cooldown
        if (allow == false) {
          _startCooldown(const Duration(minutes: 5));
        }

        // Refresh counters after a voice decision as well
        _refreshTodaySummary();

        await ScreenCaptureService.captureAndSend();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Audio server error: ${resp.statusCode}'),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Audio network error: $e'),
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
            'Please enter a short text – including how long you want to use the app (e.g. 5 minutes).',
          ),
        ),
      );
      return;
    }

    ContextLogger().log('submit_text_reason', {
      'reason': textReason,
      'appName': widget.appName,
    });

    await _sendToBackend(textReason);
  }

  // ---------------- VOICE RECORDING ----------------

  Future<void> _toggleRecording() async {
    if (_isInCooldown) {
      final msg =
          'You need to wait ${_formatCooldown(_cooldownRemaining)} before asking again.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
      return;
    }

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
            content: Text('Recording stopped – now being analyzed.'),
            duration: Duration(seconds: 1),
          ),
        );

        ContextLogger().log('submit_voice_reason', {
          'path': path,
          'appName': widget.appName,
        });

        await _sendVoiceToBackend(path);
      }

      return;
    }

    // START recording
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No microphone permission.'),
        ),
      );
      return;
    }

    final dir = await getApplicationDocumentsDirectory();
    final filePath =
        '${dir.path}/reason_${DateTime.now().millisecondsSinceEpoch}.m4a';

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

    ContextLogger().log('voice_recording_started', {
      'filePath': filePath,
      'appName': widget.appName,
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Recording started...'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  // ---------------- UI ----------------

  @override
  Widget build(BuildContext context) {
    final cooldownText =
        _isInCooldown ? 'You can ask again in ${_formatCooldown(_cooldownRemaining)}.' : null;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: tumBlue,
        centerTitle: true,
        title: Text(
          'Why ${widget.appName}?',
          style: const TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.camera),
            tooltip: 'Send screen + context',
            onPressed: () async {
              await ScreenCaptureService.captureAndSend();
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          // some space at the bottom for the FAB
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Why do you want to open ${widget.appName} right now – and for how long?',
                style: Theme.of(context).textTheme.headlineSmall,
              ),

              // Two big numbers: hours + requests
              _buildTodayUsage(),

              if (cooldownText != null) ...[
                const SizedBox(height: 8),
                Text(
                  cooldownText,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.redAccent,
                  ),
                ),
              ],

              const SizedBox(height: 8),
              Text(
                'Briefly describe why you want to use the app now and how much time you want to give yourself (e.g. 5 minutes, 3 minutes).',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),

              // Textfield + send button
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _reasonController,
                      maxLines: 1,
                      enabled: !_isInCooldown && !_isSubmitting,
                      decoration: InputDecoration(
                        labelText: 'Reason + desired time',
                        border: const OutlineInputBorder(),
                        hintText:
                            'E.g. 5 minutes to reply to messages and then back to work',
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
                                onPressed: (_isInCooldown || _isSubmitting)
                                    ? null
                                    : _submitText,
                              ),
                      ),
                      onChanged: (value) {
                        ContextLogger().log('text_changed', {
                          'field': 'reason',
                          'length': value.length,
                          'appName': widget.appName,
                        });
                      },
                      onSubmitted: (_) {
                        if (!_isInCooldown && !_isSubmitting) {
                          _submitText();
                        }
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Recording status / last recording
              if (_audioPath != null || _isRecording) ...[
                Text(
                  _isRecording
                      ? 'Recording in progress...'
                      : 'Last recording: ${File(_audioPath!).uri.pathSegments.last}',
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
                                    ? 'Go for it – but don\'t lose yourself!'
                                    : 'Try again later!',
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
                                    'Allowed time: $_allowedMinutes minutes.',
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

      // Mic FAB in the middle bottom, TUM blue
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FloatingActionButton(
        onPressed:
            (_isSubmitting || _isInCooldown) ? null : _toggleRecording,
        backgroundColor: _isRecording
            ? tumBlue.withOpacity(0.8)
            : tumBlue,
        tooltip: _isRecording
            ? 'Stop recording'
            : 'Start voice recording',
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

