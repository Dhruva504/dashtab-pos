import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/app_theme.dart';
import '../../theme/demo_data.dart';
import '../../theme/app_widgets.dart';

/// Kitchen view — mirrors the HTML kitchen section (3-column board).
class KitchenView extends ConsumerStatefulWidget {
  const KitchenView({super.key});

  @override
  ConsumerState<KitchenView> createState() => _KitchenViewState();
}

class _KitchenViewState extends ConsumerState<KitchenView> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final d = demo;

    String elapsed(KitchenTicket k) {
      final mins = (DateTime.now().millisecondsSinceEpoch - k.sinceMs) ~/ 60000;
      final h = mins ~/ 60;
      final m = mins % 60;
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
    }

    int elapsedMins(KitchenTicket k) =>
        (DateTime.now().millisecondsSinceEpoch - k.sinceMs) ~/ 60000;

    String tableFor(int orderId) {
      final o = demo.orders.where((x) => x.id == orderId).firstOrNull;
      return o?.table ?? 'TO-GO';
    }

    List<CartLine> itemsFor(int orderId) {
      final o = demo.orders.where((x) => x.id == orderId).firstOrNull;
      return o?.items ?? [];
    }

    String nameFor(int productId) {
      final p = demo.product(productId);
      return p?.name ?? 'Unknown';
    }

    void advance(KitchenTicket k) {
      demo.advanceKitchen(k);
      setState(() {});
    }

    final columns = [
      ('new', 'Incoming', AppColors.amber, AppColors.amberT, 'Start Cooking'),
      ('preparing', 'Preparing', AppColors.blue, AppColors.blueT, 'Mark Ready'),
      (
        'ready',
        'Ready to Serve',
        AppColors.teal,
        AppColors.tealT,
        'Serve & Complete',
      ),
    ];

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 1000;
            final cols = columns.map((c) {
              final tickets = d.kitchen.where((k) => k.status == c.$1).toList();
              final column = Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard2 : AppColors.card2,
                  border: Border.all(
                    color: isDark ? AppColors.darkLine : AppColors.line,
                  ),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Pill(c.$2.toUpperCase(), color: c.$3, background: c.$4),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkCard : AppColors.card,
                            border: Border.all(
                              color: isDark
                                  ? AppColors.darkLine
                                  : AppColors.line,
                            ),
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Text(
                            '${tickets.length}',
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (tickets.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(20),
                        child: Center(
                          child: Text(
                            'Nothing here.',
                            style: TextStyle(color: AppColors.text3),
                          ),
                        ),
                      )
                    else
                      for (final k in tickets)
                        Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkCard : AppColors.card,
                            border: Border.all(
                              color: isDark
                                  ? AppColors.darkLine
                                  : AppColors.line,
                            ),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: AppTheme.shadow,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    '#${k.orderId}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? AppColors.darkLine2
                                          : AppColors.line2,
                                      borderRadius: BorderRadius.circular(7),
                                    ),
                                    child: Text(
                                      tableFor(k.orderId),
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: isDark
                                            ? AppColors.darkText2
                                            : AppColors.text2,
                                      ),
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    elapsed(k),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: elapsedMins(k) >= 15
                                          ? AppColors.red
                                          : elapsedMins(k) >= 8
                                          ? AppColors.amber
                                          : AppColors.green,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              for (final item in itemsFor(k.orderId))
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 2,
                                  ),
                                  child: Text(
                                    '${item.qty}× ${nameFor(item.productId)}${item.note != null ? '  *${item.note}' : ''}',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: item.note != null
                                          ? AppColors.amber
                                          : (isDark
                                                ? AppColors.darkText
                                                : AppColors.text),
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 10),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton(
                                  onPressed: () => advance(k),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: c.$3,
                                    side: BorderSide(color: c.$3),
                                  ),
                                  child: Text(c.$5),
                                ),
                              ),
                            ],
                          ),
                        ),
                  ],
                ),
              );
              return wide ? Expanded(child: column) : column;
            }).toList();

            if (wide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < cols.length; i++) ...[
                    if (i > 0) const SizedBox(width: 16),
                    cols[i],
                  ],
                ],
              );
            }
            return Column(
              children: [
                for (var i = 0; i < cols.length; i++) ...[
                  if (i > 0) const SizedBox(height: 16),
                  cols[i],
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}
