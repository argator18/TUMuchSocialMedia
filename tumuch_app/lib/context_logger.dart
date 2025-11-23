// lib/context_logger.dart
class AppEvent {
  final DateTime time;
  final String type;
  final Map<String, dynamic> data;

  AppEvent({
    required this.time,
    required this.type,
    required this.data,
  });

  Map<String, dynamic> toJson() => {
        'time': time.toIso8601String(),
        'type': type,
        'data': data,
      };
}

class ContextLogger {
  static final ContextLogger _instance = ContextLogger._internal();
  factory ContextLogger() => _instance;
  ContextLogger._internal();

  final List<AppEvent> _events = [];
  Duration contextWindow = const Duration(minutes: 5);

  void log(String type, Map<String, dynamic> data) {
    final now = DateTime.now();
    _events.add(AppEvent(time: now, type: type, data: data));
    _trim(now);
  }

  void _trim(DateTime now) {
    _events.removeWhere((e) => now.difference(e.time) > contextWindow);
  }

  List<AppEvent> getCurrentContext() {
    final now = DateTime.now();
    _trim(now);
    return List.unmodifiable(_events);
  }
}

