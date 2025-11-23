// onboarding_page.dart
import 'dart:math';

import 'package:flutter/material.dart';

import 'app_storage.dart';
import 'dart:convert';               // <--- NEW
import 'package:http/http.dart' as http;  // <--- NEW


class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  AppPrefs? _prefs;

  // Time-of-day impact scores (0–10)
  Map<String, double> _impactScores = {
    'After waking up': 0,
    'During work/uni': 0,
    'In the evening': 0,
    'Before going to bed': 0,
  };

  // Available & selected apps
  final List<String> _availableApps = [
    'Instagram',
    'TikTok',
    'YouTube',
    'Facebook',
    'Twitter/X',
    'Reddit',
    'Snapchat',
  ];

  List<String> _selectedApps = [
    'Instagram',
    'TikTok',
  ];

  Future<void> _loadPrefs() async {
    _prefs = await AppPrefs.getInstance();
  }

  void _updateImpactScore(String category, double newValue) {
    setState(() {
      _impactScores[category] = newValue;
    });
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
      // Last page -> save onboarding results
      final prefs = _prefs!;

      // 1. Save impact scores (time-of-day sliders)
      for (final entry in _impactScores.entries) {
        await prefs.setDouble('$impactScorePrefix${entry.key}', entry.value);
      }

      // 2. Save selected apps
      await prefs.setStringList(controlledAppsKey, _selectedApps);

      // 3. Mark onboarding as complete
      await prefs.setBool(onboardingCompleteKey, true);

      // 4. Navigate away (e.g. to reason page)
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/reason');
    }
  }

  // --- Slides ---

  Widget _buildWelcomeSlide() {
    return const Padding(
      padding: EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Icon(Icons.spa, size: 80, color: Colors.green),
          SizedBox(height: 30),
          Text(
            'You are using TUMuch social media.',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 15),
          Text(
            'Let us help you be more mindful and use your time more consciously.',
            style: TextStyle(fontSize: 18, color: Colors.black54),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionSlide() {
    return const Padding(
      padding: EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Icon(Icons.security, size: 80, color: Colors.blue),
          SizedBox(height: 30),
          Text(
            'System Permissions',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 15),
          Text(
            'Damit wir Ihre App-Nutzung überwachen können, sind spezielle Berechtigungen notwendig. Wir speichern Ihre Daten nur lokal.',
            style: TextStyle(fontSize: 18, color: Colors.black54),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildUsageSlide() {
    final List<int> weeklyUsageMinutes =
        List.generate(7, (index) => 30 + Random().nextInt(150));
    final double maxUsage = weeklyUsageMinutes.reduce(max).toDouble();
    final List<String> weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Last Week´s Social Media Usage ',
            style: Theme.of(context)
                .textTheme
                .headlineMedium!
                .copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          const Text(
            'Eine Darstellung Ihrer geschätzten App-Nutzung der letzten 7 Tage (in Minuten pro Tag).',
            style: TextStyle(fontSize: 16, color: Colors.black54),
          ),
          const SizedBox(height: 40),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: weeklyUsageMinutes.asMap().entries.map((entry) {
                final index = entry.key;
                final usage = entry.value.toDouble();
                final double barHeightRatio = usage / maxUsage;
                final double barHeight = barHeightRatio * 180;

                return Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      '${usage.round()}',
                      style:
                          const TextStyle(fontSize: 12, color: Colors.black87),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      height: barHeight,
                      width: 30,
                      decoration: BoxDecoration(
                        color: Colors.deepPurple.shade300,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(6),
                          topRight: Radius.circular(6),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      weekdays[index],
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                );
              }).toList(),
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
            'During which times during the day do you want to be specifically mindful about your usage?',
            style: Theme.of(context)
                .textTheme
                .headlineMedium!
                .copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          const Text(
            'Rate how strong you want us to intervene during different times of the day.',
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
            'On which apps do you waste time?',
            style: Theme.of(context)
                .textTheme
                .headlineMedium!
                .copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          const Text(
            'Choose for which apps you need us to help you change your habits. You can change this in the Settings later.',
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
            'We don\'t want to forbid you from using your apps. We want you to make conscious decisions about when and why you use social media. We detect the moment you drift off and help you come back on track.',
            style: TextStyle(fontSize: 18, color: Colors.black54),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 15),
          Text(
            'So gewinnen Sie die Kontrolle über Ihre Zeit zurück.',
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
    // _loadPrefs() happens in didChangeDependencies
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadPrefs();
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
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeIn,
                            );
                          },
                          child: const Text('Zurück'),
                        )
                      : const SizedBox(width: 80),
                  _currentPage == 0
                      ? TextButton(
                          onPressed: () {
                            _pageController.jumpToPage(slides.length - 1);
                          },
                          child: const Text('Überspringen'),
                        )
                      : const SizedBox.shrink(),
                  FilledButton(
                    onPressed: _nextPage,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 25, vertical: 12),
                    ),
                    child: Text(isLastPage ? 'Starten' : 'Weiter'),
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

