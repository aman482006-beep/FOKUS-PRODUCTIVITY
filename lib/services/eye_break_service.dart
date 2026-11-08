import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import '../shared/theme.dart';
import 'notification_service.dart';

// 20-20-20 Eye Break Reminder
// Every 20 minutes, reminds the user to look at something
// 20 feet away for 20 seconds to reduce digital eye strain.

class EyeBreakService {
  static const _keyEnabled = 'eye_break_enabled';
  static const _keyInterval = 'eye_break_interval';
  static Timer? _timer;
  static int _currentIntervalMinutes = 20;
  static bool _running = false;
  static bool _enabled = false;

  static bool get enabled => _enabled;
  static bool get enabledStatic => _enabled;
  static int get intervalMinutes => _currentIntervalMinutes;
  static int get intervalMinutesStatic => _currentIntervalMinutes;

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool(_keyEnabled) ?? false;
    _currentIntervalMinutes = prefs.getInt(_keyInterval) ?? 20;
    if (_enabled) _startTimer();
  }

  static void start() => _startTimer();
  static void stop() => _stopTimer();

  static Future<void> setEnabled(bool value) async {
    _enabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyEnabled, value);
    if (value) {
      _startTimer();
    } else {
      _stopTimer();
    }
  }

  static Future<void> setInterval(int minutes) async {
    _currentIntervalMinutes = minutes.clamp(5, 120);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyInterval, minutes);
    if (_running) {
      _stopTimer();
      _startTimer();
    }
  }

  static void dispose() {
    _timer?.cancel();
    _timer = null;
    _running = false;
  }

  static void disposeStatic() {
    _timer?.cancel();
    _timer = null;
    _running = false;
  }

  static void _startTimer() {
    _timer?.cancel();
    _running = true;
    _timer = Timer.periodic(
      Duration(minutes: _currentIntervalMinutes),
      (_) => _showReminder(),
    );
  }

  static void _stopTimer() {
    _timer?.cancel();
    _running = false;
  }

  static void _showReminder() {
    NotificationService.show(
      id: 999,
      title: 'Eye Break Reminder',
      body: 'Look at something 20 feet away for 20 seconds.',
    );
  }
}

// Eye Break Settings Widget

class EyeBreakSettingsCard extends StatefulWidget {
  final ThemeTokens? tokens;

  const EyeBreakSettingsCard({super.key, this.tokens});

  @override
  State<EyeBreakSettingsCard> createState() => _EyeBreakSettingsCardState();
}

class _EyeBreakSettingsCardState extends State<EyeBreakSettingsCard> {
  ThemeTokens get _tokens => widget.tokens ?? FocusOsTheme.of(context);

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final t = _tokens;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.borderSubtle, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.teal.withValues(alpha: 0.15),
                ),
                child: Icon(Icons.visibility_outlined,
                    size: 18, color: Colors.teal),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '20-20-20 Eye Breaks',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: t.textPrimary,
                      ),
                    ),
                    Text(
                      'Every ${EyeBreakService.intervalMinutes} min — look away 20ft for 20s',
                      style: TextStyle(
                        fontSize: 11,
                        color: t.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              _EyeBreakSwitch(
                value: EyeBreakService.enabled,
                tokens: t,
                onChanged: (v) {
                  EyeBreakService.setEnabled(v);
                  _refresh();
                },
              ),
            ],
          ),

          // Interval selector
          if (EyeBreakService.enabled) ...[
            const SizedBox(height: 16),
            Divider(color: t.borderSubtle, height: 1),
            const SizedBox(height: 16),
            Row(
              children: [
                Text(
                  'Interval',
                  style: TextStyle(
                    fontSize: 12,
                    color: t.textSecondary,
                  ),
                ),
                const Spacer(),
                _IntervalChip(
                  label: '10 min',
                  selected: EyeBreakService.intervalMinutes == 10,
                  tokens: t,
                  onTap: () {
                    EyeBreakService.setInterval(10);
                    _refresh();
                  },
                ),
                const SizedBox(width: 6),
                _IntervalChip(
                  label: '20 min',
                  selected: EyeBreakService.intervalMinutes == 20,
                  tokens: t,
                  onTap: () {
                    EyeBreakService.setInterval(20);
                    _refresh();
                  },
                ),
                const SizedBox(width: 6),
                _IntervalChip(
                  label: '30 min',
                  selected: EyeBreakService.intervalMinutes == 30,
                  tokens: t,
                  onTap: () {
                    EyeBreakService.setInterval(30);
                    _refresh();
                  },
                ),
                const SizedBox(width: 6),
                _IntervalChip(
                  label: '60 min',
                  selected: EyeBreakService.intervalMinutes == 60,
                  tokens: t,
                  onTap: () {
                    EyeBreakService.setInterval(60);
                    _refresh();
                  },
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _EyeBreakSwitch extends StatelessWidget {
  final bool value;
  final ThemeTokens tokens;
  final ValueChanged<bool> onChanged;

  const _EyeBreakSwitch({
    required this.value,
    required this.tokens,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        width: 46,
        height: 26,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(13),
          color: value
              ? Colors.teal.withValues(alpha: 0.30)
              : tokens.borderMedium,
          border: Border.all(
            color: value
                ? Colors.teal.withValues(alpha: 0.5)
                : tokens.borderSubtle,
            width: 1,
          ),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.all(3),
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color:
                    value ? Colors.teal : tokens.textMuted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _IntervalChip extends StatelessWidget {
  final String label;
  final bool selected;
  final ThemeTokens tokens;
  final VoidCallback onTap;

  const _IntervalChip({
    required this.label,
    required this.selected,
    required this.tokens,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected
              ? Colors.teal.withValues(alpha: 0.15)
              : tokens.borderMedium.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected
                ? Colors.teal.withValues(alpha: 0.40)
                : tokens.borderSubtle,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? Colors.teal : tokens.textSecondary,
          ),
        ),
      ),
    );
  }
}
