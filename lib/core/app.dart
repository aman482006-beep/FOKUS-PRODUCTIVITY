import 'dart:async';
import 'dart:io';
import 'dart:ui' show ImageFilter;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart' as wm;
import 'package:pasteboard/pasteboard.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../models/quick_capture_item.dart';
import '../services/blue_light_service.dart';
import '../services/fokus_mode_service.dart';
import '../services/screen_time_service.dart';
import '../services/notification_service.dart';
import '../services/timer_sound_service.dart';
import '../shared/motion.dart';
import '../shared/theme.dart';
import '../shared/widgets/brain_dump_overlay.dart';
import '../shared/widgets/sidebar.dart';
import '../shared/widgets/keyboard_shortcuts_overlay.dart';
import '../shared/widgets/calculator_overlay.dart';
import '../shared/widgets/floating_sticky_note.dart';
import '../shared/widgets/sticky_overlay_widget.dart';
import '../features/tools/sticky_notes_tool.dart';
import '../shared/shortcuts.dart';
import '../features/fokus_timer/fokus_timer_page.dart';
import '../features/tasks/tasks_page.dart';
import '../features/settings/settings_modal.dart';
import '../features/fokus_stats/fokus_stats_page.dart';
import '../features/health/health_page.dart';
import '../features/reminders/reminders_page.dart';
import '../models/reminder.dart';
import '../features/tools/tools_page.dart';
import '../features/support/support_page.dart';
import '../features/screen_time/screen_time_page.dart';
import '../features/fokus_timer/deep_work_mode.dart';
import '../features/fokus_timer/widgets/mini_floating_timer.dart';
import 'navigation.dart';
import 'providers.dart';
import '../shared/responsive.dart';

/// Fokus — premium desktop productivity shell.
/// Handles navigation, deep work mode, global keyboard shortcuts,
/// and orchestrates all background services.
class FocusApp extends ConsumerStatefulWidget {
  const FocusApp({super.key});

  @override
  ConsumerState<FocusApp> createState() => _FocusAppState();
}

class _FocusAppState extends ConsumerState<FocusApp> with wm.WindowListener {
  Timer? _tickTimer;
  bool _autoModeListenerRegistered = false;
  bool _servicesStarted = false;
  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleGlobalKeyEvent);
    if (!kIsWeb) {
      wm.WindowManager.instance.addListener(this);
    }
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleGlobalKeyEvent);
    if (!kIsWeb) {
      wm.WindowManager.instance.removeListener(this);
    }
    _tickTimer?.cancel();
    ScreenTimeService.stopTracking();
    super.dispose();
  }

  @override
  void onWindowEnterFullScreen() {
    ref.read(fullscreenProvider.notifier).setFullscreen(true);
  }

  @override
  void onWindowLeaveFullScreen() {
    ref.read(fullscreenProvider.notifier).setFullscreen(false);
  }

  @override
  void onWindowClose() async {
    if (kIsWeb) return;
    final runInBackground = ref.read(runInBackgroundProvider);
    if (runInBackground) {
      final isPreventClose = await wm.WindowManager.instance.isPreventClose();
      if (isPreventClose) {
        await wm.WindowManager.instance.minimize();
        await NotificationService.show(
          id: 888,
          title: 'Fokus',
          body: 'Fokus is running in the background.',
        );
      }
    } else {
      await wm.WindowManager.instance.destroy();
    }
  }

  /// Periodic tick for all services that need it.
  void _startPeriodicTicks() {
    if (_servicesStarted) return;
    _servicesStarted = true;

    _tickTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _checkReminders();
    });
    ScreenTimeService.startTracking();
  }

  void _checkReminders() {
    final reminders = ref.read(remindersProvider);
    final now = DateTime.now();
    for (final reminder in reminders) {
      if (!reminder.isTriggered && reminder.dateTime.isBefore(now)) {
        ref.read(activeReminderPopupProvider.notifier).state = reminder;
        ref.read(remindersProvider.notifier).markAsTriggered(reminder.id);

        // Play alarm sound if enabled for this reminder
        if (reminder.alarmEnabled) {
          _playReminderAlarm(reminder.alarmSoundPath);
        }
        break;
      }
    }
  }

  /// Plays a system alarm sound when a reminder fires.
  /// Uses SystemSound for an immediate alert, and also triggers
  /// Windows system beeps via PowerShell for a more noticeable alarm.
  void _playReminderAlarm(String? soundPath) {
    // Immediate system alert sound
    SystemSound.play(SystemSoundType.alert);
    HapticFeedback.heavyImpact();

    // Play custom/configured alarm sound if available
    if (soundPath != null && soundPath.isNotEmpty) {
      ref.read(timerSoundProvider.notifier).previewAlarm(soundPath);
    } else {
      ref.read(timerSoundProvider.notifier).previewAlarm('assets/alarm_sounds/digital alarm.mp3');
    }

    // On Windows, trigger a louder multi-beep alarm via PowerShell
    if (!kIsWeb && Platform.isWindows) {
      // Play 3 short beeps with pauses for urgency
      Process.run('powershell', [
        '-NoProfile', '-NonInteractive', '-Command',
        '[console]::beep(1000,300); Start-Sleep -m 200; [console]::beep(1200,300); Start-Sleep -m 200; [console]::beep(1400,400)',
      ]).then((_) {}).catchError((_) {});
    }
  }


  /// Handle global keyboard shortcuts using centralized definitions.
  bool _handleGlobalKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return false;

    final shortcutsEnabled = ref.read(keyboardShortcutsProvider);
    if (!shortcutsEnabled) return false;

    final keysPressed = HardwareKeyboard.instance.logicalKeysPressed;
    final ctrlPressed = keysPressed.contains(LogicalKeyboardKey.controlLeft) ||
      keysPressed.contains(LogicalKeyboardKey.controlRight) ||
      keysPressed.contains(LogicalKeyboardKey.metaLeft) ||
      keysPressed.contains(LogicalKeyboardKey.metaRight);
    final shiftPressed = keysPressed.contains(LogicalKeyboardKey.shiftLeft) ||
      keysPressed.contains(LogicalKeyboardKey.shiftRight);

    // Escape always works — no text-field guard (needed to dismiss overlays even when typing)
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      // Close overlays in order of priority (most recent on top)
      if (ref.read(calculatorOpenProvider)) {
        ref.read(calculatorOpenProvider.notifier).state = false;
        return true;
      }
      if (ref.read(keyboardShortcutsOpenProvider)) {
        ref.read(keyboardShortcutsOpenProvider.notifier).state = false;
        return true;
      }
      if (ref.read(quickCaptureOpenProvider)) {
        ref.read(quickCaptureOpenProvider.notifier).state = false;
        return true;
      }
      if (ref.read(brainDumpOpenProvider)) {
        ref.read(brainDumpOpenProvider.notifier).state = false;
        return true;
      }
      if (ref.read(profileOverlayOpenProvider)) {
        ref.read(profileOverlayOpenProvider.notifier).state = false;
        return true;
      }
      if (ref.read(settingsModalOpenProvider)) {
        ref.read(settingsModalOpenProvider.notifier).state = false;
        return true;
      }
      if (ref.read(deepWorkModeProvider)) {
        ref.read(deepWorkModeProvider.notifier).state = false;
        return true;
      }
      return false;
    }

    // All other shortcuts require no text field to be focused
    if (!noTextFieldFocused()) return false;

    // Match against the centralized shortcut list
    for (final shortcut in globalShortcuts) {
      if (shortcut.matches(event, ctrlPressed, shiftPressed)) {
        _executeAction(shortcut.action);
        return true;
      }
    }
    return false;
  }

  /// Execute the action corresponding to a matched shortcut.
  void _executeAction(FocusOsAction action) {
    switch (action) {
      case FocusOsAction.startPauseTimer:
        _toggleTimer();
      case FocusOsAction.resetTimer:
        _resetTimer();
      case FocusOsAction.quickCapture:
        ref.read(quickCaptureOpenProvider.notifier).state =
            !ref.read(quickCaptureOpenProvider.notifier).state;
      case FocusOsAction.toggleCalculator:
        ref.read(calculatorOpenProvider.notifier).state =
            !ref.read(calculatorOpenProvider);
      case FocusOsAction.brainDump:
        ref.read(brainDumpOpenProvider.notifier).state =
            !ref.read(brainDumpOpenProvider.notifier).state;
      case FocusOsAction.openSettings:
        ref.read(settingsModalOpenProvider.notifier).state = true;
      case FocusOsAction.toggleSidebar:
        final current = ref.read(sidebarExpandedProvider);
        ref.read(sidebarExpandedProvider.notifier).state = !current;
      case FocusOsAction.toggleDnd:
        final fokusMode = ref.read(fokusModeProvider);
        ref.read(fokusModeProvider.notifier).state = !fokusMode;
      case FocusOsAction.toggleFullscreen:
        ref.read(fullscreenProvider.notifier).toggle();
        _setNativeFullscreen(ref.read(fullscreenProvider));
      case FocusOsAction.closeOverlay:
        // Handled separately above for multi-layer escape logic
        break;
      case FocusOsAction.toggleShortcutsCheatSheet:
        ref.read(keyboardShortcutsOpenProvider.notifier).state =
            !ref.read(keyboardShortcutsOpenProvider);
      case FocusOsAction.navigateFocus:
        ref.read(navigationProvider.notifier).state = NavDestination.focus;
      case FocusOsAction.navigateTasks:
        ref.read(navigationProvider.notifier).state = NavDestination.tasks;
      case FocusOsAction.navigateAnalytics:
        ref.read(navigationProvider.notifier).state = NavDestination.analytics;
      // navigateBlocker removed — merged into Focus Shield
      case FocusOsAction.navigateHealth:
        ref.read(navigationProvider.notifier).state = NavDestination.health;
      case FocusOsAction.navigateTools:
        ref.read(navigationProvider.notifier).state = NavDestination.tools;
      case FocusOsAction.navigateUp:
        // Navigate up handled elsewhere; no-op here
        break;
      case FocusOsAction.navigateDown:
        // Navigate down handled elsewhere; no-op here
        break;
      case FocusOsAction.cycleTimerStyle:
        final current = ref.read(timerCustomizationProvider);
        const styles = ['minimal', 'bold_digital', 'futuristic', 'elegant', 'mechanical'];
        final currentIndex = styles.indexOf(current.fontStyle);
        final nextIndex = (currentIndex + 1) % styles.length;
        ref.read(timerCustomizationProvider.notifier).update(
          current.copyWith(fontStyle: styles[nextIndex]),
        );
      case FocusOsAction.toggleMiniTimer:
        ref.read(miniModeProvider.notifier).toggle();
    }
  }

  void _toggleTimer() {
    final timerState = ref.read(timerProvider);
    final notifier = ref.read(timerProvider.notifier);
    if (timerState.running) {
      notifier.pause();
      _exitFocusMode();
    } else {
      notifier.start();
      ref.read(fokusModeProvider.notifier).state = true;
      ref.read(blueLightProvider.notifier).onFokusSessionStart();
    }
  }

  void _resetTimer() {
    ref.read(timerProvider.notifier).reset();
    _exitFocusMode();
    ref.read(deepWorkModeProvider.notifier).state = false;
  }

  void _setNativeFullscreen(bool enabled) {
    if (!kIsWeb) {
      try {
        if (enabled) {
          wm.WindowManager.instance.setFullScreen(true);
        } else {
          wm.WindowManager.instance.setFullScreen(false);
        }
      } catch (_) {}
    }
  }

  void _exitFocusMode() {
    ref.read(fokusModeProvider.notifier).state = false;
    ref.read(blueLightProvider.notifier).onFokusSessionEnd();
  }

  @override
  Widget build(BuildContext context) {
    // Register services once
    if (!_autoModeListenerRegistered) {
      _autoModeListenerRegistered = true;
      _startPeriodicTicks();
    }

    final blueLight = ref.watch(blueLightProvider);
    final themeDef = ref.watch(themeProvider);

    // Reactive Focus Mode Listener
    ref.listen<bool>(fokusModeProvider, (previous, next) {
      if (next) {
        FokusModeService.enableFocusMode(context, ref);
      } else {
        FokusModeService.disableFocusMode(context, ref);
      }
    });

    // Listen for sidebar settings navigation -> open modal instead
    ref.listen<NavDestination>(navigationProvider, (prev, next) {
      if (next == NavDestination.settings && !ref.read(settingsModalOpenProvider)) {
        Future.microtask(() {
          ref.read(settingsModalOpenProvider.notifier).state = true;
          ref.read(navigationProvider.notifier).state = prev ?? NavDestination.focus;
        });
      }
    });

    return MaterialApp(
      title: 'Fokus',
      theme: FocusOsTheme.fromDefinition(themeDef),
      darkTheme: FocusOsTheme.fromDefinition(themeDef),
      themeMode: themeDef.category == 'Light' ? ThemeMode.light : ThemeMode.dark,
      debugShowCheckedModeBanner: false,
      scrollBehavior: _PremiumScrollBehavior(),
      builder: (context, child) {
        if (blueLight.enabled || blueLight.grayscale) {
          return ColorFiltered(
            colorFilter: ColorFilter.matrix(
              BlueLightService.matrixForSettings(blueLight.toSettings()),
            ),
            child: child,
          );
        }
        return child ?? const SizedBox.shrink();
      },
      home: Builder(
        builder: (context) => Focus(
          autofocus: true,
          onKeyEvent: (node, event) =>
              _handleGlobalKeyEvent(event) ? KeyEventResult.handled : KeyEventResult.ignored,
          child: const _AppShell(),
        ),
      ),
    );
  }
}

// ── Premium Scroll Behavior ──

class _PremiumScrollBehavior extends MaterialScrollBehavior {
  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const BouncingScrollPhysics(
      parent: ClampingScrollPhysics(),
    );
  }
}

// ──────────────────────────────────────────────
// Quick Capture Overlay
// ──────────────────────────────────────────────

class _QuickCaptureOverlay extends ConsumerStatefulWidget {
  final VoidCallback onClose;

  const _QuickCaptureOverlay({required this.onClose});

  @override
  ConsumerState<_QuickCaptureOverlay> createState() =>
      _QuickCaptureOverlayState();
}

class _QuickCaptureOverlayState extends ConsumerState<_QuickCaptureOverlay>
    with SingleTickerProviderStateMixin {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;
  List<String> _attachedImages = [];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: PremiumDurations.overlayFade,
    );
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: PremiumCurves.easeOutCubic,
    );
    _scaleAnim = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: PremiumCurves.springyOut),
    );
    _animController.forward();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _focusNode.canRequestFocus) {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _pasteFromClipboard() async {
    try {
      // Check for images in clipboard
      final imageBytes = await Pasteboard.image;
      if (imageBytes != null) {
        final tempDir = await getTemporaryDirectory();
        final filePath = '${tempDir.path}/qc_img_${DateTime.now().millisecondsSinceEpoch}.png';
        final file = File(filePath);
        await file.writeAsBytes(imageBytes);
        setState(() => _attachedImages.add(filePath));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Image attached from clipboard'),
              backgroundColor: FocusOsTheme.of(context).surfaceAlt,
              duration: const Duration(seconds: 1),
            ),
          );
        }
        return;
      }

      // Check for files in clipboard
      final files = await Pasteboard.files();
      if (files.isNotEmpty) {
        final imageExts = ['.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp'];
        final newImages = files.where((f) =>
          imageExts.any((ext) => f.toLowerCase().endsWith(ext))
        ).toList();
        if (newImages.isNotEmpty) {
          setState(() => _attachedImages.addAll(newImages));
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${newImages.length} image(s) attached from clipboard'),
                backgroundColor: FocusOsTheme.of(context).surfaceAlt,
                duration: const Duration(seconds: 1),
              ),
            );
          }
          _focusNode.requestFocus();
          return;
        }
      }

      // Check for text
      final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
      if (clipboardData?.text != null && clipboardData!.text!.isNotEmpty) {
        final pasted = clipboardData.text!;
        final val = _controller.value;
        final currentText = val.text;
        final start = val.selection.start;
        final end = val.selection.end;

        if (start >= 0 && end >= 0 && start < currentText.length) {
          final newText = currentText.replaceRange(start, end, pasted);
          _controller.value = TextEditingValue(
            text: newText,
            selection: TextSelection.collapsed(offset: start + pasted.length),
          );
        } else if (currentText.isEmpty) {
          _controller.text = pasted;
        } else {
          _controller.text = '$currentText\n$pasted';
        }

        // Show how many links were detected
        final urls = extractUrls(pasted);
        if (urls.isNotEmpty && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${urls.length} link(s) detected'),
              backgroundColor: FocusOsTheme.of(context).surfaceAlt,
              duration: const Duration(seconds: 1),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Clipboard paste error: $e');
    } finally {
      _focusNode.requestFocus();
    }
  }

  Future<void> _pickImages() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'png', 'jpeg', 'gif', 'webp'],
        allowMultiple: true,
      );
      if (result != null) {
        final paths = result.files
            .where((f) => f.path != null)
            .map((f) => f.path!)
            .toList();
        if (paths.isNotEmpty) {
          setState(() => _attachedImages.addAll(paths));
        }
      }
    } catch (e) {
      debugPrint('Image pick error: $e');
    }
  }

  void _saveToInbox() {
    final text = _controller.text.trim();
    final hasContent = text.isNotEmpty || _attachedImages.isNotEmpty;
    if (!hasContent) return;

    ref.read(quickCaptureProvider.notifier).addEntry(
      text,
      mediaPaths: _attachedImages.isNotEmpty ? _attachedImages : null,
    );
    _controller.clear();
    _close();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isNotEmpty || _attachedImages.isNotEmpty) {
      // Save the text content as a task item
      ref.read(tasksProvider.notifier).addTask(text.isNotEmpty ? text : 'Captured image');
      // Also save images to quick capture if there are any
      if (_attachedImages.isNotEmpty) {
        ref.read(quickCaptureProvider.notifier).addEntry(
          text.isNotEmpty ? text : 'Captured image',
          mediaPaths: _attachedImages,
        );
      }
      _controller.clear();
      _close();
    }
  }

  Future<void> _close() async {
    await _animController.reverse();
    widget.onClose();
    FocusManager.instance.primaryFocus?.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = FocusOsTheme.of(context);

    return FadeTransition(
      opacity: _fadeAnim,
      child: GestureDetector(
        onTap: _close,
        child: Container(
          color: Colors.black.safeWithOpacity(0.5),
          child: Center(
            child: Material(
              color: Colors.transparent,
              child: GestureDetector(
                onTap: () {},
                child: ScaleTransition(
                  scale: _scaleAnim,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460, maxHeight: 520),
                    child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: tokens.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: tokens.borderSubtle),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.safeWithOpacity(0.3),
                          blurRadius: 40,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                        // Header
                        Row(
                          children: [
                            Icon(Icons.bolt_rounded, size: 16, color: tokens.accent),
                            const SizedBox(width: 8),
                            Text(
                              'Quick Capture',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: tokens.textPrimary,
                              ),
                            ),
                            const Spacer(),
                            GestureDetector(
                              onTap: _close,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: tokens.borderSubtle,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Icon(Icons.close, size: 14, color: tokens.textMuted),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Text input
                        TextField(
                          controller: _controller,
                          focusNode: _focusNode,
                          autofocus: true,
                          maxLines: 5,
                          minLines: 2,
                          style: TextStyle(color: tokens.textPrimary, fontSize: 14, height: 1.4),
                          decoration: InputDecoration(
                            hintText: 'Type an idea, task, or paste a link...',
                            hintStyle: TextStyle(color: tokens.textMuted, fontSize: 14),
                            filled: true,
                            fillColor: tokens.background,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.all(12),
                          ),
                        ),

                        // Attached images preview
                        if (_attachedImages.isNotEmpty) ...[Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: SizedBox(
                            height: 56,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: _attachedImages.length,
                              separatorBuilder: (_, __) => const SizedBox(width: 6),
                              itemBuilder: (context, index) {
                                return Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(6),
                                      child: Image.file(
                                        File(_attachedImages[index]),
                                        width: 56,
                                        height: 56,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Container(
                                          width: 56,
                                          height: 56,
                                          color: tokens.borderSubtle,
                                          child: Icon(Icons.broken_image, size: 20, color: tokens.textMuted),
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      top: 2,
                                      right: 2,
                                      child: GestureDetector(
                                        onTap: () => setState(() => _attachedImages.removeAt(index)),
                                        child: Container(
                                          padding: const EdgeInsets.all(2),
                                          decoration: const BoxDecoration(
                                            color: Colors.black54,
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(Icons.close, size: 10, color: Colors.white),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                        )],

                        const SizedBox(height: 12),

                        // Bottom actions
                        Row(
                          children: [
                            // Attach images button
                            GestureDetector(
                              onTap: _pickImages,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: tokens.borderSubtle,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Icon(Icons.add_photo_alternate_rounded, size: 14, color: tokens.textSecondary),
                              ),
                            ),
                            const SizedBox(width: 6),
                            // Paste from clipboard
                            GestureDetector(
                              onTap: _pasteFromClipboard,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: tokens.borderSubtle,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Icon(Icons.content_paste_rounded, size: 14, color: tokens.textSecondary),
                              ),
                            ),
                            const Spacer(),
                            // Save to inbox
                            GestureDetector(
                              onTap: _saveToInbox,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: tokens.borderSubtle,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Save to inbox',
                                  style: TextStyle(
                                      fontSize: 12, color: tokens.textSecondary),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Add task
                            GestureDetector(
                              onTap: _submit,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 6),
                                decoration: BoxDecoration(
                                  gradient: tokens.accentGradient,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Add task',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────
// Hardcore Lock Overlay
// ──────────────────────────────────────────────

class _HardcoreLockOverlay extends ConsumerStatefulWidget {
  @override
  ConsumerState<_HardcoreLockOverlay> createState() =>
      _HardcoreLockOverlayState();
}

class _HardcoreLockOverlayState extends ConsumerState<_HardcoreLockOverlay>
    with SingleTickerProviderStateMixin {
  final _passwordController = TextEditingController();
  int _penaltyCountdown = 0;
  Timer? _penaltyTimer;
  bool _showPenalty = false;
  bool _wrongPassword = false;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: PremiumDurations.overlayFade,
    );
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: PremiumCurves.easeOutCubic,
    );
    _animController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final penalty = ref.read(hardcoreLockProvider).penaltySeconds;
      setState(() {
        _penaltyCountdown = penalty;
        _showPenalty = true;
      });
      _startPenalty();
    });
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _penaltyTimer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  void _startPenalty() {
    _penaltyTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_penaltyCountdown <= 1) {
        timer.cancel();
        setState(() => _showPenalty = false);
      } else {
        setState(() => _penaltyCountdown--);
      }
    });
  }

  void _unlock() {
    final password = _passwordController.text;
    if (ref.read(hardcoreLockProvider.notifier).verifyPassword(password)) {
      ref.read(hardcoreLockProvider.notifier).setLocked(false);
      ref.read(timerProvider.notifier).pause();
      ref.read(deepWorkModeProvider.notifier).state = false;
    } else {
      if (mounted) setState(() => _wrongPassword = true);
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _wrongPassword = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = FocusOsTheme.of(context);

    return FadeTransition(
      opacity: _fadeAnim,
      child: Container(
        color: Colors.black.safeWithOpacity(0.85),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: tokens.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: tokens.accent.safeWithOpacity(0.40)),
              boxShadow: [
                BoxShadow(
                  color: tokens.accent.safeWithOpacity(0.15),
                  blurRadius: 40,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: tokens.accent.safeWithOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.lock_outline,
                      size: 24, color: tokens.accent),
                ),
                const SizedBox(height: 16),
                Text(
                  'Fokus Locked',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: tokens.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _showPenalty
                      ? 'Wait $_penaltyCountdown seconds or enter password'
                      : 'Enter password to exit fokus mode',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: tokens.textSecondary),
                ),
                const SizedBox(height: 20),
                if (_showPenalty) ...[
                  AnimatedDigit(
                    value: '$_penaltyCountdown',
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.w300,
                      fontFamily: 'monospace',
                      color: tokens.accent,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: ref.read(hardcoreLockProvider).penaltySeconds > 0
                          ? _penaltyCountdown /
                              ref.read(hardcoreLockProvider).penaltySeconds
                          : 0,
                      minHeight: 3,
                      backgroundColor: tokens.borderMedium,
                      valueColor: AlwaysStoppedAnimation<Color>(tokens.accent),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                SizedBox(
                  height: 40,
                  child: TextField(
                    controller: _passwordController,
                    obscureText: true,
                    autofocus: !_showPenalty,
                    enabled: !_showPenalty,
                    style: TextStyle(color: tokens.textPrimary, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: _wrongPassword ? 'Wrong password' : 'Password',
                      hintStyle: TextStyle(
                        color: _wrongPassword
                            ? tokens.accent
                            : tokens.textMuted,
                        fontSize: 14,
                      ),
                      filled: true,
                      fillColor: tokens.background,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: _wrongPassword
                              ? tokens.accent
                              : tokens.borderMedium,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: tokens.borderSubtle),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: _wrongPassword
                              ? tokens.accent
                              : tokens.accent,
                        ),
                      ),
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 12),
                      isDense: true,
                    ),
                    onSubmitted: (_) => _unlock(),
                  ),
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: _showPenalty ? null : _unlock,
                  child: AnimatedContainer(
                    duration: PremiumDurations.microFeedbackLong,
                    curve: PremiumCurves.easeOutCubic,
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: _showPenalty
                          ? tokens.borderMedium.safeWithOpacity(0.3)
                          : tokens.accent.safeWithOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _showPenalty
                            ? tokens.borderSubtle
                            : tokens.accent.safeWithOpacity(0.40),
                      ),
                    ),
                    child: Text(
                      'Unlock',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _showPenalty
                            ? tokens.textMuted
                            : tokens.accent,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            ),
            ),
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────
// Reminder Popup Overlay
// ──────────────────────────────────────────────

class _ReminderPopupOverlay extends ConsumerStatefulWidget {
  final Reminder reminder;
  final VoidCallback onClose;

  const _ReminderPopupOverlay({
    required this.reminder,
    required this.onClose,
  });

  @override
  ConsumerState<_ReminderPopupOverlay> createState() => _ReminderPopupOverlayState();
}

class _ReminderPopupOverlayState extends ConsumerState<_ReminderPopupOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );
    _scaleAnim = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: Curves.easeOutBack,
      ),
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _close() async {
    await _animController.reverse();
    widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = FocusOsTheme.of(context);

    return FadeTransition(
      opacity: _fadeAnim,
      child: GestureDetector(
        onTap: _close,
        child: Container(
          color: Colors.black.safeWithOpacity(0.65),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Center(
              child: Material(
                color: Colors.transparent,
                child: GestureDetector(
                  onTap: () {}, // Prevent click propagation
                  child: ScaleTransition(
                    scale: _scaleAnim,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: Container(
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          color: tokens.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: tokens.accent.safeWithOpacity(0.3), width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: tokens.accent.safeWithOpacity(0.15),
                              blurRadius: 30,
                              offset: const Offset(0, 8),
                            ),
                            BoxShadow(
                              color: Colors.black.safeWithOpacity(0.4),
                              blurRadius: 20,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Pulse Alert Icon
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                color: tokens.accent.safeWithOpacity(0.15),
                                shape: BoxShape.circle,
                                border: Border.all(color: tokens.accent.safeWithOpacity(0.25), width: 2),
                              ),
                              child: Icon(
                                Icons.alarm_on_rounded,
                                size: 32,
                                color: tokens.accent,
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Alert Tag
                            Text(
                              'REMINDER',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: tokens.accent,
                                letterSpacing: 1.5,
                              ),
                            ),
                            const SizedBox(height: 8),

                            // Topic
                            Text(
                              widget.reminder.title,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: tokens.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Description
                            if (widget.reminder.description.isNotEmpty) ...[
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: tokens.background.safeWithOpacity(0.5),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: tokens.borderSubtle),
                                ),
                                child: Text(
                                  widget.reminder.description,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: tokens.textSecondary,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),
                            ],

                            // Close Button
                            MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: GestureDetector(
                                onTap: _close,
                                child: Container(
                                  width: double.infinity,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    gradient: tokens.accentGradient,
                                    borderRadius: BorderRadius.circular(10),
                                    boxShadow: [
                                      BoxShadow(
                                        color: tokens.accent.safeWithOpacity(0.25),
                                        blurRadius: 8,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),                                    child: const Center(
                                    child: Text(
                                      'Acknowledge',
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
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════
// APP SHELL — Isolated main layout + overlay gates
// ═══════════════════════════════════════════════════
// Each overlay is wrapped in its own Consumer widget so that
// changing a single overlay's provider does NOT rebuild the
// entire widget tree (sidebar, page content, other overlays).
// ═══════════════════════════════════════════════════

/// Main app shell — watches layout providers and orchestrates all overlays.
/// Extracted so overlay provider changes don't rebuild the entire tree.
/// On mobile screens, the sidebar is replaced with a bottom navigation bar.
class _AppShell extends ConsumerWidget {
  const _AppShell();

  Widget _buildPage(NavDestination dest) {
    switch (dest) {
      case NavDestination.focus:
        return const FokusTimerPage();
      case NavDestination.tasks:
        return const TasksPage();
      case NavDestination.reminders:
        return const RemindersPage();
      case NavDestination.analytics:
        return const FokusStatsPage();
      case NavDestination.screenTime:
        return const ScreenTimePage();
      case NavDestination.health:
        return const HealthPage();
      case NavDestination.tools:
        return const ToolsPage();
      case NavDestination.support:
        return const SupportPage();
      case NavDestination.settings:
        return const SizedBox.shrink();
    }
  }

  /// Primary destinations shown in the mobile bottom nav bar.
  static const _mobileDestinations = [
    NavDestination.focus,
    NavDestination.tasks,
    NavDestination.analytics,
    NavDestination.tools,
    NavDestination.health,
  ];

  /// Secondary destinations accessible via the "More" overflow.
  static const _mobileMoreDestinations = [
    NavDestination.reminders,
    NavDestination.screenTime,
    NavDestination.support,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isMini = ref.watch(miniModeProvider);
    final stickyState = ref.watch(stickyOverlayProvider);
    final isSticky = stickyState != StickyOverlayState.off;
    final currentDest = ref.watch(navigationProvider);
    final isDeepWork = ref.watch(deepWorkModeProvider);
    final isFullscreen = ref.watch(fullscreenProvider);
    final showMobileNav = isMobile(context) && !isDeepWork && !isFullscreen && !isMini && !isSticky;

    return Scaffold(
      backgroundColor: isSticky ? Colors.transparent : null,
      body: isMini
          ? const MiniFloatingTimerWidget()
          : isSticky
              ? const StickyOverlayWidget()
              : Stack(
                  children: [
                    // ── Main layout with RepaintBoundary isolation ──
                    RepaintBoundary(
                      child: AnimatedContainer(
                        duration: PremiumDurations.themeTransition,
                        curve: PremiumCurves.easeOutCubic,
                        decoration: BoxDecoration(
                          color: Theme.of(context).scaffoldBackgroundColor,
                        ),
                        child: Row(
                          children: [
                            // Sidebar — hidden on mobile, shown on desktop/tablet
                            if (!showMobileNav)
                              RepaintBoundary(
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 150),
                                  switchInCurve: Curves.easeOut,
                                  switchOutCurve: Curves.easeIn,
                                  transitionBuilder: (child, animation) {
                                    return FadeTransition(
                                      opacity: animation,
                                      child: child,
                                    );
                                  },
                                  child: (isDeepWork || isFullscreen)
                                      ? const SizedBox.shrink(key: ValueKey('hidden'))
                                      : const FocusOsSidebar(key: ValueKey('sidebar')),
                                ),
                              ),

                            // Main content area — isolated repaint
                            Expanded(
                              child: RepaintBoundary(
                                child: isDeepWork
                                    ? const DeepWorkMode()
                                    : AnimatedSwitcher(
                                        duration: const Duration(milliseconds: 120),
                                        switchInCurve: Curves.easeOut,
                                        switchOutCurve: Curves.easeIn,
                                        transitionBuilder: (child, animation) {
                                          return FadeTransition(
                                            opacity: animation,
                                            child: child,
                                          );
                                        },
                                        child: KeyedSubtree(
                                          key: ValueKey(currentDest),
                                          child: _buildPage(currentDest),
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // ── Overlay gates (each watches only its own provider) ──
                    const _FocusModeIndicatorGate(),
                    const _SettingsModalGate(),
                    const _BrainDumpOverlayGate(),
                    const _QuickCaptureOverlayGate(),
                    const _HardcoreLockOverlayGate(),
                    const _KeyboardShortcutsOverlayGate(),
                    const _CalculatorOverlayGate(),
                    _StickyNotesContent(),
                    const _ReminderPopupGate(),
                  ],
                ),

      // ── Bottom Navigation Bar (mobile only) ──
      bottomNavigationBar: showMobileNav
          ? _MobileBottomNav(
              currentDest: currentDest,
              destinations: _mobileDestinations,
              moreDestinations: _mobileMoreDestinations,
              onTap: (dest) {
                ref.read(navigationProvider.notifier).state = dest;
              },
              onSettingsTap: () {
                ref.read(settingsModalOpenProvider.notifier).state = true;
              },
            )
          : null,
    );
  }
}

// ──────────────────────────────────────────────
// Mobile Bottom Navigation Bar
// ──────────────────────────────────────────────

class _MobileBottomNav extends StatelessWidget {
  final NavDestination currentDest;
  final List<NavDestination> destinations;
  final List<NavDestination> moreDestinations;
  final ValueChanged<NavDestination> onTap;
  final VoidCallback onSettingsTap;

  const _MobileBottomNav({
    required this.currentDest,
    required this.destinations,
    required this.moreDestinations,
    required this.onTap,
    required this.onSettingsTap,
  });

  bool get _isMoreActive =>
      moreDestinations.any((d) => d == currentDest);

  void _showMoreMenu(BuildContext context) {
    final tokens = FocusOsTheme.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: tokens.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final t = FocusOsTheme.of(ctx);
        return SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 16),
                decoration: BoxDecoration(
                  color: t.borderSubtle,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ...moreDestinations.map((dest) => ListTile(
                    leading: Icon(dest.icon, size: 20, color: t.textSecondary),
                    title: Text(dest.label,
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: t.textPrimary)),
                    onTap: () {
                      Navigator.pop(ctx);
                      onTap(dest);
                    },
                  )),
              const Divider(height: 1),
              ListTile(
                leading: Icon(Icons.settings_outlined,
                    size: 20, color: t.textSecondary),
                title: Text('Settings',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: t.textPrimary)),
                onTap: () {
                  Navigator.pop(ctx);
                  onSettingsTap();
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = FocusOsTheme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: tokens.surface.withValues(alpha: 0.92),
        border: Border(
          top: BorderSide(
            color: tokens.borderSubtle.withValues(alpha: 0.5),
            width: 0.5,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 56,
          child: Row(
            children: [
              ...destinations.map((dest) {
                final isActive = dest == currentDest;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => onTap(dest),
                    behavior: HitTestBehavior.opaque,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: isActive
                                ? tokens.accent.withValues(alpha: 0.10)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            dest.icon,
                            size: 20,
                            color: isActive ? tokens.accent : tokens.textMuted,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          dest.label,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight:
                                isActive ? FontWeight.w600 : FontWeight.w400,
                            color: isActive ? tokens.accent : tokens.textMuted,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                );
              }),
              // "More" overflow button
              Expanded(
                child: GestureDetector(
                  onTap: () => _showMoreMenu(context),
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: _isMoreActive
                              ? tokens.accent.withValues(alpha: 0.10)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.more_horiz_rounded,
                          size: 20,
                          color: _isMoreActive
                              ? tokens.accent
                              : tokens.textMuted,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'More',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: _isMoreActive
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color:
                              _isMoreActive ? tokens.accent : tokens.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────
// Overlay Gates — each is a standalone ConsumerWidget
// so toggling one overlay never rebuilds others.
// ──────────────────────────────────────────────

class _FocusModeIndicatorGate extends ConsumerWidget {
  const _FocusModeIndicatorGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fokusMode = ref.watch(fokusModeProvider);
    final isDeepWork = ref.watch(deepWorkModeProvider);
    if (!fokusMode || isDeepWork) return const SizedBox.shrink();

    return PremiumEnterTransition(
      duration: PremiumDurations.overlayFade,
      child: Positioned(
        top: 12,
        right: 16,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: FocusOsTheme.of(context).surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: FocusOsTheme.of(context).borderSubtle,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.do_not_disturb_alt,
                  size: 14,
                  color: FocusOsTheme.of(context).accent),
              const SizedBox(width: 6),
              Text('Fokus mode',
                  style: TextStyle(
                      fontSize: 11,
                      color: FocusOsTheme.of(context).textSecondary)),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsModalGate extends ConsumerWidget {
  const _SettingsModalGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOpen = ref.watch(settingsModalOpenProvider);
    if (!isOpen) return const SizedBox.shrink();

    return SettingsModal(
      onClose: () => ref.read(settingsModalOpenProvider.notifier).state = false,
    );
  }
}

class _BrainDumpOverlayGate extends ConsumerWidget {
  const _BrainDumpOverlayGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOpen = ref.watch(brainDumpOpenProvider);
    if (!isOpen) return const SizedBox.shrink();

    return BrainDumpOverlay(
      onClose: () => ref.read(brainDumpOpenProvider.notifier).state = false,
    );
  }
}

class _QuickCaptureOverlayGate extends ConsumerWidget {
  const _QuickCaptureOverlayGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOpen = ref.watch(quickCaptureOpenProvider);
    if (!isOpen) return const SizedBox.shrink();

    return _QuickCaptureOverlay(
      onClose: () => ref.read(quickCaptureOpenProvider.notifier).state = false,
    );
  }
}

class _HardcoreLockOverlayGate extends ConsumerWidget {
  const _HardcoreLockOverlayGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLocked = ref.watch(hardcoreLockProvider.select((s) => s.locked));
    if (!isLocked) return const SizedBox.shrink();

    return _HardcoreLockOverlay();
  }
}

class _KeyboardShortcutsOverlayGate extends ConsumerWidget {
  const _KeyboardShortcutsOverlayGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOpen = ref.watch(keyboardShortcutsOpenProvider);
    if (!isOpen) return const SizedBox.shrink();

    return KeyboardShortcutsOverlay(
      onClose: () => ref.read(keyboardShortcutsOpenProvider.notifier).state = false,
    );
  }
}

class _CalculatorOverlayGate extends ConsumerWidget {
  const _CalculatorOverlayGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOpen = ref.watch(calculatorOpenProvider);
    if (!isOpen) return const SizedBox.shrink();

    return CalculatorOverlay(
      onClose: () => ref.read(calculatorOpenProvider.notifier).state = false,
    );
  }
}

class _StickyNotesContent extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showNotes = ref.watch(showStickyNotesProvider);
    if (!showNotes) return const SizedBox.shrink();
    final notes = ref.watch(stickyNotesProvider);
    // Wrap in SizedBox.expand + inner Stack so FloatingStickyNote
    // can use Positioned layout within the outer Stack's bounds.
    return SizedBox.expand(
      child: Stack(
        clipBehavior: Clip.none,
        children: notes.map((note) => FloatingStickyNote(note: note)).toList(),
      ),
    );
  }
}

class _ReminderPopupGate extends ConsumerWidget {
  const _ReminderPopupGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reminder = ref.watch(activeReminderPopupProvider);
    if (reminder == null) return const SizedBox.shrink();

    return _ReminderPopupOverlay(
      reminder: reminder,
      onClose: () {
        ref.read(timerSoundProvider.notifier).stopAlarm();
        ref.read(activeReminderPopupProvider.notifier).state = null;
      },
    );
  }
}

