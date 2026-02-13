import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ============================================================================
/// COLOR PICKER WIDGET - CORE SHARED COMPONENT
/// ============================================================================
/// 
/// This widget is used across ALL mini-apps (Tasks, Habits, Finance, Sleep, etc.)
/// for color selection. Any changes here affect the entire application.
/// 
/// ## FEATURES:
/// - Preset color palette with Material Design colors
/// - Custom color creation with HSV color wheel (optimized for 60fps)
/// - RGB sliders for fine-tuning
/// - Hex color input
/// - Save custom colors for later use (persisted across app restarts)
/// - Saved colors shared across all mini-apps
/// 
/// ## USAGE:
/// ```dart
/// final color = await showDialog<Color>(
///   context: context,
///   builder: (context) => ColorPickerWidget(
///     selectedColor: currentColor,
///     isDark: isDarkMode,
///   ),
/// );
/// if (color != null) {
///   setState(() => _selectedColor = color);
/// }
/// ```
/// 
/// ## IMPORTANT FOR DEVELOPERS:
/// 1. Always provide isDark for consistent theming
/// 2. Handle null returns (user may close dialog)
/// 3. Saved colors are automatically persisted using SharedPreferences
/// 4. Test on both light and dark themes after any modifications
/// 
/// ============================================================================

class ColorPickerWidget extends StatefulWidget {
  final Color selectedColor;
  final bool isDark;
  final void Function(Color)? onColorSelected;
  final List<Color>? savedColors;

  const ColorPickerWidget({
    super.key,
    required this.selectedColor,
    this.isDark = false,
    this.onColorSelected,
    this.savedColors,
  });

  @override
  State<ColorPickerWidget> createState() => _ColorPickerWidgetState();
}

class _ColorPickerWidgetState extends State<ColorPickerWidget>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late Color _currentColor;
  late HSVColor _hsvColor;
  late TextEditingController _hexController;
  List<Color> _savedColors = [];

  static const String _savedColorsKey = 'life_manager_saved_colors';

  static const List<Color> _popularColors = [
    Color(0xFFFF6B6B), Color(0xFFFF8E53), Color(0xFFFFB347), Color(0xFFFFD93D),
    Color(0xFF6BCB77), Color(0xFF4ECDC4), Color(0xFF45B7D1), Color(0xFF6C5CE7),
    Color(0xFFA66CFF), Color(0xFFFF6B9D), Color(0xFFCDAF56), Color(0xFF2D3139),
  ];

  static const List<List<Color>> _colorRows = [
    [Color(0xFFFFCDD2), Color(0xFFEF9A9A), Color(0xFFE57373), Color(0xFFEF5350), Color(0xFFF44336), Color(0xFFE53935), Color(0xFFD32F2F), Color(0xFFC62828), Color(0xFFB71C1C)],
    [Color(0xFFF8BBD0), Color(0xFFF48FB1), Color(0xFFF06292), Color(0xFFEC407A), Color(0xFFE91E63), Color(0xFFD81B60), Color(0xFFC2185B), Color(0xFFAD1457), Color(0xFF880E4F)],
    [Color(0xFFE1BEE7), Color(0xFFCE93D8), Color(0xFFBA68C8), Color(0xFFAB47BC), Color(0xFF9C27B0), Color(0xFF8E24AA), Color(0xFF7B1FA2), Color(0xFF6A1B9A), Color(0xFF4A148C)],
    [Color(0xFFBBDEFB), Color(0xFF90CAF9), Color(0xFF64B5F6), Color(0xFF42A5F5), Color(0xFF2196F3), Color(0xFF1E88E5), Color(0xFF1976D2), Color(0xFF1565C0), Color(0xFF0D47A1)],
    [Color(0xFFB2EBF2), Color(0xFF80DEEA), Color(0xFF4DD0E1), Color(0xFF26C6DA), Color(0xFF00BCD4), Color(0xFF00ACC1), Color(0xFF0097A7), Color(0xFF00838F), Color(0xFF006064)],
    [Color(0xFFC8E6C9), Color(0xFFA5D6A7), Color(0xFF81C784), Color(0xFF66BB6A), Color(0xFF4CAF50), Color(0xFF43A047), Color(0xFF388E3C), Color(0xFF2E7D32), Color(0xFF1B5E20)],
    [Color(0xFFFFF9C4), Color(0xFFFFF59D), Color(0xFFFFF176), Color(0xFFFFEE58), Color(0xFFFFEB3B), Color(0xFFFDD835), Color(0xFFFBC02D), Color(0xFFF9A825), Color(0xFFF57F17)],
    [Color(0xFFFFE0B2), Color(0xFFFFCC80), Color(0xFFFFB74D), Color(0xFFFFA726), Color(0xFFFF9800), Color(0xFFFB8C00), Color(0xFFF57C00), Color(0xFFEF6C00), Color(0xFFE65100)],
    [Color(0xFFD7CCC8), Color(0xFFBCAAA4), Color(0xFFA1887F), Color(0xFF8D6E63), Color(0xFF795548), Color(0xFF6D4C41), Color(0xFF5D4037), Color(0xFF4E342E), Color(0xFF3E2723)],
    [Color(0xFFF5F5F5), Color(0xFFEEEEEE), Color(0xFFE0E0E0), Color(0xFFBDBDBD), Color(0xFF9E9E9E), Color(0xFF757575), Color(0xFF616161), Color(0xFF424242), Color(0xFF212121)],
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _currentColor = widget.selectedColor;
    _hsvColor = HSVColor.fromColor(_currentColor);
    _hexController = TextEditingController(text: _colorToHex(_currentColor));
    _loadSavedColors();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _hexController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedColors() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedColorStrings = prefs.getStringList(_savedColorsKey) ?? [];
      if (mounted) {
        setState(() {
          _savedColors = savedColorStrings
              .map((hex) => _hexToColor(hex))
              .whereType<Color>()
              .toList();
        });
      }
    } catch (e) {
      // Loading error, just keep empty list
    }
  }

  Future<void> _saveColorToStorage(Color color) async {
    if (_savedColors.any((c) => c.value == color.value)) {
      _showSnackBar('Color already saved');
      return;
    }
    
    setState(() {
      _savedColors.insert(0, color);
      if (_savedColors.length > 20) {
        _savedColors = _savedColors.take(20).toList();
      }
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final colorStrings = _savedColors.map((c) => _colorToHex(c)).toList();
      await prefs.setStringList(_savedColorsKey, colorStrings);
      _showSnackBar('Color saved!');
    } catch (e) {
      // Silently fail
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _removeColorFromStorage(Color color) async {
    setState(() {
      _savedColors.removeWhere((c) => c.value == color.value);
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final colorStrings = _savedColors.map((c) => _colorToHex(c)).toList();
      await prefs.setStringList(_savedColorsKey, colorStrings);
    } catch (e) {
      // Silently fail
    }
  }

  String _colorToHex(Color color) {
    return '#${color.value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
  }

  Color? _hexToColor(String hex) {
    try {
      hex = hex.replaceAll('#', '');
      if (hex.length == 6) hex = 'FF$hex';
      return Color(int.parse(hex, radix: 16));
    } catch (e) {
      return null;
    }
  }

  void _updateColor(Color color) {
    HapticFeedback.selectionClick();
    setState(() {
      _currentColor = color;
      _hsvColor = HSVColor.fromColor(color);
      _hexController.text = _colorToHex(color);
    });
  }

  void _updateFromHSV(HSVColor hsv) {
    setState(() {
      _hsvColor = hsv;
      _currentColor = hsv.toColor();
      _hexController.text = _colorToHex(_currentColor);
    });
  }

  void _onHexChanged(String value) {
    final color = _hexToColor(value);
    if (color != null) {
      setState(() {
        _currentColor = color;
        _hsvColor = HSVColor.fromColor(color);
      });
    }
  }

  void _selectColor(Color color) {
    HapticFeedback.mediumImpact();
    if (widget.onColorSelected != null) {
      widget.onColorSelected!(color);
    } else {
      Navigator.of(context).pop(color);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 620),
        decoration: BoxDecoration(
          color: widget.isDark ? const Color(0xFF1A1D21) : Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.25),
              blurRadius: 40,
              offset: const Offset(0, 15),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            _buildTabBar(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                physics: const BouncingScrollPhysics(),
                children: [
                  _buildPaletteTab(),
                  _buildCustomTab(),
                ],
              ),
            ),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 12, 12),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _currentColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: widget.isDark ? Colors.white24 : Colors.black12,
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: _currentColor.withOpacity(0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select Color',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: widget.isDark ? Colors.white : const Color(0xFF1E1E1E),
                  ),
                ),
                Text(
                  _colorToHex(_currentColor),
                  style: TextStyle(
                    fontSize: 13,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w600,
                    color: widget.isDark ? Colors.white54 : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(
              Icons.close_rounded,
              color: widget.isDark ? Colors.white38 : Colors.grey[400],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      height: 44,
      decoration: BoxDecoration(
        color: widget.isDark ? Colors.white.withOpacity(0.06) : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: const Color(0xFFCDAF56),
          borderRadius: BorderRadius.circular(10),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        indicatorPadding: const EdgeInsets.all(3),
        dividerColor: Colors.transparent,
        labelColor: Colors.white,
        unselectedLabelColor: widget.isDark ? Colors.white54 : Colors.grey[600],
        labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        tabs: const [
          Tab(text: 'Palette'),
          Tab(text: 'Custom'),
        ],
      ),
    );
  }

  Widget _buildPaletteTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      physics: const BouncingScrollPhysics(),
      children: [
        if (_savedColors.isNotEmpty) ...[
          _buildSectionHeader('Saved', showClear: true),
          const SizedBox(height: 10),
          _buildColorGrid(_savedColors, size: 38, canRemove: true),
          const SizedBox(height: 20),
        ],
        _buildSectionHeader('Popular'),
        const SizedBox(height: 10),
        _buildColorGrid(_popularColors, size: 36),
        const SizedBox(height: 20),
        _buildSectionHeader('All Colors'),
        const SizedBox(height: 10),
        ..._colorRows.map((row) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: _buildColorRow(row),
        )),
      ],
    );
  }

  Widget _buildSectionHeader(String title, {bool showClear = false}) {
    return Row(
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: widget.isDark ? Colors.white60 : Colors.grey[600],
          ),
        ),
        if (showClear) ...[
          const Spacer(),
          GestureDetector(
            onTap: _clearAllSavedColors,
            child: Text(
              'Clear all',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.red[400],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildColorGrid(List<Color> colors, {double size = 36, bool canRemove = false}) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: colors.map((color) {
        final isSelected = color.value == _currentColor.value;
        return GestureDetector(
          onTap: () => _updateColor(color),
          onLongPress: canRemove ? () => _confirmRemoveColor(color) : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected 
                    ? (widget.isDark ? Colors.white : Colors.black)
                    : Colors.transparent,
                width: 2.5,
              ),
              boxShadow: isSelected ? [
                BoxShadow(color: color.withOpacity(0.5), blurRadius: 8, offset: const Offset(0, 2)),
              ] : null,
            ),
            child: isSelected
                ? Icon(Icons.check_rounded, color: _getContrastColor(color), size: 18)
                : null,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildColorRow(List<Color> colors) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: colors.map((color) {
        final isSelected = color.value == _currentColor.value;
        return GestureDetector(
          onTap: () => _updateColor(color),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected 
                    ? (widget.isDark ? Colors.white : Colors.black)
                    : Colors.transparent,
                width: 2,
              ),
            ),
            child: isSelected
                ? Icon(Icons.check_rounded, color: _getContrastColor(color), size: 16)
                : null,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCustomTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      physics: const BouncingScrollPhysics(),
      children: [
        // Hue Slider (Rainbow bar)
        _buildSectionHeader('Hue'),
        const SizedBox(height: 10),
        _HueSlider(
          hue: _hsvColor.hue,
          onChanged: (hue) => _updateFromHSV(_hsvColor.withHue(hue)),
        ),
        const SizedBox(height: 20),

        // Saturation & Brightness
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader('Saturation'),
                  const SizedBox(height: 10),
                  _GradientSlider(
                    value: _hsvColor.saturation,
                    colors: [
                      HSVColor.fromAHSV(1, _hsvColor.hue, 0, _hsvColor.value).toColor(),
                      HSVColor.fromAHSV(1, _hsvColor.hue, 1, _hsvColor.value).toColor(),
                    ],
                    onChanged: (val) => _updateFromHSV(_hsvColor.withSaturation(val)),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader('Brightness'),
                  const SizedBox(height: 10),
                  _GradientSlider(
                    value: _hsvColor.value,
                    colors: [
                      Colors.black,
                      HSVColor.fromAHSV(1, _hsvColor.hue, _hsvColor.saturation, 1).toColor(),
                    ],
                    onChanged: (val) => _updateFromHSV(_hsvColor.withValue(val)),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Color Preview
        Center(
          child: Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: _currentColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: widget.isDark ? Colors.white24 : Colors.black12,
                width: 3,
              ),
              boxShadow: [
                BoxShadow(
                  color: _currentColor.withOpacity(0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // RGB Sliders
        _buildSectionHeader('RGB'),
        const SizedBox(height: 12),
        _RGBSlider(label: 'R', value: _currentColor.red, color: Colors.red,
          onChanged: (v) => _updateColor(Color.fromARGB(255, v, _currentColor.green, _currentColor.blue))),
        const SizedBox(height: 8),
        _RGBSlider(label: 'G', value: _currentColor.green, color: Colors.green,
          onChanged: (v) => _updateColor(Color.fromARGB(255, _currentColor.red, v, _currentColor.blue))),
        const SizedBox(height: 8),
        _RGBSlider(label: 'B', value: _currentColor.blue, color: Colors.blue,
          onChanged: (v) => _updateColor(Color.fromARGB(255, _currentColor.red, _currentColor.green, v))),
        const SizedBox(height: 20),

        // Hex Input
        _buildSectionHeader('Hex Code'),
        const SizedBox(height: 10),
        Container(
          height: 50,
          decoration: BoxDecoration(
            color: widget.isDark ? Colors.white.withOpacity(0.06) : Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                margin: const EdgeInsets.all(8),
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: _currentColor,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              Expanded(
                child: TextField(
                  controller: _hexController,
                  style: TextStyle(
                    fontSize: 16,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w600,
                    color: widget.isDark ? Colors.white : const Color(0xFF1E1E1E),
                  ),
                  decoration: InputDecoration(
                    hintText: '#FFFFFF',
                    hintStyle: TextStyle(
                      color: widget.isDark ? Colors.white30 : Colors.grey[400],
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9A-Fa-f#]')),
                    LengthLimitingTextInputFormatter(7),
                  ],
                  onChanged: _onHexChanged,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: widget.isDark ? Colors.white.withOpacity(0.08) : Colors.grey[200]!,
          ),
        ),
      ),
      child: Row(
        children: [
          OutlinedButton.icon(
            onPressed: () => _saveColorToStorage(_currentColor),
            icon: const Icon(Icons.bookmark_add_rounded, size: 18),
            label: const Text('Save'),
            style: OutlinedButton.styleFrom(
              foregroundColor: widget.isDark ? Colors.white70 : Colors.grey[700],
              side: BorderSide(
                color: widget.isDark ? Colors.white24 : Colors.grey[300]!,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: () => _selectColor(_currentColor),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFCDAF56),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Select Color',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmRemoveColor(Color color) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: widget.isDark ? const Color(0xFF2D3139) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Remove color?', style: TextStyle(color: widget.isDark ? Colors.white : Colors.black)),
        content: Container(
          width: 40, height: 40,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              _removeColorFromStorage(color);
              Navigator.pop(ctx);
            },
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _clearAllSavedColors() async {
    setState(() => _savedColors.clear());
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_savedColorsKey);
  }

  Color _getContrastColor(Color color) {
    return color.computeLuminance() > 0.5 ? Colors.black : Colors.white;
  }
}

// ============================================================================
// OPTIMIZED SLIDER WIDGETS
// ============================================================================

/// High-performance Hue slider with rainbow gradient
class _HueSlider extends StatelessWidget {
  final double hue;
  final ValueChanged<double> onChanged;

  const _HueSlider({required this.hue, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragUpdate: (details) {
        final RenderBox box = context.findRenderObject() as RenderBox;
        final localPosition = box.globalToLocal(details.globalPosition);
        final newHue = (localPosition.dx / box.size.width).clamp(0.0, 1.0) * 360;
        onChanged(newHue);
      },
      onTapDown: (details) {
        final RenderBox box = context.findRenderObject() as RenderBox;
        final localPosition = box.globalToLocal(details.globalPosition);
        final newHue = (localPosition.dx / box.size.width).clamp(0.0, 1.0) * 360;
        onChanged(newHue);
      },
      child: Container(
        height: 36,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: const LinearGradient(
            colors: [
              Color(0xFFFF0000), Color(0xFFFFFF00), Color(0xFF00FF00),
              Color(0xFF00FFFF), Color(0xFF0000FF), Color(0xFFFF00FF), Color(0xFFFF0000),
            ],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              left: (hue / 360) * (MediaQuery.of(context).size.width - 80) - 10,
              top: 3,
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: HSVColor.fromAHSV(1, hue, 1, 1).toColor(),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [
                    BoxShadow(color: Colors.black26, blurRadius: 4, offset: const Offset(0, 2)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Optimized gradient slider for saturation/brightness
class _GradientSlider extends StatelessWidget {
  final double value;
  final List<Color> colors;
  final ValueChanged<double> onChanged;

  const _GradientSlider({
    required this.value,
    required this.colors,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragUpdate: (details) {
        final RenderBox box = context.findRenderObject() as RenderBox;
        final localPosition = box.globalToLocal(details.globalPosition);
        final newValue = (localPosition.dx / box.size.width).clamp(0.0, 1.0);
        onChanged(newValue);
      },
      onTapDown: (details) {
        final RenderBox box = context.findRenderObject() as RenderBox;
        final localPosition = box.globalToLocal(details.globalPosition);
        final newValue = (localPosition.dx / box.size.width).clamp(0.0, 1.0);
        onChanged(newValue);
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final thumbPosition = value * constraints.maxWidth - 10;
          return Container(
            height: 28,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: LinearGradient(colors: colors),
              border: Border.all(color: Colors.white24),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: thumbPosition.clamp(0, constraints.maxWidth - 20),
                  top: -1,
                  child: Container(
                    width: 20,
                    height: 30,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: [
                        BoxShadow(color: Colors.black26, blurRadius: 3, offset: const Offset(0, 1)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// RGB slider component
class _RGBSlider extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  final ValueChanged<int> onChanged;

  const _RGBSlider({
    required this.label,
    required this.value,
    required this.color,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        SizedBox(
          width: 20,
          child: Text(label, style: TextStyle(fontWeight: FontWeight.w700, color: color, fontSize: 13)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: color,
              inactiveTrackColor: color.withOpacity(0.2),
              thumbColor: color,
              overlayColor: color.withOpacity(0.1),
              trackHeight: 6,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            ),
            child: Slider(
              value: value.toDouble(),
              min: 0,
              max: 255,
              onChanged: (v) => onChanged(v.round()),
            ),
          ),
        ),
        SizedBox(
          width: 36,
          child: Text(
            value.toString(),
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: 12,
              fontFamily: 'monospace',
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white54 : Colors.grey[600],
            ),
          ),
        ),
      ],
    );
  }
}
