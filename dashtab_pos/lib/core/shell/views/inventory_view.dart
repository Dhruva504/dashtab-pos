import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/app_theme.dart';
import '../../theme/app_icons.dart';
import '../../theme/demo_data.dart';
import '../../theme/app_widgets.dart';

/// Inventory view — stock items, purchase orders and product margins.
class InventoryView extends ConsumerStatefulWidget {
  const InventoryView({super.key});

  @override
  ConsumerState<InventoryView> createState() => _InventoryViewState();
}

class _InventoryViewState extends ConsumerState<InventoryView> {
  String _tab = 'stock';
  final _search = TextEditingController();
  String _stockFilter = 'All';
  String _poFilter = 'All';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final d = demo;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilterChipBtn(
              label: 'Stock Items',
              selected: _tab == 'stock',
              onTap: () => setState(() => _tab = 'stock'),
            ),
            FilterChipBtn(
              label: 'Purchase Orders',
              selected: _tab == 'po',
              onTap: () => setState(() => _tab = 'po'),
            ),
            FilterChipBtn(
              label: 'Product Margins',
              selected: _tab == 'margins',
              onTap: () => setState(() => _tab = 'margins'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_tab == 'stock') _buildStockTab(isDark, d),
        if (_tab == 'po') _buildPoTab(isDark, d),
        if (_tab == 'margins') _buildMarginsTab(isDark, d),
      ],
    );
  }

  // =================================================================
  // STOCK TAB
  // =================================================================
  Widget _buildStockTab(bool isDark, dynamic d) {
    final q = _search.text.toLowerCase();
    final all = d.inventory as List<InvItem>;
    final lowCount = all.where((i) => i.qty > 0 && i.qty <= i.reorder).length;
    final outCount = all.where((i) => i.qty <= 0).length;
    final expiringCount = all.where((i) => i.isNearExpiry).length;
    final totalValue = all.fold<double>(0, (t, i) => t + i.qty * i.cost);

    final list = all.where((i) {
      final matchesQ = q.isEmpty ||
          i.name.toLowerCase().contains(q) ||
          i.sku.toLowerCase().contains(q) ||
          i.cat.toLowerCase().contains(q) ||
          i.supplier.toLowerCase().contains(q);
      final matchesF = switch (_stockFilter) {
        'Low' => i.qty > 0 && i.qty <= i.reorder,
        'Out' => i.qty <= 0,
        'Expiring' => i.isNearExpiry,
        _ => true,
      };
      return matchesQ && matchesF;
    }).toList()
      ..sort((a, b) {
        // Expiring/expired items first (soonest expiry on top), then name.
        final da = a.daysToExpiry;
        final db = b.daysToExpiry;
        if (da != null && db != null) {
          final byDate = da.compareTo(db);
          if (byDate != 0) return byDate;
        } else if (da != null) {
          return -1;
        } else if (db != null) {
          return 1;
        }
        return a.name.compareTo(b.name);
      });

    Widget statusPill(InvItem i) {
      if (i.qty <= 0) return const Pill.cancel('OUT');
      if (i.qty <= i.reorder) return const Pill.pending('REORDER');
      return const Pill.paid('OK');
    }

    Widget expiryPill(InvItem i) {
      final days = i.daysToExpiry;
      if (days == null) return const SizedBox.shrink();
      final label = days < 0
          ? 'EXPIRED'
          : days == 0
              ? 'EXPIRES TODAY'
              : '${days}d';
      return Padding(
        padding: const EdgeInsets.only(left: 6),
        child: Pill(
          label,
          color: days < 0 ? AppColors.red : AppColors.amber,
          background:
              days < 0 ? AppColors.redT : AppColors.amberT,
        ),
      );
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            // Filters/search wrap to extra lines on narrow screens.
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'Stock Items',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                FilterChipBtn(
                  label: 'All · ${all.length}',
                  selected: _stockFilter == 'All',
                  onTap: () => setState(() => _stockFilter = 'All'),
                ),
                FilterChipBtn(
                  label: 'Low · $lowCount',
                  selected: _stockFilter == 'Low',
                  onTap: () => setState(() => _stockFilter = 'Low'),
                ),
                FilterChipBtn(
                  label: 'Out of stock · $outCount',
                  selected: _stockFilter == 'Out',
                  onTap: () => setState(() => _stockFilter = 'Out'),
                ),
                FilterChipBtn(
                  label: 'Expiring · $expiringCount',
                  selected: _stockFilter == 'Expiring',
                  onTap: () => setState(() => _stockFilter = 'Expiring'),
                ),
                Pill.paid('Value €${totalValue.toStringAsFixed(0)}'),
                SizedBox(
                  width: 210,
                  height: 38,
                  child: TextField(
                    controller: _search,
                    decoration: const InputDecoration(
                      hintText: 'Search name, SKU, supplier…',
                      prefixIcon: Icon(AppIcons.search, size: 17),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    final low = all
                        .where((i) => i.qty <= i.reorder)
                        .toList();
                    if (low.isNotEmpty) _autoRestock(low);
                  },
                  icon: const Icon(AppIcons.refresh, size: 16),
                  label: const Text('Auto-restock low'),
                ),
                ElevatedButton.icon(
                  onPressed: _showAddItemDialog,
                  icon: const Icon(AppIcons.plus, size: 16),
                  label: const Text('Add item'),
                ),
              ],
            ),
          ),
          _stockHeader(isDark),
          if (list.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Text(
                  'No items match.',
                  style: TextStyle(
                    color: isDark ? AppColors.darkText2 : AppColors.text2,
                  ),
                ),
              ),
            )
          else
            for (final i in list)
              _stockRow(
                isDark,
                i,
                statusPill(i),
                expiryPill: i.isNearExpiry ? expiryPill(i) : null,
              ),
        ],
      ),
    );
  }

  static const _hdrStyle = TextStyle(fontWeight: FontWeight.w800, fontSize: 11);

  Widget _stockHeader(bool isDark) {
    final style = const TextStyle(fontWeight: FontWeight.w800, fontSize: 11);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      color: isDark ? AppColors.darkCard2 : AppColors.card2,
      child: Row(
        children: [
          Expanded(flex: 5, child: Text('ITEM', style: style)),
          Expanded(flex: 2, child: Text('SUPPLIER', style: style)),
          Expanded(flex: 2, child: Text('IN STOCK', style: style)),
          Expanded(flex: 2, child: Text('EXPIRY', style: style)),
          Expanded(child: Text('VALUE', style: style)),
          Expanded(child: Text('STATUS', style: style)),
          SizedBox(width: 100, child: Text('ACTIONS', style: style)),
        ],
      ),
    );
  }

  Widget _stockRow(
    bool isDark,
    InvItem i,
    Widget pill, {
    Widget? expiryPill,
  }) {
    final sub = isDark ? AppColors.darkText2 : AppColors.text2;
    final days = i.daysToExpiry;
    final expiryText = days == null
        ? '—'
        : '${i.expiry} · ${days < 0 ? 'expired ${-days}d ago' : days == 0 ? 'today' : 'in ${days}d'}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppColors.darkLine2 : AppColors.line2,
          ),
        ),
      ),
      child: Row(
        children: [
          // Item name with category · SKU underneath — kills two columns.
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        i.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: i.isExpired
                              ? AppColors.red
                              : isDark
                                  ? AppColors.darkText
                                  : AppColors.text,
                        ),
                      ),
                    ),
                    if (expiryPill != null) expiryPill,
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${i.cat} · ${i.sku}${i.reorder > 0 ? ' · reorder @ ${i.reorder.toStringAsFixed(0)} ${i.unit}' : ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: sub),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              i.supplier.isEmpty ? '—' : i.supplier,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: sub),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '${i.qty.toStringAsFixed(i.qty % 1 == 0 ? 0 : 1)} ${i.unit}',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              expiryText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: days != null && days <= RestaurantInfo.expiryWarnDays
                    ? FontWeight.w700
                    : FontWeight.w400,
                color: days == null
                    ? sub
                    : days < 0
                        ? AppColors.red
                        : days <= RestaurantInfo.expiryWarnDays
                            ? AppColors.amber
                            : sub,
              ),
            ),
          ),
          Expanded(
            child: Text(
              '€${(i.qty * i.cost).toStringAsFixed(0)}',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
            ),
          ),
          Expanded(child: pill),
          SizedBox(
            width: 100,
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Adjust stock',
                  visualDensity: VisualDensity.compact,
                  icon: Icon(AppIcons.plus, size: 15, color: AppColors.green),
                  onPressed: () => _adjustStock(i),
                ),
                IconButton(
                  tooltip: 'Edit item',
                  visualDensity: VisualDensity.compact,
                  icon: Icon(AppIcons.edit, size: 15, color: sub),
                  onPressed: () => _showItemDialog(item: i),
                ),
                IconButton(
                  tooltip: 'Delete item',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(AppIcons.trash, size: 15, color: AppColors.red),
                  onPressed: () => _confirmDeleteItem(i),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =================================================================
  // PURCHASE ORDERS TAB
  // =================================================================
  Widget _buildPoTab(bool isDark, dynamic d) {
    final all = d.purchaseOrders as List<PurchaseOrder>;
    final pending = all.where((p) => p.status == 'Pending').length;
    final q = _search.text.toLowerCase();
    final list = all.where((p) {
      final matchesQ = q.isEmpty ||
          p.id.toLowerCase().contains(q) ||
          p.supplier.toLowerCase().contains(q);
      final matchesF = switch (_poFilter) {
        'Pending' => p.status == 'Pending',
        'Received' => p.status == 'Received',
        'Cancelled' => p.status == 'Cancelled',
        _ => true,
      };
      return matchesQ && matchesF;
    }).toList();

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Row(
              children: [
                Text(
                  'Purchase Orders',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(width: 12),
                FilterChipBtn(
                  label: 'All · ${all.length}',
                  selected: _poFilter == 'All',
                  onTap: () => setState(() => _poFilter = 'All'),
                ),
                const SizedBox(width: 8),
                FilterChipBtn(
                  label: 'Pending · $pending',
                  selected: _poFilter == 'Pending',
                  onTap: () => setState(() => _poFilter = 'Pending'),
                ),
                const SizedBox(width: 8),
                FilterChipBtn(
                  label:
                      'Received · ${all.where((p) => p.status == 'Received').length}',
                  selected: _poFilter == 'Received',
                  onTap: () => setState(() => _poFilter = 'Received'),
                ),
                const Spacer(),
                SizedBox(
                  width: 210,
                  height: 38,
                  child: TextField(
                    controller: _search,
                    decoration: const InputDecoration(
                      hintText: 'Search PO number, supplier…',
                      prefixIcon: Icon(AppIcons.search, size: 17),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: _showNewPoDialog,
                  icon: const Icon(AppIcons.plus, size: 16),
                  label: const Text('New PO'),
                ),
              ],
            ),
          ),
          if (list.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Text(
                  'No purchase orders match.',
                  style: TextStyle(
                    color: isDark ? AppColors.darkText2 : AppColors.text2,
                  ),
                ),
              ),
            )
          else
            for (final po in list)
              _poCard(isDark, po),
        ],
      ),
    );
  }

  Widget _poCard(bool isDark, PurchaseOrder po) {
    final line = isDark ? AppColors.darkLine2 : AppColors.line2;
    final sub = isDark ? AppColors.darkText2 : AppColors.text2;
    final (label, color, bg) = switch (po.status) {
      'Received' => ('RECEIVED', AppColors.green, AppColors.greenT),
      'Cancelled' => ('CANCELLED', AppColors.red, AppColors.redT),
      'Partial' => ('PARTIAL', AppColors.amber, AppColors.amberT),
      _ => ('PENDING', AppColors.amber, AppColors.amberT),
    };
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 12, 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: line)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      po.id,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13.5,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Pill(label, color: color, background: bg),
                    const SizedBox(width: 8),
                    if (po.expected.isNotEmpty)
                      Text(
                        'Expected ${po.expected}',
                        style: TextStyle(fontSize: 11.5, color: sub),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  po.supplier,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.brand,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                if (po.lines.isEmpty)
                  Text(
                    'No line items recorded.',
                    style: TextStyle(fontSize: 12, color: sub),
                  )
                else
                  ...po.lines.map(
                    (l) => Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Text(
                              l.item,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12.5),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              '${l.qty.toStringAsFixed(l.qty % 1 == 0 ? 0 : 1)} × €${l.cost.toStringAsFixed(2)}',
                              style: TextStyle(fontSize: 12, color: sub),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              '€${l.total.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 6),
                Text(
                  '${po.items} item(s) · Total €${po.total.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Column(
            children: [
              if (po.status == 'Pending') ...[
                ElevatedButton.icon(
                  onPressed: () => _confirmReceive(po),
                  icon: const Icon(AppIcons.check, size: 15),
                  label: const Text('Receive'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.green,
                    foregroundColor: Colors.white,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                const SizedBox(height: 6),
                TextButton.icon(
                  onPressed: () => _confirmCancelPo(po),
                  icon: const Icon(AppIcons.x, size: 14),
                  label: const Text('Cancel PO'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.amber,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
              TextButton.icon(
                onPressed: () => _confirmDeletePo(po),
                icon: const Icon(AppIcons.trash, size: 14),
                label: const Text('Delete'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.red,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // =================================================================
  // MARGINS TAB (kept from before, minor polish)
  // =================================================================
  Widget _buildMarginsTab(bool isDark, dynamic d) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
            child: Text(
              'Product Margins',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Text(
              'Based on the supplier cost recorded on each product '
              '(edit a dish in Menu to set it).',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppColors.darkText3 : AppColors.text3,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            color: isDark ? AppColors.darkCard2 : AppColors.card2,
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text('PRODUCT', style: _hdrStyle),
                ),
                Expanded(
                  flex: 2,
                  child: Text('SUPPLIER COST', style: _hdrStyle),
                ),
                Expanded(
                  flex: 2,
                  child: Text('SELLING PRICE', style: _hdrStyle),
                ),
                Expanded(
                  flex: 2,
                  child: Text('MARGIN', style: _hdrStyle),
                ),
                Expanded(child: Text('MARGIN %', style: _hdrStyle)),
              ],
            ),
          ),
          for (final p in d.products as List)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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
                    flex: 3,
                    child: Text(
                      p.name as String,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text('€${(p.cost as double).toStringAsFixed(2)}'),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      '€${(p.price as double).toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      '€${(p.margin as double).toStringAsFixed(2)}',
                      style: TextStyle(
                        color: (p.cost as double) > 0 ? AppColors.green : null,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Expanded(
                    child: (p.cost as double) > 0
                        ? Pill.paid(
                            '${(p.margin / p.price * 100).toStringAsFixed(0)}%',
                          )
                        : const Pill.pending('—'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // =================================================================
  // Actions
  // =================================================================
  Future<void> _autoRestock(List<InvItem> low) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dctx) => AlertDialog(
        title: const Text('Restock low items'),
        content: Text(
          'Bring ${low.length} low item(s) up to three times their reorder '
          'level? The new quantities are saved to the inventory.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dctx, true),
            child: const Text('Restock'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    for (final i in low) {
      i.qty = i.reorder * 3;
      demo.updateInventoryItem(i);
    }
    demo.addAudit(
        'Low stock auto-restocked', 'update', '${low.length} items topped up');
    if (mounted) {
      setState(() {});
      showToast(
        context,
        'Low stock items restocked',
        subtitle: '${low.length} items updated',
        icon: AppIcons.refresh,
      );
    }
  }

  /// Quick +/- stock adjustment dialog.
  void _adjustStock(InvItem i) {
    final amount = TextEditingController(text: '1');
    showDialog<void>(
      context: context,
      builder: (dctx) => AlertDialog(
        title: Text('Adjust · ${i.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Current: ${i.qty.toStringAsFixed(i.qty % 1 == 0 ? 0 : 1)} ${i.unit}',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: amount,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true, signed: true),
              decoration: const InputDecoration(
                labelText: 'ADJUST BY (use negative to remove)',
                hintText: 'e.g. 10 or -3',
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
              final v = double.tryParse(amount.text);
              if (v == null) return;
              Navigator.pop(dctx);
              final newQty = (i.qty + v).clamp(0, double.infinity).toDouble();
              i.qty = newQty;
              demo.updateInventoryItem(i);
              demo.addAudit(
                'Stock adjusted',
                'update',
                '${i.name} ${v >= 0 ? '+' : ''}${v.toStringAsFixed(1)} → ${newQty.toStringAsFixed(1)} ${i.unit}',
              );
              showToast(context, 'Stock updated', icon: AppIcons.check);
              setState(() {});
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteItem(InvItem i) {
    showDialog<void>(
      context: context,
      builder: (dctx) => AlertDialog(
        title: Text('Delete ${i.name}?'),
        content: const Text('This removes the item from your stock records.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.red),
            onPressed: () {
              Navigator.pop(dctx);
              final idx = demo.inventory.indexOf(i);
              demo.deleteInventoryItem(i);
              demo.addAudit('Stock item deleted', 'delete', i.name);
              final undo = demo.scheduleDbDelete(
                () => demo.deleteInventoryItemDb(i),
                undoUi: () {
                  if (idx >= 0) {
                    demo.inventory
                        .insert(idx.clamp(0, demo.inventory.length), i);
                  } else {
                    demo.inventory.add(i);
                  }
                },
              );
              showToast(
                context,
                '${i.name} deleted',
                subtitle: 'Deleting in 5s',
                icon: AppIcons.trash,
                kind: 'danger',
                actionLabel: 'Undo',
                onAction: () {
                  undo();
                  demo.addAudit('Delete undone', 'update', i.name);
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

  /// Add / edit item dialog.
  void _showItemDialog({InvItem? item}) => _showAddItemDialog(item: item);

  void _showAddItemDialog({InvItem? item}) {
    final name = TextEditingController(text: item?.name ?? '');
    final sku = TextEditingController(text: item?.sku ?? '');
    final qty = TextEditingController(
      text: item == null
          ? '10'
          : item.qty.toStringAsFixed(item.qty % 1 == 0 ? 0 : 1),
    );
    final cost =
        TextEditingController(text: item?.cost.toStringAsFixed(2) ?? '1.00');
    final reorder = TextEditingController(
      text: item?.reorder.toStringAsFixed(0) ?? '5',
    );
    final expiry = TextEditingController(text: item?.expiry ?? '');
    String? cat = item?.cat ?? 'Dry goods';
    String? unit = item?.unit ?? 'units';
    String? supplier = (item?.supplier.isEmpty ?? true) ? null : item?.supplier;
    final catOptions = <String>[
      'Meat',
      'Dairy',
      'Vegetables',
      'Bakery',
      'Beverages',
      'Dry goods',
      'Cleaning',
      ...demo.supplierCategories,
    ];
    const unitOptions = ['units', 'kg', 'g', 'L', 'ml', 'boxes', 'bottles'];
    showDialog<void>(
      context: context,
      builder: (dctx) => AlertDialog(
        title: Text(item == null ? 'Add stock item' : 'Edit · ${item.name}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                autofocus: item == null,
                decoration: const InputDecoration(labelText: 'ITEM NAME'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: cat,
                decoration: const InputDecoration(labelText: 'CATEGORY'),
                items: [
                  for (final c in catOptions.toSet())
                    DropdownMenuItem(value: c, child: Text(c)),
                ],
                onChanged: (v) => cat = v,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: qty,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'QUANTITY'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: unit,
                decoration: const InputDecoration(labelText: 'UNIT'),
                items: [
                  for (final u in unitOptions)
                    DropdownMenuItem(value: u, child: Text(u)),
                ],
                onChanged: (v) => unit = v,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: cost,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'UNIT COST (€)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reorder,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'REORDER AT'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                initialValue: supplier,
                decoration:
                    const InputDecoration(labelText: 'SUPPLIER (OPTIONAL)'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('—')),
                  for (final s in demo.suppliers)
                    DropdownMenuItem(value: s.name, child: Text(s.name)),
                ],
                onChanged: (v) => supplier = v,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: expiry,
                decoration: InputDecoration(
                  labelText: 'EXPIRY DATE (OPTIONAL, YYYY-MM-DD)',
                  hintText: 'e.g. ${DateTime.now().add(const Duration(days: 14)).toIso8601String().split(' ').first}',
                  suffixIcon: IconButton(
                    tooltip: 'Pick date',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(AppIcons.clock, size: 17),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: dctx,
                        firstDate: DateTime.now().subtract(const Duration(days: 365)),
                        lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
                        initialDate: DateTime.tryParse(expiry.text) ??
                            DateTime.now().add(const Duration(days: 14)),
                      );
                      if (picked != null) {
                        expiry.text = picked.toIso8601String().split(' ').first;
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: sku,
                decoration: const InputDecoration(
                  labelText: 'SKU (OPTIONAL)',
                  hintText: 'auto-generated when empty',
                ),
              ),
            ],
          ),
        ),
        actions: [
          if (item != null)
            TextButton.icon(
              onPressed: () {
                Navigator.pop(dctx);
                _confirmDeleteItem(item);
              },
              style: TextButton.styleFrom(foregroundColor: AppColors.red),
              icon: const Icon(AppIcons.trash, size: 16),
              label: const Text('Delete'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(dctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (name.text.trim().isEmpty) return;
              Navigator.pop(dctx);
              if (item == null) {
                setState(() {});
                demo.addInventoryItem(
                  name: name.text.trim(),
                  cat: cat ?? 'Dry goods',
                  sku: sku.text.trim().isEmpty
                      ? 'SKU-${demo.inventory.length + 100}'
                      : sku.text.trim(),
                  qty: double.tryParse(qty.text) ?? 0,
                  unit: unit ?? 'units',
                  cost: double.tryParse(cost.text) ?? 0,
                  reorder: double.tryParse(reorder.text) ?? 5,
                  supplier: supplier ?? '',
                  expiry: expiry.text.trim(),
                );
                demo.addAudit(
                  'Stock item added',
                  'create',
                  '${name.text.trim()} · ${qty.text} ${unit ?? 'units'}',
                );
                showToast(context, 'Stock item added', icon: AppIcons.check);
              } else {
                // InvItem fields are final except qty — recreate in place.
                final idx = demo.inventory.indexOf(item);
                final updated = InvItem(
                  id: item.id,
                  name: name.text.trim(),
                  cat: cat ?? item.cat,
                  sku: sku.text.trim().isEmpty ? item.sku : sku.text.trim(),
                  qty: double.tryParse(qty.text) ?? item.qty,
                  unit: unit ?? item.unit,
                  cost: double.tryParse(cost.text) ?? item.cost,
                  reorder: double.tryParse(reorder.text) ?? item.reorder,
                  supplier: supplier ?? item.supplier,
                  expiry: expiry.text.trim(),
                  dbId: item.dbId,
                );
                if (idx >= 0) demo.inventory[idx] = updated;
                demo.updateInventoryItem(updated);
                demo.addAudit('Stock item updated', 'update', name.text.trim());
                showToast(context, 'Item updated', icon: AppIcons.check);
              }
              setState(() {});
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  // =================================================================
  // Purchase order dialogs
  // =================================================================
  void _showNewPoDialog() {
    String? supplier =
        demo.suppliers.isEmpty ? null : demo.suppliers.first.name;
    final expected = TextEditingController();
    final lines = <_PoLineInput>[
      _PoLineInput(),
    ];

    showDialog<void>(
      context: context,
      builder: (dctx) => StatefulBuilder(
        builder: (dctx, setDlg) {
          double total = 0;
          for (final l in lines) {
            total += (double.tryParse(l.qty.text) ?? 0) *
                (double.tryParse(l.cost.text) ?? 0);
          }
          return AlertDialog(
            title: const Text('New purchase order'),
            content: SizedBox(
              width: 460,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (demo.suppliers.isEmpty)
                      TextField(
                        decoration: const InputDecoration(
                          labelText: 'SUPPLIER',
                          hintText: 'Add suppliers first in Suppliers',
                        ),
                        enabled: false,
                      )
                    else
                      DropdownButtonFormField<String>(
                        initialValue: supplier,
                        decoration: const InputDecoration(labelText: 'SUPPLIER'),
                        items: [
                          for (final s in demo.suppliers)
                            DropdownMenuItem(value: s.name, child: Text(s.name)),
                        ],
                        onChanged: (v) => setDlg(() => supplier = v),
                      ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: expected,
                      decoration: const InputDecoration(
                        labelText: 'EXPECTED DATE (YYYY-MM-DD)',
                        hintText: 'e.g. 2026-09-20',
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'LINE ITEMS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    for (var i = 0; i < lines.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 4,
                              child: TextField(
                                controller: lines[i].item,
                                decoration: const InputDecoration(
                                  isDense: true,
                                  labelText: 'Item',
                                ),
                                onChanged: (_) => setDlg(() {}),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: lines[i].qty,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  isDense: true,
                                  labelText: 'Qty',
                                ),
                                onChanged: (_) => setDlg(() {}),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: lines[i].cost,
                                keyboardType: const TextInputType.numberWithOptions(
                                    decimal: true),
                                decoration: const InputDecoration(
                                  isDense: true,
                                  labelText: '€',
                                ),
                                onChanged: (_) => setDlg(() {}),
                              ),
                            ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              icon: const Icon(AppIcons.trash,
                                  size: 15, color: AppColors.red),
                              onPressed: lines.length == 1
                                  ? null
                                  : () => setDlg(() => lines.removeAt(i)),
                            ),
                          ],
                        ),
                      ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => setDlg(() => lines.add(_PoLineInput())),
                        icon: const Icon(AppIcons.plus, size: 15),
                        label: const Text('Add line'),
                      ),
                    ),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total',
                            style: TextStyle(fontWeight: FontWeight.w800)),
                        Text(
                          '€${total.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            color: AppColors.brand,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  final valid = lines
                      .where((l) =>
                          l.item.text.trim().isNotEmpty &&
                          (double.tryParse(l.qty.text) ?? 0) > 0)
                      .toList();
                  if (supplier == null || valid.isEmpty) return;
                  Navigator.pop(dctx);
                  setState(() {});
                  demo.createPurchaseOrder(
                    supplier: supplier!,
                    lines: valid
                        .map(
                          (l) => PoLine(
                            item: l.item.text.trim(),
                            qty: double.tryParse(l.qty.text) ?? 0,
                            cost: double.tryParse(l.cost.text) ?? 0,
                          ),
                        )
                        .toList(),
                    expected: expected.text.trim(),
                  );
                  demo.addAudit(
                    'Purchase order created',
                    'create',
                    '$supplier · ${valid.length} lines · €${total.toStringAsFixed(2)}',
                  );
                  showToast(
                    context,
                    'Purchase order created',
                    subtitle: '€${total.toStringAsFixed(2)}',
                    icon: AppIcons.truck,
                  );
                },
                child: const Text('Create PO'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _confirmReceive(PurchaseOrder po) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dctx) => AlertDialog(
        title: Text('Receive ${po.id}?'),
        content: Text(
          '${po.lines.length} line item(s) will be added to stock from '
          '${po.supplier}, at the costs on the order. Unknown items are '
          'created automatically.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.green),
            onPressed: () => Navigator.pop(dctx, true),
            child: const Text('Receive into stock'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() {});
    demo.receivePurchaseOrder(po);
    if (mounted) {
      showToast(
        context,
        '${po.id} received',
        subtitle: '${po.lines.length} lines added to stock',
        icon: AppIcons.check,
      );
    }
  }

  Future<void> _confirmCancelPo(PurchaseOrder po) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dctx) => AlertDialog(
        title: Text('Cancel ${po.id}?'),
        content: const Text('The order will be marked Cancelled — nothing is added to stock.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dctx, false),
            child: const Text('Back'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.amber),
            onPressed: () => Navigator.pop(dctx, true),
            child: const Text('Cancel PO'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() {});
    demo.cancelPurchaseOrder(po);
    if (mounted) {
      showToast(context, '${po.id} cancelled', icon: AppIcons.x);
    }
  }

  Future<void> _confirmDeletePo(PurchaseOrder po) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dctx) => AlertDialog(
        title: Text('Delete ${po.id}?'),
        content: const Text('This removes the purchase order permanently.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.red),
            onPressed: () => Navigator.pop(dctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() {});
    final idx = demo.purchaseOrders.indexOf(po);
    demo.deletePurchaseOrder(po);
    demo.addAudit('Purchase order deleted', 'delete', po.id);
    final undo = demo.scheduleDbDelete(
      () => demo.deletePurchaseOrderDb(po),
      undoUi: () {
        if (idx >= 0) {
          demo.purchaseOrders
              .insert(idx.clamp(0, demo.purchaseOrders.length), po);
        } else {
          demo.purchaseOrders.add(po);
        }
      },
    );
    if (mounted) {
      showToast(
        context,
        '${po.id} deleted',
        subtitle: 'Deleting in 5s',
        icon: AppIcons.trash,
        kind: 'danger',
        actionLabel: 'Undo',
        onAction: () {
          undo();
          demo.addAudit('Delete undone', 'update', po.id);
        },
        duration: const Duration(seconds: 5),
      );
    }
  }
}

/// Text controllers for one PO line in the new-PO dialog.
class _PoLineInput {
  final item = TextEditingController();
  final qty = TextEditingController(text: '1');
  final cost = TextEditingController(text: '0.00');
}
