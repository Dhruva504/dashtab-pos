import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/app_theme.dart';
import '../../theme/app_icons.dart';
import '../../theme/demo_data.dart';
import '../../theme/app_widgets.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../home_shell.dart';
import '../widgets/interactive_charts.dart';

/// Dashboard view — mirrors the HTML dashboard section.
class DashboardView extends ConsumerStatefulWidget {
  const DashboardView({super.key});

  @override
  ConsumerState<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends ConsumerState<DashboardView> {
  int _revDays = 7; // Revenue chart range: 7 / 14 / 30

  @override
  Widget build(BuildContext context) {
    final ref = this.ref;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final d = demo;
    final auth = ref.watch(authProvider);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    double revenueSince(DateTime from) => d.orders
        .where((o) =>
            (o.status == 'Paid' || o.status == 'Refunded') &&
            o.createdAt != null &&
            !o.createdAt!.isBefore(from))
        .fold<double>(0, (s, o) => s + o.total + o.tip);

    final revenueToday = revenueSince(today);
    final revenueYesterday = revenueSince(yesterday);
    final ordersToday = d.orders
        .where((o) => o.createdAt != null && !o.createdAt!.isBefore(today))
        .length;
    final revenueDelta = revenueYesterday > 0
        ? (revenueToday - revenueYesterday) / revenueYesterday * 100
        : null;

    final stats = [
      (
        'Revenue Today',
        '€${revenueToday.toStringAsFixed(2)}',
        AppIcons.cash,
        AppColors.brand,
        revenueDelta == null
            ? null
            : Delta(
                '${revenueDelta.abs().toStringAsFixed(1)}% vs yesterday',
                up: revenueDelta >= 0,
              ),
      ),
      (
        'Orders Today',
        '$ordersToday',
        AppIcons.receipt,
        AppColors.blue,
        null,
      ),
      (
        'Menu Items',
        '${d.products.length} dishes',
        AppIcons.book,
        AppColors.violet,
        null,
      ),
      (
        'Active Staff',
        '${d.staff.where((s) => s.active).length}',
        AppIcons.users,
        AppColors.teal,
        null,
      ),
    ];

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        // Buttons wrap to a second line on narrow screens instead of
        // squeezing the greeting into a sliver.
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Good day, '
              '${(auth.fullName ?? 'there').split(' ').first} 👋',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 2),
            Text(
              'Here is the live picture for ${d.dateNow}.',
              style: TextStyle(
                color: isDark ? AppColors.darkText2 : AppColors.text2,
              ),
            ),
            const SizedBox(height: 10),
            // Shortcuts respect the signed-in member's permissions: a
            // kitchen-only role sees no Reports or New Order buttons.
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (d.can(Permissions.reports))
                  OutlinedButton.icon(
                    onPressed: () => ref
                        .read(currentViewProvider.notifier)
                        .go(
                          const ShellView(
                            'reports',
                            'Reports',
                            'Sales, VAT, performance & profit analytics',
                          ),
                        ),
                    icon: const Icon(AppIcons.chart, size: 18),
                    label: const Text('Reports'),
                  ),
                if (d.can(Permissions.pos))
                  ElevatedButton.icon(
                    onPressed: () => ref
                        .read(currentViewProvider.notifier)
                        .go(
                          const ShellView(
                            'pos',
                            'New Order',
                            'Point of Sale terminal · Register A',
                          ),
                      ),
                  icon: const Icon(AppIcons.plus, size: 18),
                  label: const Text('Create New Order'),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 20),
        LayoutBuilder(
          builder: (context, constraints) {
            final cols = constraints.maxWidth >= 1100
                ? 4
                : constraints.maxWidth >= 700
                ? 2
                : 1;
            return GridView.count(
              crossAxisCount: cols,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 2.2,
              children: stats
                  .map(
                    (s) => AppCard(
                      padding: const EdgeInsets.all(18),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: s.$4.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(13),
                            ),
                            child: Icon(s.$3, color: s.$4, size: 22),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // Scale down instead of wrapping so values
                                // like €47.96 never break mid-number.
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    s.$2,
                                    maxLines: 1,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(fontSize: 22),
                                  ),
                                ),
                                Text(
                                  s.$1,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? AppColors.darkText2
                                        : AppColors.text2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Flexible + FittedBox: shrink the delta chip
                          // rather than squeezing the value column.
                          if (s.$5 != null)
                            Flexible(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: s.$5!,
                              ),
                            ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            );
          },
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 1000;
            // Real revenue per day for the selected range (oldest → newest),
            // with the dine-in / takeaway split for the tooltips.
            final days = _revDays;
            final daily = List<double>.filled(days, 0);
            final dailyDine = List<double>.filled(days, 0);
            final dailyTake = List<double>.filled(days, 0);
            for (final o in d.orders) {
              final c = o.createdAt;
              if (c == null || (o.status != 'Paid' && o.status != 'Refunded')) {
                continue;
              }
              final age = now.difference(DateTime(c.year, c.month, c.day)).inDays;
              if (age >= 0 && age < days) {
                daily[days - 1 - age] += o.total + o.tip;
                if (o.type == 'Dine In') {
                  dailyDine[days - 1 - age] += o.total + o.tip;
                } else {
                  dailyTake[days - 1 - age] += o.total + o.tip;
                }
              }
            }
            final last7 = daily.reduce((a, b) => a + b);
            final prev7 = List<double>.filled(days, 0);
            for (final o in d.orders) {
              final c = o.createdAt;
              if (c == null || (o.status != 'Paid' && o.status != 'Refunded')) {
                continue;
              }
              final age = now.difference(DateTime(c.year, c.month, c.day)).inDays;
              if (age >= days && age < 2 * days) prev7[2 * days - 1 - age] += o.total + o.tip;
            }
            final prev7Total = prev7.reduce((a, b) => a + b);
            final weekDelta = prev7Total > 0
                ? (last7 - prev7Total) / prev7Total * 100
                : null;
            final revenueCard = AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                    child: Row(
                      children: [
                        Text(
                          'Revenue · Last $days Days',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const Spacer(),
                        SizedBox(
                          height: 34,
                          child: ToggleButtons(
                            isSelected: [
                              _revDays == 7,
                              _revDays == 14,
                              _revDays == 30,
                            ],
                            borderRadius: BorderRadius.circular(9),
                            constraints:
                                const BoxConstraints(minHeight: 32, minWidth: 44),
                            textStyle: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                            onPressed: (i) =>
                                setState(() => _revDays = [7, 14, 30][i]),
                            children: const [Text('7d'), Text('14d'), Text('30d')],
                          ),
                        ),
                        const SizedBox(width: 10),
                        if (weekDelta != null)
                          Delta(
                            '${weekDelta.abs().toStringAsFixed(1)}% vs prior ${days == 7 ? 'week' : 'period'}',
                            up: weekDelta >= 0,
                          ),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: 220,
                    child: InteractiveAreaChart(
                      values: daily,
                      xLabels: dayLabelsFor(daily.length),
                      color: AppColors.brand,
                      isDark: isDark,
                      emptyLabel: 'No sales recorded this period yet',
                      xLabelInterval: days > 14 ? 5 : 1,
                      tooltipDetails: [
                        for (var i = 0; i < days; i++)
                          dailyDine[i] > 0 || dailyTake[i] > 0
                              ? 'Dine-in €${dailyDine[i].toStringAsFixed(2)} · '
                                  'Takeaway €${dailyTake[i].toStringAsFixed(2)}'
                              : '',
                      ],
                    ),
                  ),
                ],
              ),
            );
            final liveCard = AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                    child: Row(
                      children: [
                        Text(
                          'Live Orders',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const Spacer(),
                        const Pill.preparing('REALTIME'),
                      ],
                    ),
                  ),
                  for (final o in d.orders.take(5))
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: isDark
                                ? AppColors.darkLine2
                                : AppColors.line2,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 9,
                            height: 9,
                            decoration: BoxDecoration(
                              color: o.status == 'Paid'
                                  ? AppColors.green
                                  : o.status == 'Cancelled'
                                  ? AppColors.red
                                  : AppColors.blue,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '#${o.id}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                                Text(
                                  '${o.customer} · ${o.items.fold<int>(0, (s, i) => s + i.qty)} items',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark
                                        ? AppColors.darkText2
                                        : AppColors.text2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _statusPill(o.status),
                        ],
                      ),
                    ),
                ],
              ),
            );
            if (wide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 2, child: revenueCard),
                  const SizedBox(width: 16),
                  Expanded(child: liveCard),
                ],
              );
            }
            return Column(
              children: [revenueCard, const SizedBox(height: 16), liveCard],
            );
          },
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 1000;
            final top = (List.of(
              d.products,
            )..sort((a, b) => b.sold.compareTo(a.sold)))
                .take(4)
                .toList();
            final maxSold = top.isEmpty ? 1 : top.first.sold;
            final popularCard = AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                    child: Text(
                      'Most Popular Items',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  if (top.isEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      child: Text(
                        'No products yet — add dishes in Menu to see rankings.',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: isDark ? AppColors.darkText3 : AppColors.text3,
                        ),
                      ),
                    ),
                  for (final p in top)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              p.img,
                              width: 44,
                              height: 44,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => Container(
                                width: 44,
                                height: 44,
                                color: AppColors.brandT,
                                child: const Icon(
                                  AppIcons.book,
                                  color: AppColors.brand,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  p.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                                Text(
                                  '${p.sold} sold · €${p.price.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark
                                        ? AppColors.darkText2
                                        : AppColors.text2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(
                            width: 110,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Container(
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? AppColors.darkLine2
                                        : AppColors.line2,
                                    borderRadius: BorderRadius.circular(99),
                                  ),
                                  child: FractionallySizedBox(
                                    alignment: Alignment.centerLeft,
                                    widthFactor: maxSold > 0
                                        ? (p.sold / maxSold).clamp(0.0, 1.0)
                                        : 0.0,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [
                                            AppColors.brand,
                                            Color(0xFFFF8A4C),
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(99),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '€${(p.sold * p.price).toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            );
            final recentCard = AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                    child: Row(
                      children: [
                        Text(
                          'Recent Orders',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const Spacer(),
                        if (d.can(Permissions.orders))
                          TextButton(
                            onPressed: () => ref
                                .read(currentViewProvider.notifier)
                                .go(
                                  const ShellView(
                                    'orders',
                                    'Orders',
                                    'Manage, resume, refund & split orders',
                                  ),
                                ),                            child: const Text('View all'),
                          ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    color: isDark ? AppColors.darkCard2 : AppColors.card2,
                    child: const Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Text(
                            'Order',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            'Customer',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            'Total',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            'Status',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  for (final o in d.orders.take(6))
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: isDark
                                ? AppColors.darkLine2
                                : AppColors.line2,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: Text(
                              '#${o.id}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Expanded(flex: 2, child: Text(o.customer)),
                          Expanded(
                            child: Text(
                              '€${o.total.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Expanded(child: _statusPill(o.status)),
                        ],
                      ),
                    ),
                ],
              ),
            );
            if (wide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 2, child: popularCard),
                  const SizedBox(width: 16),
                  Expanded(child: recentCard),
                ],
              );
            }
            return Column(
              children: [popularCard, const SizedBox(height: 16), recentCard],
            );
          },
        ),
        // Expiry warnings — inventory items inside the warning window
        // (configured in Settings → Store) or already expired.
        Builder(builder: (context) {
          final warnDays = RestaurantInfo.expiryWarnDays;
          final expiring = d.inventory
              .where((i) => i.isNearExpiry && i.qty > 0)
              .toList()
            ..sort((a, b) =>
                (a.daysToExpiry ?? 0).compareTo(b.daysToExpiry ?? 0));
          if (expiring.isEmpty) return const SizedBox.shrink();
          final expiredCount = expiring.where((i) => i.isExpired).length;
          return Column(
            children: [
              const SizedBox(height: 16),
              AppCard(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            AppIcons.clock,
                            size: 17,
                            color: expiredCount > 0
                                ? AppColors.red
                                : AppColors.amber,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            expiredCount > 0
                                ? 'Expiry alerts · ${expiring.length} item(s), '
                                    '$expiredCount expired'
                                : 'Expiring soon · within $warnDays days',
                            style:
                                Theme.of(context).textTheme.titleMedium,
                          ),
                          const Spacer(),
                          Pill(
                            'WARN AT $warnDays DAYS',
                            color: AppColors.amber,
                            background: AppColors.amberT,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      for (final i in expiring.take(6))
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 7),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: isDark
                                    ? AppColors.darkLine2
                                    : AppColors.line2,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: Text(
                                  i.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  '${i.qty.toStringAsFixed(i.qty % 1 == 0 ? 0 : 1)} ${i.unit} on hand',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark
                                        ? AppColors.darkText2
                                        : AppColors.text2,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  i.expiry,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark
                                        ? AppColors.darkText2
                                        : AppColors.text2,
                                  ),
                                ),
                              ),
                              Pill(
                                i.isExpired
                                    ? 'EXPIRED'
                                    : (i.daysToExpiry == 0
                                        ? 'TODAY'
                                        : '${i.daysToExpiry}D'),
                                color: i.isExpired
                                    ? AppColors.red
                                    : AppColors.amber,
                                background: i.isExpired
                                    ? AppColors.redT
                                    : AppColors.amberT,
                              ),
                            ],
                          ),
                        ),
                      if (expiring.length > 6)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            '+${expiring.length - 6} more in Inventory → Expiring',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? AppColors.darkText3
                                  : AppColors.text3,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          );
        }),
      ],
    );
  }

  Widget _statusPill(String status) {
    return Pill(
      status.toUpperCase(),
      color: status == 'Paid'
          ? AppColors.green
          : status == 'Preparing'
          ? AppColors.blue
          : status == 'Ready'
          ? AppColors.teal
          : status == 'Cancelled'
          ? AppColors.red
          : AppColors.amber,
      background: status == 'Paid'
          ? AppColors.greenT
          : status == 'Preparing'
          ? AppColors.blueT
          : status == 'Ready'
          ? AppColors.tealT
          : status == 'Cancelled'
          ? AppColors.redT
          : AppColors.amberT,
    );
  }
}

