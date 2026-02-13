import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data/all_icons.dart';
import '../data/icon_data.dart';

/// ============================================================================
/// ICON PICKER WIDGET - CORE SHARED COMPONENT
/// ============================================================================
/// 
/// This widget is used across ALL mini-apps (Tasks, Habits, Finance, Sleep, etc.)
/// for icon selection. Any changes here affect the entire application.
/// 
/// ## USAGE:
/// ```dart
/// final icon = await showDialog<IconData>(
///   context: context,
///   builder: (context) => IconPickerWidget(
///     selectedIcon: currentIcon,
///     isDark: isDarkMode,
///   ),
/// );
/// if (icon != null) {
///   setState(() => _selectedIcon = icon);
/// }
/// ```
/// 
/// ## TOTAL ICONS: 1700+
/// 
/// Categories: All, Common, Arrows, Media, Communication, Devices, Food,
/// Shopping, Buildings, Nature, Weather, Sports, Work, Tools, Actions,
/// Education, Technology, Photography, Travel, Maps, Health, Finance,
/// Shapes, Emotions, Spiritual, Security, Files
/// 
/// ============================================================================

class IconPickerWidget extends StatefulWidget {
  final IconData? selectedIcon;
  final bool isDark;
  final void Function(IconData)? onIconSelected;

  const IconPickerWidget({
    super.key,
    this.selectedIcon,
    this.isDark = false,
    this.onIconSelected,
  });

  @override
  State<IconPickerWidget> createState() => _IconPickerWidgetState();
}

class _IconPickerWidgetState extends State<IconPickerWidget> 
    with SingleTickerProviderStateMixin {
  late final TextEditingController _searchController;
  late final FocusNode _searchFocusNode;
  late final AnimationController _animationController;
  late final Animation<double> _fadeAnimation;
  
  String _selectedCategory = 'All';
  List<IconDataEntry> _filteredIcons = [];
  late Map<String, CategoryData> _categories;
  bool _isSearching = false;
  
  // App theme colors
  static const Color _accentColor = Color(0xFFCDAF56);
  static const Color _darkBg = Color(0xFF1A1D21);
  static const Color _darkCard = Color(0xFF2D3139);
  static const Color _lightBg = Color(0xFFFAFAFA);
  
  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchFocusNode = FocusNode();
    _categories = AllIcons.getCategorizedIcons();
    _filteredIcons = _categories['All']?.icons ?? [];
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _filterIcons(String query) {
    final categoryIcons = _categories[_selectedCategory]?.icons ?? [];
    
    if (query.isEmpty) {
      setState(() {
        _filteredIcons = categoryIcons;
        _isSearching = false;
      });
      return;
    }

    final lowerQuery = query.toLowerCase();
    setState(() {
      _isSearching = true;
      _filteredIcons = categoryIcons.where((entry) {
        if (entry.name.toLowerCase().contains(lowerQuery)) return true;
        return entry.keywords.any((k) => k.toLowerCase().contains(lowerQuery));
      }).toList();
    });
  }

  void _onCategoryChanged(String category) {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedCategory = category;
      _filterIcons(_searchController.text);
    });
  }

  void _selectIcon(IconData icon) {
    HapticFeedback.mediumImpact();
    if (widget.onIconSelected != null) {
      widget.onIconSelected!(icon);
    }
    Navigator.of(context).pop(icon);
  }

  void _clearSearch() {
    _searchController.clear();
    _filterIcons('');
    _searchFocusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark || Theme.of(context).brightness == Brightness.dark;
    
    // Theme colors
    final bgColor = isDark ? _darkBg : _lightBg;
    final cardColor = isDark ? _darkCard : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1E1E1E);
    final subtextColor = isDark ? Colors.white60 : Colors.black54;
    final borderColor = isDark ? Colors.white.withAlpha(15) : Colors.black.withAlpha(8);
    final searchBgColor = isDark ? _darkCard : Colors.white;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Container(
          constraints: BoxConstraints(
            maxWidth: 440,
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.4 : 0.15),
                blurRadius: 40,
                offset: const Offset(0, 20),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              _buildHeader(isDark, textColor, subtextColor),
              
              // Search Bar
              _buildSearchBar(isDark, cardColor, textColor, subtextColor, borderColor, searchBgColor),
              
              // Category Chips
              _buildCategoryChips(isDark, textColor, subtextColor, cardColor),
              
              // Icon Grid
              Expanded(
                child: _buildIconGrid(isDark, textColor, subtextColor, cardColor),
              ),
              
              // Footer with count
              _buildFooter(isDark, subtextColor),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark, Color textColor, Color subtextColor) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 16, 16),
      child: Row(
        children: [
          // Accent icon container
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  _accentColor,
                  _accentColor.withOpacity(0.8),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: _accentColor.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.apps_rounded,
              color: Colors.white,
              size: 26,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Choose an Icon',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _accentColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${_categories['All']?.icons.length ?? 0}+ icons',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: _accentColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '• ${_categories.length} categories',
                        style: TextStyle(
                          fontSize: 12,
                          color: subtextColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Close button
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => Navigator.of(context).pop(),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withAlpha(10) : Colors.black.withAlpha(5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.close_rounded,
                  color: subtextColor,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(bool isDark, Color cardColor, Color textColor, 
      Color subtextColor, Color borderColor, Color searchBgColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: searchBgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _isSearching ? _accentColor.withOpacity(0.5) : borderColor,
            width: _isSearching ? 1.5 : 1,
          ),
          boxShadow: [
            if (!isDark)
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Row(
          children: [
            const SizedBox(width: 16),
            Icon(
              Icons.search_rounded,
              color: _isSearching ? _accentColor : subtextColor,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                onChanged: _filterIcons,
                style: TextStyle(
                  color: textColor,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
                decoration: InputDecoration(
                  hintText: 'Search icons by name or keyword...',
                  hintStyle: TextStyle(
                    color: subtextColor.withOpacity(0.7),
                    fontSize: 14,
                    fontWeight: FontWeight.normal,
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
            if (_searchController.text.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _clearSearch,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      child: Icon(
                        Icons.clear_rounded,
                        color: subtextColor,
                        size: 18,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryChips(bool isDark, Color textColor, Color subtextColor, Color cardColor) {
    return Container(
      height: 56,
      margin: const EdgeInsets.only(top: 16),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final category = _categories.keys.elementAt(index);
          final categoryData = _categories[category]!;
          final isSelected = category == _selectedCategory;

          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _onCategoryChanged(category),
                borderRadius: BorderRadius.circular(14),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected 
                        ? _accentColor 
                        : (isDark ? _darkCard : Colors.white),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected 
                          ? _accentColor 
                          : (isDark ? Colors.white.withAlpha(10) : Colors.black.withAlpha(8)),
                      width: 1,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: _accentColor.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        categoryData.icon,
                        size: 18,
                        color: isSelected 
                            ? Colors.white 
                            : (isDark ? Colors.white70 : Colors.black54),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        category,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                          color: isSelected 
                              ? Colors.white 
                              : (isDark ? Colors.white.withOpacity(0.85) : textColor),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildIconGrid(bool isDark, Color textColor, Color subtextColor, Color cardColor) {
    if (_filteredIcons.isEmpty) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 24,
              color: subtextColor.withOpacity(0.4),
            ),
            const SizedBox(width: 12),
            Text(
              'No icons found',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: subtextColor.withOpacity(0.6),
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 5,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1,
        ),
        itemCount: _filteredIcons.length,
        itemBuilder: (context, index) {
          final entry = _filteredIcons[index];
          final isSelected = entry.icon == widget.selectedIcon;

          return _IconTile(
            entry: entry,
            isSelected: isSelected,
            isDark: isDark,
            accentColor: _accentColor,
            onTap: () => _selectIcon(entry.icon),
          );
        },
      ),
    );
  }

  Widget _buildFooter(bool isDark, Color subtextColor) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.touch_app_rounded,
            size: 14,
            color: subtextColor.withOpacity(0.6),
          ),
          const SizedBox(width: 6),
          Text(
            _isSearching 
                ? '${_filteredIcons.length} results found'
                : 'Tap an icon to select',
            style: TextStyle(
              fontSize: 12,
              color: subtextColor.withOpacity(0.6),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// Individual icon tile widget for better performance
class _IconTile extends StatefulWidget {
  final IconDataEntry entry;
  final bool isSelected;
  final bool isDark;
  final Color accentColor;
  final VoidCallback onTap;

  const _IconTile({
    required this.entry,
    required this.isSelected,
    required this.isDark,
    required this.accentColor,
    required this.onTap,
  });

  @override
  State<_IconTile> createState() => _IconTileState();
}

class _IconTileState extends State<_IconTile> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final bgColor = widget.isSelected
        ? widget.accentColor.withOpacity(0.15)
        : (_isHovered
            ? (widget.isDark ? Colors.white.withAlpha(15) : Colors.black.withAlpha(8))
            : (widget.isDark ? const Color(0xFF2D3139) : Colors.white));
    
    final iconColor = widget.isSelected
        ? widget.accentColor
        : (widget.isDark ? Colors.white.withOpacity(0.85) : Colors.black87);

    return Tooltip(
      message: widget.entry.name,
      preferBelow: false,
      waitDuration: const Duration(milliseconds: 400),
      decoration: BoxDecoration(
        color: widget.isDark ? const Color(0xFF3D4149) : Colors.grey.shade800,
        borderRadius: BorderRadius.circular(8),
      ),
      textStyle: const TextStyle(
        color: Colors.white,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: widget.isSelected
                    ? widget.accentColor
                    : (widget.isDark ? Colors.white.withAlpha(8) : Colors.black.withAlpha(5)),
                width: widget.isSelected ? 2 : 1,
              ),
              boxShadow: widget.isSelected
                  ? [
                      BoxShadow(
                        color: widget.accentColor.withOpacity(0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: AnimatedScale(
                scale: _isHovered ? 1.15 : 1.0,
                duration: const Duration(milliseconds: 150),
                child: Icon(
                  widget.entry.icon,
                  size: 26,
                  color: iconColor,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
