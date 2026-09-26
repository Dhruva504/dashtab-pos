import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../theme/app_icons.dart';

/// Full-screen PIN entry used by the app lock and the POS quick-login gate.
///
/// [onSubmit] receives the entered digits; return true to accept, false to
/// show an error and clear the entry.
class PinPadScreen extends StatefulWidget {
  final String title;
  final String subtitle;
  final bool Function(String pin) onSubmit;
  final Widget? footer;
  final IconData icon;

  const PinPadScreen({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onSubmit,
    this.footer,
    this.icon = AppIcons.lock,
  });

  @override
  State<PinPadScreen> createState() => _PinPadScreenState();
}

class _PinPadScreenState extends State<PinPadScreen> {
  String _pin = '';
  bool _error = false;

  static const _maxLen = 8;

  void _append(String d) {
    if (_pin.length >= _maxLen) return;
    setState(() {
      _error = false;
      _pin += d;
    });
  }

  void _backspace() {
    if (_pin.isEmpty) return;
    setState(() {
      _error = false;
      _pin = _pin.substring(0, _pin.length - 1);
    });
  }

  void _submit() {
    if (_pin.length < 4) {
      setState(() => _error = true);
      return;
    }
    final ok = widget.onSubmit(_pin);
    if (!ok) {
      setState(() {
        _error = true;
        _pin = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sub = isDark ? AppColors.darkText2 : AppColors.text2;
    final card = isDark ? AppColors.darkCard : AppColors.card;

    Widget key(String label, {VoidCallback? onTap, IconData? icon}) {
      return SizedBox(
        width: 72,
        height: 58,
        child: Material(
          color: isDark ? AppColors.darkCard2 : AppColors.card2,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: Center(
              child: icon != null
                  ? Icon(icon, size: 20, color: isDark ? AppColors.darkText : AppColors.text)
                  : Text(
                      label,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ),
      );
    }

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Container(
          width: 380,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: card,
            borderRadius: BorderRadius.circular(20),
            boxShadow: AppTheme.shadowLg,
            border: Border.all(
              color: isDark ? AppColors.darkLine : AppColors.line,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF8A4C), AppColors.brand],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(widget.icon, color: Colors.white, size: 24),
              ),
              const SizedBox(height: 14),
              Text(widget.title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                _error ? 'Wrong PIN — try again' : widget.subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.5,
                  color: _error ? AppColors.red : sub,
                ),
              ),
              const SizedBox(height: 18),
              // Entry dots
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < _pin.length; i++)
                    Container(
                      width: 12,
                      height: 12,
                      margin: const EdgeInsets.symmetric(horizontal: 5),
                      decoration: BoxDecoration(
                        color: _error
                            ? AppColors.red
                            : isDark
                                ? AppColors.darkText
                                : AppColors.text,
                        shape: BoxShape.circle,
                      ),
                    ),
                  if (_pin.isEmpty)
                    Text(
                      'Enter PIN',
                      style: TextStyle(fontSize: 12, color: sub),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              for (final row in const [
                ['1', '2', '3'],
                ['4', '5', '6'],
                ['7', '8', '9'],
              ])
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (final l in row) ...[
                        key(l, onTap: () => _append(l)),
                        const SizedBox(width: 10),
                      ],
                    ],
                  ),
                ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  key('', icon: AppIcons.x, onTap: _backspace),
                  const SizedBox(width: 10),
                  key('0', onTap: () => _append('0')),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 72,
                    height: 58,
                    child: ElevatedButton(
                      onPressed: _pin.isEmpty ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Icon(AppIcons.check, size: 20),
                    ),
                  ),
                ],
              ),
              if (widget.footer != null) ...[
                const SizedBox(height: 14),
                widget.footer!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
