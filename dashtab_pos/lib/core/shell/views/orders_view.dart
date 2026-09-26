import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';

import '../../theme/app_theme.dart';
import '../../theme/app_icons.dart';
import '../../theme/demo_data.dart';
import '../../theme/app_widgets.dart';
import '../home_shell.dart';
import '../widgets/csv_export.dart';
import '../widgets/payment_modal.dart';

/// Orders view — mirrors the HTML orders section (filter chips + table + actions).
class OrdersView extends ConsumerStatefulWidget {
  const OrdersView({super.key});

  @override
  ConsumerState<OrdersView> createState() => _OrdersViewState();
}

class _OrdersViewState extends ConsumerState<OrdersView> {
  final _search = TextEditingController();
  String _filter = 'All';
  final Set<int> _selected = {};

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<DemoOrder> get _selectedOrders => demo.orders
      .where((o) => _selected.contains(o.id))
      .toList(growable: false);

  /// Writes the selected orders to a CSV file at a user-chosen location
  /// via the OS save dialog.
  Future<void> _exportCsv() async {
    final rows = _selectedOrders;
    if (rows.isEmpty) return;
    final csv = buildCsv([
      [
        'Order', 'Date', 'Time', 'Type', 'Table', 'Customer', 'Status',
        'Items', 'Subtotal', 'Discount', 'IVA', 'Tip', 'Total', 'Paid via',
        'Invoice',
      ],
      for (final o in rows)
        [
          '#${o.id}',
          o.date,
          o.time,
          o.type,
          o.table ?? '',
          o.customer,
          o.status,
          o.items.fold<int>(0, (s, l) => s + l.qty),
          o.sub.toStringAsFixed(2),
          o.disc.toStringAsFixed(2),
          o.tax.toStringAsFixed(2),
          o.tip.toStringAsFixed(2),
          o.total.toStringAsFixed(2),
          o.method ?? '',
          o.invoice ?? '',
        ],
    ]);

    final savedPath = await saveFileToChosenLocation(
      context: context,
      data: csv,
      defaultName: 'orders-${DateTime.now().toIso8601String().split('T').first}.csv',
      label: 'CSV',
      subtitle: '${rows.length} orders · exported by DashTab POS',
    );

    setState(_selected.clear);
    if (savedPath == null && mounted) {
      showToast(context, 'Export cancelled', icon: AppIcons.x, kind: 'warn');
    }
  }

  /// Prints one receipt per selected order in a single print job.
  Future<void> _printSelected() async {
    final rows = _selectedOrders;
    if (rows.isEmpty) return;
    try {
      await Printing.layoutPdf(
        name: 'Receipts (${rows.length})',
        onLayout: (format) => buildReceiptsPdf(rows),
      );
    } catch (e) {
      if (mounted) {
        showToast(context, 'Could not print: $e', icon: AppIcons.x, kind: 'err');
      }
      return;
    }
    if (mounted) setState(_selected.clear);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final d = demo;
    final q = _search.text.toLowerCase();
    final filters = [
      'All',
      'Pending',
      'Preparing',
      'Ready',
      'Paid',
      'Cancelled',
      'Refunded',
    ];
    final list = d.orders.where((o) {
      final matchesFilter = _filter == 'All' || o.status == _filter;
      final matchesQ =
          q.isEmpty ||
          '#${o.id}'.contains(q) ||
          '${o.id}'.contains(q) ||
          o.customer.toLowerCase().contains(q) ||
          o.type.toLowerCase().contains(q) ||
          o.status.toLowerCase().contains(q) ||
          (o.table ?? '').toLowerCase().contains(q) ||
          (o.invoice ?? '').toLowerCase().contains(q);
      return matchesFilter && matchesQ;
    }).toList();

    Widget statusPill(String s) {
      return Pill(
        s.toUpperCase(),
        color: s == 'Paid'
            ? AppColors.green
            : s == 'Preparing'
            ? AppColors.blue
            : s == 'Ready'
            ? AppColors.teal
            : s == 'Cancelled' || s == 'Refunded'
            ? AppColors.red
            : AppColors.amber,
        background: s == 'Paid'
            ? AppColors.greenT
            : s == 'Preparing'
            ? AppColors.blueT
            : s == 'Ready'
            ? AppColors.tealT
            : s == 'Cancelled' || s == 'Refunded'
            ? AppColors.redT
            : AppColors.amberT,
      );
    }

    IconData typeIcon(String t) => t == 'Dine In'
        ? AppIcons.fork
        : t == 'Take Away'
        ? AppIcons.bag
        : AppIcons.truck;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 38,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: filters.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 8),
                          itemBuilder: (context, i) {
                            final f = filters[i];
                            return FilterChipBtn(
                              label: f,
                              selected: _filter == f,
                              onTap: () => setState(() => _filter = f),
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    SizedBox(
                      width: 260,
                      child: TextField(
                        controller: _search,
                        decoration: const InputDecoration(
                          hintText: 'Search order id / customer…',
                          prefixIcon: Icon(AppIcons.search, size: 18),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ],
                ),
              ),
              if (_selected.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: AppColors.brandT,
                    border: Border.all(color: AppColors.brandT2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Text(
                        '${_selected.length} selected',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: AppColors.brand,
                          fontSize: 13,
                        ),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () => _exportCsv(),
                        icon: const Icon(AppIcons.download, size: 16),
                        label: const Text('Export'),
                      ),
                      TextButton.icon(
                        onPressed: () => _printSelected(),
                        icon: const Icon(AppIcons.printer, size: 16),
                        label: const Text('Print'),
                      ),
                      TextButton.icon(
                        onPressed: () {
                          final n = _selected.length;
                          demo.cancelOrders(d.orders
                              .where((o) =>
                                  _selected.contains(o.id) &&
                                  o.status != 'Paid')
                              .toList());
                          demo.addAudit(
                            'Cancelled $n order(s)',
                            'delete',
                            'Bulk cancel from Orders view',
                          );
                          showToast(
                            context,
                            '$n order(s) cancelled',
                            icon: AppIcons.x,
                            kind: 'warn',
                          );
                          setState(_selected.clear);
                        },
                        icon: const Icon(AppIcons.x, size: 16),
                        label: const Text('Cancel'),
                      ),
                    ],
                  ),
                ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                color: isDark ? AppColors.darkCard2 : AppColors.card2,
                child: const Row(
                  children: [
                    SizedBox(width: 32),
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
                        'Type',
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
                        'Items',
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
                        'Payment',
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
                    Expanded(
                      child: Text(
                        'Time',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    SizedBox(width: 44),
                  ],
                ),
              ),
              if (list.isEmpty)
                const EmptyState(
                  icon: AppIcons.receipt,
                  title: 'No orders found',
                  message: 'Try a different filter or search.',
                )
              else
                for (final o in list)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: isDark ? AppColors.darkLine2 : AppColors.line2,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        InkWell(
                          onTap: () => setState(() {
                            if (_selected.contains(o.id)) {
                              _selected.remove(o.id);
                            } else {
                              _selected.add(o.id);
                            }
                          }),
                          child: Container(
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              color: _selected.contains(o.id)
                                  ? AppColors.brand
                                  : Colors.transparent,
                              border: Border.all(
                                color: _selected.contains(o.id)
                                    ? AppColors.brand
                                    : (isDark
                                          ? AppColors.darkLine
                                          : AppColors.line),
                                width: 1.5,
                              ),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: _selected.contains(o.id)
                                ? const Icon(
                                    AppIcons.check,
                                    size: 12,
                                    color: Colors.white,
                                  )
                                : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: InkWell(
                            onTap: () => _showOrderModal(o),
                            child: Text(
                              '#${o.id}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                decoration: TextDecoration.underline,
                                decorationColor: AppColors.text3,
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Row(
                            children: [
                              Icon(
                                typeIcon(o.type),
                                size: 14,
                                color: isDark
                                    ? AppColors.darkText2
                                    : AppColors.text2,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${o.type}${o.table != null ? ' · ${o.table}' : ''}',
                              ),
                            ],
                          ),
                        ),
                        Expanded(flex: 2, child: Text(o.customer)),
                        Expanded(
                          child: Text(
                            o.items
                                .fold<int>(0, (s, i) => s + i.qty)
                                .toString(),
                            style: TextStyle(
                              color: isDark
                                  ? AppColors.darkText2
                                  : AppColors.text2,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            '€${o.total.toStringAsFixed(2)}',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            o.method ?? '—',
                            style: TextStyle(
                              color: isDark
                                  ? AppColors.darkText2
                                  : AppColors.text2,
                            ),
                          ),
                        ),
                        Expanded(child: statusPill(o.status)),
                        Expanded(
                          child: Text(
                            o.time,
                            style: TextStyle(
                              color: isDark
                                  ? AppColors.darkText3
                                  : AppColors.text3,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 40,
                          child: PopupMenuButton<String>(
                            icon: Icon(
                              AppIcons.sliders,
                              size: 17,
                              color: isDark
                                  ? AppColors.darkText3
                                  : AppColors.text3,
                            ),
                            onSelected: (v) {
                              switch (v) {
                                case 'view':
                                  _showOrderModal(o);
                                case 'resume':
                                  _resumeOrder(o);
                                case 'refund':
                                  _refundOrder(o);
                                case 'print':
                                  _printOrder(o);
                              }
                            },
                            itemBuilder: (ctx) => [
                              const PopupMenuItem(
                                value: 'view',
                                child: Text('View details'),
                              ),
                              if (o.status != 'Paid' &&
                                  o.status != 'Cancelled' &&
                                  o.status != 'Refunded')
                                const PopupMenuItem(
                                  value: 'resume',
                                  child: Text('Resume order'),
                                ),
                              if (o.status == 'Paid')
                                const PopupMenuItem(
                                  value: 'refund',
                                  child: Text('Refund'),
                                ),
                              const PopupMenuItem(
                                value: 'print',
                                child: Text('Print receipt'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
            ],
          ),
        ),
      ],
    );
  }

  void _resumeOrder(DemoOrder o) {
    // Refuse orders that can no longer be edited (paid/cancelled/refunded);
    // the menu entry is hidden for them but the details dialog + races can
    // still reach this path.
    final resumed = demo.resumeOrder(o);
    if (resumed == null) {
      showToast(
        context,
        'Order #${o.id} is ${o.status.toLowerCase()} — nothing to resume',
        icon: AppIcons.info,
        kind: 'warn',
      );
      return;
    }
    // Load the order back into the cart, KEEPING its number and DB row.
    // The cart carries 'resumedOrderId' so charging settles the same row
    // instead of creating a new order (id stays stable end-to-end).
    demo.cart
      ..clear()
      ..addAll(o.items.map((l) => CartLine(l.productId, l.qty,
          note: l.note, discPct: l.discPct)));
    // Resolve the linked customer so the resume keeps loyalty attribution.
    // The order's stored customer id is authoritative (duplicate-name safe);
    // fall back to the name snapshot only for legacy orders.
    final linked = o.customerId != null
        ? demo.customers
            .where((c) =>
                c.dbId == o.customerId ||
                c.id.toString() == o.customerId)
            .toList()
        : demo.customers
            .where((c) => c.name.toLowerCase() == o.customer.toLowerCase())
            .toList();
    // Re-apply the discount the order was held with. The order row stores the
    // amount it took off, so match it against the active discounts' own maths.
    final restored = demo.discounts
        .where((x) => o.disc > 0 && (x.applyTo(o.sub) - o.disc).abs() < 0.01)
        .firstOrNull;
    demo.cartMeta = {
      'type': o.type,
      'table': o.table,
      'customer': o.customer == 'Walk-in' ? '' : o.customer,
      'customerId': linked.length == 1
          ? (linked.first.dbId ?? linked.first.id.toString())
          : null,
      'resumedOrderId': o.id,
      'discount': restored?.name,
    };
    showToast(
      context,
      'Order #${o.id} resumed',
      subtitle: 'Items loaded back into the cart — same order number',
      icon: AppIcons.refresh,
    );
    ref
        .read(currentViewProvider.notifier)
        .go(const ShellView('pos', 'New Order', 'Point of Sale terminal · Register A'));
  }

  void _refundOrder(DemoOrder o) {
    final amount = TextEditingController(
      text: (o.total + o.tip).toStringAsFixed(2),
    );
    final reason = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (dctx) => AlertDialog(
        title: Text('Refund · Order #${o.id}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amount,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Refund amount (€)',
                prefixIcon: Icon(AppIcons.cash, size: 18),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reason,
              decoration: const InputDecoration(
                labelText: 'Reason (optional)',
                hintText: 'e.g. Customer changed mind',
                prefixIcon: Icon(AppIcons.pencil, size: 18),
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
              Navigator.pop(dctx);
              final value = double.tryParse(amount.text) ?? o.total;
              demo.refundOrder(o, amount: value, reason: reason.text);
              demo.addNotif(
                'Order #${o.id} refunded',
                '€${amount.text} · ${reason.text.isEmpty ? 'No reason' : reason.text}',
                'warn',
              );
              demo.addAudit(
                'Refund processed',
                'refund',
                'Order #${o.id} · €${amount.text} · ${reason.text.isEmpty ? 'No reason' : reason.text}',
              );
              showToast(
                context,
                'Refund of €${amount.text} processed',
                icon: AppIcons.refund,
                kind: 'warn',
              );
            },
            child: const Text('Confirm refund'),
          ),
        ],
      ),
    );
  }

  void _printOrder(DemoOrder o) {
    AppModal.show(
      context,
      AppModal(
        title: 'Print receipt · Order #${o.id}',
        body: ReceiptView(order: o),
        actions: [
          OutlinedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              showToast(
                context,
                'Receipt sent to printer',
                icon: AppIcons.printer,
              );
            },
            icon: const Icon(AppIcons.printer, size: 16),
            label: const Text('Print'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showOrderModal(DemoOrder o) {
    AppModal.show(
      context,
      AppModal(
        title: 'Order #${o.id}',
        wide: true,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Pill(
                  o.type.toUpperCase(),
                  color: AppColors.brand,
                  background: AppColors.brandT,
                ),
                if (o.table != null) Pill.pending('TABLE ${o.table}'),
                _statusPill(o.status),
                if (o.invoice != null) Pill.paid('INV ${o.invoice}'),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${o.customer} · ${o.date} ${o.time}'
              '${o.customerNIF != null ? '\nNIF: ${o.customerNIF}' : ''}',
              style: TextStyle(
                fontSize: 12.5,
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.darkText2
                    : AppColors.text2,
              ),
            ),
            const SizedBox(height: 14),
            for (final l in o.items)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${l.qty}× ${demo.product(l.productId)?.name ?? 'Item'}'
                        '${l.note != null ? '  (${l.note})' : ''}'
                        '${l.discPct != null ? '  −${l.discPct}%' : ''}',
                        style: TextStyle(
                          fontSize: 13,
                          color: l.note != null ? AppColors.amber : null,
                        ),
                      ),
                    ),
                    Text(
                      fmt(_lineNet(l)),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
            const Divider(),
            TotalRow('Subtotal', fmt(o.sub)),
            if (o.disc > 0) TotalRow('Discount', '−${fmt(o.disc)}', free: true),
            TotalRow('IVA', fmt(o.tax)),
            TotalRow('Total', fmt(o.total), total: true),
            if (o.tip > 0) TotalRow('Tip (${o.tipPct}%)', fmt(o.tip)),
            if (o.tip > 0)
              TotalRow('Grand Total', fmt(o.total + o.tip), total: true),
            const SizedBox(height: 14),
            Row(
              children: [
                if (o.status != 'Paid' &&
                    o.status != 'Cancelled' &&
                    o.status != 'Refunded') ...[
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _resumeOrder(o);
                    },
                    icon: const Icon(AppIcons.refresh, size: 16),
                    label: const Text('Resume'),
                  ),
                  const SizedBox(width: 8),
                ],
                if (o.status == 'Paid') ...[
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _refundOrder(o);
                    },
                    icon: const Icon(AppIcons.refund, size: 16),
                    label: const Text('Refund'),
                  ),
                  const SizedBox(width: 8),
                ],
                OutlinedButton.icon(
                  onPressed: () => _printOrder(o),
                  icon: const Icon(AppIcons.printer, size: 16),
                  label: const Text('Print'),
                ),
              ],
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  double _lineNet(CartLine l) {
    final p = demo.product(l.productId);
    if (p == null) return 0;
    final base = p.price * l.qty;
    final disc = l.discPct != null ? base * l.discPct! / 100 : 0;
    return base - disc;
  }

  Widget _statusPill(String s) {
    return Pill(
      s.toUpperCase(),
      color: s == 'Paid'
          ? AppColors.green
          : s == 'Preparing'
          ? AppColors.blue
          : s == 'Ready'
          ? AppColors.teal
          : s == 'Cancelled' || s == 'Refunded'
          ? AppColors.red
          : AppColors.amber,
      background: s == 'Paid'
          ? AppColors.greenT
          : s == 'Preparing'
          ? AppColors.blueT
          : s == 'Ready'
          ? AppColors.tealT
          : s == 'Cancelled' || s == 'Refunded'
          ? AppColors.redT
          : AppColors.amberT,
    );
  }
}
