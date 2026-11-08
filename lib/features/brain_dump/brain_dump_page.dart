import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/providers.dart';
import '../../shared/theme.dart';
import '../../shared/widgets/premium_card.dart';
import '../../shared/widgets/premium_button.dart';
import '../../shared/widgets/brain_dump_overlay.dart';
import '../../shared/motion.dart' as motion;
import '../../services/ambient_sound_service.dart';

class BrainDumpPage extends ConsumerWidget {
  const BrainDumpPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const Scaffold(
      body: BrainDumpWorkspace(),
    );
  }
}

class BrainDumpWorkspace extends ConsumerStatefulWidget {
  final VoidCallback? onBack;

  const BrainDumpWorkspace({super.key, this.onBack});

  @override
  ConsumerState<BrainDumpWorkspace> createState() => _BrainDumpWorkspaceState();
}

class _BrainDumpWorkspaceState extends ConsumerState<BrainDumpWorkspace> {
  final _textController = TextEditingController();
  final _focusNode = FocusNode();
  bool _showArchive = false;
  bool _isFullScreen = false;
  int _promptIndex = 0;
  String? _successMessage;
  Timer? _successTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(brainDumpEntriesProvider.notifier).refresh();
    });
  }

  final List<String> _prompts = [
    "Unload your thoughts. Clear the mental clutter...",
    "What is drawing your attention away from fokus right now?",
    "What are three things you are grateful for in this moment?",
    "Describe any tension or worry you feel, write it down, and let it go...",
    "Free write. Let your thoughts flow without editing or judging...",
  ];

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    _successTimer?.cancel();
    super.dispose();
  }

  void _cyclePrompt() {
    setState(() {
      _promptIndex = (_promptIndex + 1) % _prompts.length;
    });
  }

  Future<void> _saveAndClear() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    // Save to the entries database
    await BrainDumpService.saveEntry(
      BrainDumpEntry(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text: text,
        timestamp: DateTime.now(),
      ),
    );

    // Refresh provider
    ref.read(brainDumpEntriesProvider.notifier).refresh();

    _textController.clear();
    _focusNode.unfocus();

    // Show beautiful calming success notification
    _successTimer?.cancel();
    setState(() {
      _successMessage = "Your thoughts are captured. Your mind is clear.";
    });

    _successTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() {
          _successMessage = null;
        });
      }
    });
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return '${date.month}/${date.day}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final tokens = FocusOsTheme.of(context);
    final entries = ref.watch(brainDumpEntriesProvider);
    final soundState = ref.watch(ambientSoundProvider);

    final body = Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            tokens.background,
            tokens.background.safeWithOpacity(0.95),
            Color.alphaBlend(
              tokens.accent.safeWithOpacity(_isFullScreen ? 0.06 : 0.04),
              tokens.background,
            ),
          ],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // ── Toolbar/Header ──
            AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              curve: motion.PremiumCurves.easeOutCubic,
              height: _isFullScreen ? 0 : null,
              child: _isFullScreen
                  ? null
                  : Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      child: Row(
                        children: [
                          if (widget.onBack != null) ...[
                            IconButton(
                              icon: Icon(Icons.arrow_back_ios_new_rounded,
                                  size: 18, color: tokens.textPrimary),
                              onPressed: widget.onBack,
                              splashRadius: 20,
                              tooltip: 'Back to Tools',
                            ),
                            const SizedBox(width: 8),
                          ],
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Brain Dump',
                                style: GoogleFonts.outfit(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w500,
                                  color: tokens.textPrimary,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              Text(
                                'Clear your mind and reflect',
                                style: TextStyle(fontSize: 11, color: tokens.textMuted),
                              ),
                            ],
                          ),
                          const Spacer(),

                          // Soundscape Control
                          _CalmSoundscapeControl(tokens: tokens, soundState: soundState, ref: ref),

                          const SizedBox(width: 12),

                          // Fullscreen Toggle
                          IconButton(
                            icon: Icon(
                              _isFullScreen ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded,
                              color: _isFullScreen ? tokens.accent : tokens.textSecondary,
                              size: 20,
                            ),
                            onPressed: () {
                              setState(() {
                                _isFullScreen = !_isFullScreen;
                              });
                            },
                            tooltip: _isFullScreen ? 'Exit Fullscreen' : 'Fullscreen Mode',
                          ),

                          const SizedBox(width: 12),

                          // Archive Toggle Button
                          IconButton(
                            icon: Icon(
                              _showArchive ? Icons.edit_note_rounded : Icons.history_rounded,
                              color: _showArchive ? tokens.accent : tokens.textSecondary,
                              size: 20,
                            ),
                            onPressed: () {
                              setState(() {
                                _showArchive = !_showArchive;
                              });
                            },
                            tooltip: _showArchive ? 'Write Entry' : 'View Past Reflections',
                          ),
                        ],
                      ),
                    ),
            ),

            if (!_isFullScreen)
              Divider(color: tokens.borderSubtle.safeWithOpacity(0.3), height: 1),

            // ── Content Area ──
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 500),
                switchInCurve: motion.PremiumCurves.softOut,
                switchOutCurve: motion.PremiumCurves.easeInCubic,
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: child,
                ),
                child: _showArchive
                    ? _buildArchiveView(tokens, entries)
                    : _buildWritingView(tokens, entries),
              ),
            ),
          ],
        ),
      ),
    );

    // In fullscreen, wrap with a subtle entering animation and floating exit button
    if (_isFullScreen) {
      return motion.PremiumEnterTransition(
        duration: const Duration(milliseconds: 600),
        curve: motion.PremiumCurves.softOut,
        child: Stack(
          children: [
            body,
            // Floating exit button overlay
            Positioned(
              top: 12,
              right: 12,
              child: GestureDetector(
                onTap: () => setState(() => _isFullScreen = false),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: tokens.surface.safeWithOpacity(0.6),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: tokens.borderSubtle.safeWithOpacity(0.4),
                    ),
                  ),
                  child: Icon(
                    Icons.fullscreen_exit_rounded,
                    size: 16,
                    color: tokens.textSecondary,
                  ),
                ),
              ),
            ),
            // Also show fullscreen hint at bottom
            Positioned(
              bottom: 24,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: Opacity(
                  opacity: 0.4,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: tokens.surface.safeWithOpacity(0.5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.keyboard, size: 10, color: tokens.textMuted),
                          const SizedBox(width: 6),
                          Text(
                            'Esc to exit fullscreen',
                            style: TextStyle(fontSize: 10, color: tokens.textMuted),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }
    return body;
  }

  // Distraction-free Writing workspace
  Widget _buildWritingView(ThemeTokens tokens, List<BrainDumpEntry> entries) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 16),
              // Breathing Visualizer widget
              const _BreathingVisualizer(),
              const SizedBox(height: 24),

              // Prompts header
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _prompts[_promptIndex],
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontStyle: FontStyle.italic,
                      color: tokens.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _cyclePrompt,
                    child: Icon(
                      Icons.refresh_rounded,
                      size: 14,
                      color: tokens.textMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Large minimal writing text field
              TextField(
                controller: _textController,
                focusNode: _focusNode,
                maxLines: null,
                minLines: 8,
                style: GoogleFonts.playfairDisplay(
                  fontSize: 18,
                  height: 1.6,
                  color: tokens.textPrimary,
                ),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Type freely, dump any distractions here...',
                  hintStyle: GoogleFonts.playfairDisplay(
                    fontSize: 18,
                    height: 1.6,
                    color: tokens.textMuted.safeWithOpacity(0.3),
                  ),
                ),
                cursorColor: tokens.accent,
              ),

              const SizedBox(height: 40),

              // Feedback message
              if (_successMessage != null) ...[
                motion.PremiumEnterTransition(
                  duration: const Duration(milliseconds: 300),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: tokens.accent.safeWithOpacity(0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: tokens.accent.safeWithOpacity(0.2)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle_outline_rounded, size: 14, color: tokens.accent),
                        const SizedBox(width: 8),
                        Text(
                          _successMessage!,
                          style: TextStyle(fontSize: 12, color: tokens.accent, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  PremiumButton(
                    onTap: _saveAndClear,
                    variant: PremiumButtonVariant.gradient,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                    child: Text(
                      'Save & Clear Mind',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              // Recent Reflections (saved entries)
              if (entries.isNotEmpty) ...[
                const SizedBox(height: 48),
                Row(
                  children: [
                    Icon(Icons.history_rounded, size: 16, color: tokens.textSecondary),
                    const SizedBox(width: 8),
                    Text(
                      'Recent Reflections',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: tokens.textPrimary,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => setState(() => _showArchive = true),
                      child: Text(
                        'View All (${entries.length})',
                        style: TextStyle(
                          fontSize: 11,
                          color: tokens.accent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: entries.take(3).length,
                  separatorBuilder: (context, index) => Divider(
                    color: tokens.borderSubtle.safeWithOpacity(0.3),
                    height: 24,
                  ),
                  itemBuilder: (context, index) {
                    final entry = entries[index];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _formatDate(entry.timestamp),
                              style: TextStyle(
                                fontSize: 10,
                                color: tokens.textMuted,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.delete_outline_rounded, size: 14, color: tokens.textMuted),
                              onPressed: () {
                                ref.read(brainDumpEntriesProvider.notifier).deleteEntry(entry.id);
                              },
                              splashRadius: 16,
                              constraints: const BoxConstraints(),
                              padding: EdgeInsets.zero,
                              tooltip: 'Delete reflection',
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          entry.text,
                          style: GoogleFonts.playfairDisplay(
                            fontSize: 14,
                            height: 1.5,
                            color: tokens.textPrimary,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
              const SizedBox(height: 60),
            ],
          ),
        ),
      ),
    );
  }

  // Calm, minimal Reflection history
  Widget _buildArchiveView(ThemeTokens tokens, List<BrainDumpEntry> entries) {
    if (entries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history_toggle_off_rounded, size: 48, color: tokens.textMuted),
            const SizedBox(height: 16),
            Text(
              'Your reflection history is empty',
              style: TextStyle(color: tokens.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 4),
            Text(
              'Save some reflections to see them here',
              style: TextStyle(color: tokens.textMuted, fontSize: 11),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        return Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 680),
            margin: const EdgeInsets.only(bottom: 16),
            child: PremiumCard(
              padding: const EdgeInsets.all(20),
              hoverElevation: 4.0,
              hoverYOffset: -1.0,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.calendar_today_rounded, size: 10, color: tokens.textMuted),
                      const SizedBox(width: 6),
                      Text(
                        _formatDate(entry.timestamp),
                        style: TextStyle(fontSize: 10, color: tokens.textMuted, fontWeight: FontWeight.w500),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: Icon(Icons.delete_outline_rounded, size: 16, color: tokens.textMuted),
                        onPressed: () {
                          ref.read(brainDumpEntriesProvider.notifier).deleteEntry(entry.id);
                        },
                        splashRadius: 18,
                        tooltip: 'Delete reflection',
                        constraints: const BoxConstraints(),
                        padding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    entry.text,
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 15,
                      height: 1.5,
                      color: tokens.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ── Breathing Visualizer widget (Enhanced) ──
class _BreathingVisualizer extends StatefulWidget {
  const _BreathingVisualizer();

  @override
  State<_BreathingVisualizer> createState() => _BreathingVisualizerState();
}

class _BreathingVisualizerState extends State<_BreathingVisualizer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  late Animation<double> _glowAnimation;
  String _breathingText = "Breathe In";

  // Breathing session state
  bool _sessionActive = false;
  int _sessionDuration = 0; // seconds remaining
  int _selectedMinutes = 1;
  Timer? _sessionTimer;
  bool _sessionComplete = false;

  static const _sessionOptions = [0, 1, 2, 5]; // 0 = continuous

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    );

    _animation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 60.0, end: 140.0).chain(CurveTween(curve: motion.PremiumCurves.softOut)),
        weight: 40, // 4s Breathe In
      ),
      TweenSequenceItem(
        tween: ConstantTween<double>(140.0),
        weight: 20, // 2s Hold
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 140.0, end: 60.0).chain(CurveTween(curve: motion.PremiumCurves.softOut)),
        weight: 40, // 4s Breathe Out
      ),
    ]).animate(_controller);

    _glowAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.08, end: 0.25).chain(CurveTween(curve: motion.PremiumCurves.softOut)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: ConstantTween<double>(0.25),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.25, end: 0.08).chain(CurveTween(curve: motion.PremiumCurves.softOut)),
        weight: 40,
      ),
    ]).animate(_controller);

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _controller.repeat();
      }
    });

    _controller.addListener(() {
      final value = _controller.value;
      if (value < 0.4) {
        if (_breathingText != "Breathe In") setState(() => _breathingText = "Breathe In");
      } else if (value < 0.6) {
        if (_breathingText != "Hold") setState(() => _breathingText = "Hold");
      } else {
        if (_breathingText != "Breathe Out") setState(() => _breathingText = "Breathe Out");
      }
    });

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    _sessionTimer?.cancel();
    super.dispose();
  }

  void _startSession(int minutes) {
    if (minutes == 0) {
      // Continuous mode — just ensure animation is running
      return;
    }
    setState(() {
      _selectedMinutes = minutes;
      _sessionDuration = minutes * 60;
      _sessionActive = true;
      _sessionComplete = false;
    });
    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_sessionDuration <= 1) {
        timer.cancel();
        if (mounted) {
          setState(() {
            _sessionActive = false;
            _sessionComplete = true;
          });
          // Auto-dismiss completion state after 3 seconds
          Future.delayed(const Duration(seconds: 3), () {
            if (mounted) setState(() => _sessionComplete = false);
          });
        }
      } else {
        setState(() => _sessionDuration--);
      }
    });
  }

  void _cancelSession() {
    _sessionTimer?.cancel();
    setState(() {
      _sessionActive = false;
      _sessionComplete = false;
      _sessionDuration = 0;
    });
  }

  String _formatDuration(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final tokens = FocusOsTheme.of(context);
    final size = _sessionActive ? 180.0 : 140.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _animation,
          builder: (context, child) {
            final glowOpacity = _glowAnimation.value;

            return GestureDetector(
              onTap: () {
                if (!_sessionActive && !_sessionComplete && _selectedMinutes > 0) {
                  _startSession(_selectedMinutes);
                }
              },
              child: Container(
                width: size,
                height: size,
                alignment: Alignment.center,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Outer glow ring
                    Container(
                      width: _animation.value + 40,
                      height: _animation.value + 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            tokens.accent.safeWithOpacity(0.0),
                            tokens.accent.safeWithOpacity(glowOpacity * 0.5),
                          ],
                          stops: const [0.6, 1.0],
                        ),
                      ),
                    ),
                    // Main pulsing circle
                    Container(
                      width: _animation.value,
                      height: _animation.value,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            tokens.accent.safeWithOpacity(0.02),
                            tokens.accent.safeWithOpacity(glowOpacity),
                          ],
                        ),
                        border: Border.all(
                          color: tokens.accent.safeWithOpacity(glowOpacity * 0.7),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: tokens.accent.safeWithOpacity(glowOpacity * 0.4),
                            blurRadius: 25,
                            spreadRadius: _animation.value / 20,
                          ),
                        ],
                      ),
                    ),
                    // Session timer overlay
                    if (_sessionActive)
                      Text(
                        _formatDuration(_sessionDuration),
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.w300,
                          color: tokens.accent.safeWithOpacity(0.9),
                          letterSpacing: 1,
                        ),
                      ),
                    if (_sessionComplete)
                      Icon(
                        Icons.check_circle_outline_rounded,
                        size: 28,
                        color: tokens.accent,
                      ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 10),
        // Breathing phase label
        AnimatedOpacity(
          duration: const Duration(milliseconds: 300),
          opacity: _sessionActive ? 1.0 : 0.6,
          child: Text(
            _sessionComplete
                ? 'Session Complete'
                : (_sessionActive ? _breathingText : 'Tap to begin'),
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: tokens.accent.safeWithOpacity(0.8),
              letterSpacing: 1.5,
            ),
          ),
        ),
        if (!_sessionActive && !_sessionComplete) ...[
          const SizedBox(height: 10),
          // Session duration selector
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: _sessionOptions.map((minutes) {
              final isSelected = _selectedMinutes == minutes;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: GestureDetector(
                  onTap: () {
                    setState(() => _selectedMinutes = minutes);
                    if (minutes > 0) {
                      _startSession(minutes);
                    } else {
                      // Continuous mode — just ensure animation runs
                      _cancelSession();
                    }
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: motion.PremiumCurves.easeOutCubic,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? tokens.accent.safeWithOpacity(0.12)
                          : tokens.borderSubtle.safeWithOpacity(0.5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? tokens.accent.safeWithOpacity(0.3)
                            : tokens.borderSubtle,
                      ),
                    ),
                    child: Text(
                      minutes == 0 ? '∞' : '${minutes}m',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                        color: isSelected ? tokens.accent : tokens.textSecondary,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
        if (_sessionActive) ...[
          const SizedBox(height: 10),
          GestureDetector(
            onTap: _cancelSession,
            child: Text(
              'Cancel',
              style: TextStyle(
                fontSize: 10,
                color: tokens.textMuted,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ── Calm Soundscape Control ──
class _CalmSoundscapeControl extends StatelessWidget {
  final ThemeTokens tokens;
  final AmbientSoundState soundState;
  final WidgetRef ref;

  const _CalmSoundscapeControl({
    required this.tokens,
    required this.soundState,
    required this.ref,
  });

  @override
  Widget build(BuildContext context) {
    final active = soundState.isPlaying;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: active ? tokens.accent.safeWithOpacity(0.2) : tokens.borderSubtle,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(
              active ? Icons.volume_up_rounded : Icons.volume_off_rounded,
              size: 15,
              color: active ? tokens.accent : tokens.textSecondary,
            ),
            onPressed: () {
              ref.read(ambientSoundProvider.notifier).toggle();
            },
            tooltip: active ? 'Mute Sounds' : 'Unmute Sounds',
            constraints: const BoxConstraints(),
            padding: EdgeInsets.zero,
            splashRadius: 16,
          ),
          if (active) ...[
            const SizedBox(width: 8),
            // Minimal sound cycle button
            GestureDetector(
              onTap: () {
                final current = soundState.type;
                AmbientSoundType next = AmbientSoundType.none;
                if (current == AmbientSoundType.none || current == AmbientSoundType.whiteNoise) {
                  next = AmbientSoundType.rain;
                } else if (current == AmbientSoundType.rain) {
                  next = AmbientSoundType.cafe;
                } else if (current == AmbientSoundType.cafe) {
                  next = AmbientSoundType.whiteNoise;
                }
                ref.read(ambientSoundProvider.notifier).setType(next);
              },
              child: Text(
                _soundTypeName(soundState.type),
                style: TextStyle(fontSize: 10, color: tokens.textSecondary, fontWeight: FontWeight.w500),
              ),
            ),
            const SizedBox(width: 10),
            // Minimal slider
            SizedBox(
              width: 50,
              child: SliderTheme(
                data: SliderThemeData(
                  trackHeight: 2,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 3),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 8),
                  activeTrackColor: tokens.accent,
                  inactiveTrackColor: tokens.borderSubtle,
                  thumbColor: tokens.accent,
                ),
                child: Slider(
                  value: soundState.volume,
                  onChanged: (v) {
                    ref.read(ambientSoundProvider.notifier).setVolume(v);
                  },
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _soundTypeName(AmbientSoundType type) {
    switch (type) {
      case AmbientSoundType.rain:
        return 'Rain';
      case AmbientSoundType.cafe:
        return 'Cafe';
      case AmbientSoundType.whiteNoise:
        return 'Noise';
      default:
        return 'Off';
    }
  }
}
