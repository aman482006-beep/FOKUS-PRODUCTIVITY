import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/motion.dart' as motion;
import '../../shared/theme.dart';
import '../../shared/widgets/premium_card.dart';
import '../../core/providers.dart';
import '../../models/reminder.dart';
import '../../services/timer_sound_service.dart';

/// RemindersPage — schedule and manage custom reminders.
class RemindersPage extends ConsumerStatefulWidget {
  const RemindersPage({super.key});

  @override
  ConsumerState<RemindersPage> createState() => _RemindersPageState();
}

class _RemindersPageState extends ConsumerState<RemindersPage> {
  final ScrollController _scrollController = ScrollController();
  final _topicController = TextEditingController();
  final _textController = TextEditingController();
  
  DateTime _selectedDate = DateTime.now();
  int _selectedHour = 12;
  int _selectedMinute = 0;
  String _selectedAmPm = 'AM';

  String _selectedSound = 'assets/alarm_sounds/digital alarm.mp3';

  @override
  void initState() {
    super.initState();
    final now = DateTime.now().add(const Duration(minutes: 5));
    _selectedDate = now;
    _selectedHour = now.hour > 12 ? now.hour - 12 : (now.hour == 0 ? 12 : now.hour);
    _selectedMinute = now.minute;
    _selectedAmPm = now.hour >= 12 ? 'PM' : 'AM';
    _selectedSound = 'assets/alarm_sounds/digital alarm.mp3';
  }

  @override
  void dispose() {
    _topicController.dispose();
    _textController.dispose();
    _scrollController.dispose();
    ref.read(timerSoundProvider.notifier).stopAlarm();
    super.dispose();
  }

  String _formatDateTime(DateTime dt) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final month = months[dt.month - 1];
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$month ${dt.day}, ${dt.year} at $hour:$minute $ampm';
  }

  Future<void> _pickDate() async {
    final tokens = FocusOsTheme.of(context);
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: tokens.brightness == Brightness.light
                ? ColorScheme.light(
                    primary: tokens.accent,
                    onPrimary: Colors.white,
                    surface: tokens.surface,
                    onSurface: tokens.textPrimary,
                  )
                : ColorScheme.dark(
                    primary: tokens.accent,
                    onPrimary: Colors.white,
                    surface: tokens.surface,
                    onSurface: tokens.textPrimary,
                  ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }


  void _scheduleReminder() {
    final topic = _topicController.text.trim();
    final text = _textController.text.trim();
    if (topic.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please write a topic for the reminder'),
          backgroundColor: FocusOsTheme.of(context).surfaceAlt,
        ),
      );
      return;
    }

    int hour24 = _selectedHour;
    if (_selectedAmPm == 'PM' && _selectedHour < 12) {
      hour24 += 12;
    } else if (_selectedAmPm == 'AM' && _selectedHour == 12) {
      hour24 = 0;
    }

    final reminderDateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      hour24,
      _selectedMinute,
    );

    if (reminderDateTime.isBefore(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Reminder time must be in the future'),
          backgroundColor: FocusOsTheme.of(context).surfaceAlt,
        ),
      );
      return;
    }

    ref.read(remindersProvider.notifier).addReminder(topic, text, reminderDateTime, _selectedSound);

    _topicController.clear();
    _textController.clear();
    setState(() {
      final now = DateTime.now().add(const Duration(minutes: 5));
      _selectedDate = now;
      _selectedHour = now.hour > 12 ? now.hour - 12 : (now.hour == 0 ? 12 : now.hour);
      _selectedMinute = now.minute;
      _selectedAmPm = now.hour >= 12 ? 'PM' : 'AM';
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Reminder scheduled successfully'),
        backgroundColor: FocusOsTheme.of(context).surfaceAlt,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = FocusOsTheme.of(context);
    final reminders = ref.watch(remindersProvider);

    final activeReminders = reminders.where((r) => !r.isTriggered).toList();
    final triggeredReminders = reminders.where((r) => r.isTriggered).toList();

    return motion.PremiumEnterTransition(
      duration: motion.PremiumDurations.pageTransition,
      child: Padding(
        padding: const EdgeInsets.only(left: 32, right: 32, top: 32, bottom: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Reminders',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: tokens.textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Schedule customizable notifications to pop up while working',
                      style: TextStyle(fontSize: 13, color: tokens.textMuted),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: tokens.accent.safeWithOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: tokens.accent.safeWithOpacity(0.2)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.alarm_rounded, size: 14, color: tokens.accent),
                      const SizedBox(width: 6),
                      Text(
                        '${activeReminders.length} Active',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: tokens.accent,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),

            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Left: Schedule form ──
                  Expanded(
                    flex: 4,
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          PremiumCard(
                            padding: const EdgeInsets.all(24),
                            borderRadius: BorderRadius.circular(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const PremiumSectionHeader(
                                  icon: Icons.add_alarm_rounded,
                                  title: 'Create New Reminder',
                                  subtitle: 'Set date, time, and custom popup message',
                                ),
                                const SizedBox(height: 24),
                                
                                // Topic Input
                                Text(
                                  'Topic (Title)',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: tokens.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                TextField(
                                  controller: _topicController,
                                  style: TextStyle(color: tokens.textPrimary, fontSize: 13),
                                  decoration: InputDecoration(
                                    hintText: 'e.g. Call Client, Drink Water, Meeting',
                                    hintStyle: TextStyle(color: tokens.textMuted, fontSize: 13),
                                    filled: true,
                                    fillColor: tokens.background,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: BorderSide(color: tokens.borderSubtle),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: BorderSide(color: tokens.accent),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 18),

                                // Text Input
                                Text(
                                  'Details (Optional Description)',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: tokens.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                TextField(
                                  controller: _textController,
                                  maxLines: 3,
                                  minLines: 2,
                                  style: TextStyle(color: tokens.textPrimary, fontSize: 13),
                                  decoration: InputDecoration(
                                    hintText: 'Add description or notes here...',
                                    hintStyle: TextStyle(color: tokens.textMuted, fontSize: 13),
                                    filled: true,
                                    fillColor: tokens.background,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: BorderSide(color: tokens.borderSubtle),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: BorderSide(color: tokens.accent),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 18),

                                // Date Picker
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Date',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: tokens.textSecondary,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    InkWell(
                                      onTap: _pickDate,
                                      borderRadius: BorderRadius.circular(10),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                        decoration: BoxDecoration(
                                          color: tokens.background,
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(color: tokens.borderSubtle),
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                                              style: TextStyle(color: tokens.textPrimary, fontSize: 13),
                                            ),
                                            Icon(Icons.calendar_today_rounded, size: 14, color: tokens.textMuted),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 18),

                                // Time Picker
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Time',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: tokens.textSecondary,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        // Hour selector
                                        Expanded(
                                          child: Container(
                                            height: 44,
                                            padding: const EdgeInsets.symmetric(horizontal: 12),
                                            decoration: BoxDecoration(
                                              color: tokens.background,
                                              borderRadius: BorderRadius.circular(10),
                                              border: Border.all(color: tokens.borderSubtle),
                                            ),
                                            child: DropdownButtonHideUnderline(
                                              child: DropdownButton<int>(
                                                value: _selectedHour,
                                                isExpanded: true,
                                                dropdownColor: tokens.surface,
                                                style: TextStyle(color: tokens.textPrimary, fontSize: 13),
                                                items: List.generate(12, (index) => index + 1).map((h) {
                                                  return DropdownMenuItem<int>(
                                                    value: h,
                                                    child: Text(h.toString().padLeft(2, '0')),
                                                  );
                                                }).toList(),
                                                onChanged: (val) {
                                                  if (val != null) {
                                                    setState(() => _selectedHour = val);
                                                  }
                                                },
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(':', style: TextStyle(color: tokens.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                                        const SizedBox(width: 8),
                                        // Minute selector
                                        Expanded(
                                          child: Container(
                                            height: 44,
                                            padding: const EdgeInsets.symmetric(horizontal: 12),
                                            decoration: BoxDecoration(
                                              color: tokens.background,
                                              borderRadius: BorderRadius.circular(10),
                                              border: Border.all(color: tokens.borderSubtle),
                                            ),
                                            child: DropdownButtonHideUnderline(
                                              child: DropdownButton<int>(
                                                value: _selectedMinute,
                                                isExpanded: true,
                                                dropdownColor: tokens.surface,
                                                style: TextStyle(color: tokens.textPrimary, fontSize: 13),
                                                items: List.generate(60, (index) => index).map((m) {
                                                  return DropdownMenuItem<int>(
                                                    value: m,
                                                    child: Text(m.toString().padLeft(2, '0')),
                                                  );
                                                }).toList(),
                                                onChanged: (val) {
                                                  if (val != null) {
                                                    setState(() => _selectedMinute = val);
                                                  }
                                                },
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        // AM/PM selector
                                        Container(
                                          height: 44,
                                          padding: const EdgeInsets.all(2),
                                          decoration: BoxDecoration(
                                            color: tokens.background,
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(color: tokens.borderSubtle),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              _buildAmPmButton('AM', tokens),
                                              _buildAmPmButton('PM', tokens),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 18),

                                // Alarm Sound Selector
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Alarm Sound',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: tokens.textSecondary,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        // Sound Dropdown
                                        Expanded(
                                          child: Container(
                                            height: 44,
                                            padding: const EdgeInsets.symmetric(horizontal: 12),
                                            decoration: BoxDecoration(
                                              color: tokens.background,
                                              borderRadius: BorderRadius.circular(10),
                                              border: Border.all(color: tokens.borderSubtle),
                                            ),
                                            child: DropdownButtonHideUnderline(
                                              child: DropdownButton<String>(
                                                value: _selectedSound,
                                                isExpanded: true,
                                                dropdownColor: tokens.surface,
                                                style: TextStyle(color: tokens.textPrimary, fontSize: 13),
                                                items: [
                                                  const DropdownMenuItem(
                                                    value: 'assets/alarm_sounds/digital alarm.mp3',
                                                    child: Text('Digital Alarm'),
                                                  ),
                                                  const DropdownMenuItem(
                                                    value: 'assets/alarm_sounds/irritating_alarm.mp3',
                                                    child: Text('Irritating Alarm'),
                                                  ),
                                                  const DropdownMenuItem(
                                                    value: 'assets/alarm_sounds/soft_chime.mp3',
                                                    child: Text('Soft Chime'),
                                                  ),
                                                  ...ref.watch(timerSoundProvider).customAlarms.map((alarm) {
                                                    return DropdownMenuItem(
                                                      value: alarm.id,
                                                      child: Text(alarm.name),
                                                    );
                                                  }),
                                                ],
                                                onChanged: (val) {
                                                  if (val != null) {
                                                    setState(() => _selectedSound = val);
                                                  }
                                                },
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        // Play / Stop Preview button
                                        if (ref.watch(timerSoundProvider).isAlarmPlaying)
                                          GestureDetector(
                                            onTap: () => ref.read(timerSoundProvider.notifier).stopAlarm(),
                                            child: MouseRegion(
                                              cursor: SystemMouseCursors.click,
                                              child: Container(
                                                height: 44,
                                                width: 44,
                                                decoration: BoxDecoration(
                                                  color: tokens.accentSecondary.safeWithOpacity(0.12),
                                                  borderRadius: BorderRadius.circular(10),
                                                  border: Border.all(color: tokens.accentSecondary.safeWithOpacity(0.3)),
                                                ),
                                                child: Icon(Icons.stop_rounded, color: tokens.accentSecondary, size: 20),
                                              ),
                                            ),
                                          )
                                        else
                                          GestureDetector(
                                            onTap: () => ref.read(timerSoundProvider.notifier).previewAlarm(_selectedSound),
                                            child: MouseRegion(
                                              cursor: SystemMouseCursors.click,
                                              child: Container(
                                                height: 44,
                                                width: 44,
                                                decoration: BoxDecoration(
                                                  color: tokens.accent.safeWithOpacity(0.12),
                                                  borderRadius: BorderRadius.circular(10),
                                                  border: Border.all(color: tokens.accent.safeWithOpacity(0.3)),
                                                ),
                                                child: Icon(Icons.play_arrow_rounded, color: tokens.accent, size: 20),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 28),

                                // Submit Button
                                MouseRegion(
                                  cursor: SystemMouseCursors.click,
                                  child: GestureDetector(
                                    onTap: _scheduleReminder,
                                    child: Container(
                                      width: double.infinity,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        gradient: tokens.accentGradient,
                                        borderRadius: BorderRadius.circular(10),
                                        boxShadow: [
                                          BoxShadow(
                                            color: tokens.accent.safeWithOpacity(0.25),
                                            blurRadius: 10,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: const Center(
                                        child: Text(
                                          'Schedule Reminder',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
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

                  const SizedBox(width: 24),

                  // ── Right: List of reminders ──
                  Expanded(
                    flex: 5,
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Active Reminders section ──
                          Text(
                            'Active Reminders',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: tokens.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (activeReminders.isEmpty)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
                              decoration: BoxDecoration(
                                color: tokens.surface.withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: tokens.borderSubtle),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.alarm_off_rounded, size: 28, color: tokens.textMuted),
                                  const SizedBox(height: 10),
                                  Text(
                                    'No active reminders scheduled',
                                    style: TextStyle(fontSize: 12, color: tokens.textMuted),
                                  ),
                                ],
                              ),
                            )
                          else
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: activeReminders.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                final reminder = activeReminders[index];
                                return _buildReminderCard(reminder, tokens, false);
                              },
                            ),

                          const SizedBox(height: 28),

                          // ── Triggered Reminders section ──
                          Text(
                            'Triggered History',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: tokens.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (triggeredReminders.isEmpty)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                              decoration: BoxDecoration(
                                color: tokens.surface.withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: tokens.borderSubtle),
                              ),
                              child: Center(
                                child: Text(
                                  'No previously triggered reminders',
                                  style: TextStyle(fontSize: 12, color: tokens.textMuted),
                                ),
                              ),
                            )
                          else
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: triggeredReminders.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                final reminder = triggeredReminders[index];
                                return _buildReminderCard(reminder, tokens, true);
                              },
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReminderCard(Reminder reminder, ThemeTokens tokens, bool isTriggered) {
    return PremiumCard(
      padding: const EdgeInsets.all(16),
      borderRadius: BorderRadius.circular(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isTriggered 
                  ? tokens.textMuted.safeWithOpacity(0.1)
                  : tokens.accent.safeWithOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isTriggered ? Icons.check_rounded : Icons.notifications_active_rounded, 
              size: 14, 
              color: isTriggered ? tokens.textMuted : tokens.accent,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        reminder.title,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isTriggered ? tokens.textSecondary : tokens.textPrimary,
                          decoration: isTriggered ? TextDecoration.lineThrough : null,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isTriggered 
                            ? tokens.borderSubtle 
                            : tokens.accent.safeWithOpacity(0.08),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        isTriggered ? 'Triggered' : 'Scheduled',
                        style: TextStyle(
                          fontSize: 9, 
                          color: isTriggered ? tokens.textMuted : tokens.accent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                if (reminder.description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    reminder.description,
                    style: TextStyle(
                      fontSize: 12,
                      color: tokens.textSecondary,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.calendar_today_rounded, size: 10, color: tokens.textMuted),
                    const SizedBox(width: 4),
                    Text(
                      _formatDateTime(reminder.dateTime),
                      style: TextStyle(fontSize: 10, color: tokens.textMuted),
                    ),
                    if (reminder.alarmEnabled) ...[
                      const SizedBox(width: 12),
                      Icon(Icons.music_note_rounded, size: 10, color: tokens.textMuted),
                      const SizedBox(width: 4),
                      Text(
                        (() {
                          final path = reminder.alarmSoundPath;
                          if (path == null) return 'Digital Alarm';
                          if (path == 'assets/alarm_sounds/digital alarm.mp3') return 'Digital Alarm';
                          if (path == 'assets/alarm_sounds/irritating_alarm.mp3') return 'Irritating Alarm';
                          if (path == 'assets/alarm_sounds/soft_chime.mp3') return 'Soft Chime';
                          final customAlarms = ref.read(timerSoundProvider).customAlarms;
                          final match = customAlarms.where((a) => a.id == path).firstOrNull;
                          if (match != null) return match.name;
                          return 'Digital Alarm';
                        })(),
                        style: TextStyle(fontSize: 10, color: tokens.textMuted),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Alarm toggle button
          _AlarmToggleButton(
            enabled: reminder.alarmEnabled,
            isTriggered: isTriggered,
            tokens: tokens,
            onToggle: isTriggered
                ? null
                : () {
                    ref.read(remindersProvider.notifier).toggleAlarm(reminder.id);
                  },
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () {
              ref.read(remindersProvider.notifier).deleteReminder(reminder.id);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Reminder deleted'),
                  backgroundColor: tokens.surfaceAlt,
                  duration: const Duration(seconds: 1),
                ),
              );
            },
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: tokens.borderSubtle.safeWithOpacity(0.5),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(Icons.delete_outline_rounded, size: 14, color: tokens.textMuted),
              ),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildAmPmButton(String label, ThemeTokens tokens) {
    final active = _selectedAmPm == label;
    return GestureDetector(
      onTap: () => setState(() => _selectedAmPm = label),
      child: Container(
        height: double.infinity,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: active ? tokens.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : tokens.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// Compact alarm toggle button — shows a bell icon that toggles between
/// alarm ON (accent-colored, filled bell) and alarm OFF (muted, slashed bell).
class _AlarmToggleButton extends StatefulWidget {
  final bool enabled;
  final bool isTriggered;
  final ThemeTokens tokens;
  final VoidCallback? onToggle;

  const _AlarmToggleButton({
    required this.enabled,
    required this.isTriggered,
    required this.tokens,
    this.onToggle,
  });

  @override
  State<_AlarmToggleButton> createState() => _AlarmToggleButtonState();
}

class _AlarmToggleButtonState extends State<_AlarmToggleButton>
    with SingleTickerProviderStateMixin {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final isOn = widget.enabled;
    final interactive = !widget.isTriggered && widget.onToggle != null;

    final Color iconColor = widget.isTriggered
        ? widget.tokens.textMuted.safeWithOpacity(0.5)
        : isOn
            ? widget.tokens.accent
            : widget.tokens.textMuted;

    final Color bgColor = widget.isTriggered
        ? Colors.transparent
        : isOn
            ? widget.tokens.accent.safeWithOpacity(_hovered ? 0.18 : 0.1)
            : widget.tokens.borderSubtle.safeWithOpacity(_hovered ? 0.8 : 0.5);

    return Tooltip(
      message: widget.isTriggered
          ? (isOn ? 'Alarm was enabled' : 'Alarm was disabled')
          : (isOn ? 'Alarm ON — tap to mute' : 'Alarm OFF — tap to enable'),
      waitDuration: const Duration(milliseconds: 500),
      child: MouseRegion(
        cursor: interactive ? SystemMouseCursors.click : MouseCursor.defer,
        onEnter: interactive ? (_) => setState(() => _hovered = true) : null,
        onExit: interactive ? (_) => setState(() => _hovered = false) : null,
        child: GestureDetector(
          onTap: widget.onToggle,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(7),
              border: isOn && !widget.isTriggered
                  ? Border.all(
                      color: widget.tokens.accent.safeWithOpacity(0.2),
                      width: 1,
                    )
                  : null,
              boxShadow: isOn && !widget.isTriggered
                  ? [
                      BoxShadow(
                        color: widget.tokens.accent.safeWithOpacity(0.12),
                        blurRadius: 6,
                        spreadRadius: 0,
                      ),
                    ]
                  : null,
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              switchInCurve: Curves.easeOutCubic,
              transitionBuilder: (child, animation) {
                return ScaleTransition(scale: animation, child: child);
              },
              child: Icon(
                isOn
                    ? Icons.notifications_active_rounded
                    : Icons.notifications_off_outlined,
                key: ValueKey(isOn),
                size: 14,
                color: iconColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
