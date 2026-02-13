import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/services/quit_habit_report_security_service.dart';

enum QuitHabitPasscodeDialogAction { unlock, forgot }

class QuitHabitPasscodeDialogResult {
  final QuitHabitPasscodeDialogAction action;
  final String? passcode;

  const QuitHabitPasscodeDialogResult._({required this.action, this.passcode});

  const QuitHabitPasscodeDialogResult.unlock(String passcode)
    : this._(action: QuitHabitPasscodeDialogAction.unlock, passcode: passcode);

  const QuitHabitPasscodeDialogResult.forgot()
    : this._(action: QuitHabitPasscodeDialogAction.forgot);
}

class QuitHabitReportPasscodeDialogs {
  static Future<String?> showCreatePasscodeDialog(
    BuildContext context, {
    bool isDark = false,
  }) async {
    return _showSecureBlurDialog<String>(
      context: context,
      builder: (_) => _CreatePasscodeDialog(isDark: isDark),
    );
  }

  static Future<QuitHabitPasscodeDialogResult?> showEnterPasscodeDialog(
    BuildContext context, {
    required String title,
    required String subtitle,
    bool isDark = false,
    bool showForgotPasscode = false,
  }) async {
    return _showSecureBlurDialog<QuitHabitPasscodeDialogResult>(
      context: context,
      builder: (_) => _EnterPasscodeDialog(
        title: title,
        subtitle: subtitle,
        isDark: isDark,
        showForgotPasscode: showForgotPasscode,
      ),
    );
  }

  static Future<String?> showCreateRecoveryWordDialog(
    BuildContext context, {
    bool isDark = false,
  }) async {
    return _showSecureBlurDialog<String>(
      context: context,
      builder: (_) => _CreateRecoveryWordDialog(isDark: isDark),
    );
  }

  static Future<String?> showEnterRecoveryWordDialog(
    BuildContext context, {
    required String title,
    required String subtitle,
    bool isDark = false,
  }) async {
    return _showSecureBlurDialog<String>(
      context: context,
      builder: (_) => _EnterRecoveryWordDialog(
        title: title,
        subtitle: subtitle,
        isDark: isDark,
      ),
    );
  }

  static Future<T?> _showSecureBlurDialog<T>({
    required BuildContext context,
    required WidgetBuilder builder,
  }) {
    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Secure lock dialog',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 140),
      pageBuilder: (dialogContext, _, secondaryAnimation) {
        // Keep parameter for signature completeness.
        secondaryAnimation;
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
    final bgColor = isDark ? const Color(0xFF1E1E2C) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF2D3436);
    final subtitleColor = isDark ? Colors.white54 : Colors.black54;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 20,
              offset: const Offset(0, 10),
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
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFCDAF56).withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          icon,
                          size: 32,
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
                        fontWeight: FontWeight.w700,
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
                          fontSize: 15,
                          color: subtitleColor,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Padding(padding: const EdgeInsets.all(24), child: content),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: actions.map((a) {
                    // Add spacing between actions if there are multiple
                    if (actions.indexOf(a) > 0) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: a,
                      );
                    }
                    return a;
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
    // Auto-focus after first frame to ensure dialog transition is done.
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

  void _update() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final text = widget.controller.text;
    final emptyColor = isDark
        ? Colors.white12
        : Colors.black.withValues(alpha: 0.05);
    final filledColor = const Color(0xFFCDAF56);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 52,
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
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(6, (index) {
                    final isFilled = index < text.length;
                    final isCurrent = index == text.length;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 44,
                      height: 52,
                      decoration: BoxDecoration(
                        color: isFilled
                            ? filledColor.withValues(alpha: 0.1)
                            : emptyColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isCurrent
                              ? filledColor
                              : (isFilled
                                    ? filledColor.withValues(alpha: 0.5)
                                    : (isDark
                                          ? Colors.white10
                                          : Colors.black12)),
                          width: isCurrent || isFilled ? 2 : 1,
                        ),
                      ),
                      child: Center(
                        child: isFilled
                            ? Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: filledColor,
                                  shape: BoxShape.circle,
                                ),
                              )
                            : (isCurrent && _focusNode.hasFocus
                                  ? Container(
                                      width: 2,
                                      height: 20,
                                      color: filledColor,
                                    )
                                  : null),
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
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ModernTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool isDark;
  final ValueChanged<String>? onSubmitted;
  final IconData? prefixIcon;

  const _ModernTextField({
    required this.controller,
    required this.hint,
    required this.isDark,
    this.onSubmitted,
    this.prefixIcon,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      style: TextStyle(
        fontSize: 16,
        color: isDark ? Colors.white : Colors.black87,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: isDark ? Colors.white30 : Colors.black38),
        prefixIcon: prefixIcon != null
            ? Icon(
                prefixIcon,
                color: isDark ? Colors.white38 : Colors.black38,
                size: 20,
              )
            : null,
        filled: true,
        fillColor: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.grey.shade100,
        contentPadding: const EdgeInsets.all(16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFCDAF56), width: 2),
        ),
      ),
      onSubmitted: onSubmitted,
    );
  }
}

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
  int _step = 1; // 1: Enter, 2: Confirm

  @override
  void dispose() {
    _firstController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _nextStep() {
    final first = _firstController.text.trim();
    if (first.length != 6) {
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
    return _ModernDialog(
      isDark: widget.isDark,
      icon: Icons.lock_outline_rounded,
      title: _step == 1 ? 'Create Passcode' : 'Confirm Passcode',
      subtitle: _step == 1
          ? 'Enter a 6-digit code to protect your report.'
          : 'Re-enter your passcode to confirm.',
      content: Column(
        children: [
          if (_step == 1)
            _PinCodeField(
              key: const ValueKey('create_passcode_step_1'),
              controller: _firstController,
              isDark: widget.isDark,
            )
          else
            _PinCodeField(
              key: const ValueKey('create_passcode_step_2'),
              controller: _confirmController,
              isDark: widget.isDark,
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(
                _error!,
                style: const TextStyle(
                  color: Color(0xFFFF5252),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
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
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(
            foregroundColor: widget.isDark ? Colors.white54 : Colors.black54,
          ),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

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
    final value = _controller.text.trim();
    if (value.length != 6) {
      setState(() => _error = 'Enter 6 digits');
      return;
    }
    Navigator.of(context).pop(QuitHabitPasscodeDialogResult.unlock(value));
  }

  @override
  Widget build(BuildContext context) {
    return _ModernDialog(
      isDark: widget.isDark,
      icon: Icons.lock_open_rounded,
      title: widget.title,
      subtitle: widget.subtitle,
      content: Column(
        children: [
          _PinCodeField(controller: _controller, isDark: widget.isDark),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(
                _error!,
                style: const TextStyle(
                  color: Color(0xFFFF5252),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
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
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ),
        if (widget.showForgotPasscode)
          TextButton(
            onPressed: () => Navigator.of(
              context,
            ).pop(const QuitHabitPasscodeDialogResult.forgot()),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFFF5252),
            ),
            child: const Text('Forgot Passcode?'),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(
            foregroundColor: widget.isDark ? Colors.white54 : Colors.black54,
          ),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

class _CreateRecoveryWordDialog extends StatefulWidget {
  final bool isDark;

  const _CreateRecoveryWordDialog({required this.isDark});

  @override
  State<_CreateRecoveryWordDialog> createState() =>
      _CreateRecoveryWordDialogState();
}

class _CreateRecoveryWordDialogState extends State<_CreateRecoveryWordDialog> {
  final _firstController = TextEditingController();
  final _confirmController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _firstController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  String _normalize(String value) {
    return value.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
  }

  void _submit() {
    final first = _normalize(_firstController.text);
    final confirm = _normalize(_confirmController.text);

    final minLength = QuitHabitReportSecurityService.minRecoveryWordLength;
    final maxLength = QuitHabitReportSecurityService.maxRecoveryWordLength;

    if (first.length < minLength || first.length > maxLength) {
      setState(() => _error = 'Word must be $minLength-$maxLength characters.');
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
    return _ModernDialog(
      isDark: widget.isDark,
      icon: Icons.shield_rounded,
      title: 'Set Recovery Word',
      subtitle:
          'If you forget your passcode, this word will unlock your report.',
      content: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFAB40).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFFFFAB40).withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: Color(0xFFFFAB40),
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Write this down. It cannot be viewed later.',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: widget.isDark
                          ? const Color(0xFFFFD54F)
                          : const Color(0xFFE65100),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _ModernTextField(
            controller: _firstController,
            hint: 'Enter secret word',
            isDark: widget.isDark,
            prefixIcon: Icons.key_rounded,
          ),
          const SizedBox(height: 12),
          _ModernTextField(
            controller: _confirmController,
            hint: 'Confirm secret word',
            isDark: widget.isDark,
            prefixIcon: Icons.check_circle_outline_rounded,
            onSubmitted: (_) => _submit(),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(
                _error!,
                style: const TextStyle(
                  color: Color(0xFFFF5252),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
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
            'Save Recovery Word',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(
            foregroundColor: widget.isDark ? Colors.white54 : Colors.black54,
          ),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

class _EnterRecoveryWordDialog extends StatefulWidget {
  final String title;
  final String subtitle;
  final bool isDark;

  const _EnterRecoveryWordDialog({
    required this.title,
    required this.subtitle,
    required this.isDark,
  });

  @override
  State<_EnterRecoveryWordDialog> createState() =>
      _EnterRecoveryWordDialogState();
}

class _EnterRecoveryWordDialogState extends State<_EnterRecoveryWordDialog> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _controller.text.trim();
    if (value.isEmpty) {
      setState(() => _error = 'Enter your recovery word.');
      return;
    }
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return _ModernDialog(
      isDark: widget.isDark,
      icon: Icons.security_rounded,
      title: widget.title,
      subtitle: widget.subtitle,
      content: Column(
        children: [
          _ModernTextField(
            controller: _controller,
            hint: 'Enter your recovery word',
            isDark: widget.isDark,
            prefixIcon: Icons.vpn_key_rounded,
            onSubmitted: (_) => _submit(),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(
                _error!,
                style: const TextStyle(
                  color: Color(0xFFFF5252),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
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
            'Verify',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(
            foregroundColor: widget.isDark ? Colors.white54 : Colors.black54,
          ),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
