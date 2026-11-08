import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../shared/motion.dart' as motion;
import '../../shared/theme.dart';

class NotFeelingTodayPage extends StatefulWidget {
  final VoidCallback onBack;

  const NotFeelingTodayPage({super.key, required this.onBack});

  @override
  State<NotFeelingTodayPage> createState() => _NotFeelingTodayPageState();
}

class _NotFeelingTodayPageState extends State<NotFeelingTodayPage> {
  // 100 Curated Motivational Quotes
  static const List<String> _quotes = [
    "Pressure is a privilege.",
    "You only have one life.",
    "Discipline beats motivation.",
    "Consistency compounds.",
    "Comfort is the enemy of growth.",
    "Action creates clarity.",
    "Small steps every day.",
    "The hard choice is usually the right choice.",
    "Nobody is coming to save you.",
    "Fokus is a superpower.",
    "Success leaves clues.",
    "Your habits create your future.",
    "Progress over perfection.",
    "Fear is expensive.",
    "Courage is acting despite fear.",
    "Results require repetition.",
    "Greatness is built quietly.",
    "Winners do the boring work.",
    "Excuses are self-imposed limits.",
    "Time is your most valuable asset.",
    "Talent opens doors; discipline keeps them open.",
    "Growth begins where comfort ends.",
    "What gets measured gets improved.",
    "Hard work compounds too.",
    "The best investment is in yourself.",
    "Stay hungry, stay curious.",
    "Momentum is everything.",
    "Excellence is a habit.",
    "You become what you repeatedly do.",
    "Effort never betrays you.",
    "Dreams demand sacrifice.",
    "Every master was once a beginner.",
    "Confidence comes from preparation.",
    "Patience is a competitive advantage.",
    "The future rewards the prepared.",
    "Learn faster than others.",
    "Luck favors the persistent.",
    "Energy is earned through action.",
    "One year can change everything.",
    "The obstacle is the way.",
    "Success is rented, not owned.",
    "Show up, even when you don't feel like it.",
    "Delayed gratification builds empires.",
    "Stay fokused on the mission.",
    "Your standards shape your life.",
    "Hard things build strong people.",
    "Discipline equals freedom.",
    "Excellence requires repetition.",
    "The grind is invisible before the glory.",
    "Keep going.",
    "Growth feels uncomfortable.",
    "Master the basics.",
    "The work works.",
    "Make yourself proud.",
    "Consistency creates miracles.",
    "The strongest steel faces the hottest fire.",
    "Every day is an opportunity.",
    "Success starts with self-control.",
    "Persistence beats resistance.",
    "Win the day.",
    "Nobody remembers your excuses.",
    "The pain of regret lasts longer.",
    "The best time to start is now.",
    "Simplicity scales.",
    "Fokus on what matters.",
    "Be harder to kill than your excuses.",
    "Results are earned, not given.",
    "Build before you boast.",
    "Confidence follows competence.",
    "Keep promises to yourself.",
    "The journey is the reward.",
    "Discipline is self-respect in action.",
    "Great things take time.",
    "Every setback teaches something.",
    "Pressure reveals character.",
    "Strong minds create strong lives.",
    "Outwork your doubts.",
    "Momentum loves movement.",
    "Success is a daily decision.",
    "Your future self is watching.",
    "Stay patient and trust the process.",
    "Work until your idols become your peers.",
    "You are capable of more.",
    "Don't wish for easier; become stronger.",
    "Effort is never wasted.",
    "Sacrifice today, celebrate tomorrow.",
    "The comeback is always possible.",
    "Excellence is attention to detail.",
    "Strength grows through struggle.",
    "Build a life you don't need a vacation from.",
    "Keep learning.",
    "Keep improving.",
    "Keep showing up.",
    "Hard work changes lives.",
    "The price of greatness is responsibility.",
    "Success is built one day at a time.",
    "Become obsessed with improvement.",
    "Your actions define you.",
    "The best is yet to come.",
    "Leave no potential unexplored."
  ];

  late List<int> _shuffledIndices;
  int _shuffledPointer = 0;
  bool _isBlackTheme = true; // True = Black card/White text, False = White card/Black text
  bool _hovered = false;

  @override
  void initState() {
    super.initState();
    _generateShuffledIndices();
  }

  void _generateShuffledIndices() {
    _shuffledIndices = List<int>.generate(_quotes.length, (i) => i);
    _shuffledIndices.shuffle(Random());
    _shuffledPointer = 0;
  }

  void _nextQuote() {
    setState(() {
      if (_shuffledPointer < _quotes.length - 1) {
        _shuffledPointer++;
      } else {
        // Re-shuffle and reset pointer when all 100 quotes have been viewed
        _generateShuffledIndices();
      }
    });
    HapticFeedback.lightImpact();
  }

  void _prevQuote() {
    if (_shuffledPointer > 0) {
      setState(() {
        _shuffledPointer--;
      });
      HapticFeedback.lightImpact();
    }
  }

  void _toggleTheme() {
    setState(() {
      _isBlackTheme = !_isBlackTheme;
    });
    HapticFeedback.selectionClick();
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Copied quote to clipboard!',
          style: TextStyle(
            color: _isBlackTheme ? Colors.black : Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: _isBlackTheme ? Colors.white : Colors.black87,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = FocusOsTheme.of(context);
    final activeIndex = _shuffledIndices[_shuffledPointer];
    final currentQuote = _quotes[activeIndex];

    // Card styling parameters based on isBlackTheme
    final Color cardBg = _isBlackTheme ? const Color(0xFF000000) : const Color(0xFFFFFFFF);
    final Color cardText = _isBlackTheme ? const Color(0xFFFFFFFF) : const Color(0xFF000000);
    final Color cardBorder = _isBlackTheme ? Colors.white.withValues(alpha: 0.15) : Colors.black.withValues(alpha: 0.15);
    final Color cardSubText = _isBlackTheme ? Colors.white60 : Colors.black54;

    return motion.PremiumEnterTransition(
      duration: motion.PremiumDurations.pageTransition,
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top Navigation / Back Header ──
            Row(
              children: [
                IconButton(
                  icon: Icon(Icons.arrow_back_ios_new_rounded,
                      size: 18, color: tokens.textPrimary),
                  onPressed: widget.onBack,
                  splashRadius: 20,
                  tooltip: 'Back to Tools',
                ),
                const SizedBox(width: 8),
                Text(
                  'Tools',
                  style: TextStyle(
                    fontSize: 14,
                    color: tokens.textMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '/',
                  style: TextStyle(fontSize: 14, color: tokens.borderSubtle),
                ),
                const SizedBox(width: 6),
                Text(
                  'Not Feeling Today?',
                  style: TextStyle(
                    fontSize: 14,
                    color: tokens.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 36),

            // ── Center Content Area ──
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Subtitle Header
                      Text(
                        'NOT FEELING TODAY?',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: tokens.accent,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tap the card or swipe to reveal dynamic perspectives.',
                        style: TextStyle(
                          fontSize: 13,
                          color: tokens.textMuted,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 28),

                      // ── The Quote Card ──
                      GestureDetector(
                        onHorizontalDragEnd: (details) {
                          if (details.primaryVelocity != null) {
                            if (details.primaryVelocity! < 0) {
                              _nextQuote(); // Swipe Left
                            } else if (details.primaryVelocity! > 0) {
                              _prevQuote(); // Swipe Right
                            }
                          }
                        },
                        onTap: _nextQuote,
                        child: MouseRegion(
                          cursor: SystemMouseCursors.click,
                          onEnter: (_) => setState(() => _hovered = true),
                          onExit: (_) => setState(() => _hovered = false),
                          child: AnimatedContainer(
                            duration: motion.PremiumDurations.hoverLong,
                            curve: motion.PremiumCurves.easeOutCubic,
                            width: double.infinity,
                            height: 360,
                            padding: const EdgeInsets.symmetric(horizontal: 44, vertical: 40),
                            decoration: BoxDecoration(
                              color: cardBg,
                              borderRadius: BorderRadius.circular(32),
                              border: Border.all(
                                color: _hovered
                                    ? (_isBlackTheme ? Colors.white38 : Colors.black38)
                                    : cardBorder,
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: _isBlackTheme ? 0.4 : 0.08),
                                  blurRadius: _hovered ? 36 : 24,
                                  offset: Offset(0, _hovered ? 12 : 8),
                                ),
                              ],
                            ),
                            transform: Matrix4.translationValues(
                              0.0,
                              _hovered ? -6.0 : 0.0,
                              0.0,
                            ),
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 350),
                              switchInCurve: Curves.easeOutCubic,
                              switchOutCurve: Curves.easeInCubic,
                              transitionBuilder: (Widget child, Animation<double> animation) {
                                return FadeTransition(
                                  opacity: animation,
                                  child: SlideTransition(
                                    position: Tween<Offset>(
                                      begin: const Offset(0.04, 0),
                                      end: Offset.zero,
                                    ).animate(animation),
                                    child: child,
                                  ),
                                );
                              },
                              child: Column(
                                key: ValueKey<int>(_shuffledPointer),
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  // Quote Icon indicator
                                  Align(
                                    alignment: Alignment.topLeft,
                                    child: Icon(
                                      Icons.format_quote_rounded,
                                      size: 38,
                                      color: cardSubText.withValues(alpha: 0.3),
                                    ),
                                  ),

                                  // Core Quote Text
                                  Expanded(
                                    child: Center(
                                      child: Text(
                                        currentQuote,
                                        style: TextStyle(
                                          fontSize: currentQuote.length > 30 ? 25 : 30,
                                          fontWeight: FontWeight.w800,
                                          color: cardText,
                                          height: 1.45,
                                          letterSpacing: -0.5,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),

                                  // Card Footer metadata
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'PERSPECTIVE ${_shuffledPointer + 1}/100',
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w900,
                                          color: cardSubText,
                                          letterSpacing: 1.0,
                                        ),
                                      ),
                                      Text(
                                        'TAP TO ROTATE',
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w900,
                                          color: cardSubText.withValues(alpha: 0.5),
                                          letterSpacing: 0.8,
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
                      const SizedBox(height: 36),

                      // ── Control Bar Buttons ──
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Previous Button
                          _buildControlBtn(
                            icon: Icons.chevron_left_rounded,
                            tooltip: 'Previous Quote',
                            onTap: _shuffledPointer > 0 ? _prevQuote : null,
                            tokens: tokens,
                          ),
                          const SizedBox(width: 16),

                          // Theme Toggle Button
                          _buildControlBtn(
                            icon: _isBlackTheme ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                            tooltip: 'Toggle Theme',
                            onTap: _toggleTheme,
                            tokens: tokens,
                          ),
                          const SizedBox(width: 16),

                          // Copy Button
                          _buildControlBtn(
                            icon: Icons.copy_all_rounded,
                            tooltip: 'Copy Quote',
                            onTap: () => _copyToClipboard(currentQuote),
                            tokens: tokens,
                          ),
                          const SizedBox(width: 16),

                          // Next Button
                          _buildControlBtn(
                            icon: Icons.chevron_right_rounded,
                            tooltip: 'Next Quote',
                            onTap: _nextQuote,
                            tokens: tokens,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlBtn({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onTap,
    required ThemeTokens tokens,
  }) {
    final bool enabled = onTap != null;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: enabled ? tokens.surface : tokens.surface.withValues(alpha: 0.4),
              border: Border.all(
                color: enabled ? tokens.borderSubtle : tokens.borderSubtle.withValues(alpha: 0.4),
                width: 1.2,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              icon,
              size: 20,
              color: enabled ? tokens.textPrimary : tokens.textMuted.withValues(alpha: 0.4),
            ),
          ),
        ),
      ),
    );
  }
}
