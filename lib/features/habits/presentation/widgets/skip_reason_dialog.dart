import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/habit_reason.dart';
import '../providers/habit_reason_providers.dart';

/// Dialog to select a reason for skipping a habit
class SkipReasonDialog extends ConsumerStatefulWidget {
  final bool isDark;
  final String habitName;

  const SkipReasonDialog({
    super.key,
    required this.isDark,
    required this.habitName,
  });

  @override
  ConsumerState<SkipReasonDialog> createState() => _SkipReasonDialogState();
}

class _SkipReasonDialogState extends ConsumerState<SkipReasonDialog> {
  String? _selectedReason;
  final TextEditingController _customReasonController = TextEditingController();
  bool _showCustomInput = false;

  @override
  void dispose() {
    _customReasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final skipReasonsAsync = ref.watch(habitActiveNotDoneReasonsProvider);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 150),
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Center(
        child: SingleChildScrollView(
          child: Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 450),
              decoration: BoxDecoration(
                color: widget.isDark ? const Color(0xFF1A1D22) : Colors.white,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: widget.isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 30,
                    offset: const Offset(0, 15),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Modern Header
                  Stack(
                    children: [
                      Container(
                        padding: const EdgeInsets.fromLTRB(24, 32, 24, 20),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    const Color(0xFFFFB347),
                                    const Color(0xFFFFB347).withOpacity(0.7),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(18),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFFFB347).withOpacity(0.3),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.pause_circle_filled_rounded,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 18),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Skip Habit',
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900,
                                      color: widget.isDark ? Colors.white : const Color(0xFF1E1E1E),
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    widget.habitName,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: widget.isDark ? Colors.white38 : Colors.black38,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        top: 12,
                        right: 12,
                        child: IconButton(
                          onPressed: () => Navigator.pop(context),
                          style: IconButton.styleFrom(
                            backgroundColor: widget.isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
                            padding: const EdgeInsets.all(8),
                          ),
                          icon: Icon(
                            Icons.close_rounded,
                            size: 20,
                            color: widget.isDark ? Colors.white38 : Colors.black38,
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Divider
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Divider(
                      color: widget.isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
                      thickness: 1,
                    ),
                  ),

                  // Content
                  Flexible(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                      child: skipReasonsAsync.when(
                        data: (reasons) => _buildReasonsContent(reasons),
                        loading: () => const SizedBox(
                          height: 200,
                          child: Center(child: CircularProgressIndicator()),
                        ),
                        error: (error, _) => Center(child: Text('Error: $error')),
                      ),
                    ),
                  ),

                  // Footer Actions
                  Container(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pop(context),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: Text(
                              'Maybe Later',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: widget.isDark ? Colors.white38 : Colors.black38,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: _selectedReason != null ? [
                                BoxShadow(
                                  color: const Color(0xFFFFB347).withOpacity(0.3),
                                  blurRadius: 15,
                                  offset: const Offset(0, 6),
                                ),
                              ] : null,
                            ),
                            child: ElevatedButton(
                              onPressed: (_selectedReason == null || (_showCustomInput && _customReasonController.text.trim().isEmpty))
                                  ? null
                                  : () {
                                      final reason = _showCustomInput
                                          ? _customReasonController.text.trim()
                                          : _selectedReason!;
                                      Navigator.pop(context, reason);
                                    },
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                backgroundColor: const Color(0xFFFFB347),
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: widget.isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
                                disabledForegroundColor: widget.isDark ? Colors.white10 : Colors.black12,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 0,
                              ),
                              child: const Text(
                                'Confirm Skip',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
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
        ),
      ),
    );
  }

  Widget _buildReasonsContent(List<HabitReason> reasons) {
    final allReasons = [...reasons, null];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'WHY ARE YOU SKIPPING?',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
            color: widget.isDark ? Colors.white24 : Colors.black26,
          ),
        ),
        const SizedBox(height: 20),
        Flexible(
          child: GridView.builder(
            shrinkWrap: true,
            physics: const BouncingScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 2.2,
            ),
            itemCount: allReasons.length,
            itemBuilder: (context, index) {
              final reason = allReasons[index];
              final isOther = reason == null;
              final label = isOther ? 'Other' : reason.text;
              final icon = isOther ? Icons.edit_note_rounded : (reason.icon ?? Icons.note_rounded);
              final color = isOther ? const Color(0xFF78909C) : reason.color;
              final isSelected = _selectedReason == label;

              return InkWell(
                onTap: () {
                  setState(() {
                    _selectedReason = label;
                    _showCustomInput = isOther;
                  });
                },
                borderRadius: BorderRadius.circular(20),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? color.withOpacity(widget.isDark ? 0.15 : 0.1)
                        : widget.isDark
                            ? Colors.white.withOpacity(0.03)
                            : Colors.black.withOpacity(0.02),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected ? color : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isSelected 
                              ? color.withOpacity(0.2) 
                              : (widget.isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03)),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          icon,
                          color: isSelected ? color : (widget.isDark ? Colors.white38 : Colors.black38),
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          label,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                            color: isSelected
                                ? (widget.isDark ? Colors.white : color)
                                : (widget.isDark ? Colors.white70 : Colors.black87),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        if (_showCustomInput) ...[
          const SizedBox(height: 24),
          Text(
            'SPECIFY REASON',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
              color: widget.isDark ? Colors.white24 : Colors.black26,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _customReasonController,
            autofocus: true,
            maxLength: 60,
            onChanged: (val) => setState(() {}),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: widget.isDark ? Colors.white : Colors.black87,
            ),
            decoration: InputDecoration(
              hintText: 'What happened?',
              hintStyle: TextStyle(
                color: widget.isDark ? Colors.white24 : Colors.black26,
              ),
              counterStyle: TextStyle(
                color: widget.isDark ? Colors.white24 : Colors.black26,
              ),
              filled: true,
              fillColor: widget.isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.02),
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: const BorderSide(
                  color: Color(0xFFFFB347),
                  width: 2,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class HabitDetailSnoozeSheet extends StatelessWidget {
  final List<int> options;
  final int defaultOption;
  final bool isDark;

  const HabitDetailSnoozeSheet({
    super.key,
    required this.options,
    required this.defaultOption,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C2026) : Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF42A5F5).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.snooze_rounded,
                    color: Color(0xFF42A5F5),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Text(
                  'Snooze for...',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF1A1C1E),
                  ),
                ),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ...options.map((minutes) {
                    final isDefault = minutes == defaultOption;
                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => Navigator.pop(context, minutes),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                          child: Row(
                            children: [
                              Icon(
                                isDefault ? Icons.timer_rounded : Icons.timer_outlined,
                                color: isDefault ? const Color(0xFF42A5F5) : (isDark ? Colors.white54 : Colors.black45),
                                size: 22,
                              ),
                              const SizedBox(width: 14),
                              Text(
                                _formatDuration(minutes),
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: isDefault ? FontWeight.w700 : FontWeight.w500,
                                  color: isDark ? Colors.white : const Color(0xFF1A1C1E),
                                ),
                              ),
                              if (isDefault) ...[
                                const SizedBox(width: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF42A5F5).withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'Default',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF42A5F5),
                                    ),
                                  ),
                                ),
                              ],
                              const Spacer(),
                              Icon(
                                Icons.chevron_right_rounded,
                                color: isDark ? Colors.white24 : Colors.black26,
                                size: 22,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: const SizedBox(height: 8),
          ),
        ],
      ),
    );
  }

  String _formatDuration(int minutes) {
    if (minutes < 60) return '$minutes minutes';
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    if (mins == 0) return '$hours ${hours == 1 ? 'hour' : 'hours'}';
    return '$hours hr $mins min';
  }
}

