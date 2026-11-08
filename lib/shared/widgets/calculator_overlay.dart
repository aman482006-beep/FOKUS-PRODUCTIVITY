import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../motion.dart';

enum CalculatorMode { simple, scientific }

/// A single entry in the calculator history.
class _CalcHistoryEntry {
  final String expression;
  final String result;
  final DateTime timestamp;

  _CalcHistoryEntry({
    required this.expression,
    required this.result,
  }) : timestamp = DateTime.now();
}

class CalculatorOverlay extends ConsumerStatefulWidget {
  final VoidCallback onClose;

  const CalculatorOverlay({super.key, required this.onClose});

  @override
  ConsumerState<CalculatorOverlay> createState() => _CalculatorOverlayState();
}

class _CalculatorOverlayState extends ConsumerState<CalculatorOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;

  // Position for dragging
  double _x = 120.0;
  double _y = 80.0;
  bool _positionInitialized = false;

  // Active mode
  CalculatorMode _mode = CalculatorMode.simple;

  // Simple/Scientific state
  String _display = '0';
  double? _operand1;
  String? _operator;
  bool _resetOnNextInput = false;
  bool _isDegreeMode = true;
  double _memory = 0.0;

  // History state
  final List<_CalcHistoryEntry> _history = [];
  bool _showHistory = false;

  final FocusNode _keyboardFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );
    _scaleAnim = Tween<double>(begin: 0.94, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: PremiumCurves.springyOut),
    );
    _animController.forward();
    
    // Request focus for keyboard listener
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _keyboardFocusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    _keyboardFocusNode.dispose();
    super.dispose();
  }

  // ──────────────────────────────────────────────
  // Math & Calculation Logic (Simple/Scientific)
  // ──────────────────────────────────────────────

  void _onDigitPress(String digit) {
    setState(() {
      if (_display == '0' || _resetOnNextInput) {
        _display = digit;
        _resetOnNextInput = false;
      } else {
        // Prevent overly long numbers in display
        if (_display.length < 15) {
          _display += digit;
        }
      }
    });
  }

  void _onDecimalPress() {
    setState(() {
      if (_resetOnNextInput) {
        _display = '0.';
        _resetOnNextInput = false;
      } else if (!_display.contains('.')) {
        _display += '.';
      }
    });
  }

  void _onClearPress() {
    setState(() {
      _display = '0';
      _operand1 = null;
      _operator = null;
      _resetOnNextInput = false;
    });
  }

  void _clearHistory() {
    setState(() {
      _history.clear();
    });
  }

  void _addToHistory(String expression, String result) {
    _history.insert(0, _CalcHistoryEntry(expression: expression, result: result));
  }

  void _onToggleSignPress() {
    setState(() {
      double val = double.tryParse(_display) ?? 0.0;
      if (val != 0.0) {
        _display = _formatNumber(-val);
      }
    });
  }

  void _onPercentagePress() {
    setState(() {
      double val = double.tryParse(_display) ?? 0.0;
      _display = _formatNumber(val / 100.0);
    });
  }

  void _onOperatorPress(String op) {
    double currentVal = double.tryParse(_display) ?? 0.0;
    setState(() {
      if (_operator != null && !_resetOnNextInput) {
        final expr = '${_formatNumber(_operand1 ?? currentVal)} ${_operator} ${_formatNumber(currentVal)}';
        _executeCalculation(currentVal);
        _addToHistory(expr, _display);
      } else {
        _operand1 = currentVal;
      }
      _operator = op;
      _resetOnNextInput = true;
    });
  }

  void _onEqualsPress() {
    double currentVal = double.tryParse(_display) ?? 0.0;
    setState(() {
      if (_operator != null) {
        final expr = '${_formatNumber(_operand1 ?? 0)} ${_operator} ${_formatNumber(currentVal)}';
        _executeCalculation(currentVal);
        _addToHistory(expr, _display);
        _operator = null;
        _resetOnNextInput = true;
      }
    });
  }

  void _executeCalculation(double operand2) {
    if (_operand1 == null || _operator == null) return;
    double op1 = _operand1!;
    double result = 0.0;

    switch (_operator) {
      case '+':
        result = op1 + operand2;
        break;
      case '-':
        result = op1 - operand2;
        break;
      case '×':
        result = op1 * operand2;
        break;
      case '÷':
        result = operand2 != 0.0 ? op1 / operand2 : double.nan;
        break;
      case 'xʸ':
        result = math.pow(op1, operand2).toDouble();
        break;
      case 'ʸ√x':
        result = operand2 != 0.0 ? math.pow(op1, 1.0 / operand2).toDouble() : double.nan;
        break;
      default:
        return;
    }

    _display = _formatNumber(result);
    _operand1 = result;
  }

  void _executeScientificFunc(String func) {
    double val = double.tryParse(_display) ?? 0.0;
    double result = 0.0;

    switch (func) {
      case 'x²':
        result = val * val;
        break;
      case 'x³':
        result = val * val * val;
        break;
      case 'eˣ':
        result = math.exp(val);
        break;
      case '10ˣ':
        result = math.pow(10, val).toDouble();
        break;
      case '1/x':
        result = val != 0.0 ? 1.0 / val : double.nan;
        break;
      case '√x':
        result = val >= 0.0 ? math.sqrt(val) : double.nan;
        break;
      case '³√x':
        result = val >= 0.0 ? math.pow(val, 1.0 / 3.0).toDouble() : -math.pow(-val, 1.0 / 3.0).toDouble();
        break;
      case 'ln':
        result = val > 0.0 ? math.log(val) : double.nan;
        break;
      case 'log':
        result = val > 0.0 ? math.log(val) / math.ln10 : double.nan;
        break;
      case 'x!':
        result = _factorial(val);
        break;
      case 'sin':
        result = math.sin(_isDegreeMode ? val * math.pi / 180.0 : val);
        break;
      case 'cos':
        result = math.cos(_isDegreeMode ? val * math.pi / 180.0 : val);
        break;
      case 'tan':
        result = math.tan(_isDegreeMode ? val * math.pi / 180.0 : val);
        break;
      case 'sinh':
        result = (math.exp(val) - math.exp(-val)) / 2.0;
        break;
      case 'cosh':
        result = (math.exp(val) + math.exp(-val)) / 2.0;
        break;
      case 'tanh':
        double ev = math.exp(val);
        double env = math.exp(-val);
        result = (ev - env) / (ev + env);
        break;
      case 'π':
        result = math.pi;
        break;
      case 'e':
        result = math.e;
        break;
      case 'Rand':
        result = math.Random().nextDouble();
        break;
      default:
        return;
    }

    setState(() {
      _display = _formatNumber(result);
      _resetOnNextInput = true;
    });
    // Record scientific function results in history
    if (!func.contains('Rand')) {
      _addToHistory('$func(${_formatNumber(val)})', _display);
    }
  }

  void _executeMemoryFunc(String action) {
    double val = double.tryParse(_display) ?? 0.0;
    setState(() {
      switch (action) {
        case 'mc':
          _memory = 0.0;
          break;
        case 'mr':
          _display = _formatNumber(_memory);
          _resetOnNextInput = true;
          break;
        case 'm+':
          _memory += val;
          _resetOnNextInput = true;
          break;
        case 'm-':
          _memory -= val;
          _resetOnNextInput = true;
          break;
      }
    });
  }

  double _factorial(double n) {
    if (n < 0 || n != n.toInt().toDouble()) return double.nan;
    int val = n.toInt();
    if (val > 170) return double.infinity;
    double result = 1.0;
    for (int i = 2; i <= val; i++) {
      result *= i;
    }
    return result;
  }

  String _formatNumber(double val) {
    if (val.isNaN) return 'Error';
    if (val.isInfinite) return 'Error';
    if (val == 0.0) return '0';

    // If it's an integer
    if (val == val.toInt().toDouble()) {
      return val.toInt().toString();
    }

    String s = val.toString();
    if (s.length > 12) {
      if (val.abs() > 1e10 || val.abs() < 1e-6) {
        return val.toStringAsExponential(5);
      }
      String formatted = val.toStringAsFixed(8);
      while (formatted.endsWith('0')) {
        formatted = formatted.substring(0, formatted.length - 1);
      }
      if (formatted.endsWith('.')) {
        formatted = formatted.substring(0, formatted.length - 1);
      }
      return formatted;
    }
    return s;
  }



  // ──────────────────────────────────────────────
  // Keyboard Input Handler
  // ──────────────────────────────────────────────

  KeyEventResult _handleKeyboard(KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final key = event.logicalKey;
    final text = event.character;

    // Backspace: clear or remove last character
    if (key == LogicalKeyboardKey.backspace) {
      setState(() {
        if (_display.isNotEmpty && _display != '0') {
          _display = _display.substring(0, _display.length - 1);
          if (_display.isEmpty || _display == '-') _display = '0';
        }
      });
      return KeyEventResult.handled;
    }

    // Escape: close calculator
    if (key == LogicalKeyboardKey.escape) {
      _close();
      return KeyEventResult.handled;
    }

    // Enter / Numpad Enter: Equals
    if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter) {
      _onEqualsPress();
      return KeyEventResult.handled;
    }

    // Number keys and arithmetic operators
    if (text != null && text.isNotEmpty) {
      if (RegExp(r'^[0-9]$').hasMatch(text)) {
        _onDigitPress(text);
        return KeyEventResult.handled;
      }
      if (text == '.') {
        _onDecimalPress();
        return KeyEventResult.handled;
      }
      if (text == '+') {
        _onOperatorPress('+');
        return KeyEventResult.handled;
      }
      if (text == '-') {
        _onOperatorPress('-');
        return KeyEventResult.handled;
      }
      if (text == '*' || text == 'x' || text == 'X') {
        _onOperatorPress('×');
        return KeyEventResult.handled;
      }
      if (text == '/') {
        _onOperatorPress('÷');
        return KeyEventResult.handled;
      }
      if (text == '%' || text == 'p' || text == 'P') {
        _onPercentagePress();
        return KeyEventResult.handled;
      }
      if (text == 'c' || text == 'C') {
        _onClearPress();
        return KeyEventResult.handled;
      }
    }

    return KeyEventResult.ignored;
  }

  // Close calculator animation
  Future<void> _close() async {
    await _animController.reverse();
    widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    // Dynamically calculate default position to center the calculator if not set
    if (!_positionInitialized) {
      _x = (size.width - _getWidth()) / 2;
      _y = (size.height - _getHeight()) / 2;
      _positionInitialized = true;
    }

    // Keep within boundaries
    _x = _x.clamp(0.0, size.width - 50);
    _y = _y.clamp(0.0, size.height - 50);

    return Positioned(
      left: _x,
      top: _y,
      child: FadeTransition(
        opacity: _fadeAnim,
        child: ScaleTransition(
          scale: _scaleAnim,
          child: Material(
            color: Colors.transparent,
            child: Focus(
              focusNode: _keyboardFocusNode,
              autofocus: true,
              onKeyEvent: (node, event) => _handleKeyboard(event),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: PremiumCurves.easeOutCubic,
                width: _getWidth(),
                height: _getHeight(),
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1C1E),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 36,
                      offset: const Offset(0, 14),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // ──────────────────────────────────────────────
                    // Title Bar (Draggable)
                    // ──────────────────────────────────────────────
                    GestureDetector(
                      onPanUpdate: (details) {
                        setState(() {
                          _x += details.delta.dx;
                          _y += details.delta.dy;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: const BoxDecoration(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                        ),
                        child: Row(
                          children: [
                            // Traffic lights macOS style controls
                            Row(
                              children: [
                                // Red Close
                                GestureDetector(
                                  onTap: _close,
                                  child: Container(
                                    width: 13,
                                    height: 13,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFFF5F56),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Center(
                                      child: Icon(Icons.close, size: 8, color: Color(0x4D000000)),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 9),
                                // Yellow Minimize
                                GestureDetector(
                                  onTap: _close,
                                  child: Container(
                                    width: 13,
                                    height: 13,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFFFBD2E),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 9),
                                // Green Toggle Mode
                                GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      // Cycle modes
                                      _mode = CalculatorMode.values[(_mode.index + 1) % CalculatorMode.values.length];
                                    });
                                  },
                                  child: Container(
                                    width: 13,
                                    height: 13,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF27C93F),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const Spacer(),
                            // History toggle button
                            GestureDetector(
                              onTap: () => setState(() => _showHistory = !_showHistory),
                              child: Container(
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                  color: _showHistory
                                      ? Colors.white.withValues(alpha: 0.15)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Icon(
                                  Icons.history_rounded,
                                  size: 14,
                                  color: _showHistory
                                      ? Colors.white
                                      : Colors.white.withValues(alpha: 0.5),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Mode label
                            Padding(
                              padding: const EdgeInsets.only(right: 4),
                              child: Text(
                                _mode == CalculatorMode.simple ? 'Basic' : 'Sci',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white.withValues(alpha: 0.5),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // ──────────────────────────────────────────────
                    // Display Area
                    // ──────────────────────────────────────────────
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        alignment: Alignment.bottomRight,
                        height: 64,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (_operand1 != null && _operator != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 2),
                                child: Text(
                                  '${_formatNumber(_operand1!)} $_operator',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w400,
                                    color: Colors.white.withValues(alpha: 0.5),
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerRight,
                              child: Text(
                                _display,
                                style: TextStyle(
                                  fontSize: 40,
                                  fontWeight: FontWeight.w300,
                                  color: Colors.white,
                                  fontFamily: 'SF Mono',
                                  fontFamilyFallback: ['Monaco', 'Cascadia Code', 'monospace'],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // ──────────────────────────────────────────────
                    // Keyboard Grid Area
                    // ──────────────────────────────────────────────
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
                        child: _buildCalculatorInterface(),
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

  double _getWidth() {
    switch (_mode) {
      case CalculatorMode.simple:
        return 258.0;
      case CalculatorMode.scientific:
        return 510.0;
    }
  }

  double _getHeight() {
    double base;
    switch (_mode) {
      case CalculatorMode.simple:
        base = 410.0;
      case CalculatorMode.scientific:
        base = 410.0;
    }
    if (_showHistory) {
      // Expand height to accommodate history panel (max ~300px of list + header + button)
      final entryCount = _history.length;
      final listHeight = (entryCount * 48.0).clamp(120.0, 280.0);
      return base + listHeight + 60.0;
    }
    return base;
  }



  Widget _buildCalculatorInterface() {
    if (_showHistory) {
      return _buildHistoryPanel();
    }
    switch (_mode) {
      case CalculatorMode.simple:
        return _buildSimpleKeys();
      case CalculatorMode.scientific:
        return Row(
          children: [
            Expanded(child: _buildScientificPanel()),
            const SizedBox(width: 8),
            SizedBox(width: 200, child: _buildSimpleKeys()),
          ],
        );
    }
  }

  // ──────────────────────────────────────────────
  // Basic Keyboard Grid
  // ──────────────────────────────────────────────
  Widget _buildSimpleKeys() {
    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              _buildBtn(text: _display == '0' ? 'AC' : 'C', color: const Color(0xFFA5A5A5), textColor: Colors.black, onTap: _onClearPress),
              _buildBtn(text: '+/-', color: const Color(0xFFA5A5A5), textColor: Colors.black, onTap: _onToggleSignPress),
              _buildBtn(text: '%', color: const Color(0xFFA5A5A5), textColor: Colors.black, onTap: _onPercentagePress),
              _buildBtn(text: '÷', color: const Color(0xFFFF9F0A), onTap: () => _onOperatorPress('÷'), isOperator: true, opSymbol: '÷'),
            ],
          ),
        ),
        const SizedBox(height: 3),
        Expanded(
          child: Row(
            children: [
              _buildBtn(text: '7', onTap: () => _onDigitPress('7')),
              _buildBtn(text: '8', onTap: () => _onDigitPress('8')),
              _buildBtn(text: '9', onTap: () => _onDigitPress('9')),
              _buildBtn(text: '×', color: const Color(0xFFFF9F0A), onTap: () => _onOperatorPress('×'), isOperator: true, opSymbol: '×'),
            ],
          ),
        ),
        const SizedBox(height: 3),
        Expanded(
          child: Row(
            children: [
              _buildBtn(text: '4', onTap: () => _onDigitPress('4')),
              _buildBtn(text: '5', onTap: () => _onDigitPress('5')),
              _buildBtn(text: '6', onTap: () => _onDigitPress('6')),
              _buildBtn(text: '–', color: const Color(0xFFFF9F0A), onTap: () => _onOperatorPress('-'), isOperator: true, opSymbol: '-'),
            ],
          ),
        ),
        const SizedBox(height: 3),
        Expanded(
          child: Row(
            children: [
              _buildBtn(text: '1', onTap: () => _onDigitPress('1')),
              _buildBtn(text: '2', onTap: () => _onDigitPress('2')),
              _buildBtn(text: '3', onTap: () => _onDigitPress('3')),
              _buildBtn(text: '+', color: const Color(0xFFFF9F0A), onTap: () => _onOperatorPress('+'), isOperator: true, opSymbol: '+'),
            ],
          ),
        ),
        const SizedBox(height: 3),
        Expanded(
          child: Row(
            children: [
              _buildBtn(text: '0', flex: 2, onTap: () => _onDigitPress('0')),
              _buildBtn(text: '.', onTap: _onDecimalPress),
              _buildBtn(text: '=', color: const Color(0xFFFF9F0A), onTap: _onEqualsPress),
            ],
          ),
        ),
      ],
    );
  }

  // ──────────────────────────────────────────────
  // Scientific Keyboard Panel
  // ──────────────────────────────────────────────
  Widget _buildScientificPanel() {
    return Column(
      children: [
        // Memory / Constants row
        Expanded(
          child: Row(
            children: [
              _buildSciBtn('mc', onTap: () => _executeMemoryFunc('mc')),
              _buildSciBtn('mr', onTap: () => _executeMemoryFunc('mr')),
              _buildSciBtn('m+', onTap: () => _executeMemoryFunc('m+')),
              _buildSciBtn('m-', onTap: () => _executeMemoryFunc('m-')),
              _buildSciBtn('π', onTap: () => _executeScientificFunc('π')),
            ],
          ),
        ),
        const SizedBox(height: 3),
        // Pow / Trig row 1
        Expanded(
          child: Row(
            children: [
              _buildSciBtn('x²', onTap: () => _executeScientificFunc('x²')),
              _buildSciBtn('x³', onTap: () => _executeScientificFunc('x³')),
              _buildSciBtn('xʸ', onTap: () => _onOperatorPress('xʸ')),
              _buildSciBtn('eˣ', onTap: () => _executeScientificFunc('eˣ')),
              _buildSciBtn('10ˣ', onTap: () => _executeScientificFunc('10ˣ')),
            ],
          ),
        ),
        const SizedBox(height: 3),
        // Roots / Log row
        Expanded(
          child: Row(
            children: [
              _buildSciBtn('1/x', onTap: () => _executeScientificFunc('1/x')),
              _buildSciBtn('√x', onTap: () => _executeScientificFunc('√x')),
              _buildSciBtn('³√x', onTap: () => _executeScientificFunc('³√x')),
              _buildSciBtn('ʸ√x', onTap: () => _onOperatorPress('ʸ√x')),
              _buildSciBtn('ln', onTap: () => _executeScientificFunc('ln')),
            ],
          ),
        ),
        const SizedBox(height: 3),
        // Trig row 2
        Expanded(
          child: Row(
            children: [
              _buildSciBtn('log', onTap: () => _executeScientificFunc('log')),
              _buildSciBtn('x!', onTap: () => _executeScientificFunc('x!')),
              _buildSciBtn('sin', onTap: () => _executeScientificFunc('sin')),
              _buildSciBtn('cos', onTap: () => _executeScientificFunc('cos')),
              _buildSciBtn('tan', onTap: () => _executeScientificFunc('tan')),
            ],
          ),
        ),
        const SizedBox(height: 3),
        // Mode toggle row
        Expanded(
          child: Row(
            children: [
              _buildSciBtn(
                _isDegreeMode ? 'Deg' : 'Rad',
                onTap: () => setState(() => _isDegreeMode = !_isDegreeMode),
                color: const Color(0xFF424244),
                textColor: Colors.white,
              ),
              _buildSciBtn('e', onTap: () => _executeScientificFunc('e')),
              _buildSciBtn('sinh', onTap: () => _executeScientificFunc('sinh')),
              _buildSciBtn('cosh', onTap: () => _executeScientificFunc('cosh')),
              _buildSciBtn('tanh', onTap: () => _executeScientificFunc('tanh')),
            ],
          ),
        ),
      ],
    );
  }



  // ──────────────────────────────────────────────
  // History Panel
  // ──────────────────────────────────────────────

  Widget _buildHistoryPanel() {
    return Column(
      children: [
        // ── History header ──
        Row(
          children: [
            Icon(Icons.history_rounded, size: 12, color: Colors.white.withValues(alpha: 0.5)),
            const SizedBox(width: 6),
            Text(
              'Paper Tape',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.5),
                letterSpacing: 0.5,
              ),
            ),
            const Spacer(),
            if (_history.isNotEmpty)
              GestureDetector(
                onTap: _clearHistory,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Clear',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),

        // ── History list ──
        Expanded(
          child: _history.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.calculate_outlined,
                        size: 28,
                        color: Colors.white.withValues(alpha: 0.15),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'No calculations yet',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _history.length,
                  padding: EdgeInsets.zero,
                  itemBuilder: (context, index) {
                    final entry = _history[index];
                    return _buildHistoryRow(entry);
                  },
                ),
        ),

        // ── Back to keypad button ──
        const SizedBox(height: 4),
        GestureDetector(
          onTap: () => setState(() => _showHistory = false),
          child: Container(
            height: 32,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Center(
              child: Text(
                'Back to Keypad',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withValues(alpha: 0.5),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryRow(_CalcHistoryEntry entry) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      margin: const EdgeInsets.only(bottom: 2),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  entry.expression,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.5),
                    fontFamily: 'SF Mono',
                    fontFamilyFallback: ['Monaco', 'Cascadia Code', 'monospace'],
                  ),
                  textAlign: TextAlign.right,
                ),
                const SizedBox(height: 2),
                Text(
                  '= ${entry.result}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    fontFamily: 'SF Mono',
                    fontFamilyFallback: ['Monaco', 'Cascadia Code', 'monospace'],
                  ),
                  textAlign: TextAlign.right,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────
  // UI Builder Helpers (Buttons)
  // ──────────────────────────────────────────────

  Widget _buildBtn({
    required String text,
    Color color = const Color(0xFF333333),
    Color textColor = Colors.white,
    double flex = 1,
    required VoidCallback onTap,
    bool isOperator = false,
    String? opSymbol,
  }) {
    // Fixed macOS Calculator color palette — never theme-dependent
    Color btnColor;
    Color btnTextColor;

    if (isOperator || color == const Color(0xFFFF9F0A)) {
      btnColor = const Color(0xFFFF9F0A);
      btnTextColor = Colors.white;
    } else if (color == const Color(0xFFA5A5A5)) {
      btnColor = const Color(0xFFA5A5A5);
      btnTextColor = Colors.black;
    } else {
      btnColor = const Color(0xFF333333);
      btnTextColor = Colors.white;
    }

    final activeOperator = isOperator && _operator == opSymbol && _resetOnNextInput;

    return Expanded(
      flex: flex.toInt(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              onTap();
              _keyboardFocusNode.requestFocus();
            },
            borderRadius: BorderRadius.circular(50),
            child: Container(
              height: 46,
              decoration: BoxDecoration(
                shape: flex == 1 ? BoxShape.circle : BoxShape.rectangle,
                borderRadius: flex > 1 ? BorderRadius.circular(23) : null,
                color: activeOperator ? Colors.white : btnColor,
              ),
              child: Center(
                child: Text(
                  text,
                  style: TextStyle(
                    color: activeOperator ? const Color(0xFFFF9F0A) : btnTextColor,
                    fontSize: 20,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSciBtn(
    String text, {
    required VoidCallback onTap,
    Color color = const Color(0xFF212124),
    Color textColor = Colors.white,
  }) {
    // Fixed macOS scientific palette
    Color btnColor;
    Color btnTextColor;
    
    if (color == const Color(0xFF424244)) {
      btnColor = const Color(0xFF424244);
      btnTextColor = Colors.white;
    } else {
      btnColor = const Color(0xFF505052);
      btnTextColor = Colors.white.withValues(alpha: 0.85);
    }

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2.5),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              onTap();
              _keyboardFocusNode.requestFocus();
            },
            borderRadius: BorderRadius.circular(5),
            child: Container(
              height: 34,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(5),
                color: btnColor,
              ),
              child: Center(
                child: Text(
                  text,
                  style: TextStyle(
                    color: btnTextColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
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
