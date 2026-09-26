import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/app_theme.dart';
import '../../theme/app_icons.dart';
import '../../theme/demo_data.dart';
import '../../theme/app_widgets.dart';

/// Suppliers view — supplier database with custom categories and full CRUD.
class SuppliersView extends ConsumerStatefulWidget {
  const SuppliersView({super.key});

  @override
  ConsumerState<SuppliersView> createState() => _SuppliersViewState();
}

class _SuppliersViewState extends ConsumerState<SuppliersView> {
  final _search = TextEditingController();
  String _cat = 'All';

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
    final cats = d.supplierCategories;
    final list = d.suppliers.where((s) {
      final matchesQ = q.isEmpty ||
          s.name.toLowerCase().contains(q) ||
          s.contact.toLowerCase().contains(q) ||
          s.email.toLowerCase().contains(q);
      final matchesCat = _cat == 'All' || s.cat == _cat;
      return matchesQ && matchesCat;
    }).toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        // Category tabs + actions row
        Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            FilterChipBtn(
              label: 'All · ${d.suppliers.length}',
              selected: _cat == 'All',
              onTap: () => setState(() => _cat = 'All'),
            ),
            for (final c in cats)
              FilterChipBtn(
                label:
                    '$c · ${d.suppliers.where((s) => s.cat == c).length}',
                selected: _cat == c,
                onTap: () => setState(() => _cat = c),
              ),
            const SizedBox(width: 4),
            TextButton.icon(
              onPressed: () => _showCategoryManager(),
              icon: const Icon(AppIcons.settings, size: 15),
              label: const Text('Manage categories'),
            ),
            const SizedBox(width: 4),
            SizedBox(
              width: 230,
              height: 38,
              child: TextField(
                controller: _search,
                decoration: const InputDecoration(
                  hintText: 'Search suppliers…',
                  prefixIcon: Icon(AppIcons.search, size: 17),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () => _showSupplierDialog(),
              icon: const Icon(AppIcons.plus, size: 16),
              label: const Text('Add supplier'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (list.isEmpty)
          SectionCard(
            title: _cat == 'All' ? 'Suppliers' : _cat,
            bodyPadding: const EdgeInsets.all(40),
            child: Center(
              child: Text(
                'No suppliers match.',
                style: TextStyle(
                  color: isDark ? AppColors.darkText2 : AppColors.text2,
                ),
              ),
            ),
          )
        else
          SectionCard(
            title: _cat == 'All' ? 'Suppliers' : _cat,
            trailing: Pill.paid('${list.length} suppliers'),
            bodyPadding: const EdgeInsets.all(20),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 330,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: 2.2,
              ),
              itemCount: list.length,
              itemBuilder: (context, i) => _SupplierCard(
                s: list[i],
                isDark: isDark,
                onEdit: () => _showSupplierDialog(supplier: list[i]),
                onDelete: () => _deleteSupplier(list[i]),
              ),
            ),
          ),
      ],
    );
  }

  // -------------------------------------------------------------
  // Supplier dialog
  // -------------------------------------------------------------
  void _showSupplierDialog({Supplier? supplier}) {
    final name = TextEditingController(text: supplier?.name ?? '');
    final contact = TextEditingController(text: supplier?.contact ?? '');
    final phone = TextEditingController(text: supplier?.phone ?? '');
    final email = TextEditingController(text: supplier?.email ?? '');
    final terms = TextEditingController(text: supplier?.terms ?? '30 days');
    final addr = TextEditingController(text: supplier?.addr ?? '');
    final cats = demo.supplierCategories;
    String? cat = supplier?.cat ?? cats.first;

    showDialog<void>(
      context: context,
      builder: (dctx) => AlertDialog(
        title: Text(supplier == null ? 'Add supplier' : 'Edit · ${supplier.name}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                autofocus: supplier == null,
                decoration: const InputDecoration(
                  labelText: 'NAME',
                  hintText: 'e.g. Makro España S.A.',
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: cat,
                decoration: const InputDecoration(labelText: 'CATEGORY'),
                items: [
                  for (final c in cats) DropdownMenuItem(value: c, child: Text(c)),
                ],
                onChanged: (v) => cat = v,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: contact,
                decoration: const InputDecoration(labelText: 'CONTACT NAME'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'PHONE'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: email,
                decoration: const InputDecoration(labelText: 'EMAIL'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: terms,
                decoration: const InputDecoration(
                  labelText: 'PAYMENT TERMS',
                  hintText: 'e.g. COD, 15 days, 30 days',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: addr,
                decoration: const InputDecoration(labelText: 'ADDRESS'),
              ),
            ],
          ),
        ),
        actions: [
          if (supplier != null)
            TextButton.icon(
              onPressed: () {
                Navigator.pop(dctx);
                _deleteSupplier(supplier);
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
              final t = terms.text.trim().isEmpty ? '30 days' : terms.text.trim();
              if (supplier == null) {
                demo.addSupplier(
                  name: name.text.trim(),
                  contact:
                      contact.text.trim().isEmpty ? '—' : contact.text.trim(),
                  phone: phone.text.trim().isEmpty ? '—' : phone.text.trim(),
                  email: email.text.trim().isEmpty ? '—' : email.text.trim(),
                  cat: cat ?? demo.supplierCategories.first,
                  terms: t,
                  addr: addr.text.trim().isEmpty ? '—' : addr.text.trim(),
                );
                demo.addAudit('New supplier added', 'create',
                    '${name.text.trim()} · $cat');
                showToast(context, 'Supplier added', icon: AppIcons.check);
              } else {
                demo.updateSupplier(
                  supplier,
                  name: name.text.trim(),
                  contact: contact.text.trim(),
                  phone: phone.text.trim(),
                  email: email.text.trim(),
                  cat: cat ?? supplier.cat,
                  terms: t,
                  addr: addr.text.trim(),
                );
                demo.addAudit(
                    'Supplier updated', 'update', '${name.text.trim()} · $cat');
                showToast(context, 'Supplier updated', icon: AppIcons.check);
              }
              setState(() {});
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _deleteSupplier(Supplier s) {
    showDialog<void>(
      context: context,
      builder: (dctx) => AlertDialog(
        title: Text('Delete ${s.name}?'),
        content: const Text('This will remove the supplier from your records.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.red,
            ),
            onPressed: () {
              Navigator.pop(dctx);
              final idx = demo.suppliers.indexOf(s);
              demo.deleteSupplier(s);
              demo.addAudit('Supplier deleted', 'delete', s.name);
              final undo = demo.scheduleDbDelete(
                () => demo.deleteSupplierDb(s),
                undoUi: () {
                  if (idx >= 0) {
                    demo.suppliers
                        .insert(idx.clamp(0, demo.suppliers.length), s);
                  } else {
                    demo.suppliers.add(s);
                  }
                },
              );
              showToast(
                context,
                '${s.name} deleted',
                subtitle: 'Deleting in 5s',
                icon: AppIcons.trash,
                kind: 'danger',
                actionLabel: 'Undo',
                onAction: () {
                  undo();
                  demo.addAudit('Delete undone', 'update', s.name);
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

  // -------------------------------------------------------------
  // Category manager
  // -------------------------------------------------------------
  void _showCategoryManager() {
    final cats = List.of(demo.supplierCategories);
    showDialog<void>(
      context: context,
      builder: (dctx) => StatefulBuilder(
        builder: (dctx, setDlg) => AlertDialog(
          title: const Text('Supplier categories'),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Categories are shared across all suppliers. Removing one '
                  'moves its suppliers to the first remaining category.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? AppColors.darkText2
                        : AppColors.text2,
                  ),
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        for (var i = 0; i < cats.length; i++)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    initialValue: cats[i],
                                    decoration: const InputDecoration(
                                      isDense: true,
                                    ),
                                    onChanged: (v) => cats[i] = v,
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Remove category',
                                  icon: Icon(
                                    AppIcons.trash,
                                    size: 16,
                                    color: AppColors.red,
                                  ),
                                  onPressed: () => setDlg(() => cats.removeAt(i)),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => setDlg(() => cats.add('')),
                    icon: const Icon(AppIcons.plus, size: 15),
                    label: const Text('Add category'),
                  ),
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
                Navigator.pop(dctx);
                demo.saveSupplierCategories(cats);
                demo.addAudit(
                  'Supplier categories updated',
                  'update',
                  cats.where((c) => c.trim().isNotEmpty).join(', '),
                );
                showToast(context, 'Categories saved', icon: AppIcons.check);
                setState(() {});
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------
// Supplier card — compact horizontal layout
// ----------------------------------------------------------------
class _SupplierCard extends StatelessWidget {
  final Supplier s;
  final bool isDark;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _SupplierCard({
    required this.s,
    required this.isDark,
    required this.onEdit,
    required this.onDelete,
  });

  String get _initials => s.name
      .split(' ')
      .take(2)
      .map((w) => w.isEmpty ? '' : w[0])
      .join()
      .toUpperCase();

  @override
  Widget build(BuildContext context) {
    final line = isDark ? AppColors.darkLine : AppColors.line;
    final sub = isDark ? AppColors.darkText2 : AppColors.text2;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.card,
        border: Border.all(color: line),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.brandT,
              borderRadius: BorderRadius.circular(11),
            ),
            alignment: Alignment.center,
            child: Text(
              _initials,
              style: const TextStyle(
                color: AppColors.brand,
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Full-width name row — nothing competes with it.
                Text(
                  s.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Pill.paid(s.terms),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        s.cat,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: AppColors.brand,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${s.contact} · ${s.phone}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11.5, color: sub),
                ),
                const SizedBox(height: 1),
                Text(
                  s.email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11.5, color: sub),
                ),
              ],
            ),
          ),
          // Compact icon-only actions — no labels stealing width.
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Edit supplier',
                onPressed: onEdit,
                icon: Icon(AppIcons.edit, size: 16, color: sub),
                visualDensity: VisualDensity.compact,
              ),
              IconButton(
                tooltip: 'Delete supplier',
                onPressed: onDelete,
                icon: const Icon(AppIcons.trash, size: 16, color: AppColors.red),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
