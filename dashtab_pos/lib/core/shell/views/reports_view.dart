import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/app_theme.dart';
import '../../theme/app_icons.dart';
import '../../theme/demo_data.dart';
import '../../theme/app_widgets.dart';
import '../widgets/interactive_charts.dart';

/// Reports view — every number is computed from the live store (orders,
/// products, inventory synced from Supabase). No simulated figures.
class ReportsView extends ConsumerStatefulWidget {
  const ReportsView({super.key});

  @override
  ConsumerState<ReportsView> createState() => _ReportsViewState();
}

class _ReportsViewState extends ConsumerState<ReportsView> {
  String _tab = 'sales';
  int _salesDays = 14; // Daily Sales chart range: 7 / 14 / 30

  bool _isPaid(DemoOrder o) =>
      o.status == 'Paid' || o.status == 'Refunded';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final d = demo;

    final tabs = [
      ('sales', 'Sales', AppIcons.chart),
      ('vat', 'VAT / IVA', AppIcons.tax),
      ('products', 'Products', AppIcons.book),
      ('waiters', 'Waiters', AppIcons.users),
      ('hourly', 'Hourly', AppIcons.clock),
      ('inventory', 'Inventory', AppIcons.box),
      ('profit', 'Profit', AppIcons.cash),
    ];

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: tabs.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              return FilterChipBtn(
                label: tabs[i].$2,
                selected: _tab == tabs[i].$1,
                onTap: () => setState(() => _tab = tabs[i].$1),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        if (_tab == 'sales')
          _buildSales(context, d, isDark)
        else if (_tab == 'vat')
          _buildVat(context, d, isDark)
        else if (_tab == 'products')
          _buildProducts(context, d, isDark)
        else if (_tab == 'waiters')
          _buildWaiters(context, d, isDark)
        else if (_tab == 'hourly')
          _buildHourly(context, d, isDark)
        else if (_tab == 'inventory')
          _buildInventory(context, d, isDark)
        else
          _buildProfit(context, d, isDark),
      ],
    );
  }

  // ---------------------------------------------------------------------
  // Sales — today's takings plus the last 14 days of revenue.
  // ---------------------------------------------------------------------

  Widget _buildSales(BuildContext context, AppStore d, bool isDark) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final paidToday = d.orders
        .where((o) => _isPaid(o) && o.createdAt != null && !o.createdAt!.isBefore(today))
        .toList();
    final revenue = paidToday.fold<double>(0, (s, o) => s + o.total);
    final dineIn = paidToday.where((o) => o.type == 'Dine In').length;
    final takeAway =
        paidToday.where((o) => o.type == 'Take Away' || o.type == 'Delivery').length;

    // Revenue per day for the selected range (oldest → newest), plus the
    // dine-in vs takeaway split shown in each tooltip.
    final days = _salesDays;
    final daily = List<double>.filled(days, 0);
    final dailyDine = List<double>.filled(days, 0);
    final dailyTake = List<double>.filled(days, 0);
    for (final o in d.orders.where(_isPaid)) {
      final c = o.createdAt;
      if (c == null) continue;
      final age = now.difference(DateTime(c.year, c.month, c.day)).inDays;
      if (age >= 0 && age < days) {
        daily[days - 1 - age] += o.total;
        if (o.type == 'Dine In') {
          dailyDine[days - 1 - age] += o.total;
        } else {
          dailyTake[days - 1 - age] += o.total;
        }
      }
    }
    final rangeTotal = daily.fold<double>(0, (s, v) => s + v);

    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Daily Sales', style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                Text(
                  'Settled revenue · $rangeTotal',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.darkText3 : AppColors.text3,
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  height: 34,
                  child: ToggleButtons(
                    isSelected: [_salesDays == 7, _salesDays == 14, _salesDays == 30],
                    borderRadius: BorderRadius.circular(9),
                    constraints: const BoxConstraints(minHeight: 32, minWidth: 44),
                    textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    onPressed: (i) => setState(() => _salesDays = [7, 14, 30][i]),
                    children: const [Text('7d'), Text('14d'), Text('30d')],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Today · settled orders (paid & refunded)',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppColors.darkText3 : AppColors.text3,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _ReportStat(label: 'Revenue', value: fmt(revenue), color: AppColors.brand),
                _ReportStat(
                  label: 'Orders',
                  value: '${paidToday.length}',
                  color: AppColors.blue,
                ),
                _ReportStat(label: 'Dine-in', value: '$dineIn', color: AppColors.violet),
                _ReportStat(label: 'Take away', value: '$takeAway', color: AppColors.teal),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 180,
              child: InteractiveAreaChart(
                values: daily,
                xLabels: dayLabelsFor(daily.length),
                color: AppColors.blue,
                isDark: isDark,
                emptyLabel: 'No sales recorded in the last $days days yet',
                xLabelInterval: days > 14 ? 5 : 1,
                tooltipDetails: [
                  for (var i = 0; i < days; i++)
                    dailyDine[i] > 0 || dailyTake[i] > 0
                        ? 'Dine-in ${fmt(dailyDine[i])} · Takeaway ${fmt(dailyTake[i])}'
                        : '',
                ],
              ),
            ),
            const SizedBox(height: 14),
            // Compact dine-in / takeaway split: one stacked bar + legend.
            Builder(builder: (context) {
              final dine = dailyDine.fold<double>(0, (s, v) => s + v);
              final take = dailyTake.fold<double>(0, (s, v) => s + v);
              final total = dine + take;
              final dineShare = total > 0 ? dine / total : 0.0;
              if (total <= 0) return const SizedBox.shrink();
              Widget legend(Color color, String label, double value) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '$label ${fmt(value)} '
                      '(${(value / total * 100).round()}%)',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: isDark ? AppColors.darkText2 : AppColors.text2,
                      ),
                    ),
                  ],
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: SizedBox(
                      height: 6,
                      child: Row(
                        children: [
                          Expanded(
                            flex: (dineShare * 1000).round(),
                            child: ColoredBox(color: AppColors.violet),
                          ),
                          Expanded(
                            flex: 1000 - (dineShare * 1000).round(),
                            child: ColoredBox(color: AppColors.teal),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      legend(AppColors.violet, 'Dine-in', dine),
                      const SizedBox(width: 20),
                      legend(AppColors.teal, 'Takeaway', take),
                    ],
                  ),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // VAT — IVA collected per rate, from the products' sold counters.
  // ---------------------------------------------------------------------

  Widget _buildVat(BuildContext context, AppStore d, bool isDark) {
    final rates = d.products.map((p) => p.iva).toSet().toList()..sort();
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('IVA Breakdown by Rate', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'All-time, computed from sold units × price × rate',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppColors.darkText3 : AppColors.text3,
              ),
            ),
            const SizedBox(height: 16),
            if (rates.isEmpty)
              _emptyHint('Add products to see IVA collected here.', isDark)
            else
              for (final rate in rates)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: isDark ? AppColors.darkLine2 : AppColors.line2,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Pill.paid('$rate%'),
                      const SizedBox(width: 12),
                      Text('IVA $rate% collected'),
                      const Spacer(),
                      Text(
                        fmt(d.products
                            .where((p) => p.iva == rate)
                            .fold<double>(0, (s, p) => s + p.price * p.sold * rate / 100)),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Products — units sold and revenue from the sold counters.
  // ---------------------------------------------------------------------

  Widget _buildProducts(BuildContext context, AppStore d, bool isDark) {
    final ranked = List.of(d.products)..sort((a, b) => b.sold.compareTo(a.sold));
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Product Performance', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'All-time units sold',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppColors.darkText3 : AppColors.text3,
              ),
            ),
            const SizedBox(height: 16),
            if (ranked.isEmpty)
              _emptyHint('No products yet.', isDark)
            else ...[
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isDark ? AppColors.darkLine : AppColors.line,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(flex: 3, child: Text('PRODUCT', style: _hdrStyle)),
                    Expanded(flex: 2, child: Text('CATEGORY', style: _hdrStyle)),
                    Expanded(flex: 2, child: Text('UNITS SOLD', style: _hdrStyle)),
                    Expanded(
                      flex: 2,
                      child: Text('REVENUE', style: _hdrStyle),
                    ),
                  ],
                ),
              ),
              for (final p in ranked)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: isDark ? AppColors.darkLine2 : AppColors.line2,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(flex: 3, child: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w700))),
                      Expanded(flex: 2, child: Text(p.cat)),
                      Expanded(flex: 2, child: Text('${p.sold} sold')),
                      Expanded(
                        flex: 2,
                        child: Text(
                          fmt(p.price * p.sold),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Waiters — orders taken and revenue, from paid orders this week.
  // ---------------------------------------------------------------------

  Widget _buildWaiters(BuildContext context, AppStore d, bool isDark) {
    final weekAgo = DateTime.now().subtract(const Duration(days: 7));
    final stats = <String, ({int orders, double revenue})>{};
    for (final o in d.orders.where(_isPaid)) {
      if (o.createdAt == null || o.createdAt!.isBefore(weekAgo)) continue;
      final name = o.waiter ?? 'Unassigned';
      final cur = stats[name] ?? (orders: 0, revenue: 0.0);
      stats[name] = (orders: cur.orders + 1, revenue: cur.revenue + o.total);
    }
    final rows = stats.entries.toList()
      ..sort((a, b) => b.value.revenue.compareTo(a.value.revenue));

    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Waiter Performance', style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                const Pill.preparing('THIS WEEK'),
              ],
            ),
            const SizedBox(height: 16),
            if (rows.isEmpty)
              _emptyHint(
                'No settled orders in the last 7 days. Orders you take are '
                'attributed automatically once staff have login accounts.',
                isDark,
              )
            else
              for (final row in rows)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: isDark ? AppColors.darkLine2 : AppColors.line2,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFF8A4C), AppColors.brand],
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          row.key
                              .split(' ')
                              .take(2)
                              .map((w) => w.isEmpty ? '?' : w[0])
                              .join()
                              .toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          row.key,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                        ),
                      ),
                      Text(
                        '${row.value.orders} orders',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.darkText2 : AppColors.text2,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Text(
                        fmt(row.value.revenue),
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                      ),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Hourly — revenue by hour of day across the loaded order history.
  // ---------------------------------------------------------------------

  Widget _buildHourly(BuildContext context, AppStore d, bool isDark) {
    // Service window 08:00–23:00 — matches Spanish restaurant hours.
    const openHour = 8, closeHour = 23;
    final revenueByHour = List<double>.filled(closeHour - openHour + 1, 0);
    var orderCount = 0;
    final weekdayCount = List<int>.filled(7, 0);
    for (final o in d.orders.where(_isPaid)) {
      final c = o.createdAt;
      if (c == null) continue;
      if (c.hour >= openHour && c.hour <= closeHour) {
        revenueByHour[c.hour - openHour] += o.total;
      }
      orderCount++;
      weekdayCount[c.weekday % 7]++;
    }

    var peak = 0;
    var quiet = -1;
    for (var i = 0; i < revenueByHour.length; i++) {
      if (revenueByHour[i] > revenueByHour[peak]) peak = i;
      if (revenueByHour[i] > 0 && (quiet < 0 || revenueByHour[i] < revenueByHour[quiet])) {
        quiet = i;
      }
    }
    final activeHours = revenueByHour.where((v) => v > 0).length;
    final busiestDay = weekdayCount.indexWhere((c) => c == weekdayCount.reduce((a, b) => a > b ? a : b));
    const dayNames = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Hourly Sales Distribution', style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                Text(
                  'Revenue by hour · settled orders',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.darkText3 : AppColors.text3,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 190,
              child: InteractiveBarChart(
                values: revenueByHour,
                xLabels: [
                  for (var h = openHour; h <= closeHour; h++) h.toString().padLeft(2, '0'),
                ],
                color: AppColors.violet,
                isDark: isDark,
                emptyLabel: 'No settled orders yet',
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Open hours 08:00 – 23:00',
              style: TextStyle(
                fontSize: 11,
                color: isDark ? AppColors.darkText3 : AppColors.text3,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _ReportStat(
                  label: 'Peak hour',
                  value: revenueByHour[peak] > 0 ? '${(openHour + peak).toString().padLeft(2, '0')}:00' : '—',
                  color: AppColors.brand,
                ),
                _ReportStat(
                  label: 'Busiest day',
                  value: orderCount > 0 ? dayNames[busiestDay] : '—',
                  color: AppColors.blue,
                ),
                _ReportStat(
                  label: 'Avg order / hr',
                  value: activeHours > 0
                      ? (orderCount / activeHours).toStringAsFixed(1)
                      : '—',
                  color: AppColors.violet,
                ),
                _ReportStat(
                  label: 'Quiet hour',
                  value: quiet >= 0 ? '${(openHour + quiet).toString().padLeft(2, '0')}:00' : '—',
                  color: AppColors.teal,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Inventory — stock valuation from the synced inventory table.
  // ---------------------------------------------------------------------

  Widget _buildInventory(BuildContext context, AppStore d, bool isDark) {
    final groups = _groupByCat(d.inventory);
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Inventory Valuation by Category', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            if (groups.isEmpty)
              _emptyHint('No inventory items recorded.', isDark)
            else ...[
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isDark ? AppColors.darkLine : AppColors.line,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(flex: 2, child: Text('CATEGORY', style: _hdrStyle)),
                    Expanded(child: Text('ITEMS', style: _hdrStyle)),
                    Expanded(child: Text('STOCK ON HAND', style: _hdrStyle)),
                    Expanded(child: Text('VALUE', style: _hdrStyle)),
                  ],
                ),
              ),
              for (final entry in groups.entries)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 9),
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
                        flex: 2,
                        child: Text(entry.key, style: const TextStyle(fontWeight: FontWeight.w700)),
                      ),
                      Expanded(child: Text('${entry.value.length} items')),
                      Expanded(
                        child: Text(
                          '${entry.value.fold<double>(0, (s, i) => s + i.qty).toStringAsFixed(1)} ${entry.value.first.unit}',
                        ),
                      ),
                      Expanded(
                        child: Text(
                          fmt(entry.value.fold<double>(0, (s, i) => s + i.qty * i.cost)),
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: AppColors.green,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const Divider(),
              Row(
                children: [
                  const Spacer(),
                  Text(
                    'Total value  ${fmt(d.inventory.fold<double>(0, (s, i) => s + i.qty * i.cost))}',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Profit — revenue vs recorded food cost per category.
  // ---------------------------------------------------------------------

  Widget _buildProfit(BuildContext context, AppStore d, bool isDark) {
    // Category revenue / cost from sold counters and recorded unit costs.
    final byCat = <String, ({double revenue, double cost})>{};
    for (final p in d.products) {
      final cur = byCat[p.cat] ?? (revenue: 0.0, cost: 0.0);
      byCat[p.cat] = (
        revenue: cur.revenue + p.price * p.sold,
        cost: cur.cost + p.cost * p.sold,
      );
    }
    final revenue = byCat.values.fold<double>(0, (s, v) => s + v.revenue);
    final cost = byCat.values.fold<double>(0, (s, v) => s + v.cost);
    final gross = revenue - cost;
    final margin = revenue > 0 ? gross / revenue * 100 : 0.0;
    final rows = byCat.entries.toList()
      ..sort((a, b) => b.value.revenue.compareTo(a.value.revenue));

    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Profit & Margin', style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                if (revenue > 0) Delta('${margin.toStringAsFixed(1)}% margin', up: margin >= 0),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'All-time. Enter supplier costs on products for accurate margins.',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppColors.darkText3 : AppColors.text3,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _ReportStat(label: 'Revenue', value: fmt(revenue), color: AppColors.brand),
                _ReportStat(label: 'Food cost', value: fmt(cost), color: AppColors.amber),
                _ReportStat(label: 'Gross profit', value: fmt(gross), color: AppColors.green),
                _ReportStat(
                  label: 'Margin',
                  value: revenue > 0 ? '${margin.toStringAsFixed(0)}%' : '—',
                  color: AppColors.violet,
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (rows.isEmpty)
              _emptyHint('No sales recorded yet.', isDark)
            else ...[
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isDark ? AppColors.darkLine : AppColors.line,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(flex: 2, child: Text('CATEGORY', style: _hdrStyle)),
                    Expanded(child: Text('REVENUE', style: _hdrStyle)),
                    Expanded(child: Text('FOOD COST', style: _hdrStyle)),
                    Expanded(child: Text('GROSS PROFIT', style: _hdrStyle)),
                    Expanded(child: Text('MARGIN', style: _hdrStyle)),
                  ],
                ),
              ),
              for (final entry in rows)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 9),
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
                        flex: 2,
                        child: Text(entry.key, style: const TextStyle(fontWeight: FontWeight.w700)),
                      ),
                      Expanded(child: Text(fmt(entry.value.revenue))),
                      Expanded(child: Text(fmt(entry.value.cost))),
                      Expanded(
                        child: Text(
                          fmt(entry.value.revenue - entry.value.cost),
                          style: const TextStyle(
                            color: AppColors.green,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Expanded(
                        child: entry.value.revenue > 0
                            ? Pill.paid(
                                '${((entry.value.revenue - entry.value.cost) / entry.value.revenue * 100).toStringAsFixed(0)}%',
                              )
                            : const Pill.pending('—'),
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  static const _hdrStyle = TextStyle(fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 0.3);

  Widget _emptyHint(String message, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            color: isDark ? AppColors.darkText3 : AppColors.text3,
          ),
        ),
      ),
    );
  }

  Map<String, List<InvItem>> _groupByCat(List<InvItem> items) {
    final map = <String, List<InvItem>>{};
    for (final i in items) {
      map.putIfAbsent(i.cat, () => []).add(i);
    }
    return map;
  }
}

class _ReportStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _ReportStat({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.darkText2
                    : AppColors.text2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
