import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../shared/theme.dart';
import '../../shared/motion.dart' as motion;
import '../../shared/widgets/premium_button.dart';

// ──────────────────────────────────────────────
// Social Link data model
// ──────────────────────────────────────────────

class _SocialLink {
  final String name;
  final String handle;
  final String url;
  final String letter;
  final Color brandColor;

  const _SocialLink({
    required this.name,
    required this.handle,
    required this.url,
    required this.letter,
    required this.brandColor,
  });
}

const List<_SocialLink> _socialLinks = [
  _SocialLink(
    name: 'Instagram', handle: '@aman.ja1n',
    url: 'https://www.instagram.com/aman.ja1n/',
    letter: 'I', brandColor: Color(0xFFE4405F),
  ),
  _SocialLink(
    name: 'YouTube', handle: '@AmanJain-4',
    url: 'https://www.youtube.com/@AmanJain-4',
    letter: 'Y', brandColor: Color(0xFFFF0000),
  ),
  _SocialLink(
    name: 'Threads', handle: '@aman.ja1n',
    url: 'https://www.threads.com/@aman.ja1n',
    letter: 'T', brandColor: Color(0xFF333333),
  ),
  _SocialLink(
    name: 'X (Twitter)', handle: '@aman_ja1n',
    url: 'https://x.com/aman_ja1n',
    letter: 'X', brandColor: Color(0xFF1DA1F2),
  ),
  _SocialLink(
    name: 'Substack', handle: '@amanjain519188',
    url: 'https://substack.com/@amanjain519188',
    letter: 'S', brandColor: Color(0xFFFF6719),
  ),
  _SocialLink(
    name: 'LinkedIn', handle: '/in/amanmalu/',
    url: 'https://www.linkedin.com/in/amanmalu/',
    letter: 'L', brandColor: Color(0xFF0A66C2),
  ),
];

// ──────────────────────────────────────────────
// Support Page
// ──────────────────────────────────────────────

class SupportPage extends StatefulWidget {
  const SupportPage({super.key});

  @override
  State<SupportPage> createState() => _SupportPageState();
}

class _SupportPageState extends State<SupportPage> {
  @override
  Widget build(BuildContext context) {
    final tokens = FocusOsTheme.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header Text (Centered) ──
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Support Me',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: tokens.textPrimary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Follow and support me on socials',
                      style: TextStyle(fontSize: 14, color: tokens.textMuted),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // ── Caffeine & Code Donation Card ──
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final useRatio = constraints.maxWidth >= 500;
                      if (useRatio) {
                        return AspectRatio(
                          aspectRatio: 16 / 10,
                          child: _DonationCard(tokens: tokens, isRatio: true),
                        );
                      }
                      return _DonationCard(tokens: tokens, isRatio: false);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // ── Social Links Grid ──
              _SocialGrid(),
              const SizedBox(height: 40),

              // ── Divider ──
              Container(height: 1, color: tokens.borderSubtle),
              const SizedBox(height: 36),

              // ── Contact Form ──
              _ContactForm(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────
// Social Grid
// ──────────────────────────────────────────────

class _SocialGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 320,
            mainAxisSpacing: 24,
            crossAxisSpacing: 24,
            mainAxisExtent: 160,
          ),
          itemCount: _socialLinks.length,
          itemBuilder: (context, index) {
            return _SocialLinkCard(link: _socialLinks[index]);
          },
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────
// Social Link Card
// ──────────────────────────────────────────────

class _SocialLinkCard extends StatefulWidget {
  final _SocialLink link;

  const _SocialLinkCard({
    required this.link,
  });

  @override
  State<_SocialLinkCard> createState() => _SocialLinkCardState();
}

class _SocialLinkCardState extends State<_SocialLinkCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final tokens = FocusOsTheme.of(context);
    final link = widget.link;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () => _openUrl(link.url),
        child: AnimatedContainer(
          duration: motion.PremiumDurations.hoverLong,
          curve: motion.PremiumCurves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: tokens.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: _hovered
                  ? link.brandColor.withValues(alpha: 0.4)
                  : tokens.borderSubtle,
              width: _hovered ? 1.5 : 1.0,
            ),
            boxShadow: _hovered
                ? [
                    BoxShadow(
                      color: link.brandColor.withValues(alpha: 0.18),
                      blurRadius: 28.0,
                      offset: const Offset(0.0, 8.0),
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 12.0,
                      offset: const Offset(0.0, 4.0),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 4.0,
                      offset: const Offset(0.0, 2.0),
                    ),
                  ],
          ),
          transform: Matrix4.translationValues(
            0.0,
            _hovered ? -4.0 : 0.0,
            0.0,
          ),
          transformAlignment: Alignment.center,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Top row: Logo Letter + Arrow ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Glassmorphism brand letter container
                  AnimatedContainer(
                    duration: motion.PremiumDurations.hover,
                    curve: motion.PremiumCurves.easeOutCubic,
                    width: _hovered ? 56 : 50,
                    height: _hovered ? 56 : 50,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          link.brandColor.withValues(alpha: 0.22),
                          link.brandColor.withValues(alpha: 0.08),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: link.brandColor.withValues(alpha: _hovered ? 0.35 : 0.15),
                        width: 1.0,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(6.0),
                      child: Image.asset(
                        'assets/icons/${(link.name.toLowerCase().contains('twitter') || link.name.toLowerCase() == 'x') ? 'twitter' : link.name.toLowerCase().replaceAll(' ', '_')}.png',
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return Center(
                            child: Text(
                              link.letter,
                              style: TextStyle(
                                fontSize: _hovered ? 24 : 22,
                                fontWeight: FontWeight.w800,
                                color: link.brandColor,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  // Animated arrow
                  AnimatedOpacity(
                    duration: motion.PremiumDurations.hover,
                    opacity: _hovered ? 1.0 : 0.4,
                    child: AnimatedSlide(
                      duration: motion.PremiumDurations.hover,
                      curve: motion.PremiumCurves.easeOutCubic,
                      offset: _hovered ? const Offset(0.2, 0.0) : Offset.zero,
                      child: TweenAnimationBuilder<Color?>(
                        tween: ColorTween(
                          end: _hovered ? link.brandColor : tokens.textMuted,
                        ),
                        duration: motion.PremiumDurations.hover,
                        curve: motion.PremiumCurves.easeOutCubic,
                        builder: (context, color, _) => Icon(
                          Icons.arrow_forward_rounded,
                          size: 16,
                          color: color,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              // Title & Subtitle block
              Text(
                link.name,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: tokens.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                link.handle,
                style: TextStyle(fontSize: 12, color: tokens.textMuted),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              // Bottom accent bar
              AnimatedContainer(
                duration: motion.PremiumDurations.hover,
                curve: motion.PremiumCurves.easeOutCubic,
                height: 3,
                width: _hovered ? 60 : 32,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      link.brandColor,
                      link.brandColor.withValues(alpha: 0.4),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Central URL Opener Helper ──
Future<void> _openUrl(String url) async {
  try {
    if (Platform.isWindows) {
      await Process.run('start', ['""', url], runInShell: true);
    } else if (Platform.isMacOS) {
      await Process.run('open', [url]);
    } else if (Platform.isLinux) {
      await Process.run('xdg-open', [url]);
    }
  } catch (e) {
    debugPrint('_openUrl error: $e');
  }
}

// ──────────────────────────────────────────────
// Premium Caffeine Refueling Donation Card
// ──────────────────────────────────────────────

class _DonationCard extends StatefulWidget {
  final ThemeTokens tokens;
  final bool isRatio;

  const _DonationCard({
    required this.tokens,
    this.isRatio = false,
  });

  @override
  State<_DonationCard> createState() => _DonationCardState();
}

class _DonationCardState extends State<_DonationCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final tokens = widget.tokens;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () => _openUrl('https://razorpay.me/@amanmalu'),
        child: AnimatedContainer(
          duration: motion.PremiumDurations.hoverLong,
          curve: motion.PremiumCurves.easeOutCubic,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                _hovered ? tokens.surface : tokens.surface.withValues(alpha: 0.85),
                _hovered
                    ? tokens.surfaceAlt.withValues(alpha: 0.95)
                    : tokens.surfaceAlt.withValues(alpha: 0.75),
              ],
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: _hovered
                  ? (isDark ? const Color(0xFFF59E0B) : const Color(0xFFD97706)) // Gold on hover
                  : (isDark ? const Color(0xFFF59E0B) : const Color(0xFFD97706)).withValues(alpha: 0.35),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.12 : 0.05),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
              if (_hovered)
                BoxShadow(
                  color: (isDark ? const Color(0xFFF59E0B) : const Color(0xFFD97706)).withValues(alpha: 0.12),
                  blurRadius: 32,
                  spreadRadius: 2,
                ),
            ],
          ),
          transform: Matrix4.translationValues(
            0.0,
            _hovered ? -5.0 : 0.0,
            0.0,
          ),
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        'Developer Refueling Station',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: _hovered
                              ? (isDark ? const Color(0xFFF59E0B) : const Color(0xFFD97706))
                              : tokens.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    _buildBatteryWidget(tokens),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '• Fokus is free, ad-free, and built by a solo developer.',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: tokens.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'If Fokus has helped you stay productive, save time, reduce distractions, or improve your workflow, consider supporting its future development.',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: tokens.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Every contribution helps fund new features, bug fixes, performance improvements, and future updates.',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: tokens.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                // Highlight Box with subtle blue accent background
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1E3A8A).withValues(alpha: 0.2)
                        : const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFF3B82F6).withValues(alpha: 0.3)
                          : const Color(0xFFBFDBFE),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF3B82F6).withValues(alpha: isDark ? 0.08 : 0.03),
                        blurRadius: 8,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '⚡ Pay what you think Fokus is worth.',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF1E40AF),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'There is no required amount. Whether it\'s the price of a chai, a coffee, a pizza, or something larger, every contribution helps keep Focus free and continuously improving.',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1E3A8A),
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    Text(
                      'Current fuel level: 14% ⚡',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: isDark ? const Color(0xFFF59E0B) : const Color(0xFFD97706),
                      ),
                    ),
                    Text(
                      '🚀 Thanks for helping independent software stay alive.',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: tokens.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _PulsingCtaButton(
                  isDark: isDark,
                  hovered: _hovered,
                  onTap: () => _openUrl('https://razorpay.me/@amanmalu'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBatteryWidget(ThemeTokens tokens) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Pulsing red dot
        _BatteryPulsingDot(),
        const SizedBox(width: 6),
        Text(
          'LOW POWER',
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w800,
            color: const Color(0xFFEF4444).withValues(alpha: 0.9),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(width: 8),
        // Battery Body
        Container(
          width: 38,
          height: 18,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            border: Border.all(
              color: _hovered ? const Color(0xFFEF4444) : const Color(0xFFEF4444).withValues(alpha: 0.6),
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Stack(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: 0.14,
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444),
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ),
              ),
              const Center(
                child: Text(
                  '14%',
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    height: 1.0,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 1),
        // Battery Cap
        Container(
          width: 2,
          height: 6,
          decoration: BoxDecoration(
            color: _hovered ? const Color(0xFFEF4444) : const Color(0xFFEF4444).withValues(alpha: 0.6),
            borderRadius: const BorderRadius.only(
              topRight: Radius.circular(1),
              bottomRight: Radius.circular(1),
            ),
          ),
        ),
      ],
    );
  }
}

// A stateful widget to handle battery dot pulsing animation
class _BatteryPulsingDot extends StatefulWidget {
  @override
  State<_BatteryPulsingDot> createState() => _BatteryPulsingDotState();
}

class _BatteryPulsingDotState extends State<_BatteryPulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _pulseCtrl,
      child: Container(
        width: 6,
        height: 6,
        decoration: const BoxDecoration(
          color: Color(0xFFEF4444),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────
// Pulsing CTA Button — always-on glow animation
// ──────────────────────────────────────────────

class _PulsingCtaButton extends StatefulWidget {
  final bool isDark;
  final bool hovered;
  final VoidCallback onTap;

  const _PulsingCtaButton({
    required this.isDark,
    required this.hovered,
    required this.onTap,
  });

  @override
  State<_PulsingCtaButton> createState() => _PulsingCtaButtonState();
}

class _PulsingCtaButtonState extends State<_PulsingCtaButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _glowCtrl;
  late Animation<double> _glowAnim;

  @override
  void initState() {
    super.initState();
    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    _glowAnim = Tween<double>(begin: 0.25, end: 0.65).animate(
      CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _glowCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final goldColor = widget.isDark ? const Color(0xFFF59E0B) : const Color(0xFFD97706);
    final goldDark  = widget.isDark ? const Color(0xFFD97706) : const Color(0xFFB45309);

    return AnimatedBuilder(
      animation: _glowAnim,
      builder: (context, child) {
        return AnimatedScale(
          scale: widget.hovered ? 1.02 : 1.0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutBack,
          child: GestureDetector(
            onTap: widget.onTap,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [goldColor, goldDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: goldColor.withValues(alpha: _glowAnim.value),
                    blurRadius: widget.hovered ? 20 : 12,
                    spreadRadius: widget.hovered ? 1 : 0,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      '☕',
                      style: TextStyle(fontSize: 16),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Support Fokus',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Icon(
                      Icons.bolt_rounded,
                      size: 16,
                      color: Colors.white,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ──────────────────────────────────────────────
// Contact Form
// ──────────────────────────────────────────────

class _ContactForm extends StatefulWidget {
  @override
  State<_ContactForm> createState() => _ContactFormState();
}

class _ContactFormState extends State<_ContactForm> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _submitting = false;

  static const _webhookUrl =
      'https://script.google.com/macros/s/AKfycbxrAQAmVV_Hd8HV2PaVlUcAY5CB1xWeHJjpK5OL919vZCtizlIjZ1U3Y1sX3H2mBtHj/exec';

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);

    try {
      final client = http.Client();
      try {
        final request = http.Request('POST', Uri.parse(_webhookUrl));
        request.headers['Content-Type'] = 'application/json';
        request.body = jsonEncode({
          'name': _nameCtrl.text.trim(),
          'email': _emailCtrl.text.trim(),
          'message': _messageCtrl.text.trim(),
        });

        final response = await client.send(request);
        final code = response.statusCode;

        if (!mounted) return;

        if (code == 200 || code == 201 || code == 302) {
          _nameCtrl.clear();
          _emailCtrl.clear();
          _messageCtrl.clear();
          if (mounted) _showSnack('Message sent successfully', Colors.green);
        } else {
          if (mounted) _showSnack('Server error ($code). Try again.', Colors.red);
        }
      } finally {
        client.close();
      }
    } catch (e) {
      if (mounted) {
        _showSnack('Could not send. Check your connection.', Colors.red);
        debugPrint('Contact form error: $e');
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showSnack(String msg, Color bg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      behavior: SnackBarBehavior.floating,
      backgroundColor: bg,
      duration: const Duration(seconds: 3),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final tokens = FocusOsTheme.of(context);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: tokens.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: tokens.borderSubtle, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.safeWithOpacity(0.08),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Contact Me',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: tokens.textPrimary,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Have a question or feedback? Drop me a message.',
                style: TextStyle(fontSize: 13, color: tokens.textMuted),
              ),
              const SizedBox(height: 24),
              Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: _nameCtrl,
                      style: TextStyle(color: tokens.textPrimary, fontSize: 14),
                      decoration: InputDecoration(
                        labelText: 'Name',
                        labelStyle: TextStyle(color: tokens.textSecondary, fontSize: 13),
                        floatingLabelStyle: TextStyle(color: tokens.accent, fontWeight: FontWeight.w500),
                        filled: true,
                        fillColor: tokens.surfaceAlt,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: tokens.borderSubtle),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: tokens.borderSubtle),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: tokens.accent, width: 1.5),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.redAccent),
                        ),
                        focusedErrorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
                        ),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _emailCtrl,
                      style: TextStyle(color: tokens.textPrimary, fontSize: 14),
                      decoration: InputDecoration(
                        labelText: 'Email',
                        labelStyle: TextStyle(color: tokens.textSecondary, fontSize: 13),
                        floatingLabelStyle: TextStyle(color: tokens.accent, fontWeight: FontWeight.w500),
                        filled: true,
                        fillColor: tokens.surfaceAlt,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: tokens.borderSubtle),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: tokens.borderSubtle),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: tokens.accent, width: 1.5),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.redAccent),
                        ),
                        focusedErrorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
                        ),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Required';
                        if (!v.contains('@')) return 'Invalid email';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _messageCtrl,
                      maxLines: 4,
                      style: TextStyle(color: tokens.textPrimary, fontSize: 14),
                      decoration: InputDecoration(
                        labelText: 'Message',
                        labelStyle: TextStyle(color: tokens.textSecondary, fontSize: 13),
                        floatingLabelStyle: TextStyle(color: tokens.accent, fontWeight: FontWeight.w500),
                        filled: true,
                        fillColor: tokens.surfaceAlt,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: tokens.borderSubtle),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: tokens.borderSubtle),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: tokens.accent, width: 1.5),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.redAccent),
                        ),
                        focusedErrorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
                        ),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 24),
                    PremiumButton(
                      onTap: _submitting ? null : _submit,
                      variant: PremiumButtonVariant.gradient,
                      width: double.infinity,
                      height: 48,
                      borderRadius: BorderRadius.circular(12),
                      enabled: !_submitting,
                      child: _submitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Send Message',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
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
    );
  }
}
