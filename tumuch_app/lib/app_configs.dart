// app_configs.dart
import 'package:flutter/material.dart';

import 'app_storage.dart';

//const String API_BASE = "http://172.20.10.3:8000";
const String API_BASE = "http://3.74.158.108:8000";

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

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

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
      _isLoading = false;
    });
  }

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
    }

    if (mounted) {
      setState(() {
        _isSaving = false;
      });
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
                );
              },
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: _controlledApps
                  .map(
                    (app) => Chip(
                      label: Text(app),
                        backgroundColor: const Color(0xFFE1ECF7), // light TUM Blue background
                        labelStyle: const TextStyle(color: Color(0xFF3070B3)), // TUM Blue text
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
                          style:
                              TextStyle(fontSize: 12, color: Colors.black54),
                        ),
                        Text(
                          'Very strongly',
                          style:
                              TextStyle(fontSize: 12, color: Colors.black54),
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

