import 'dart:async';

import 'package:flutter/material.dart';
import 'app_theme.dart';
import 'app_icons.dart';

/// Pill / status badge like `.pill` in the HTML.
class Pill extends StatelessWidget {
  final String label;
  final Color? color;
  final Color? background;
  final IconData? icon;
  final bool dot;
  final double fontSize;

  const Pill(
    this.label, {
    super.key,
    this.color,
    this.background,
    this.icon,
    this.dot = false,
    this.fontSize = 11,
  });

  const Pill.pending(this.label, {super.key})
    : color = AppColors.amber,
      background = AppColors.amberT,
      icon = null,
      dot = false,
      fontSize = 11;
  const Pill.preparing(this.label, {super.key})
    : color = AppColors.blue,
      background = AppColors.blueT,
      icon = null,
      dot = false,
      fontSize = 11;
  const Pill.ready(this.label, {super.key})
    : color = AppColors.teal,
      background = AppColors.tealT,
      icon = null,
      dot = false,
      fontSize = 11;
  const Pill.paid(this.label, {super.key})
    : color = AppColors.green,
      background = AppColors.greenT,
      icon = null,
      dot = false,
      fontSize = 11;
  const Pill.cancel(this.label, {super.key})
    : color = AppColors.red,
      background = AppColors.redT,
      icon = null,
      dot = false,
      fontSize = 11;
  const Pill.reserved(this.label, {super.key})
    : color = AppColors.violet,
      background = AppColors.violetT,
      icon = null,
      dot = false,
      fontSize = 11;
  const Pill.free(this.label, {super.key})
    : color = null,
      background = null,
      icon = null,
      dot = false,
      fontSize = 11;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveColor =
        color ?? (isDark ? AppColors.darkText2 : AppColors.text2);
    final effectiveBg =
        background ?? (isDark ? AppColors.darkLine2 : AppColors.line2);
    // Align relaxes tight flex constraints (Expanded cells) so the pill
    // hugs its label instead of stretching across the whole cell.
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: effectiveBg,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: effectiveColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
          ],
          if (icon != null) ...[
            Icon(icon, size: 12, color: effectiveColor),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.02,
                color: effectiveColor,
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }
}

/// Delta badge (▲ up / ▼ down) matching `.delta` in the HTML.
class Delta extends StatelessWidget {
  final String label;
  final bool up;

  const Delta(this.label, {super.key, this.up = true});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: up ? AppColors.greenT : AppColors.redT,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        '${up ? '▲' : '▼'} $label',
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          color: up ? AppColors.green : AppColors.red,
        ),
      ),
    );
  }
}

/// Card wrapper using the brand shadow + radius.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final VoidCallback? onTap;
  final Color? color;
  final BorderRadius? borderRadius;
  final BorderSide? border;

  const AppCard({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.margin = EdgeInsets.zero,
    this.onTap,
    this.color,
    this.borderRadius,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final radius = borderRadius ?? BorderRadius.circular(AppColors.r);
    final side =
        border ??
        BorderSide(color: isDark ? AppColors.darkLine : AppColors.line);
    final content = Container(
      padding: padding,
      constraints: const BoxConstraints(),
      child: child,
    );
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: color ?? (isDark ? AppColors.darkCard : AppColors.card),
        borderRadius: radius,
        border: Border.fromBorderSide(side),
        boxShadow: AppTheme.shadow,
      ),
      child: onTap != null
          ? InkWell(onTap: onTap, borderRadius: radius, child: content)
          : content,
    );
  }
}

/// Card with a header row (`.card-h`) and optional body.
class SectionCard extends StatelessWidget {
  final String? title;
  final Widget? titleWidget;
  final Widget? trailing;
  final Widget child;
  final EdgeInsetsGeometry bodyPadding;
  final EdgeInsetsGeometry headerPadding;

  const SectionCard({
    super.key,
    this.title,
    this.titleWidget,
    this.trailing,
    required this.child,
    this.bodyPadding = const EdgeInsets.all(16),
    this.headerPadding = const EdgeInsets.symmetric(
      horizontal: 20,
      vertical: 16,
    ),
  });

  @override
  Widget build(BuildContext context) {
    final showHeader = title != null || titleWidget != null || trailing != null;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showHeader)
            Container(
              padding: headerPadding,
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? AppColors.darkLine2
                        : AppColors.line2,
                  ),
                ),
              ),
              // Wide windows: title left, controls right. Narrow windows
              // stack them so the controls never overflow the card.
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final titleRow = titleWidget ??
                      Text(
                        title!,
                        style: Theme.of(context).textTheme.titleMedium,
                      );
                  if (constraints.maxWidth < 720) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        titleRow,
                        if (trailing != null) ...[
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [trailing!],
                            ),
                          ),
                        ],
                      ],
                    );
                  }
                  return Row(
                    children: [
                      titleRow,
                      const Spacer(),
                      ?trailing,
                    ],
                  );
                },
              ),
            ),
          Padding(padding: bodyPadding, child: child),
        ],
      ),
    );
  }
}

/// Selectable chip like `.chip` in the HTML.
class FilterChipBtn extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final double height;
  final double horizontalPadding;

  const FilterChipBtn({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.height = 34,
    this.horizontalPadding = 15,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(99),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: height,
        padding: EdgeInsets.symmetric(
          horizontal: horizontalPadding,
          vertical: ((height - 18) / 2).clamp(3.0, 8.0),
        ),
        // No `alignment` here: inside a Wrap a bounded-width constraint
        // with alignment expands the chip to the full row width.
        decoration: BoxDecoration(
          // Brand pill for the active filter; quiet outlined pill otherwise.
          color: selected
              ? AppColors.brand
              : (isDark ? AppColors.darkCard : AppColors.card),
          border: Border.all(
            color: selected
                ? AppColors.brand
                : (isDark ? AppColors.darkLine : AppColors.line),
          ),
          borderRadius: BorderRadius.circular(99),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: height <= 30 ? 11.5 : 12.5,
            fontWeight: FontWeight.w700,
            color: selected
                ? Colors.white
                : (isDark ? AppColors.darkText2 : AppColors.text2),
          ),
        ),
      ),
    );
  }
}

/// Segmented control like `.seg` in the HTML.
class Segmented extends StatelessWidget {
  final List<Widget> options;
  final int selectedIndex;
  final ValueChanged<int> onChanged;
  final bool brand;

  const Segmented({
    super.key,
    required this.options,
    required this.selectedIndex,
    required this.onChanged,
    this.brand = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard2 : AppColors.card2,
        border: Border.all(color: isDark ? AppColors.darkLine : AppColors.line),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: List.generate(options.length, (i) {
          final selected = i == selectedIndex;
          return Expanded(
            child: InkWell(
              onTap: () => onChanged(i),
              borderRadius: BorderRadius.circular(9),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                decoration: BoxDecoration(
                  color: selected
                      ? (brand
                            ? AppColors.brand
                            : isDark
                            ? AppColors.darkCard
                            : AppColors.card)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                  boxShadow: selected && !brand
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: DefaultTextStyle(
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: selected
                        ? (brand
                              ? Colors.white
                              : isDark
                              ? AppColors.darkText
                              : AppColors.text)
                        : (isDark ? AppColors.darkText2 : AppColors.text2),
                  ),
                  child: options[i],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

/// Empty state like `.empty-cta` in the HTML.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard2 : AppColors.card2,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(
                icon,
                size: 28,
                color: isDark ? AppColors.darkText3 : AppColors.text3,
              ),
            ),
            const SizedBox(height: 16),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            if (message != null) ...[
              const SizedBox(height: 6),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isDark ? AppColors.darkText2 : AppColors.text2,
                  fontSize: 13,
                ),
              ),
            ],
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}

/// Toggle switch like `.switch` in the HTML.
class AppSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const AppSwitch({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 42,
        height: 24,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: value
              ? AppColors.green
              : (Theme.of(context).brightness == Brightness.dark
                    ? AppColors.darkLine
                    : AppColors.line),
          borderRadius: BorderRadius.circular(99),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 200),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 18,
            height: 18,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 5,
                  offset: Offset(0, 2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A modal bottom-up / centered overlay like `.modal` in the HTML.
class AppModal extends StatelessWidget {
  final String title;
  final Widget body;
  final List<Widget>? actions;
  final bool wide;

  const AppModal({
    super.key,
    required this.title,
    required this.body,
    this.actions,
    this.wide = false,
  });

  static Future<T?> show<T>(BuildContext context, AppModal modal) {
    return showDialog<T>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (_) => modal,
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = wide ? 760.0 : 560.0;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Dialog(
      backgroundColor: isDark ? AppColors.darkCard : AppColors.card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: width,
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: isDark ? AppColors.darkLine2 : AppColors.line2,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    borderRadius: BorderRadius.circular(9),
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Icon(
                        AppIcons.x,
                        size: 20,
                        color: isDark ? AppColors.darkText3 : AppColors.text3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(22),
                child: body,
              ),
            ),
            if (actions != null && actions!.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: isDark ? AppColors.darkLine2 : AppColors.line2,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    for (var i = 0; i < actions!.length; i++) ...[
                      if (i > 0) const SizedBox(width: 10),
                      actions![i],
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Avatar with initials like `.avatar` in the HTML.
class Avatar extends StatelessWidget {
  final String name;
  final double size;
  final double radius;

  const Avatar({
    super.key,
    required this.name,
    this.size = 36,
    this.radius = 10,
  });

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFF8A4C), AppColors.brand],
        ),
        borderRadius: BorderRadius.circular(radius),
      ),
      alignment: Alignment.center,
      child: Text(
        _initials,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: size * 0.35,
        ),
      ),
    );
  }
}

/// Divider row for totals like `.t-row` in the cart.
class TotalRow extends StatelessWidget {
  final String label;
  final String value;
  final bool total;
  final bool free;
  final double fontSize;

  const TotalRow(
    this.label,
    this.value, {
    super.key,
    this.total = false,
    this.free = false,
    this.fontSize = 13,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: total ? const EdgeInsets.only(top: 10) : EdgeInsets.zero,
      decoration: total
          ? BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: isDark ? AppColors.darkLine : AppColors.line,
                  width: 1.2,
                ),
              ),
            )
          : null,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: total ? FontWeight.w800 : FontWeight.w400,
              color: free
                  ? AppColors.green
                  : total
                  ? (isDark ? AppColors.darkText : AppColors.text)
                  : (isDark ? AppColors.darkText2 : AppColors.text2),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: total ? fontSize + 3 : fontSize,
              fontWeight: total ? FontWeight.w800 : FontWeight.w400,
              color: free
                  ? AppColors.green
                  : total
                  ? (isDark ? AppColors.darkText : AppColors.text)
                  : (isDark ? AppColors.darkText2 : AppColors.text2),
            ),
          ),
        ],
      ),
    );
  }
}

/// Matches subtitles that announce a delay in seconds, e.g. "Deleting in 5s".
final RegExp _toastSecondsPattern = RegExp(r'^(.*?)(\d+)s$');

/// Design-style toast (dark pill, icon chip, bottom-center) like the HTML toast.
/// [actionLabel]/[onAction] render an UNDO-style button on the toast; pass
/// [duration] to keep it alive longer (e.g. the 5s undo window).
///
/// Undo toasts get a live countdown for free: when the subtitle ends in a
/// number of seconds ("Deleting in 5s") that number ticks down 4…3…2…1 while
/// the toast is up, seeded from the subtitle and dismissed by [duration].
void showToast(
  BuildContext context,
  String message, {
  IconData? icon,
  String? subtitle,
  String kind = 'ok',
  String? actionLabel,
  VoidCallback? onAction,
  Duration duration = const Duration(milliseconds: 3200),
}) {
  final overlay = Overlay.of(context);
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final color = kind == 'ok'
      ? AppColors.green
      : kind == 'warn'
      ? AppColors.amber
      : AppColors.red;
  late final OverlayEntry entry;
  // Live countdown for undo toasts: when the subtitle ends in "…Ns" (e.g.
  // "Deleting in 5s"), tick the number down each second while the toast is
  // visible so users can see how long they have to undo.
  final secondsMatch =
      subtitle != null ? _toastSecondsPattern.firstMatch(subtitle) : null;
  final subtitleSeconds = secondsMatch != null
      ? int.parse(secondsMatch.group(2)!)
      : null;
  final secondsLeft = ValueNotifier<int>(
    subtitleSeconds ?? duration.inSeconds,
  );
  Timer? ticker;
  if (subtitleSeconds != null && subtitleSeconds > 1) {
    ticker = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!entry.mounted) {
        t.cancel();
        return;
      }
      final left = secondsLeft.value - 1;
      if (left >= 1) secondsLeft.value = left;
    });
  }
  late final Timer autoDismiss;
  void dismiss() {
    autoDismiss.cancel();
    ticker?.cancel();
    if (entry.mounted) entry.remove();
  }
  entry = OverlayEntry(
    builder: (ctx) => Positioned(
      left: 0,
      right: 0,
      bottom: 28,
      child: IgnorePointer(
        ignoring: false,
        child: Center(
          child: Material(
            color: Colors.transparent,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 220),
              opacity: 1,
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF232834) : const Color(0xFF181B25),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: AppTheme.shadowLg,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Icon(icon ?? AppIcons.check, size: 16, color: color),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          message,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (subtitle != null)
                          if (secondsMatch != null)
                            ValueListenableBuilder<int>(
                              valueListenable: secondsLeft,
                              builder: (_, left, _) => Text(
                                '${secondsMatch.group(1)}${left}s',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.65),
                                  fontSize: 11.5,
                                ),
                              ),
                            )
                          else
                            Text(
                              subtitle,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.65),
                                fontSize: 11.5,
                              ),
                            ),
                      ],
                    ),
                    const SizedBox(width: 10),
                    if (actionLabel != null && onAction != null)
                      Padding(
                        padding: const EdgeInsets.only(right: 2),
                        child: InkWell(
                          onTap: () {
                            onAction();
                            dismiss();
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            child: Text(
                              actionLabel.toUpperCase(),
                              style: const TextStyle(
                                color: Color(0xFF4ADE80),
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.04,
                              ),
                            ),
                          ),
                        ),
                      ),
                    InkWell(
                      onTap: dismiss,
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          AppIcons.x,
                          size: 15,
                          color: Colors.white.withValues(alpha: 0.6),
                        ),
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
  );
  overlay.insert(entry);
  autoDismiss = Timer(duration, dismiss);
}

/// Search box like `.search-box` in the HTML.
class SearchBox extends StatelessWidget {
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final String hint;
  final double? maxWidth;

  const SearchBox({
    super.key,
    this.controller,
    this.onChanged,
    this.hint = 'Search…',
    this.maxWidth,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: maxWidth,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: const Icon(AppIcons.search, size: 20),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}
