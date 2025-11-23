// onboarding_page.dart
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'app_storage.dart';
import 'app_configs.dart';
import 'usage_service.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  AppPrefs? _prefs;

  // Name entered on first slide
  final TextEditingController _nameController = TextEditingController();

  // Time-of-day impact scores (0–10) - must match settings categories
  Map<String, double> _impactScores = {
    'After waking up': 0,
    'During work/uni': 0,
    'In the evening': 0,
    'Before going to bed': 0,
  };

  // Available & selected apps
  final List<String> _availableApps = const [
    'Instagram',
    'TikTok',
    'YouTube',
    'Facebook',
    'Twitter/X',
    'Reddit',
    'Snapchat',
  ];

  List<String> _selectedApps = [
  ];

  Future<void> _loadPrefs() async {
    _prefs = await AppPrefs.getInstance();
  }

  void _updateImpactScore(String category, double newValue) {
    setState(() {
      _impactScores[category] = newValue;
    });
  }

  /// Send onboarding data to backend in the format
  /// payload.config expected by OnboardInput:
  ///
  /// {
  ///   "config": {
  ///     "name": "...",
  ///     "surname": "...",
  ///     "apps": [...],
  ///     "morning_factor": ...,
  ///     "worktime_factor": ...,
  ///     "evening_factor": ...,
  ///     "before_bed_factor": ...
  ///   }
  /// }
  ///
  /// And store returned user_id for all future API requests.
  Future<void> _sendOnboardingToServer() async {
    final name = _nameController.text.trim();
    // We no longer ask for surname on the UI, but keep the field for backend compatibility.
    const surname = '';

    // Map our categories to the required JSON fields
    final morningFactor = _impactScores['After waking up']?.round() ?? 0;
    final worktimeFactor = _impactScores['During work/uni']?.round() ?? 0;
    final eveningFactor = _impactScores['In the evening']?.round() ?? 0;
    final beforeBedFactor =
        _impactScores['Before going to bed']?.round() ?? 0;

    // Apps as lowercase like in your example
    final appsLower = _selectedApps.map((app) => app.toLowerCase()).toList();

    final uri = Uri.parse('$API_BASE/onboard');

    final payload = {
      "config": {
        "name": name,
        "surname": surname,
        "apps": appsLower,
        "morning_factor": morningFactor,
        "worktime_factor": worktimeFactor,
        "evening_factor": eveningFactor,
        "before_bed_factor": beforeBedFactor,
      }
    };

    try {
      final response = await http.post(
        uri,
        headers: const {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      );

      debugPrint('Onboard POST status: ${response.statusCode}');
      debugPrint('Onboard response body: ${response.body}');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final userId = decoded['user_id'];

        if (userId != null) {
          final prefs = await AppPrefs.getInstance();
          await prefs.setString(userIdKey, userId.toString());
          debugPrint('Stored user_id: $userId');
        }
      }
    } catch (e) {
      debugPrint('Error sending onboarding data: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not send onboarding data.'),
        ),
      );
    }
  }

  void _nextPage() async {
    if (_prefs == null) {
      await _loadPrefs();
      if (_prefs == null) return;
    }

    final slides = _slides;

    if (_currentPage < slides.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeIn,
      );
    } else {
      final prefs = _prefs!;

      // 1. Save impact scores locally
      for (final entry in _impactScores.entries) {
        await prefs.setDouble('$impactScorePrefix${entry.key}', entry.value);
      }

      // 2. Save apps locally
      await prefs.setStringList(controlledAppsKey, _selectedApps);

      // 3. Save onboarding complete flag
      await prefs.setBool(onboardingCompleteKey, true);

      // 4. Send onboarding data to backend (wrapped in "config")
      await _sendOnboardingToServer();

      // 5. Navigate to main page (adjust route name if needed)
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/');
    }
  }

  // --- Slides ---

  /// 1) Welcome + name only
  Widget _buildWelcomeSlide() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Icon(Icons.spa, size: 80, color: Colors.green),
            const SizedBox(height: 30),
            const Text(
              'You are using TUMuch Social Media',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 15),
            const Text(
              'Let us help you be more mindful and use your time more consciously.',
              style: TextStyle(fontSize: 18, color: Colors.black54),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),

            // Name input only
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'How should we call you?',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 2) Permissions (usage access + accessibility)
  Widget _buildPermissionSlide() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Icon(Icons.security, size: 80, color: Colors.blue),
            const SizedBox(height: 30),
            const Text(
              'System Permissions',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 15),
            const Text(
              'To monitor your social media usage and gently intervene, we need special Android permissions. '
              'We only use this data to help you stay in control.',
              style: TextStyle(fontSize: 18, color: Colors.black54),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),

            Card(
              child: ListTile(
                leading: const Icon(Icons.bar_chart),
                title: const Text('Usage access'),
                subtitle: const Text(
                  'Allow TUMuch Social Media to see your app usage statistics for the last 24 hours.',
                ),
                trailing: ElevatedButton(
                  onPressed: () {
                    UsageService.openUsageSettings();
                  },
                  child: const Text('Open settings'),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: const Icon(Icons.accessibility_new),
                title: const Text('Accessibility service'),
                subtitle: const Text(
                  'Enable our accessibility service so we can detect when social apps are on screen and ask you for a conscious decision.',
                ),
                trailing: ElevatedButton(
                  onPressed: () {
                    UsageService.openAccessibilitySettings();
                  },
                  child: const Text('Open settings'),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'You can always change these permissions later in Android system settings.',
              style: TextStyle(fontSize: 16, color: Colors.black54),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// 3) Usage slide – now uses real data from UsageService.getUsageSummary()
  Widget _buildUsageSlide() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Your recent social media usage',
            style: Theme.of(context)
                .textTheme
                .headlineMedium!
                .copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          const Text(
            'This is a summary of how much time you spent in different apps during the last 24 hours.',
            style: TextStyle(fontSize: 16, color: Colors.black54),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: FutureBuilder<List<dynamic>>(
              future: UsageService.getUsageSummary(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return const Center(
                    child: Text(
                      'Could not load usage data.',
                      style: TextStyle(color: Colors.redAccent),
                    ),
                  );
                }

                final data = snapshot.data ?? [];

                if (data.isEmpty) {
                  return const Center(
                    child: Text(
                      'No usage data available. Make sure you enabled usage access in the previous step.',
                      textAlign: TextAlign.center,
                    ),
                  );
                }

                // We expect a list of maps like:
                // { "appName": "Instagram", "totalMinutes": 120, ... }
                final entries = data
                    .whereType<Map<dynamic, dynamic>>()
                    .map((m) => m.map((key, value) =>
                        MapEntry(key.toString(), value)))
                    .toList();

                if (entries.isEmpty) {
                  return const Center(
                    child: Text(
                      'Usage data format not recognized.',
                      textAlign: TextAlign.center,
                    ),
                  );
                }

                final usages = entries
                    .map((e) => (e['totalMinutes'] as num?)?.toDouble() ?? 0.0)
                    .toList();

                final maxUsage =
                    usages.isEmpty ? 0.0 : usages.reduce(max).toDouble();

                return ListView.builder(
                  itemCount: entries.length,
                  itemBuilder: (context, index) {
                    final entry = entries[index];
                    final appName = entry['appName']?.toString() ??
                        entry['packageName']?.toString() ??
                        'Unknown app';
                    final minutes =
                        (entry['totalMinutes'] as num?)?.toDouble() ?? 0.0;

                    final barRatio =
                        (maxUsage > 0) ? (minutes / maxUsage) : 0.0;

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6.0),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: Text(
                              appName,
                              style: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w600),
                            ),
                          ),
                          Expanded(
                            flex: 4,
                            child: Stack(
                              children: [
                                Container(
                                  height: 16,
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade300,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                FractionallySizedBox(
                                  widthFactor: barRatio.clamp(0.0, 1.0),
                                  child: Container(
                                    height: 16,
                                    decoration: BoxDecoration(
                                      color: Colors.deepPurple.shade300,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 50,
                            child: Text(
                              '${minutes.round()} min',
                              textAlign: TextAlign.right,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoriesSlide() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'When do you want to be especially mindful?',
            style: Theme.of(context)
                .textTheme
                .headlineMedium!
                .copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          const Text(
            'Rate how strongly you want us to intervene during different times of the day.',
            style: TextStyle(fontSize: 16, color: Colors.black54),
          ),
          const SizedBox(height: 30),
          Expanded(
            child: ListView(
              children: _impactScores.keys.map((category) {
                final value = _impactScores[category]!;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 20.0),
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
                            style: TextStyle(
                                fontSize: 12, color: Colors.black54),
                          ),
                          Text(
                            'Very strongly',
                            style: TextStyle(
                                fontSize: 12, color: Colors.black54),
                          ),
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

  Widget _buildAppSelectionSlide() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Which apps should we track?',
            style: Theme.of(context)
                .textTheme
                .headlineMedium!
                .copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          const Text(
            'Choose the apps where you want us to help you change your habits. ',
            style: TextStyle(fontSize: 16, color: Colors.black54),
          ),
          const SizedBox(height: 30),
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
                        if (!_selectedApps.contains(app)) {
                          _selectedApps.add(app);
                        }
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
            'We do not want to forbid you from using your apps. '
            'We want you to make conscious decisions about when and why you use social media. '
            'We detect the moment you drift off and help you get back on track.',
            style: TextStyle(fontSize: 18, color: Colors.black54),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 15),
          Text(
            'This way, you regain control over your time.',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  List<Widget> get _slides => [
        _buildWelcomeSlide(),
        _buildPermissionSlide(),
        _buildUsageSlide(),
        _buildCategoriesSlide(),
        _buildAppSelectionSlide(),
        _buildPrincipleSlide(),
      ];

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadPrefs();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    super.dispose();
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
            LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey.shade300,
              color: Theme.of(context).colorScheme.primary,
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (int page) {
                  setState(() {
                    _currentPage = page;
                  });
                },
                children: slides,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 24.0, vertical: 20.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  _currentPage > 0
                      ? TextButton(
                          onPressed: () {
                            _pageController.previousPage(
                              duration:
                                  const Duration(milliseconds: 300),
                              curve: Curves.easeIn,
                            );
                          },
                          child: const Text('Back'),
                        )
                      : const SizedBox(width: 80),
                  FilledButton(
                    onPressed: _nextPage,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 25, vertical: 12),
                    ),
                    child: Text(isLastPage ? 'Start' : 'Next'),
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

