import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../shared/theme.dart';
import '../../shared/motion.dart' as motion;

class ColorPickerPage extends StatefulWidget {
  final VoidCallback onBack;

  const ColorPickerPage({super.key, required this.onBack});

  @override
  State<ColorPickerPage> createState() => _ColorPickerPageState();
}

class _ColorPickerPageState extends State<ColorPickerPage> {
  Color _currentColor = const Color(0xFF6366F1); // Indigo default
  List<Color> _savedPalette = [];
  List<Color> _history = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Load Palette
    final rawPalette = prefs.getStringList('color_palette');
    if (rawPalette != null) {
      setState(() {
        _savedPalette = rawPalette.map((hex) => Color(int.parse(hex))).toList();
      });
    } else {
      _savedPalette = [
        const Color(0xFFEF4444), // Red
        const Color(0xFFF59E0B), // Yellow
        const Color(0xFF10B981), // Green
        const Color(0xFF3B82F6), // Blue
        const Color(0xFF6366F1), // Indigo
      ];
    }

    // Load History
    final rawHistory = prefs.getStringList('color_history');
    if (rawHistory != null) {
      setState(() {
        _history = rawHistory.map((hex) => Color(int.parse(hex))).toList();
      });
    } else {
      _history = [const Color(0xFF6366F1)];
    }
  }

  Future<void> _savePalette() async {
    final prefs = await SharedPreferences.getInstance();
    final hexStrings = _savedPalette.map((c) => '0x${c.toARGB32().toRadixString(16)}').toList();
    await prefs.setStringList('color_palette', hexStrings);
  }

  Future<void> _saveHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final hexStrings = _history.map((c) => '0x${c.toARGB32().toRadixString(16)}').toList();
    await prefs.setStringList('color_history', hexStrings);
  }

  void _updateColor(Color color) {
    setState(() {
      _currentColor = color;
      if (!_history.contains(color)) {
        _history.insert(0, color);
        if (_history.length > 12) {
          _history.removeLast();
        }
        _saveHistory();
      }
    });
  }

  void _addToPalette(Color color) {
    if (!_savedPalette.contains(color)) {
      setState(() {
        _savedPalette.add(color);
        _savePalette();
      });
    }
  }

  void _removeFromPalette(Color color) {
    setState(() {
      _savedPalette.remove(color);
      _savePalette();
    });
  }

  String _toHexStr(Color c) {
    return '#${c.toARGB32().toRadixString(16).substring(2).toUpperCase()}';
  }

  String _toRgbStr(Color c) {
    return 'RGB(${(c.r * 255).round()}, ${(c.g * 255).round()}, ${(c.b * 255).round()})';
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copied: $text'),
        backgroundColor: FocusOsTheme.of(context).surfaceAlt,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = FocusOsTheme.of(context);

    // Custom gradient wheel or pad values
    final sliderR = _currentColor.r * 255;
    final sliderG = _currentColor.g * 255;
    final sliderB = _currentColor.b * 255;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: motion.PremiumEnterTransition(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                GestureDetector(
                  onTap: widget.onBack,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: tokens.borderSubtle.withValues(alpha: 0.5),
                    ),
                    child: Icon(Icons.arrow_back, size: 16, color: tokens.textPrimary),
                  ),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Color Picker & Palettes',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: tokens.textPrimary),
                    ),
                    Text(
                      'Create, customize, and save harmonious palettes locally.',
                      style: TextStyle(fontSize: 12, color: tokens.textSecondary),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),

            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left panel: Color Preview, Adjust Channels, Suggestions
                  Expanded(
                    flex: 7,
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Color Preview Card (With embedded copyable HEX & RGB values in a glass bar)
                            Container(
                              height: 160,
                              decoration: BoxDecoration(
                                color: _currentColor,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: tokens.borderSubtle),
                                boxShadow: [
                                  BoxShadow(
                                    color: _currentColor.withValues(alpha: 0.25),
                                    blurRadius: 20,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  ClipRRect(
                                    borderRadius: const BorderRadius.only(
                                      bottomLeft: Radius.circular(16),
                                      bottomRight: Radius.circular(16),
                                    ),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                      color: Colors.black.withValues(alpha: 0.55),
                                      child: Row(
                                        children: [
                                          // HEX
                                          Expanded(
                                            child: Row(
                                              children: [
                                                Text('HEX', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white.withValues(alpha: 0.6))),
                                                const SizedBox(width: 6),
                                                Text(_toHexStr(_currentColor), style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                                                const SizedBox(width: 6),
                                                GestureDetector(
                                                  onTap: () => _copyToClipboard(_toHexStr(_currentColor)),
                                                  child: Icon(Icons.copy_rounded, size: 12, color: Colors.white.withValues(alpha: 0.7)),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Container(width: 1, height: 14, color: Colors.white.withValues(alpha: 0.2)),
                                          const SizedBox(width: 12),
                                          // RGB
                                          Expanded(
                                            child: Row(
                                              children: [
                                                Text('RGB', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white.withValues(alpha: 0.6))),
                                                const SizedBox(width: 6),
                                                Text('${(_currentColor.r * 255).round()},${(_currentColor.g * 255).round()},${(_currentColor.b * 255).round()}', style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                                                const SizedBox(width: 6),
                                                GestureDetector(
                                                  onTap: () => _copyToClipboard(_toRgbStr(_currentColor)),
                                                  child: Icon(Icons.copy_rounded, size: 12, color: Colors.white.withValues(alpha: 0.7)),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Adjust Channels Section Title
                            Text('Adjust Channels', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: tokens.textSecondary, letterSpacing: 0.5)),
                            const SizedBox(height: 12),
                            _buildSliderRow('Red', sliderR, (v) {
                              _updateColor(Color.fromARGB(255, v.toInt(), (_currentColor.g * 255).round(), (_currentColor.b * 255).round()));
                            }, Colors.redAccent),
                            const SizedBox(height: 10),
                            _buildSliderRow('Green', sliderG, (v) {
                              _updateColor(Color.fromARGB(255, (_currentColor.r * 255).round(), v.toInt(), (_currentColor.b * 255).round()));
                            }, Colors.greenAccent),
                            const SizedBox(height: 10),
                            _buildSliderRow('Blue', sliderB, (v) {
                              _updateColor(Color.fromARGB(255, (_currentColor.r * 255).round(), (_currentColor.g * 255).round(), v.toInt()));
                            }, Colors.blueAccent),
                            const SizedBox(height: 24),

                            // Harmonious Suggestions Section Title
                            Text('Harmonious Suggestions', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: tokens.textSecondary, letterSpacing: 0.5)),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                _buildHarmonicCard('Complementary', _getComplementary(_currentColor)),
                                const SizedBox(width: 8),
                                _buildHarmonicCard('Analogous', _getAnalogous(_currentColor)),
                                const SizedBox(width: 8),
                                _buildHarmonicCard('Triadic', _getTriadic(_currentColor)),
                                const SizedBox(width: 8),
                                _buildHarmonicCard('Monochromatic', _getMonochromatic(_currentColor)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 24),

                  // Right panel: A single, clean card hosting Saved Palette & Color History
                  Expanded(
                    flex: 5,
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: tokens.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: tokens.borderSubtle),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Saved Palette Section
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Saved Palette', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: tokens.textPrimary)),
                              GestureDetector(
                                onTap: () => _addToPalette(_currentColor),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: tokens.accent.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: tokens.accent.withValues(alpha: 0.24)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.add_rounded, size: 12, color: tokens.accent),
                                      const SizedBox(width: 4),
                                      Text('Add Current', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: tokens.accent)),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (_savedPalette.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              child: Center(
                                child: Text('No saved colors yet', style: TextStyle(fontSize: 11, color: tokens.textMuted)),
                              ),
                            )
                          else
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _savedPalette.map((color) {
                                return GestureDetector(
                                  onTap: () => _updateColor(color),
                                  onSecondaryTap: () => _removeFromPalette(color),
                                  onLongPress: () => _removeFromPalette(color),
                                  child: Tooltip(
                                    message: '${_toHexStr(color)} (Right click/Hold to remove)',
                                    child: Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        color: color,
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.white24),
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          const SizedBox(height: 20),
                          Divider(color: tokens.borderSubtle, height: 1, thickness: 1),
                          const SizedBox(height: 20),

                          // Color History Section
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Recent Colors', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: tokens.textPrimary)),
                                const SizedBox(height: 12),
                                Expanded(
                                  child: GridView.builder(
                                    physics: const BouncingScrollPhysics(),
                                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 6,
                                      mainAxisSpacing: 8,
                                      crossAxisSpacing: 8,
                                    ),
                                    itemCount: _history.length,
                                    itemBuilder: (context, index) {
                                      final c = _history[index];
                                      return GestureDetector(
                                        onTap: () => setState(() => _currentColor = c),
                                        child: Tooltip(
                                          message: _toHexStr(c),
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: c,
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(color: Colors.white12, width: 1),
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
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

  Widget _buildSliderRow(String name, double val, ValueChanged<double> onChanged, Color activeColor) {
    final tokens = FocusOsTheme.of(context);
    return Row(
      children: [
        SizedBox(width: 48, child: Text(name, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: tokens.textSecondary))),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3.0,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.0),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 12.0),
              activeTrackColor: activeColor,
              inactiveTrackColor: tokens.borderSubtle,
              thumbColor: activeColor,
              overlayColor: activeColor.withValues(alpha: 0.15),
            ),
            child: Slider(
              value: val,
              min: 0.0,
              max: 255.0,
              onChanged: onChanged,
            ),
          ),
        ),
        SizedBox(
          width: 32,
          child: Text(
            val.toInt().toString(),
            style: TextStyle(fontSize: 11, color: tokens.textPrimary, fontFamily: 'monospace', fontWeight: FontWeight.bold),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }

  Widget _buildHarmonicCard(String label, Color color) {
    final tokens = FocusOsTheme.of(context);
    return Expanded(
      child: GestureDetector(
        onTap: () => _updateColor(color),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: tokens.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: tokens.borderSubtle),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                height: 28,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.white12, width: 1),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(fontSize: 9, color: tokens.textPrimary, fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                _toHexStr(color),
                style: TextStyle(fontSize: 8, color: tokens.textMuted, fontFamily: 'monospace'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getComplementary(Color c) {
    return Color.fromARGB(255, 255 - (c.r * 255).round(), 255 - (c.g * 255).round(), 255 - (c.b * 255).round());
  }

  Color _getAnalogous(Color c) {
    // Shift Hue (simplistic RGB rotation approximation)
    return Color.fromARGB(255, (c.g * 255).round(), (c.b * 255).round(), (c.r * 255).round());
  }

  Color _getTriadic(Color c) {
    return Color.fromARGB(255, (c.b * 255).round(), (c.r * 255).round(), (c.g * 255).round());
  }

  Color _getMonochromatic(Color c) {
    final hsv = HSVColor.fromColor(c);
    final double newValue = (hsv.value > 0.5) ? hsv.value - 0.25 : hsv.value + 0.25;
    return hsv.withValue(newValue.clamp(0.0, 1.0)).toColor();
  }
}
