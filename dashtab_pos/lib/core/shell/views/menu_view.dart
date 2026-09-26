import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/app_theme.dart';
import '../../theme/app_icons.dart';
import '../../theme/demo_data.dart';
import '../../theme/app_widgets.dart';

/// Menu view — mirrors the HTML menu section (card grid, stock steppers).
class MenuView extends ConsumerStatefulWidget {
  const MenuView({super.key});

  @override
  ConsumerState<MenuView> createState() => _MenuViewState();
}

class _MenuViewState extends ConsumerState<MenuView> {
  final _search = TextEditingController();
  String _filter = 'All'; // All | Out of stock | Low stock | Unavailable

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// Products low/out of stock, for the bulk restock action.
  List<DemoProduct> get _restockable => demo.products
      .where((p) => p.stock <= RestaurantInfo.lowStockThreshold)
      .toList();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final d = demo;
    final isDarkTheme = isDark;
    final threshold = RestaurantInfo.lowStockThreshold;
    // Out of stock is purely stock-based — an unavailable dish is a
    // deliberate choice, not a stock condition.
    final oosCount = d.products.where((p) => p.stock <= 0).length;
    final unavailCount = d.products.where((p) => !p.avail).length;
    final lowCount = d.products
        .where((p) => p.avail && p.stock > 0 && p.stock <= threshold)
        .length;

    final q = _search.text.trim().toLowerCase();
    final products = d.products.where((p) {
      final matchesQ =
          q.isEmpty ||
          p.name.toLowerCase().contains(q) ||
          p.cat.toLowerCase().contains(q);
      final matchesFilter = switch (_filter) {
        'Out of stock' => p.stock <= 0,
        'Low stock' => p.avail && p.stock > 0 && p.stock <= threshold,
        'Unavailable' => !p.avail,
        _ => true,
      };
      return matchesQ && matchesFilter;
    }).toList();

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        SectionCard(
          title: 'Product Management',
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Pill.pending('$oosCount out of stock'),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _restockable.isEmpty
                    ? null
                    : () => _showRestockDialog(_restockable),
                icon: const Icon(AppIcons.refresh, size: 16),
                label: Text('Restock (${_restockable.length})'),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () => _showDishDialog(),
                icon: const Icon(AppIcons.plus, size: 16),
                label: const Text('Add new dish'),
              ),
            ],
          ),
          bodyPadding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Search + stock filters
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _search,
                      decoration: InputDecoration(
                        hintText: 'Search dishes by name or category…',
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
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  FilterChipBtn(
                    label: 'All · ${d.products.length}',
                    selected: _filter == 'All',
                    onTap: () => setState(() => _filter = 'All'),
                  ),
                  FilterChipBtn(
                    label: 'Out of stock · $oosCount',
                    selected: _filter == 'Out of stock',
                    onTap: () => setState(() => _filter = 'Out of stock'),
                  ),
                  FilterChipBtn(
                    label: 'Low stock · $lowCount',
                    selected: _filter == 'Low stock',
                    onTap: () => setState(() => _filter = 'Low stock'),
                  ),
                  FilterChipBtn(
                    label: 'Unavailable · $unavailCount',
                    selected: _filter == 'Unavailable',
                    onTap: () => setState(() => _filter = 'Unavailable'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (products.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: EmptyState(
                    icon: AppIcons.search,
                    title: 'No dishes match your filters.',
                  ),
                )
              else
                GridView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 210,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.92,
            ),
            children: products
                .map(
                  (p) => Container(
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
                        SizedBox(
                          height: 104,
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: Image.network(
                                  p.img,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => Container(
                                    color: AppColors.brandT,
                                    child: const Icon(
                                      AppIcons.book,
                                      color: AppColors.brand,
                                      size: 26,
                                    ),
                                  ),
                                ),
                              ),
                              if (p.stock <= threshold)
                                Positioned(
                                  top: 6,
                                  left: 6,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 7,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: p.stock == 0
                                          ? AppColors.red
                                          : AppColors.amber,
                                      borderRadius: BorderRadius.circular(99),
                                    ),
                                    child: Text(
                                      p.stock == 0 ? 'OUT' : '${p.stock} left',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                p.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12.5,
                                ),
                              ),
                              const SizedBox(height: 1),
                              Text(
                                '${p.cat} · IVA ${p.iva}% · ${p.sold} sold',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  color: isDarkTheme
                                      ? AppColors.darkText2
                                      : AppColors.text2,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Text(
                                    '€${p.price.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const Spacer(),
                                  _StockStepper(
                                    value: p.stock,
                                    onChanged: (v) => setState(() {
                                      p.stock = v.clamp(0, 999);
                                      demo.updateProduct(p);
                                    }),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Text(
                                    'Available',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: isDarkTheme
                                          ? AppColors.darkText2
                                          : AppColors.text2,
                                    ),
                                  ),
                                  const Spacer(),
                                  AppSwitch(
                                    value: p.avail,
                                    onChanged: (v) => setState(() {
                                      // Availability only controls whether the
                                      // dish can be ordered — stock is untouched.
                                      p.avail = v;
                                      demo.updateProduct(p);
                                    }),
                                  ),
                                  const SizedBox(width: 6),
                                  if (p.stock <= threshold)
                                    _CardIconBtn(
                                      icon: AppIcons.refresh,
                                      tooltip: 'Restock',
                                      onTap: () => _showRestockDialog([p]),
                                    ),
                                  _CardIconBtn(
                                    icon: AppIcons.pencil,
                                    tooltip: 'Edit dish',
                                    onTap: () => _showDishDialog(product: p),
                                  ),
                                  _CardIconBtn(
                                    icon: AppIcons.trash,
                                    tooltip: 'Delete dish',
                                    onTap: () => _confirmDeleteDish(p),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
            ],
          ),
        ),
      ],
    );
  }

  /// Confirms, then deletes the dish. Orders that included it keep their
  /// history (line items store the product name); the DB row is removed.
  Future<void> _confirmDeleteDish(DemoProduct p) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dctx) => AlertDialog(
        title: Text('Delete ${p.name}?'),
        content: Text(
          'This removes ${p.name} from the menu permanently. Past orders '
          'that included it are not affected — they keep their line items '
          'and totals.',
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
    final idx = demo.products.indexOf(p);
    demo.deleteProduct(p);
    demo.addAudit('Menu item deleted', 'delete', p.name);
    final undo = demo.scheduleDbDelete(
      () => demo.deleteProductDb(p),
      undoUi: () {
        if (idx >= 0 && idx <= demo.products.length) {
          demo.products.insert(idx.clamp(0, demo.products.length), p);
        } else {
          demo.products.add(p);
        }
      },
    );
    if (mounted) {
      showToast(
        context,
        '${p.name} removed from menu',
        subtitle: 'Deleting in 5s',
        icon: AppIcons.trash,
        kind: 'danger',
        actionLabel: 'Undo',
        onAction: () {
          undo();
          demo.addAudit('Delete undone', 'update', p.name);
        },
        duration: const Duration(seconds: 5),
      );
      setState(() {});
    }
  }

  /// Bulk restock: sets each listed dish's stock to a purchase quantity
  /// (default: the configured low-stock threshold × 4). Optionally also
  /// marks unavailable dishes available again.
  Future<void> _showRestockDialog(List<DemoProduct> items) async {
    final qty = TextEditingController(
      text: (RestaurantInfo.lowStockThreshold * 4).toString(),
    );
    var markAvailable = items.any((p) => !p.avail);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dctx) => StatefulBuilder(
        builder: (dctx, setDlg) => AlertDialog(
          title: Text(
            items.length == 1
                ? 'Restock · ${items.first.name}'
                : 'Restock ${items.length} dishes',
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sets stock to the purchase quantity for:\n'
                '${items.take(6).map((p) => '• ${p.name} (${p.stock} left)').join('\n')}'
                '${items.length > 6 ? '\n• +${items.length - 6} more' : ''}',
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: qty,
                autofocus: true,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'PURCHASE QUANTITY (NEW STOCK LEVEL)',
                ),
              ),
              if (items.any((p) => !p.avail)) ...[
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: const Text('Also mark unavailable dishes available'),
                  value: markAvailable,
                  onChanged: (v) => setDlg(() => markAvailable = v),
                ),
              ],
            ],
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
      ),
    );
    if (confirmed != true) return;
    final newStock = int.tryParse(qty.text);
    if (newStock == null || newStock < 0) return;
    for (final p in items) {
      p.stock = newStock.clamp(0, 999);
      if (markAvailable && !p.avail) p.avail = true;
      demo.updateProduct(p);
    }
    demo.addAudit(
      'Dishes restocked',
      'update',
      '${items.length} dish(es) set to $newStock units',
    );
    setState(() {});
    showToast(
      context,
      '${items.length} dish(es) restocked to $newStock',
      icon: AppIcons.refresh,
    );
  }

  void _showDishDialog({DemoProduct? product}) {
    final name = TextEditingController(text: product?.name ?? '');
    final price = TextEditingController(text: product?.price.toString() ?? '');
    final cost = TextEditingController(
      text: product != null && product.cost > 0 ? product.cost.toString() : '',
    );
    final stock = TextEditingController(
      text: product?.stock.toString() ?? '10',
    );
    final img = TextEditingController(text: product?.img ?? '');
    // Categories come from the live menu; new ones are created on save.
    final categories = demo.products.map((p) => p.cat).toSet().toList()..sort();
    String? cat = (product == null || !categories.contains(product.cat))
        ? null
        : product.cat;
    var newCategory = false;
    var iva = product?.iva ?? 10;

    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialog) => AlertDialog(
        title: Text(
          product == null ? 'Add new dish' : 'Edit · ${product.name}',
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Dish name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: price,
                decoration: const InputDecoration(labelText: 'Price (€)'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: cost,
                decoration: const InputDecoration(
                  labelText: 'Supplier cost (€) — used for profit reports',
                  hintText: 'e.g. 3.50',
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: stock,
                decoration: const InputDecoration(labelText: 'Stock'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                initialValue: cat,
                decoration: const InputDecoration(labelText: 'Category'),
                items: [
                  for (final c in categories)
                    DropdownMenuItem(value: c, child: Text(c)),
                  const DropdownMenuItem(
                    value: null,
                    child: Text('New category…'),
                  ),
                ],
                onChanged: (v) => setDialog(() {
                  cat = v;
                  newCategory = v == null;
                }),
              ),
              if (newCategory)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: TextField(
                    autofocus: true,
                    onChanged: (v) => cat = v.trim(),
                    decoration: const InputDecoration(
                      labelText: 'New category name',
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: iva,
                decoration: const InputDecoration(labelText: 'IVA rate'),
                items: const [
                  DropdownMenuItem(value: 10, child: Text('10% · Reduced (food)')),
                  DropdownMenuItem(value: 21, child: Text('21% · General (drinks)')),
                  DropdownMenuItem(value: 4, child: Text('4% · Super-reduced')),
                ],
                onChanged: (v) => iva = v ?? iva,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: img,
                decoration: const InputDecoration(
                  labelText: 'Image URL (optional)',
                  hintText: 'https://…',
                ),
                keyboardType: TextInputType.url,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              setState(() {});
              if (product == null) {
                demo.addProduct(
                  name: name.text,
                  cat: cat ?? 'General',
                  price: double.tryParse(price.text) ?? 0,
                  cost: double.tryParse(cost.text) ?? 0,
                  iva: iva,
                  stock: int.tryParse(stock.text) ?? 0,
                  img: img.text.trim(),
                );
              } else {
                product.name = name.text;
                product.price = double.tryParse(price.text) ?? product.price;
                product.cost = double.tryParse(cost.text) ?? product.cost;
                product.stock = int.tryParse(stock.text) ?? product.stock;
                product.cat = cat ?? product.cat;
                product.iva = iva;
                product.img = img.text.trim();
                demo.updateProduct(product);
              }
              demo.addAudit(
                product == null ? 'New product created' : 'Menu item updated',
                product == null ? 'create' : 'update',
                '${name.text} · ${fmt(double.tryParse(price.text) ?? 0)} · IVA $iva%',
              );
              showToast(
                context,
                product == null ? 'Dish added to menu' : 'Dish updated',
                icon: AppIcons.check,
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
      ),
    );
  }
}

/// Compact edit / delete icon button used on menu cards.
class _CardIconBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _CardIconBtn({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(7),
      child: Padding(
        padding: const EdgeInsets.all(5),
        child: Icon(
          icon,
          size: 15,
          color: AppColors.text3,
          semanticLabel: tooltip,
        ),
      ),
    );
  }
}

class _StockStepper extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;

  const _StockStepper({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard2 : AppColors.card2,
        border: Border.all(color: isDark ? AppColors.darkLine : AppColors.line),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Btn(icon: AppIcons.minus, onTap: () => onChanged(value - 1)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text(
              '$value',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 11.5,
              ),
            ),
          ),
          _Btn(icon: AppIcons.plus, onTap: () => onChanged(value + 1)),
        ],
      ),
    );
  }
}

class _Btn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _Btn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(7),
      child: Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.card,
          border: Border.all(
            color: isDark ? AppColors.darkLine : AppColors.line,
          ),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(
          icon,
          size: 11,
          color: isDark ? AppColors.darkText2 : AppColors.text2,
        ),
      ),
    );
  }
}
