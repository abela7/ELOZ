import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/services/finance_security_service.dart';

// ---------------------------------------------------------------------------
// Public dialog action types
// ---------------------------------------------------------------------------

enum FinancePasscodeDialogAction { unlock, forgot }

class FinancePasscodeDialogResult {
  final FinancePasscodeDialogAction action;
  final String? passcode;

  const FinancePasscodeDialogResult._({required this.action, this.passcode});

  const FinancePasscodeDialogResult.unlock(String passcode)
    : this._(action: FinancePasscodeDialogAction.unlock, passcode: passcode);

  const FinancePasscodeDialogResult.forgot()
    : this._(action: FinancePasscodeDialogAction.forgot);
}

// ---------------------------------------------------------------------------
// FinanceSecurityDialogs — static entry points
// ---------------------------------------------------------------------------

class FinanceSecurityDialogs {
  /// Create a new 6-digit passcode (enter + confirm).
  static Future<String?> showCreatePasscodeDialog(
    BuildContext context, {
    bool isDark = false,
  }) {
    return _showSecureBlurDialog<String>(
      context: context,
      builder: (_) => _CreatePasscodeDialog(isDark: isDark),
    );
  }

  /// Prompt for an existing passcode. Optionally show "Forgot Passcode?".
  static Future<FinancePasscodeDialogResult?> showEnterPasscodeDialog(
    BuildContext context, {
    required String title,
    required String subtitle,
    bool isDark = false,
    bool showForgotPasscode = false,
  }) {
    return _showSecureBlurDialog<FinancePasscodeDialogResult>(
      context: context,
      builder: (_) => _EnterPasscodeDialog(
        title: title,
        subtitle: subtitle,
        isDark: isDark,
        showForgotPasscode: showForgotPasscode,
      ),
    );
  }

  /// Create a new memorable word (enter + confirm).
  static Future<String?> showCreateMemorableWordDialog(
    BuildContext context, {
    bool isDark = false,
  }) {
    return _showSecureBlurDialog<String>(
      context: context,
      builder: (_) => _CreateMemorableWordDialog(isDark: isDark),
    );
  }

  /// Bank-style character challenge dialog.
  ///
  /// [challenge] contains the positions to ask about.
  /// Returns the map of positions→characters if submitted, or null if cancelled.
  static Future<Map<int, String>?> showCharacterChallengeDialog(
    BuildContext context, {
    required CharacterChallenge challenge,
    required int attemptsRemaining,
    bool isDark = false,
  }) {
    return _showSecureBlurDialog<Map<int, String>>(
      context: context,
      builder: (_) => _CharacterChallengeDialog(
        challenge: challenge,
        attemptsRemaining: attemptsRemaining,
        isDark: isDark,
      ),
    );
  }

  // ---- Shared blur backdrop ----

  static Future<T?> _showSecureBlurDialog<T>({
    required BuildContext context,
    required WidgetBuilder builder,
  }) {
    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Finance security dialog',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 140),
      pageBuilder: (dialogContext, _, secondaryAnimation) {
        secondaryAnimation; // keep for signature completeness
        return Stack(
          children: [
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: ColoredBox(color: Colors.black.withValues(alpha: 0.28)),
              ),
            ),
            Center(child: builder(dialogContext)),
          ],
        );
      },
      transitionBuilder: (dialogContext, animation, _, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(opacity: curved, child: child);
      },
    );
  }
}

// ===========================================================================
// Shared base dialog shell
// ===========================================================================

class _ModernDialog extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget content;
  final List<Widget> actions;
  final bool isDark;
  final IconData? icon;

  const _ModernDialog({
    required this.title,
    this.subtitle,
    required this.content,
    required this.actions,
    required this.isDark,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isDark ? const Color(0xFF1A1F26) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1E1E1E);
    final subtitleColor = isDark ? Colors.white60 : Colors.black54;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.black.withValues(alpha: 0.05),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 40,
              offset: const Offset(0, 20),
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
                child: Column(
                  children: [
                    if (icon != null) ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFFCDAF56,
                          ).withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          icon,
                          size: 28,
                          color: const Color(0xFFCDAF56),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: textColor,
                        letterSpacing: -0.5,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        subtitle!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: subtitleColor,
                          height: 1.4,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                child: content,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: actions.asMap().entries.map((e) {
                    if (e.key > 0) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: e.value,
                      );
                    }
                    return e.value;
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ===========================================================================
// Pin code field (6-digit)
// ===========================================================================

class _PinCodeField extends StatefulWidget {
  final TextEditingController controller;
  final bool isDark;

  const _PinCodeField({
    super.key,
    required this.controller,
    required this.isDark,
  });

  @override
  State<_PinCodeField> createState() => _PinCodeFieldState();
}

class _PinCodeFieldState extends State<_PinCodeField> {
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_update);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _requestFocusAndKeyboard();
    });
  }

  @override
  void dispose() {
    widget.controller.removeListener(_update);
    _focusNode.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _PinCodeField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_update);
      widget.controller.addListener(_update);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _requestFocusAndKeyboard();
      });
    }
  }

  void _requestFocusAndKeyboard() {
    if (!mounted) return;
    FocusScope.of(context).requestFocus(_focusNode);
    Future<void>.delayed(const Duration(milliseconds: 30), () {
      if (!mounted) return;
      SystemChannels.textInput.invokeMethod('TextInput.show');
    });
  }

  void _update() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final text = widget.controller.text;
    final emptyColor = isDark
        ? const Color(0xFF2D3139)
        : Colors.black.withValues(alpha: 0.05);
    const filledColor = Color(0xFFCDAF56);

    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate dynamic width to prevent overflow on small screens
        final totalSpacing = 5 * 8.0; // 5 gaps of 8px
        final itemWidth = (constraints.maxWidth - totalSpacing) / 6;
        final finalItemWidth = itemWidth.clamp(32.0, 48.0);

        return SizedBox(
          height: 64,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: Opacity(
                  opacity: 0.01,
                  child: TextField(
                    controller: widget.controller,
                    focusNode: _focusNode,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    autofocus: false,
                    showCursor: false,
                    enableInteractiveSelection: false,
                    textAlign: TextAlign.center,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: const TextStyle(
                      color: Colors.transparent,
                      fontSize: 1,
                      height: 1,
                    ),
                    cursorColor: Colors.transparent,
                    decoration: const InputDecoration(
                      counterText: '',
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                    onTap: _requestFocusAndKeyboard,
                  ),
                ),
              ),
              IgnorePointer(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(6, (index) {
                    final isFilled = index < text.length;
                    final isCurrent = index == text.length;
                    return Padding(
                      padding: EdgeInsets.only(right: index == 5 ? 0 : 8),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: finalItemWidth,
                        height: 60,
                        decoration: BoxDecoration(
                          color: isFilled
                              ? filledColor.withValues(alpha: 0.12)
                              : emptyColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isCurrent
                                ? filledColor
                                : (isFilled
                                      ? filledColor.withValues(alpha: 0.6)
                                      : (isDark
                                            ? Colors.white.withValues(
                                                alpha: 0.08,
                                              )
                                            : Colors.black.withValues(
                                                alpha: 0.08,
                                              ))),
                            width: isCurrent || isFilled ? 2 : 1.5,
                          ),
                          boxShadow: isCurrent
                              ? [
                                  BoxShadow(
                                    color: filledColor.withValues(alpha: 0.2),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ]
                              : [],
                        ),
                        child: Center(
                          child: isFilled
                              ? Container(
                                  width: 12,
                                  height: 12,
                                  decoration: const BoxDecoration(
                                    color: filledColor,
                                    shape: BoxShape.circle,
                                  ),
                                )
                              : (isCurrent && _focusNode.hasFocus
                                    ? Container(
                                        width: 2,
                                        height: 20,
                                        decoration: BoxDecoration(
                                          color: filledColor,
                                          borderRadius: BorderRadius.circular(
                                            1,
                                          ),
                                        ),
                                      )
                                    : null),
                        ),
                      ),
                    );
                  }),
                ),
              ),
              Positioned.fill(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _requestFocusAndKeyboard,
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ===========================================================================
// Modern text field
// ===========================================================================

class _ModernTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool isDark;
  final ValueChanged<String>? onSubmitted;
  final IconData? prefixIcon;
  final int? maxLength;
  final bool obscureText;
  final Widget? suffix;

  const _ModernTextField({
    required this.controller,
    required this.hint,
    required this.isDark,
    this.onSubmitted,
    this.prefixIcon,
    this.maxLength,
    this.obscureText = false,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLength: maxLength,
      obscureText: obscureText,
      style: TextStyle(
        fontSize: 16,
        color: isDark ? Colors.white : const Color(0xFF1E1E1E),
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          color: isDark ? Colors.white30 : Colors.black38,
          fontWeight: FontWeight.w500,
        ),
        counterText: '',
        prefixIcon: prefixIcon != null
            ? Container(
                margin: const EdgeInsets.only(left: 12, right: 8),
                padding: const EdgeInsets.all(8),
                child: Icon(
                  prefixIcon,
                  color: isDark
                      ? const Color(0xFFCDAF56).withValues(alpha: 0.7)
                      : const Color(0xFFCDAF56),
                  size: 20,
                ),
              )
            : null,
        suffixIcon: suffix != null
            ? Padding(padding: const EdgeInsets.only(right: 16), child: suffix)
            : null,
        suffixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        filled: true,
        fillColor: isDark ? const Color(0xFF2D3139) : Colors.grey.shade50,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 18,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.black.withValues(alpha: 0.05),
            width: 1,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.black.withValues(alpha: 0.05),
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: Color(0xFFCDAF56), width: 2),
        ),
      ),
      onSubmitted: onSubmitted,
    );
  }
}

// ===========================================================================
// Create Passcode Dialog (2-step)
// ===========================================================================

class _CreatePasscodeDialog extends StatefulWidget {
  final bool isDark;
  const _CreatePasscodeDialog({required this.isDark});

  @override
  State<_CreatePasscodeDialog> createState() => _CreatePasscodeDialogState();
}

class _CreatePasscodeDialogState extends State<_CreatePasscodeDialog> {
  final _firstController = TextEditingController();
  final _confirmController = TextEditingController();
  String? _error;
  int _step = 1;

  @override
  void dispose() {
    _firstController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_firstController.text.trim().length != 6) {
      setState(() => _error = 'Enter 6 digits');
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _error = null;
      _step = 2;
      _confirmController.clear();
    });
  }

  void _submit() {
    final first = _firstController.text.trim();
    final confirm = _confirmController.text.trim();
    if (confirm.length != 6) {
      setState(() => _error = 'Enter 6 digits');
      return;
    }
    if (first != confirm) {
      setState(() {
        _error = 'Passcodes do not match. Try again.';
        _step = 1;
        _firstController.clear();
        _confirmController.clear();
      });
      return;
    }
    Navigator.of(context).pop(first);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    return _ModernDialog(
      isDark: isDark,
      icon: Icons.lock_outline_rounded,
      title: _step == 1 ? 'Create Passcode' : 'Confirm Passcode',
      subtitle: _step == 1
          ? 'Enter a 6-digit code to protect your finances.'
          : 'Re-enter your passcode to confirm.',
      content: Column(
        children: [
          if (_step == 1)
            _PinCodeField(
              key: const ValueKey('finance_passcode_step_1'),
              controller: _firstController,
              isDark: isDark,
            )
          else
            _PinCodeField(
              key: const ValueKey('finance_passcode_step_2'),
              controller: _confirmController,
              isDark: isDark,
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 24),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF5252).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _error!,
                  style: const TextStyle(
                    color: Color(0xFFFF5252),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
      actions: [
        ElevatedButton(
          onPressed: _step == 1 ? _nextStep : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFCDAF56),
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 0,
          ),
          child: Text(
            _step == 1 ? 'Continue' : 'Save Passcode',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(
            foregroundColor: isDark ? Colors.white38 : Colors.black38,
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
          child: const Text(
            'Cancel',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

// ===========================================================================
// Enter Passcode Dialog
// ===========================================================================

class _EnterPasscodeDialog extends StatefulWidget {
  final String title;
  final String subtitle;
  final bool isDark;
  final bool showForgotPasscode;

  const _EnterPasscodeDialog({
    required this.title,
    required this.subtitle,
    required this.isDark,
    required this.showForgotPasscode,
  });

  @override
  State<_EnterPasscodeDialog> createState() => _EnterPasscodeDialogState();
}

class _EnterPasscodeDialogState extends State<_EnterPasscodeDialog> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (_controller.text.trim().length != 6) {
      setState(() => _error = 'Enter 6 digits');
      return;
    }
    Navigator.of(
      context,
    ).pop(FinancePasscodeDialogResult.unlock(_controller.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    return _ModernDialog(
      isDark: isDark,
      icon: Icons.lock_open_rounded,
      title: widget.title,
      subtitle: widget.subtitle,
      content: Column(
        children: [
          _PinCodeField(controller: _controller, isDark: isDark),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 24),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF5252).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _error!,
                  style: const TextStyle(
                    color: Color(0xFFFF5252),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
      actions: [
        ElevatedButton(
          onPressed: _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFCDAF56),
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 0,
          ),
          child: const Text(
            'Unlock',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
        ),
        if (widget.showForgotPasscode)
          TextButton(
            onPressed: () =>
                Navigator.of(context).pop(FinancePasscodeDialogResult.forgot()),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFFF5252),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            child: const Text(
              'Forgot Passcode?',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(
            foregroundColor: isDark ? Colors.white38 : Colors.black38,
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
          child: const Text(
            'Cancel',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

// ===========================================================================
// Create Memorable Word Dialog
// ===========================================================================

class _CreateMemorableWordDialog extends StatefulWidget {
  final bool isDark;
  const _CreateMemorableWordDialog({required this.isDark});

  @override
  State<_CreateMemorableWordDialog> createState() =>
      _CreateMemorableWordDialogState();
}

class _CreateMemorableWordDialogState
    extends State<_CreateMemorableWordDialog> {
  final _firstController = TextEditingController();
  final _confirmController = TextEditingController();
  String? _error;

  @override
  void initState() {
    super.initState();
    _firstController.addListener(_onTextChanged);
    _confirmController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _firstController.removeListener(_onTextChanged);
    _confirmController.removeListener(_onTextChanged);
    _firstController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _onTextChanged() => setState(() {});

  String _normalize(String value) {
    return value.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
  }

  void _submit() {
    final first = _normalize(_firstController.text);
    final confirm = _normalize(_confirmController.text);

    if (first.length < FinanceSecurityService.minMemorableWordLength ||
        first.length > FinanceSecurityService.maxMemorableWordLength) {
      setState(
        () => _error =
            'Must be ${FinanceSecurityService.minMemorableWordLength}-'
            '${FinanceSecurityService.maxMemorableWordLength} characters.',
      );
      return;
    }
    if (!RegExp(r'[a-zA-Z]').hasMatch(first)) {
      setState(() => _error = 'Must include letters.');
      return;
    }
    if (first != confirm) {
      setState(() => _error = 'Words do not match.');
      return;
    }
    Navigator.of(context).pop(first);
  }

  @override
  Widget build(BuildContext context) {
    final charCount = _normalize(_firstController.text).length;
    final isLengthValid =
        charCount >= FinanceSecurityService.minMemorableWordLength &&
        charCount <= FinanceSecurityService.maxMemorableWordLength;
    final isDark = widget.isDark;

    return _ModernDialog(
      isDark: isDark,
      icon: Icons.shield_rounded,
      title: 'Create Memorable Word',
      subtitle:
          'This word will be used in case you forget your passcode. Keep it somewhere else as a backup.',
      content: Column(
        children: [
          _ModernTextField(
            controller: _firstController,
            hint: 'Enter memorable word',
            isDark: isDark,
            prefixIcon: Icons.key_rounded,
            maxLength: FinanceSecurityService.maxMemorableWordLength,
            suffix: Text(
              '$charCount/${FinanceSecurityService.maxMemorableWordLength}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: isLengthValid
                    ? const Color(0xFF4CAF50)
                    : (isDark ? Colors.white24 : Colors.black26),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _ModernTextField(
            controller: _confirmController,
            hint: 'Confirm memorable word',
            isDark: isDark,
            prefixIcon: Icons.check_circle_outline_rounded,
            maxLength: FinanceSecurityService.maxMemorableWordLength,
            onSubmitted: (_) => _submit(),
          ),

          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF5252).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _error!,
                  style: const TextStyle(
                    color: Color(0xFFFF5252),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
      actions: [
        ElevatedButton(
          onPressed: _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFCDAF56),
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 0,
          ),
          child: const Text(
            'Save Memorable Word',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(
            foregroundColor: isDark ? Colors.white38 : Colors.black38,
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
          child: const Text(
            'Cancel',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

// ===========================================================================
// Bank-style Character Challenge Dialog
// ===========================================================================

class _CharacterChallengeDialog extends StatefulWidget {
  final CharacterChallenge challenge;
  final int attemptsRemaining;
  final bool isDark;

  const _CharacterChallengeDialog({
    required this.challenge,
    required this.attemptsRemaining,
    required this.isDark,
  });

  @override
  State<_CharacterChallengeDialog> createState() =>
      _CharacterChallengeDialogState();
}

class _CharacterChallengeDialogState extends State<_CharacterChallengeDialog> {
  late final List<TextEditingController> _controllers;
  late final List<FocusNode> _focusNodes;
  String? _error;

  @override
  void initState() {
    super.initState();
    final count = widget.challenge.positions.length;
    _controllers = List.generate(count, (_) => TextEditingController());
    _focusNodes = List.generate(count, (_) => FocusNode());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _focusNodes.isNotEmpty) {
        FocusScope.of(context).requestFocus(_focusNodes[0]);
      }
    });
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _submit() {
    final result = <int, String>{};
    for (var i = 0; i < widget.challenge.positions.length; i++) {
      final text = _controllers[i].text.trim().toLowerCase();
      if (text.length != 1) {
        setState(() => _error = 'Enter exactly one character for each field.');
        return;
      }
      result[widget.challenge.positions[i]] = text;
    }
    Navigator.of(context).pop(result);
  }

  String _ordinal(int n) {
    if (n >= 11 && n <= 13) return '${n}th';
    switch (n % 10) {
      case 1:
        return '${n}st';
      case 2:
        return '${n}nd';
      case 3:
        return '${n}rd';
      default:
        return '${n}th';
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayPositions = widget.challenge.displayPositions;
    final isDark = widget.isDark;
    final warningColor = widget.attemptsRemaining <= 1
        ? const Color(0xFFFF5252)
        : const Color(0xFFFFAB40);

    return _ModernDialog(
      isDark: isDark,
      icon: Icons.security_rounded,
      title: 'Security Verification',
      subtitle:
          'Enter the characters of your memorable word at the positions shown below.',
      content: Column(
        children: [
          // Warning banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: warningColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: warningColor.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(
                    Icons.warning_amber_rounded,
                    color: warningColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    widget.attemptsRemaining <= 1
                        ? 'LAST ATTEMPT — all finance data will be permanently deleted on failure.'
                        : '${widget.attemptsRemaining} attempts remaining before all finance data is permanently deleted.',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: warningColor,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Character input fields
          ...List.generate(displayPositions.length, (i) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Row(
                children: [
                  Container(
                    width: 110,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : Colors.black.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_ordinal(displayPositions[i])} char',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white70 : Colors.black87,
                        letterSpacing: -0.2,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: SizedBox(
                      height: 60,
                      child: TextField(
                        controller: _controllers[i],
                        focusNode: _focusNodes[i],
                        maxLength: 1,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF1E1E1E),
                        ),
                        decoration: InputDecoration(
                          counterText: '',
                          filled: true,
                          fillColor: isDark
                              ? const Color(0xFF2D3139)
                              : Colors.grey.shade50,
                          contentPadding: EdgeInsets.zero,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: BorderSide(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.05)
                                  : Colors.black.withValues(alpha: 0.05),
                              width: 1,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: BorderSide(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.05)
                                  : Colors.black.withValues(alpha: 0.05),
                              width: 1,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: const BorderSide(
                              color: Color(0xFFCDAF56),
                              width: 2,
                            ),
                          ),
                        ),
                        onChanged: (value) {
                          if (value.isNotEmpty && i < _focusNodes.length - 1) {
                            FocusScope.of(
                              context,
                            ).requestFocus(_focusNodes[i + 1]);
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),

          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF5252).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _error!,
                  style: const TextStyle(
                    color: Color(0xFFFF5252),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
      actions: [
        ElevatedButton(
          onPressed: _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFCDAF56),
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 0,
          ),
          child: const Text(
            'Verify Identity',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(
            foregroundColor: isDark ? Colors.white38 : Colors.black38,
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
          child: const Text(
            'Cancel',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
