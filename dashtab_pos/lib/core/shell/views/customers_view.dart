import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/app_theme.dart';
import '../../theme/app_icons.dart';
import '../../theme/demo_data.dart';
import '../../theme/app_widgets.dart';

/// Customers view — customer database, loyalty program & gift card management.
class CustomersView extends ConsumerStatefulWidget {
  const CustomersView({super.key});

  @override
  ConsumerState<CustomersView> createState() => _CustomersViewState();
}

class _CustomersViewState extends ConsumerState<CustomersView> {
  String _tab = 'cust';
  final _search = TextEditingController();
  // List header controls: which column orders the list, and an optional
  // tier filter ("All" = no filtering).
  String _sort = 'spent';
  bool _sortAsc = false;
  String _tierFilter = 'All';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final d = demo;
    final q = _search.text.toLowerCase();
    final customers = d.customers
        .where(
          (c) =>
              (q.isEmpty ||
                  c.name.toLowerCase().contains(q) ||
                  c.phone.contains(q)) &&
              (_tierFilter == 'All' || c.tier == _tierFilter),
        )
        .toList()
      ..sort(_compareCustomers);
    // Tier options: the configured loyalty tiers plus any tier actually in
    // use on a customer record (e.g. a legacy default).
    final tierOptions = <String>{
      for (final t in d.loyaltyTiers) t.name,
      for (final c in d.customers) c.tier,
    }.toList()
      ..sort();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
          child: Row(
            children: [
              for (final tab in const [
                ('cust', 'Customers', AppIcons.users),
                ('loyalty', 'Loyalty', AppIcons.star),
                ('gift', 'Gift Cards', AppIcons.gift),
              ])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChipBtn(
                    label: tab.$2,
                    selected: _tab == tab.$1,
                    onTap: () => setState(() => _tab = tab.$1),
                  ),
                ),
              const Spacer(),
              if (_tab == 'cust') ...[
                SizedBox(
                  width: 240,
                  child: TextField(
                    controller: _search,
                    decoration: InputDecoration(
                      hintText: 'Search by name / phone…',
                      isDense: true,
                      prefixIcon: const Icon(AppIcons.search, size: 18),
                      suffixIcon: _search.text.isEmpty
                          ? null
                          : IconButton(
                              visualDensity: VisualDensity.compact,
                              onPressed: () {
                                _search.clear();
                                setState(() {});
                              },
                              icon: const Icon(AppIcons.x, size: 16),
                            ),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: _showCustomerDialog,
                  icon: const Icon(AppIcons.plus, size: 16),
                  label: const Text('Add customer'),
                ),
              ],
              if (_tab == 'gift')
                ElevatedButton.icon(
                  onPressed: _showGiftCardDialog,
                  icon: const Icon(AppIcons.plus, size: 16),
                  label: const Text('Issue gift card'),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: _tab == 'cust'
              ? _buildCustomersTab(
                  context,
                  isDark,
                  customers,
                  q,
                  tierOptions,
                )
              : _tab == 'gift'
              ? _buildGiftTab(context, isDark, d)
              : _buildLoyaltyTab(context, isDark, d),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Customers tab — compact cards that fit many customers on screen.
  // ---------------------------------------------------------------------------

  /// Orders the list by the column selected in the header.
  int _compareCustomers(Customer a, Customer b) {
    final int r;
    switch (_sort) {
      case 'name':
        r = a.name.toLowerCase().compareTo(b.name.toLowerCase());
      case 'tier':
        r = _tierRank(a.tier).compareTo(_tierRank(b.tier));
      case 'visits':
        r = a.visits.compareTo(b.visits);
      case 'points':
        r = a.points.compareTo(b.points);
      default:
        r = a.total.compareTo(b.total);
    }
    return _sortAsc ? r : -r;
  }

  /// Orders tiers by their configured points threshold, so Gold sits above
  /// Silver regardless of alphabetical order.
  int _tierRank(String tier) {
    final tiers = demo.loyaltyTiers;
    final i = tiers.indexWhere((t) => t.name == tier);
    return i < 0 ? -1 : i;
  }

  /// Tapping a column header sorts by it; tapping the active one flips the
  /// direction.
  void _toggleSort(String key) {
    setState(() {
      if (_sort == key) {
        _sortAsc = !_sortAsc;
      } else {
        _sort = key;
        // Names read best A→Z, numbers biggest first.
        _sortAsc = key == 'name';
      }
    });
  }

  Widget _buildCustomersTab(
    BuildContext context,
    bool isDark,
    List<Customer> customers,
    String q,
    List<String> tierOptions,
  ) {
    if (customers.isEmpty) {
      return EmptyState(
        icon: AppIcons.users,
        title: q.isEmpty ? 'No customers yet' : 'No matches',
        message: q.isEmpty
            ? 'Customers are added automatically when orders are placed, or use "Add customer".'
            : (_tierFilter == 'All'
                ? 'Nothing matches "$q".'
                : 'No $_tierFilter customers match "$q".'),
      );
    }
    // Dense list: every customer is one row — fits many more on screen
    // than a card grid while keeping all stats visible.
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.card,
        border: Border.all(
          color: isDark ? AppColors.darkLine : AppColors.line,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard2 : AppColors.card2,
              border: Border(
                bottom: BorderSide(
                  color: isDark ? AppColors.darkLine2 : AppColors.line2,
                ),
              ),
            ),
            child: Row(
              children: [
                const SizedBox(width: 40),
                Expanded(child: _sortHeader('name', 'CUSTOMER')),
                SizedBox(
                  width: 110,
                  child: Row(
                    children: [
                      _sortHeader('tier', 'TIER'),
                      const SizedBox(width: 6),
                      _tierFilterMenu(tierOptions),
                    ],
                  ),
                ),
                SizedBox(width: 70, child: _sortHeader('visits', 'VISITS')),
                SizedBox(width: 90, child: _sortHeader('spent', 'SPENT')),
                SizedBox(width: 70, child: _sortHeader('points', 'POINTS')),
                const SizedBox(width: 36),
              ],
            ),
          ),
          // Count + active filter, so the current view is never ambiguous.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              children: [
                Text(
                  '${customers.length} customers',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.darkText3 : AppColors.text3,
                  ),
                ),
                if (_tierFilter != 'All') ...[
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () => setState(() => _tierFilter = 'All'),
                    borderRadius: BorderRadius.circular(99),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: _tierColor(_tierFilter).withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _tierFilter,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: _tierColor(_tierFilter),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            AppIcons.x,
                            size: 12,
                            color: _tierColor(_tierFilter),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: customers.length,
              itemBuilder: (context, i) {
                final c = customers[i];
                final tierColor = _tierColor(c.tier);
                return InkWell(
                  onTap: () => _showCustomerDetails(context, c),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 9,
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
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFF8A4C), AppColors.brand],
                            ),
                            borderRadius: BorderRadius.circular(9),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            c.name
                                .split(' ')
                                .take(2)
                                .map((w) => w[0])
                                .join()
                                .toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                c.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12.5,
                                ),
                              ),
                              Text(
                                c.phone,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  color: isDark
                                      ? AppColors.darkText3
                                      : AppColors.text3,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(
                          width: 110,
                          child: Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: tierColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                c.tier,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: tierColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(
                          width: 70,
                          child: Text(
                            '${c.visits}',
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 90,
                          child: Text(
                            '€${c.total.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 70,
                          child: Text(
                            '${c.points}',
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: AppColors.brand,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 36,
                          child: Icon(
                            AppIcons.chevD,
                            size: 14,
                            color: AppColors.text3,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  static const _headStyle = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w800,
    letterSpacing: 0.06,
    color: AppColors.text3,
  );

  /// A clickable column header: tap to sort by it, tap again to flip the
  /// direction. The active column shows an arrow.
  Widget _sortHeader(String key, String label) {
    final active = _sort == key;
    return InkWell(
      onTap: () => _toggleSort(key),
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: active
                    ? _headStyle.copyWith(color: AppColors.brand)
                    : _headStyle,
              ),
            ),
            if (active) ...[
              const SizedBox(width: 3),
              Icon(
                _sortAsc ? AppIcons.sortAsc : AppIcons.sortDesc,
                size: 12,
                color: AppColors.brand,
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Tier filter, driven from the TIER column header.
  Widget _tierFilterMenu(List<String> tierOptions) {
    final active = _tierFilter != 'All';
    return PopupMenuButton<String>(
      tooltip: 'Filter by tier',
      initialValue: _tierFilter,
      onSelected: (v) => setState(() => _tierFilter = v),
      itemBuilder: (ctx) => [
        for (final t in ['All', ...tierOptions])
          PopupMenuItem(
            value: t,
            child: Row(
              children: [
                if (t != 'All') ...[
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _tierColor(t),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Text(
                  t == 'All' ? 'All tiers' : t,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: t == 'All' ? null : _tierColor(t),
                  ),
                ),
              ],
            ),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: active ? AppColors.brandT : null,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(
          AppIcons.filter,
          size: 14,
          color: active ? AppColors.brand : AppColors.text3,
        ),
      ),
    );
  }

  /// Details / edit sheet for a single customer, with their order history.
  void _showCustomerDetails(BuildContext context, Customer c) {
    final nameCtrl = TextEditingController(text: c.name);
    final phoneCtrl = TextEditingController(text: c.phone);
    final history = demo.ordersForCustomer(c);
    final settled = history
        .where((o) => o.status == 'Paid')
        .fold<double>(0, (s, o) => s + o.total + o.tip);
    showDialog<void>(
      context: context,
      builder: (dctx) => AlertDialog(
        title: Text(c.name),
        content: SizedBox(
          width: 460,
          height: 470,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _DetailStat(label: 'Visits', value: '${c.visits}'),
                  _DetailStat(
                    label: 'Spent',
                    value: '€${c.total.toStringAsFixed(2)}',
                  ),
                  _DetailStat(label: 'Points', value: '${c.points}'),
                  _DetailStat(label: 'Tier', value: c.tier),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'EDIT DETAILS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.06,
                  color: AppColors.text3,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  prefixIcon: Icon(AppIcons.user, size: 18),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone',
                  prefixIcon: Icon(AppIcons.wallet, size: 18),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text(
                    'PURCHASE HISTORY',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.06,
                      color: AppColors.text3,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${history.length} orders · €${settled.toStringAsFixed(2)} settled',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.green,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: history.isEmpty
                    ? const Center(
                        child: Text(
                          'No orders for this customer yet.',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: AppColors.text3,
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: EdgeInsets.zero,
                        itemCount: history.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (_, i) => _historyRow(history[i]),
                      ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dctx);
              _confirmDeleteCustomer(c);
            },
            child: const Text('Delete', style: TextStyle(color: AppColors.red)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final newName = nameCtrl.text.trim();
              if (newName.isEmpty) return;
              Navigator.pop(dctx);
              c.name = newName;
              c.phone = phoneCtrl.text.trim();
              demo.updateCustomer(c);
              demo.addAudit('Customer updated', 'update', newName);
              showToast(context, 'Customer updated', icon: AppIcons.check);
              setState(() {});
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  /// One line of a customer's purchase history: when, what, how, total.
  Widget _historyRow(DemoOrder o) {
    final statusColor = switch (o.status) {
      'Paid' => AppColors.green,
      'Cancelled' => AppColors.red,
      'Refunded' => AppColors.amber,
      _ => AppColors.brand,
    };
    final qty = o.items.fold<int>(0, (s, l) => s + l.qty);
    final detail = [
      o.method ?? 'Unpaid',
      if (o.table != null) 'Table ${o.table}',
      o.time,
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          SizedBox(
            width: 78,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '#${o.id}',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  o.date,
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: AppColors.text3,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$qty items · ${o.type}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  detail,
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: AppColors.text3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '€${(o.total + o.tip).toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Container(
                margin: const EdgeInsets.only(top: 2),
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  o.status.toUpperCase(),
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.04,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Confirms, then deletes the customer. Their past orders keep the name
  /// snapshot; only the link is cleared.
  Future<void> _confirmDeleteCustomer(Customer c) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dctx) => AlertDialog(
        title: Text('Delete ${c.name}?'),
        content: Text(
          'This removes ${c.name} from your customer database. Their past '
          'orders stay in reports, but loyalty points and history are lost.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(dctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final idx = demo.customers.indexOf(c);
    demo.deleteCustomer(c);
    demo.addAudit('Customer deleted', 'delete', c.name);
    final undo = demo.scheduleDbDelete(
      () => demo.deleteCustomerDb(c),
      undoUi: () {
        if (idx >= 0) {
          demo.customers.insert(idx.clamp(0, demo.customers.length), c);
        } else {
          demo.customers.add(c);
        }
      },
    );
    if (!mounted) return;
    showToast(
      context,
      '${c.name} deleted',
      subtitle: 'Deleting in 5s',
      icon: AppIcons.trash,
      kind: 'danger',
      actionLabel: 'Undo',
      onAction: () {
        undo();
        demo.addAudit('Delete undone', 'update', c.name);
      },
      duration: const Duration(seconds: 5),
    );
    setState(() {});
  }

  // ---------------------------------------------------------------------------
  // Loyalty tab — settings the owner controls + live tier overview.
  // ---------------------------------------------------------------------------

  Widget _buildLoyaltyTab(BuildContext context, bool isDark, AppStore d) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      children: [
        AppCard(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Loyalty Program',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(width: 12),
                    AppSwitch(
                      value: d.loyaltyEnabled,
                      onChanged: (v) => setState(
                        () => d.saveLoyaltySetting('loyalty_enabled', '$v'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      d.loyaltyEnabled ? 'Active' : 'Paused',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: d.loyaltyEnabled
                            ? AppColors.green
                            : AppColors.text3,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 20,
                  runSpacing: 12,
                  children: [
                    _LoyaltyField(
                      label: 'EARN RATE',
                      hint: 'Points per euro',
                      value: d.earnRate.toString(),
                      onSave: (v) =>
                          d.saveLoyaltySetting('loyalty_earn_rate', v),
                    ),
                    _LoyaltyField(
                      label: 'POINT VALUE',
                      hint: 'Euro per point',
                      value: d.pointValue.toString(),
                      onSave: (v) =>
                          d.saveLoyaltySetting('loyalty_point_value', v),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  'Customers earn points automatically on paid orders and can '
                  'redeem them at the till. Tiers are configured below.',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.darkText3 : AppColors.text3,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        AppCard(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('Tiers', style: Theme.of(context).textTheme.titleMedium),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () => _showTierEditor(context),
                      icon: const Icon(AppIcons.pencil, size: 15),
                      label: const Text('Edit tiers'),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                for (final t in d.loyaltyTiers)
                  Builder(
                    builder: (_) {
                      final members = d.customers
                          .where((c) => c.tier == t.name)
                          .length;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: _tierColor(t.name).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Text(
                              t.name,
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: _tierColor(t.name),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              t.minPoints == 0
                                  ? 'From 0 pts'
                                  : 'From ${t.minPoints} pts',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? AppColors.darkText2
                                    : AppColors.text2,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '$members member${members == 1 ? '' : 's'}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Color _tierColor(String tier) => switch (tier) {
        'Gold' => AppColors.violet,
        'Silver' => AppColors.blue,
        _ => AppColors.amber,
      };

  /// Add / rename / remove loyalty tiers. Saving re-tiers every customer.
  void _showTierEditor(BuildContext context) {
    final rows = [
      for (final t in demo.loyaltyTiers)
        (name: TextEditingController(text: t.name), points: TextEditingController(text: '${t.minPoints}')),
    ];
    showDialog<void>(
      context: context,
      builder: (dctx) => StatefulBuilder(
        builder: (dctx, setDlg) => AlertDialog(
          title: const Text('Loyalty tiers'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'The lowest tier starts at 0 points automatically. '
                  'Saving re-tier every customer instantly.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.text3,
                  ),
                ),
                const SizedBox(height: 14),
                for (var i = 0; i < rows.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextField(
                            controller: rows[i].name,
                            decoration: InputDecoration(
                              labelText: 'Tier name',
                              isDense: true,
                              prefixIcon: Container(
                                width: 10,
                                alignment: Alignment.center,
                                child: Container(
                                  width: 9,
                                  height: 9,
                                  decoration: BoxDecoration(
                                    color: _tierColor(rows[i].name.text.isEmpty
                                        ? '?'
                                        : rows[i].name.text),
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: rows[i].points,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Min points',
                              isDense: true,
                            ),
                          ),
                        ),
                        // Can't delete the last tier.
                        if (rows.length > 1)
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            tooltip: 'Remove tier',
                            onPressed: () => setDlg(() => rows.removeAt(i)),
                            icon: const Icon(
                              AppIcons.trash,
                              size: 15,
                              color: AppColors.red,
                            ),
                          ),
                      ],
                    ),
                  ),
                TextButton.icon(
                  onPressed: () => setDlg(
                    () => rows.add(
                      (name: TextEditingController(), points: TextEditingController()),
                    ),
                  ),
                  icon: const Icon(AppIcons.plus, size: 15),
                  label: const Text('Add tier'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                // Validate: every tier needs a name; points must parse.
                final parsed = <({String name, int minPoints})>[];
                for (final r in rows) {
                  final tierName = r.name.text.trim();
                  final pts = int.tryParse(r.points.text.trim()) ?? -1;
                  if (tierName.isEmpty || pts < 0) return;
                  parsed.add((name: tierName, minPoints: pts));
                }
                if (parsed.isEmpty) return;
                // Force the first tier to start at 0.
                parsed[0] = (name: parsed[0].name, minPoints: 0);
                Navigator.pop(dctx);
                demo.saveLoyaltyTiers(parsed);
                demo.addAudit(
                  'Loyalty tiers updated',
                  'update',
                  parsed.map((t) => '${t.name}@${t.minPoints}').join(', '),
                );
                showToast(
                  context,
                  'Tiers saved — customers re-tiered',
                  icon: AppIcons.check,
                );
                setState(() {});
              },
              child: const Text('Save tiers'),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Gift Cards tab — full management: top-up, freeze, delete.
  // ---------------------------------------------------------------------------

  Widget _buildGiftTab(BuildContext context, bool isDark, AppStore d) {
    if (d.giftCards.isEmpty) {
      return EmptyState(
        icon: AppIcons.gift,
        title: 'No gift cards issued',
        message: 'Issue a gift card with the button above — it can be '
            'redeemed as a payment method at the POS.',
      );
    }
    final totalOutstanding = d.giftCards.fold<double>(
      0,
      (s, g) => s + (g.status == 'Active' ? g.balance : 0),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
          child: Row(
            children: [
              Text(
                '${d.giftCards.length} cards · ',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.darkText2 : AppColors.text2,
                ),
              ),
              Text(
                '€${totalOutstanding.toStringAsFixed(2)} outstanding balance',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.brand,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 380,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.9,
            ),
            itemCount: d.giftCards.length,
            itemBuilder: (context, i) {
              final g = d.giftCards[i];
              final active = g.status == 'Active';
              return InkWell(
                onTap: () => _showManageGiftCardDialog(g),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: active
                        ? const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [AppColors.brandT, AppColors.violetT],
                          )
                        : null,
                    color: active
                        ? null
                        : (isDark ? AppColors.darkCard2 : AppColors.card2),
                    border: Border.all(
                      color: active
                          ? AppColors.brandT2
                          : (isDark ? AppColors.darkLine : AppColors.line),
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Card top: gift icon + full code + status pill.
                      Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.darkCard : AppColors.card,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              AppIcons.gift,
                              color: active ? AppColors.brand : AppColors.text3,
                              size: 17,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              g.code,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                                letterSpacing: 0.02,
                              ),
                            ),
                          ),
                          Pill(
                            g.status.toUpperCase(),
                            color: active
                                ? AppColors.green
                                : g.status == 'Redeemed'
                                ? AppColors.amber
                                : AppColors.red,
                            background: active
                                ? AppColors.greenT
                                : g.status == 'Redeemed'
                                ? AppColors.amberT
                                : AppColors.redT,
                          ),
                        ],
                      ),
                      const Spacer(),
                      // Balance + recipient row.
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '€${g.balance.toStringAsFixed(2)}',
                            style: TextStyle(
                              color: active ? AppColors.brand : AppColors.text3,
                              fontWeight: FontWeight.w800,
                              fontSize: 22,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 3),
                            child: Text(
                              'of €${g.amount.toStringAsFixed(0)}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? AppColors.darkText3
                                    : AppColors.text3,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Expanded(
                            child: Text(
                              g.recipient.isEmpty
                                  ? 'Issued ${g.issued}'
                                  : 'For ${g.recipient} · ${g.issued}',
                              textAlign: TextAlign.right,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark
                                    ? AppColors.darkText3
                                    : AppColors.text3,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      // Action row.
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _showTopUpDialog(g),
                              icon: const Icon(AppIcons.plus, size: 14),
                              label: const Text('Top up'),
                              style: OutlinedButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(vertical: 4),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _showManageGiftCardDialog(g),
                              icon: const Icon(AppIcons.pencil, size: 14),
                              label: const Text('Manage'),
                              style: OutlinedButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(vertical: 4),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showTopUpDialog(GiftCard g) {
    final ctrl = TextEditingController(text: '10.00');
    showDialog<void>(
      context: context,
      builder: (dctx) => AlertDialog(
        title: Text('Top up ${g.code}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Current balance: €${g.balance.toStringAsFixed(2)}'),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'AMOUNT (€)',
                prefixIcon: Icon(AppIcons.gift, size: 18),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final v = double.tryParse(ctrl.text) ?? 0;
              Navigator.pop(dctx);
              if (demo.topUpGiftCard(g, v)) {
                showToast(
                  context,
                  '${g.code} topped up',
                  subtitle: 'New balance €${g.balance.toStringAsFixed(2)}',
                  icon: AppIcons.gift,
                );
              } else {
                showToast(
                  context,
                  'Enter an amount above 0',
                  icon: AppIcons.x,
                  kind: 'err',
                );
              }
              setState(() {});
            },
            child: const Text('Top up'),
          ),
        ],
      ),
    );
  }

  /// Full management dialog for a gift card: balance adjust, recipient edit,
  /// freeze/activate and delete — all in one place.
  void _showManageGiftCardDialog(GiftCard g) {
    final balanceCtrl = TextEditingController(text: g.balance.toStringAsFixed(2));
    final recipientCtrl = TextEditingController(text: g.recipient);
    var status = g.status;
    showDialog<void>(
      context: context,
      builder: (dctx) => StatefulBuilder(
        builder: (dctx, setDlg) => AlertDialog(
          title: Text('Manage ${g.code}'),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Summary strip.
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.brandT,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'BALANCE',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.06,
                              color: AppColors.brand,
                            ),
                          ),
                          Text(
                            '€${g.balance.toStringAsFixed(2)} of €${g.amount.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              color: AppColors.brand,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text(
                            'ISSUED',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.06,
                              color: AppColors.brand,
                            ),
                          ),
                          Text(
                            g.issued,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                              color: AppColors.brand,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'BALANCE (€)',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.06,
                    color: AppColors.text3,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: balanceCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    hintText: 'e.g. 25.00',
                    prefixIcon: Icon(AppIcons.cash, size: 18),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'RECIPIENT',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.06,
                    color: AppColors.text3,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: recipientCtrl,
                  decoration: const InputDecoration(
                    hintText: 'e.g. Jessica Alba',
                    prefixIcon: Icon(AppIcons.user, size: 18),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'STATUS',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.06,
                    color: AppColors.text3,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final s in const ['Active', 'Redeemed', 'Expired'])
                      FilterChipBtn(
                        label: s,
                        selected: status == s,
                        onTap: () => setDlg(() => status = s),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                if (status == 'Expired')
                  Text(
                    'Frozen cards are rejected as a payment method at the till.',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: AppColors.amber,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dctx);
                _confirmDeleteGiftCard(g);
              },
              child: const Text(
                'Delete card',
                style: TextStyle(color: AppColors.red),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final newBalance =
                    double.tryParse(balanceCtrl.text.trim()) ?? g.balance;
                final newRecipient = recipientCtrl.text.trim();
                Navigator.pop(dctx);
                if (newBalance < 0) {
                  showToast(
                    context,
                    'Balance cannot be negative',
                    icon: AppIcons.x,
                    kind: 'err',
                  );
                  return;
                }
                if (newBalance != g.balance) {
                  demo.adjustGiftCardBalance(g, newBalance);
                }
                if (newRecipient != g.recipient) {
                  demo.updateGiftCardRecipient(g, newRecipient);
                }
                if (status != g.status) {
                  demo.setGiftCardStatus(g, status);
                }
                showToast(
                  context,
                  '${g.code} updated',
                  subtitle: 'Balance €${g.balance.toStringAsFixed(2)} · $status',
                  icon: AppIcons.check,
                );
                setState(() {});
              },
              child: const Text('Save changes'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteGiftCard(GiftCard g) {
    showDialog<void>(
      context: context,
      builder: (dctx) => AlertDialog(
        title: Text('Delete ${g.code}?'),
        content: Text(
          'This permanently removes the card. Remaining balance: '
          '€${g.balance.toStringAsFixed(2)}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(dctx);
              final idx = demo.giftCards.indexOf(g);
              demo.deleteGiftCard(g);
              final undo = demo.scheduleDbDelete(
                () => demo.deleteGiftCardDb(g),
                undoUi: () {
                  if (idx >= 0) {
                    demo.giftCards
                        .insert(idx.clamp(0, demo.giftCards.length), g);
                  } else {
                    demo.giftCards.add(g);
                  }
                },
              );
              showToast(
                context,
                '${g.code} deleted',
                subtitle: 'Deleting in 5s',
                icon: AppIcons.trash,
                kind: 'danger',
                actionLabel: 'Undo',
                onAction: () {
                  undo();
                  demo.addAudit('Delete undone', 'update', g.code);
                },
                duration: const Duration(seconds: 5),
              );
              setState(() {});
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Dialogs
  // ---------------------------------------------------------------------------

  void _showCustomerDialog() {
    final name = TextEditingController();
    final phone = TextEditingController();
    final email = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (dctx) => AlertDialog(
        title: const Text('Add customer'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'FULL NAME',
                hintText: 'e.g. Jessica Alba',
                prefixIcon: Icon(AppIcons.user, size: 18),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'PHONE',
                hintText: '+34 …',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'EMAIL (optional)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (name.text.trim().isEmpty) return;
              Navigator.pop(dctx);
              setState(() {});
              demo.addCustomer(
                name: name.text.trim(),
                phone: phone.text.trim().isEmpty ? '—' : phone.text.trim(),
                email: email.text.trim().isEmpty ? null : email.text.trim(),
              );
              demo.addAudit(
                'Customer added',
                'create',
                '${name.text.trim()} · ${phone.text.trim()}',
              );
              showToast(context, 'Customer added', icon: AppIcons.check);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showGiftCardDialog() {
    final amount = TextEditingController(text: '25.00');
    final recipient = TextEditingController();
    final code = demo.generateGiftCardCode();
    showDialog<void>(
      context: context,
      builder: (dctx) => AlertDialog(
        title: const Text('Issue gift card'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.brandT,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Code: $code',
                style: const TextStyle(
                  color: AppColors.brand,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: amount,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'AMOUNT (€)',
                prefixIcon: Icon(AppIcons.gift, size: 18),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: recipient,
              decoration: const InputDecoration(
                labelText: 'RECIPIENT (optional)',
                hintText: 'e.g. Jessica Alba',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final v = double.tryParse(amount.text) ?? 0;
              if (v <= 0) return;
              Navigator.pop(dctx);
              setState(() {});
              demo.issueGiftCard(
                amount: v,
                recipient: recipient.text.trim(),
                code: code,
              );
              showToast(
                context,
                'Gift card $code issued',
                subtitle: fmt(v),
                icon: AppIcons.gift,
              );
            },
            child: const Text('Issue card'),
          ),
        ],
      ),
    );
  }
}

/// Stat readout used in the customer details dialog.
class _DetailStat extends StatelessWidget {
  final String label;
  final String value;

  const _DetailStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
          ),
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 10,
              color: AppColors.text3,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.04,
            ),
          ),
        ],
      ),
    );
  }
}

/// Inline editable loyalty setting (label + text field + save on submit).
class _LoyaltyField extends StatefulWidget {
  final String label;
  final String hint;
  final String value;
  final ValueChanged<String> onSave;

  const _LoyaltyField({
    required this.label,
    required this.hint,
    required this.value,
    required this.onSave,
  });

  @override
  State<_LoyaltyField> createState() => _LoyaltyFieldState();
}

class _LoyaltyFieldState extends State<_LoyaltyField> {
  late final TextEditingController _ctrl = TextEditingController(
    text: widget.value,
  );

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.label,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.06,
              color: AppColors.text3,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _ctrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              hintText: widget.hint,
              isDense: true,
              suffixIcon: IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'Save',
                onPressed: () {
                  widget.onSave(_ctrl.text.trim());
                  showToast(
                    context,
                    'Loyalty setting saved',
                    icon: AppIcons.check,
                  );
                },
                icon: const Icon(
                  AppIcons.check,
                  size: 15,
                  color: AppColors.brand,
                ),
              ),
            ),
            onSubmitted: (v) {
              widget.onSave(v.trim());
              showToast(
                context,
                'Loyalty setting saved',
                icon: AppIcons.check,
              );
            },
          ),
        ],
      ),
    );
  }
}
