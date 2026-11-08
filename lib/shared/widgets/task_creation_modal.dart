import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../motion.dart';
import '../theme.dart';
import 'premium_button.dart';
import '../../core/providers.dart';

/// Task creation colors — a curated palette of premium accent colors.
const taskColors = [
  '#6366F1', // Indigo
  '#8B5CF6', // Violet
  '#EC4899', // Pink
  '#EF4444', // Red
  '#F59E0B', // Amber
  '#22C55E', // Green
  '#14B8A6', // Teal
  '#06B6D4', // Cyan
  '#3B82F6', // Blue
  '#0EA5E9', // Sky
];

/// Premium task creation modal with background blur, staggered entrance,
/// animated focus state, enhanced color picker, and keyboard-first UX.
class TaskCreationModal extends ConsumerStatefulWidget {
  final VoidCallback onClose;

  const TaskCreationModal({super.key, required this.onClose});

  @override
  ConsumerState<TaskCreationModal> createState() => _TaskCreationModalState();
}

class _TaskCreationModalState extends ConsumerState<TaskCreationModal>
    with SingleTickerProviderStateMixin {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;
  late Animation<Offset> _slideAnim;
  late Animation<double> _contentFadeAnim;
  String? _selectedColor;
  bool _valid = false;
  bool _focused = false;
  String _selectedPriority = 'medium';
  DateTime? _selectedDueDate;
  double _estimatedHours = 0.0;

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
    _scaleAnim = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: PremiumCurves.springyOut),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animController, curve: PremiumCurves.easeOutCubic),
    );
    _contentFadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.15, 0.35, curve: PremiumCurves.easeOutCubic),
      ),
    );
    _animController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _focusNode.canRequestFocus) {
        _focusNode.requestFocus();
      }
    });

    _focusNode.addListener(() {
      if (mounted) {
        setState(() => _focused = _focusNode.hasFocus);
      }
    });

    _controller.addListener(() {
      if (!mounted) return;
      final valid = _controller.text.trim().isNotEmpty;
      if (valid != _valid) {
        setState(() => _valid = valid);
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

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    ref.read(tasksProvider.notifier).addTask(
          text,
          color: _selectedColor,
          priority: _selectedPriority,
          dueDate: _selectedDueDate,
          estimatedMinutes: (_estimatedHours * 60).toInt(),
        );
    _controller.clear();
    _close();
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
          color: Colors.black.safeWithOpacity(0.5),
          child: Center(
            child: Material(
              color: Colors.transparent,
              child: GestureDetector(
                onTap: () {},
                child: ScaleTransition(
                  scale: _scaleAnim,
                  child: SlideTransition(
                    position: _slideAnim,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: Container(
                      padding: const EdgeInsets.all(24),
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
                      child: FadeTransition(
                        opacity: _contentFadeAnim,
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                            // ── Header with staggered slide-up ──
                            _StaggeredFadeSlide(
                              index: 0,
                              parentController: _animController,
                              child: Row(
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: tokens.accent.safeWithOpacity(0.12),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(Icons.add_task_rounded,
                                        size: 18, color: tokens.accent),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'New Task',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: tokens.textPrimary,
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                  const Spacer(),
                                  PremiumHoverEffect(
                                    hoverScale: 1.08,
                                    pressScale: 0.92,
                                    onTap: _close,
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: tokens.borderSubtle,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Icon(Icons.close,
                                          size: 14, color: tokens.textMuted),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),

                            // ── Task name input with animated focus state ──
                            _StaggeredFadeSlide(
                              index: 1,
                              parentController: _animController,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  AnimatedContainer(
                                    duration: PremiumDurations.hover,
                                    curve: PremiumCurves.easeOutCubic,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: _focused
                                            ? tokens.accent.safeWithOpacity(0.5)
                                            : Colors.transparent,
                                      ),
                                      boxShadow: _focused
                                          ? [
                                              BoxShadow(
                                                color: tokens.accent
                                                    .safeWithOpacity(0.08),
                                                blurRadius: 12,
                                                offset: const Offset(0, 2),
                                              ),
                                            ]
                                          : null,
                                    ),
                                    child: TextField(
                                      controller: _controller,
                                      focusNode: _focusNode,
                                      autofocus: true,
                                      style: TextStyle(
                                        color: tokens.textPrimary,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w400,
                                      ),
                                      decoration: InputDecoration(
                                        hintText: 'What are you fokusing on?',
                                        hintStyle: TextStyle(
                                          color: tokens.textMuted,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w400,
                                        ),
                                        filled: true,
                                        fillColor: tokens.background,
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(10),
                                          borderSide: BorderSide.none,
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(10),
                                          borderSide: BorderSide.none,
                                        ),
                                        contentPadding: const EdgeInsets.symmetric(
                                            horizontal: 14, vertical: 12),
                                        isDense: true,
                                      ),
                                      onSubmitted: (_) => _submit(),
                                      textInputAction: TextInputAction.done,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),

                            // ── Color picker with enhanced interaction ──
                            _StaggeredFadeSlide(
                              index: 2,
                              parentController: _animController,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        'Task color',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: tokens.textSecondary,
                                        ),
                                      ),
                                      if (_selectedColor != null) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          width: 10,
                                          height: 10,
                                          decoration: BoxDecoration(
                                            color: Color(int.parse(
                                                _selectedColor!.replaceFirst('#', '0xFF'))),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: taskColors.map((hex) {
                                      final colorVal =
                                          int.parse(hex.replaceFirst('#', '0xFF'));
                                      final isSelected = _selectedColor == hex;
                                      return _PremiumColorDot(
                                        color: Color(colorVal),
                                        isSelected: isSelected,
                                        onTap: () {
                                          if (mounted) {
                                            setState(() => _selectedColor = hex);
                                          }
                                        },
                                      );
                                    }).toList(),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            _StaggeredFadeSlide(
                              index: 3,
                              parentController: _animController,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Priority',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: tokens.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: ['low', 'medium', 'high'].map((p) {
                                      final isSel = _selectedPriority == p;
                                      final color = p == 'high'
                                          ? const Color(0xFFEF4444)
                                          : p == 'medium'
                                              ? const Color(0xFFF59E0B)
                                              : const Color(0xFF3B82F6);
                                      return Expanded(
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 2),
                                          child: InkWell(
                                            onTap: () => setState(() => _selectedPriority = p),
                                            borderRadius: BorderRadius.circular(6),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(vertical: 8),
                                              decoration: BoxDecoration(                                                    color: isSel
                                                    ? color.withValues(alpha: 0.12)
                                                    : tokens.background,
                                                borderRadius: BorderRadius.circular(6),
                                                border: Border.all(
                                                  color: isSel ? color : tokens.borderSubtle,
                                                ),
                                              ),
                                              child: Center(
                                                child: Text(
                                                  p.toUpperCase(),
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                    color: isSel ? color : tokens.textMuted,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            _StaggeredFadeSlide(
                              index: 4,
                              parentController: _animController,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Due Date',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: tokens.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  InkWell(
                                    onTap: () async {
                                      final picked = await showDatePicker(
                                        context: context,
                                        initialDate: _selectedDueDate ?? DateTime.now(),
                                        firstDate: DateTime.now().subtract(const Duration(days: 365)),
                                        lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                                        builder: (context, child) {
                                          return Theme(
                                            data: Theme.of(context).copyWith(
                                              colorScheme: ColorScheme.dark(
                                                primary: tokens.accent,
                                                onPrimary: Colors.white,
                                                surface: tokens.surface,
                                                onSurface: tokens.textPrimary,
                                              ),
                                              dialogTheme: DialogThemeData(backgroundColor: tokens.background),
                                            ),
                                            child: child!,
                                          );
                                        },
                                      );
                                      if (picked != null) {
                                        setState(() => _selectedDueDate = picked);
                                      }
                                    },
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: tokens.background,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: tokens.borderSubtle),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(Icons.calendar_today_outlined, size: 14, color: tokens.textMuted),
                                          const SizedBox(width: 8),
                                          Text(
                                            _selectedDueDate == null
                                                ? 'No due date'
                                                : '${_selectedDueDate!.day}/${_selectedDueDate!.month}/${_selectedDueDate!.year}',
                                            style: TextStyle(fontSize: 13, color: tokens.textPrimary),
                                          ),
                                          const Spacer(),
                                          if (_selectedDueDate != null)
                                            IconButton(
                                              icon: const Icon(Icons.clear, size: 14),
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints(),
                                              onPressed: () => setState(() => _selectedDueDate = null),
                                              color: tokens.textMuted,
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            _StaggeredFadeSlide(
                              index: 5,
                              parentController: _animController,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Estimated Fokus Time',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: tokens.textSecondary,
                                        ),
                                      ),
                                      Text(
                                        _estimatedHours == 0.0
                                            ? 'None'
                                            : '${_estimatedHours.toStringAsFixed(1)} hours',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: tokens.accent,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Slider(
                                    value: _estimatedHours,
                                    min: 0.0,
                                    max: 12.0,
                                    divisions: 24,
                                    activeColor: tokens.accent,
                                    inactiveColor: tokens.borderSubtle,
                                    onChanged: (val) {
                                      setState(() {
                                        _estimatedHours = val;
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),

                            // ── Actions with keyboard hint ──
                            _StaggeredFadeSlide(
                              index: 6,
                              parentController: _animController,
                              child: Row(
                                children: [
                                  PremiumButton(
                                    onTap: _close,
                                    variant: PremiumButtonVariant.ghost,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 10),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Text('Cancel'),
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 4, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: tokens.borderSubtle,
                                            borderRadius: BorderRadius.circular(3),
                                          ),
                                          child: Text(
                                            'Esc',
                                            style: TextStyle(
                                              fontSize: 9,
                                              color: tokens.textMuted,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Spacer(),
                                  PremiumButton(
                                    onTap: _valid ? _submit : null,
                                    variant: PremiumButtonVariant.gradient,
                                    enabled: _valid,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 20, vertical: 10),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          'Create Task',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Icon(Icons.arrow_forward_rounded,
                                            size: 14, color: Colors.white),
                                      ],
                                    ),
                                  ),
                                ],
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
      ),
    ),
  );
}
}

/// A premium color dot with hover scale, press feedback, and selected indicator.
class _PremiumColorDot extends StatefulWidget {
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _PremiumColorDot({
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_PremiumColorDot> createState() => _PremiumColorDotState();
}

class _PremiumColorDotState extends State<_PremiumColorDot> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) {
        if (mounted) setState(() => _hovered = true);
      },
      onExit: (_) {
        if (mounted) setState(() => _hovered = false);
      },
      child: GestureDetector(
        onTapDown: (_) {
          if (mounted) setState(() => _pressed = true);
        },
        onTapUp: (_) {
          if (mounted) setState(() => _pressed = false);
        },
        onTapCancel: () {
          if (mounted) setState(() => _pressed = false);
        },
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _pressed
              ? 0.88
              : _hovered
                  ? 1.18
                  : 1.0,
          duration: _pressed
              ? const Duration(milliseconds: 70)
              : const Duration(milliseconds: 150),
          curve: _pressed
              ? PremiumCurves.pressCurve
              : PremiumCurves.releaseCurve,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: PremiumCurves.springyOut,
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: widget.color,
              borderRadius:
                  BorderRadius.circular(widget.isSelected ? 10 : 8),
              border: widget.isSelected
                  ? Border.all(
                      color: Colors.white.safeWithOpacity(0.5),
                      width: 2,
                    )
                  : null,
              boxShadow: widget.isSelected
                  ? [
                      BoxShadow(
                        color: widget.color.safeWithOpacity(0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : _hovered
                      ? [
                          BoxShadow(
                            color: widget.color.safeWithOpacity(0.25),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
            ),
            child: widget.isSelected
                ? const Center(
                    child: Icon(Icons.check, size: 16, color: Colors.white),
                  )
                : null,
          ),
        ),
      ),
    );
  }
}

/// Staggered fade+slide child that animates based on a parent controller.
class _StaggeredFadeSlide extends StatelessWidget {
  final int index;
  final AnimationController parentController;
  final Widget child;

  const _StaggeredFadeSlide({
    required this.index,
    required this.parentController,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final start = 0.1 + index * 0.08;
    final fadeAnim = CurvedAnimation(
      parent: parentController,
      curve: Interval(start, (start + 0.15).clamp(0.0, 1.0),
          curve: PremiumCurves.easeOutCubic),
    );
    final slideAnim = Tween<Offset>(
      begin: Offset(0, 0.02 + index * 0.01),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: parentController,
      curve: Interval(start, (start + 0.12).clamp(0.0, 1.0),
          curve: PremiumCurves.easeOutCubic),
    ));

    return FadeTransition(
      opacity: fadeAnim,
      child: SlideTransition(position: slideAnim, child: child),
    );
  }
}
