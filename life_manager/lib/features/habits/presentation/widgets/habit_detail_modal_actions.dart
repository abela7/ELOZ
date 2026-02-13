part of 'habit_detail_modal.dart';

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool isPrimary;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        onTap();
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(4), // Space for outer outline
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: color.withOpacity(0.4), width: 2.5),
            ),
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              child: Icon(icon, color: Colors.white, size: 26),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: TextStyle(
              color: isDark ? Colors.white.withOpacity(0.9) : Colors.black87,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }
}

// Slip Tracking Modal (for quit habits) - REQUIRES a reason!
class _SlipTrackingModal extends ConsumerStatefulWidget {
  final Habit habit;
  final VoidCallback? onHabitUpdated;
  final DateTime? selectedDate;

  const _SlipTrackingModal({
    required this.habit,
    this.onHabitUpdated,
    this.selectedDate,
  });

  @override
  ConsumerState<_SlipTrackingModal> createState() => _SlipTrackingModalState();
}

class _SlipTrackingModalState extends ConsumerState<_SlipTrackingModal>
    with TickerProviderStateMixin {
  double _slipAmount = 1.0;
  HabitReason? _selectedReason;
  String _customNote = '';
  late AnimationController _successController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  bool _showEffect = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _successController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _successController, curve: Curves.elasticOut),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _successController, curve: Curves.easeIn),
    );
  }

  @override
  void dispose() {
    _successController.dispose();
    super.dispose();
  }

  // Calculate penalty based on slip amount
  int get _penalty {
    return widget.habit.calculateSlipPenalty(_slipAmount.toInt());
  }

  // Check if form is valid (reason is required!)
  bool get _isValid => _selectedReason != null;

  Future<void> _recordSlip() async {
    if (!_isValid || _isSubmitting) return;

    setState(() => _isSubmitting = true);
    HapticFeedback.mediumImpact();
    // Capture before navigation pops; using `context` after pop can crash.
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    // Show effect overlay
    setState(() => _showEffect = true);
    _successController.forward();

    await Future.delayed(const Duration(milliseconds: 1500));

    if (!mounted) return;

    try {
      final date = widget.selectedDate ?? DateTime.now();

      // Build the reason text (include note if provided)
      String reasonText = _selectedReason!.text;
      if (_customNote.isNotEmpty) {
        reasonText = '$reasonText: $_customNote';
      }

      // Record the slip with proper penalty handling (all-in-one atomic operation)
      // This properly:
      // - Records the slip completion
      // - Deducts penalty points
      // - Increments slip count
      // - Resets streak
      await ref
          .read(habitNotifierProvider.notifier)
          .slipHabitForDate(
            widget.habit.id,
            date,
            reason: reasonText,
            penalty: _penalty,
            slipAmount: _slipAmount.toInt(),
          );

      // Close modals and refresh
      if (!mounted) return;
      navigator.pop(); // Close slip modal
      navigator.pop(); // Close habit detail modal
      widget.onHabitUpdated?.call();

      // Show feedback snackbar (must NOT use `context` after pop)
      messenger.showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Slip recorded. -$_penalty points. Tomorrow is a new day! ðŸ’ª',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFFFF6B6B),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _showEffect = false;
        });
        messenger.showSnackBar(
          SnackBar(
            content: Text('Error recording slip: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1A1D21) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1E1E1E);
    final subtextColor = isDark ? Colors.white70 : Colors.grey[600];

    // Get slip reasons from provider
    final slipReasonsAsync = ref.watch(habitActiveSlipReasonsProvider);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Stack(
        children: [
          // Main content
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.grey[300],
                  borderRadius: BorderRadius.circular(3),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF6B6B),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.sentiment_dissatisfied_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Record a Slip',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                              color: textColor,
                            ),
                          ),
                          Text(
                            'Be honest - it helps you improve',
                            style: TextStyle(fontSize: 13, color: subtextColor),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(
                        Icons.close_rounded,
                        color: isDark ? Colors.white38 : Colors.grey[400],
                      ),
                    ),
                  ],
                ),
              ),

              // Content
              Flexible(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    24,
                    16,
                    24,
                    MediaQuery.of(context).viewInsets.bottom + 24,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Required reason section
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF6B6B).withOpacity(0.08),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFFFF6B6B).withOpacity(0.2),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.warning_amber_rounded,
                                  color: const Color(0xFFFF6B6B),
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Why did you slip? *',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: textColor,
                                  ),
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFFFF6B6B,
                                    ).withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'Required',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFFFF6B6B),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),

                            // Slip reasons
                            slipReasonsAsync.when(
                              data: (reasons) {
                                if (reasons.isEmpty) {
                                  return Container(
                                    padding: const EdgeInsets.all(20),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? Colors.white.withOpacity(0.05)
                                          : Colors.grey[100],
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Column(
                                      children: [
                                        Icon(
                                          Icons.info_outline_rounded,
                                          color: isDark
                                              ? Colors.white38
                                              : Colors.grey[400],
                                          size: 32,
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          'No slip reasons configured',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: textColor,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Add slip reasons in Habit Settings â†’ Reasons',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: subtextColor,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ],
                                    ),
                                  );
                                }

                                return Wrap(
                                  spacing: 10,
                                  runSpacing: 10,
                                  children: reasons.map((reason) {
                                    final isSelected =
                                        _selectedReason?.id == reason.id;
                                    return GestureDetector(
                                      onTap: () {
                                        setState(
                                          () => _selectedReason = isSelected
                                              ? null
                                              : reason,
                                        );
                                        HapticFeedback.selectionClick();
                                      },
                                      child: AnimatedContainer(
                                        duration: const Duration(
                                          milliseconds: 200,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 10,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? reason.color.withOpacity(0.15)
                                              : (isDark
                                                    ? Colors.white.withOpacity(
                                                        0.05,
                                                      )
                                                    : Colors.grey[100]),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          border: Border.all(
                                            color: isSelected
                                                ? reason.color
                                                : (isDark
                                                      ? Colors.white
                                                            .withOpacity(0.1)
                                                      : Colors.grey[300]!),
                                            width: isSelected ? 2 : 1,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              reason.icon ??
                                                  Icons.error_outline_rounded,
                                              color: reason.color,
                                              size: 18,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              reason.text,
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: isSelected
                                                    ? FontWeight.w700
                                                    : FontWeight.w500,
                                                color: textColor,
                                              ),
                                            ),
                                            if (isSelected) ...[
                                              const SizedBox(width: 6),
                                              Icon(
                                                Icons.check_rounded,
                                                color: reason.color,
                                                size: 16,
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                );
                              },
                              loading: () => const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(20),
                                  child: CircularProgressIndicator(),
                                ),
                              ),
                              error: (e, _) =>
                                  Text('Error loading reasons: $e'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Optional note
                      TextField(
                        maxLines: 2,
                        maxLength: 150,
                        onChanged: (value) => _customNote = value,
                        style: TextStyle(color: textColor),
                        decoration: InputDecoration(
                          labelText: 'Additional details (optional)',
                          labelStyle: TextStyle(color: subtextColor),
                          hintText: 'What triggered it? How did you feel?',
                          hintStyle: TextStyle(
                            color: isDark ? Colors.white30 : Colors.grey[400],
                          ),
                          filled: true,
                          fillColor: isDark
                              ? Colors.white.withOpacity(0.05)
                              : Colors.grey[100],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: Color(0xFFFF6B6B),
                              width: 2,
                            ),
                          ),
                          counterStyle: TextStyle(
                            color: isDark ? Colors.white38 : Colors.grey[500],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Amount slider (if per-unit penalty)
                      if (widget.habit.slipCalculation != 'fixed') ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withOpacity(0.05)
                                : Colors.grey[100],
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'How many ${widget.habit.unit ?? 'times'}?',
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _buildCountButton(
                                    isDark,
                                    Icons.remove_rounded,
                                    () {
                                      if (_slipAmount > 1) {
                                        setState(() => _slipAmount--);
                                      }
                                      HapticFeedback.selectionClick();
                                    },
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 32,
                                    ),
                                    child: Text(
                                      '${_slipAmount.toInt()}',
                                      style: TextStyle(
                                        fontSize: 42,
                                        fontWeight: FontWeight.w800,
                                        color: const Color(0xFFFF6B6B),
                                      ),
                                    ),
                                  ),
                                  _buildCountButton(
                                    isDark,
                                    Icons.add_rounded,
                                    () {
                                      if (_slipAmount < 99) {
                                        setState(() => _slipAmount++);
                                      }
                                      HapticFeedback.selectionClick();
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],

                      // Penalty display
                      if (_penalty > 0)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.red.withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.remove_circle_outline_rounded,
                                color: Colors.red,
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Point Penalty',
                                      style: TextStyle(
                                        color: textColor,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      'This will be deducted from your score',
                                      style: TextStyle(
                                        color: subtextColor,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                '-$_penalty',
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // Footer with action button
              Container(
                padding: EdgeInsets.fromLTRB(
                  24,
                  16,
                  24,
                  MediaQuery.of(context).viewInsets.bottom > 0 ? 16 : 24,
                ),
                decoration: BoxDecoration(
                  color: bgColor,
                  border: Border(
                    top: BorderSide(
                      color: isDark
                          ? Colors.white.withOpacity(0.08)
                          : Colors.grey[200]!,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: BorderSide(
                            color: isDark ? Colors.white24 : Colors.grey[300]!,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white70 : Colors.grey[700],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: _isValid && !_isSubmitting
                            ? _recordSlip
                            : null,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: const Color(0xFFFF6B6B),
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: isDark
                              ? Colors.white.withOpacity(0.1)
                              : Colors.grey[300],
                          disabledForegroundColor: isDark
                              ? Colors.white38
                              : Colors.grey[500],
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (_isSubmitting)
                              const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            else ...[
                              Text(
                                _isValid ? 'Record Slip' : 'Select a Reason',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (_isValid) ...[
                                const SizedBox(width: 8),
                                const Icon(Icons.check_rounded, size: 20),
                              ],
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Effect Overlay
          if (_showEffect)
            Positioned.fill(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF6B6B).withOpacity(0.95),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                  ),
                  child: Center(
                    child: ScaleTransition(
                      scale: _scaleAnimation,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 160,
                            height: 160,
                            child: Lottie.asset(
                              'assets/animations/big-frown.json',
                              repeat: false,
                              fit: BoxFit.contain,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Slip Recorded',
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: 1.2,
                                ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Tomorrow is a new opportunity!',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 14,
                            ),
                          ),
                          if (_penalty > 0) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.2),
                                ),
                              ),
                              child: Text(
                                '-$_penalty points',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
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

  Widget _buildCountButton(bool isDark, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: const Color(0xFFFF6B6B).withOpacity(0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFFF6B6B).withOpacity(0.3)),
        ),
        child: Icon(icon, color: const Color(0xFFFF6B6B), size: 28),
      ),
    );
  }
}
