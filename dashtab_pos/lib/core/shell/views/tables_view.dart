import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/app_theme.dart';
import '../../theme/app_icons.dart';
import '../../theme/demo_data.dart';
import '../../theme/app_widgets.dart';
import '../home_shell.dart';
import '../widgets/payment_modal.dart';

/// Tables view — mirrors the HTML tables section (zone tabs + table cards).
class TablesView extends ConsumerStatefulWidget {
  const TablesView({super.key});

  @override
  ConsumerState<TablesView> createState() => _TablesViewState();
}

class _TablesViewState extends ConsumerState<TablesView> {
  // 'All tables' is the default so every table shows on first open.
  String _zone = 'All tables';

  /// Grid of cards vs. the draggable visual floor plan.
  bool _planMode = false;

  /// Whether the plan is in "arrange" mode (drag / resize handles visible).
  bool _editLayout = false;

  int _statusCount(String s) => demo.tables.where((t) => t.status == s).length;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final d = demo;
    // Zones come from the live tables (their `zone` column in the DB).
    final tables = _zone == 'All tables'
        ? d.tables
        : d.tables
            .where((t) =>
                t.floorId ==
                d.floors.where((f) => f.name == _zone).firstOrNull?.dbId)
            .toList();

    String elapsed(DemoTable t) {
      if (t.startedAtMs == null) return '--:--';
      final mins =
          (DateTime.now().millisecondsSinceEpoch - t.startedAtMs!) ~/ 60000;
      final h = mins ~/ 60;
      final m = mins % 60;
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
    }

    return ListView(
      padding: const EdgeInsets.all(24),
      // Layout editing owns the pointer: no page scrolling while dragging
      // tables, so a drag never scrolls the view instead of moving a table.
      physics: _planMode && _editLayout
          ? const NeverScrollableScrollPhysics()
          : null,
      children: [
        AppCard(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'Floor Overview',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                // Grid of cards / draggable floor plan.
                FilterChipBtn(
                  label: 'Grid',
                  selected: !_planMode,
                  onTap: () => setState(() => _planMode = false),
                ),
                FilterChipBtn(
                  label: 'Floor plan',
                  selected: _planMode,
                  onTap: () => setState(() => _planMode = true),
                ),
                if (_planMode && _editLayout)
                  OutlinedButton.icon(
                    onPressed: () => _arrangeShownFloors(),
                    icon: const Icon(AppIcons.squares, size: 16),
                    label: const Text('Arrange'),
                  ),
                if (_planMode)
                  FilterChipBtn(
                    label: _editLayout ? 'Editing layout' : 'Edit layout',
                    selected: _editLayout,
                    onTap: () => setState(() {
                      _editLayout = !_editLayout;
                      // One plan at a time while editing, so the tables of the
                      // floor you are working on always fit on screen.
                      if (_editLayout &&
                          _zone == 'All tables' &&
                          d.floors.isNotEmpty) {
                        _zone = d.floors.first.name;
                      }
                    }),
                  ),
                if (!_planMode) ...[
                  OutlinedButton.icon(
                    onPressed: () => _showFloorManager(context),
                    icon: const Icon(AppIcons.grid, size: 16),
                    label: const Text('Manage Zones'),
                  ),
                ],
                OutlinedButton.icon(
                  onPressed: () => _showTableEditor(context),
                  icon: const Icon(AppIcons.plus, size: 16),
                  label: const Text('Add Table'),
                ),
                // The plan colours each table by status, so the legend is
                // only needed in the card grid.
                if (!_planMode) ...[
                  _LegendItem(
                    color: isDark ? AppColors.darkLine : AppColors.line,
                    label: '${_statusCount('free')} free',
                  ),
                  _LegendItem(
                    color: AppColors.brand,
                    label: '${_statusCount('occ')} occupied',
                  ),
                  _LegendItem(
                    color: AppColors.violet,
                    label: '${_statusCount('res')} reserved',
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Zone tabs (DB floors) — tables are grouped by the zone they sit in.
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            for (final f in [
              'All tables',
              ...d.floors.map((f) => f.name),
            ])
              Builder(builder: (_) {
                final floor = d.floors
                    .where((x) => x.name == f)
                    .firstOrNull;
                final count = f == 'All tables'
                    ? d.tables.length
                    : d.tables.where((t) => t.floorId == floor?.dbId).length;
                return FilterChipBtn(
                  label: '$f · $count',
                  selected: _zone == f,
                  onTap: () => setState(() => _zone = f),
                );
              }),
          ],
        ),
        const SizedBox(height: 16),
        if (_planMode)
          ..._buildFloorPlans(context, tables)
        else
        GridView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 180,
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            childAspectRatio: 0.9,
          ),
          children: tables
              .map(
                (t) => InkWell(
                  onTap: () => _showTableDialog(context, t),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: t.status == 'occ'
                          ? AppColors.brandT
                          : t.status == 'res'
                          ? AppColors.violetT
                          : (isDark ? AppColors.darkCard : AppColors.card),
                      border: Border.all(
                        color: t.status == 'occ'
                            ? AppColors.brand
                            : t.status == 'res'
                            ? AppColors.violet
                            : (isDark ? AppColors.darkLine : AppColors.line),
                        width: 1.5,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: t.status == 'free' ? [] : AppTheme.shadow,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                t.name,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(
                                      fontSize: 18,
                                      color: t.status == 'occ'
                                          ? AppColors.brand
                                          : t.status == 'res'
                                          ? AppColors.violet
                                          : (isDark
                                                ? AppColors.darkText
                                                : AppColors.text),
                                    ),
                              ),
                            ),
                            const Spacer(),
                            // Edit / delete affordances (stop propagation so
                            // they don't trigger the card's tap action).
                            _TableCardAction(
                              icon: AppIcons.pencil,
                              tooltip: 'Edit table',
                              onTap: () => _showTableEditor(context, t),
                            ),
                            const SizedBox(width: 2),
                            _TableCardAction(
                              icon: AppIcons.trash,
                              tooltip: 'Delete table',
                              onTap: () => _confirmDeleteTable(context, t),
                            ),
                            const SizedBox(width: 4),
                            if (t.status == 'occ')
                              const Pill(
                                'OCC',
                                color: AppColors.brand,
                                background: Colors.transparent,
                              )
                            else if (t.status == 'res')
                              const Pill(
                                'RES',
                                color: AppColors.violet,
                                background: Colors.transparent,
                              )
                            else
                              Pill.free('FREE'),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(
                              AppIcons.users,
                              size: 13,
                              color: isDark
                                  ? AppColors.darkText2
                                  : AppColors.text2,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${t.seats} seats',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? AppColors.darkText2
                                    : AppColors.text2,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (t.status == 'occ')
                          Text(
                            '${t.guest ?? 'Walk-in'} · ${t.persons ?? 1} pax\n${elapsed(t)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: t.status == 'occ'
                                  ? AppColors.brand
                                  : (isDark
                                        ? AppColors.darkText
                                        : AppColors.text),
                            ),
                          )
                        else if (t.status == 'res')
                          Text(
                            '${t.guest ?? 'Reserved'} · ${t.persons ?? 1} pax',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.violet,
                            ),
                          )
                        else
                          Text(
                            'Tap to seat guests',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? AppColors.darkText3
                                  : AppColors.text3,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  /// One draggable plan per floor currently shown (all floors, or the zone
  /// selected in the chips above).
  List<Widget> _buildFloorPlans(BuildContext context, List<DemoTable> tables) {
    final grouped = <String, List<DemoTable>>{};
    for (final t in tables) {
      grouped.putIfAbsent(t.floorId ?? '', () => []).add(t);
    }
    if (grouped.isEmpty) {
      return [
        EmptyState(
          icon: AppIcons.map,
          title: 'Nothing to lay out',
          message: _zone == 'All tables'
              ? 'Add a table to start building the floor plan.'
              : 'No tables in $_zone yet.',
        ),
      ];
    }
    return [
      for (final entry in grouped.entries) ...[
        _FloorPlanCanvas(
          key: ValueKey('plan-${entry.key}'),
          title: demo.floors
                  .where((f) => f.dbId == entry.key)
                  .map((f) => f.name)
                  .firstOrNull ??
              'Unassigned',
          tables: entry.value,
          editing: _editLayout,
          onTapTable: (t) => _showTableDialog(context, t),
          onEditTable: (t) => _showTableEditor(context, t),
          onArrange: () => setState(
            () => demo.arrangeFloorLayout(entry.key.isEmpty ? null : entry.key),
          ),
        ),
        const SizedBox(height: 16),
      ],
    ];
  }

  /// Re-lays every plan currently on screen on a tidy grid.
  void _arrangeShownFloors() {
    final ids = _zone == 'All tables'
        ? demo.floors.map((f) => f.dbId).toList()
        : [
            demo.floors.where((f) => f.name == _zone).firstOrNull?.dbId,
          ];
    if (ids.isEmpty) return;
    setState(() {
      for (final id in ids) {
        demo.arrangeFloorLayout(id);
      }
    });
    showToast(
      context,
      'Floor plan arranged',
      icon: AppIcons.squares,
    );
  }

  void _showTableDialog(BuildContext context, DemoTable t) {
    if (t.status == 'occ') {
      _showTableActions(t);
    } else {
      _showCheckIn(t);
    }
  }

  /// Create / edit modal for a table (name + seats + zone).
  /// Pass a table to edit it; leave null to create a new one.
  void _showTableEditor(BuildContext context, [DemoTable? t]) {
    final name = TextEditingController(text: t?.name ?? '');
    final seats = TextEditingController(text: '${t?.seats ?? 4}');
    final zoneNames = demo.floors.map((f) => f.name).toList();
    final currentZone = t == null
        ? null
        : demo.floors.where((f) => f.dbId == t.floorId).firstOrNull;
    var selectedZone = currentZone?.name ??
        (demo.floors.isNotEmpty ? demo.floors.first.name : '');
    var shape = t?.shape ?? 0;
    showDialog<void>(
      context: context,
      builder: (dctx) => StatefulBuilder(
        builder: (dctx, setDlg) => AlertDialog(
        title: Text(t == null ? 'Add Table' : 'Edit Table ${t.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'TABLE NAME',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.06,
                color: AppColors.text3,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: name,
              autofocus: t == null,
              decoration: const InputDecoration(
                hintText: 'e.g. T9',
                prefixIcon: Icon(AppIcons.table, size: 18),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'SEATS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.06,
                color: AppColors.text3,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: seats,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                hintText: '4',
                prefixIcon: Icon(AppIcons.users, size: 18),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'ZONE',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.06,
                color: AppColors.text3,
              ),
            ),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              initialValue: selectedZone.isEmpty ? null : selectedZone,
              hint: zoneNames.isEmpty ? const Text('No zones yet') : null,
              items: [
                for (final f in zoneNames)
                  DropdownMenuItem(value: f, child: Text(f)),
              ],
              onChanged: (v) => setDlg(() => selectedZone = v ?? selectedZone),
              decoration: const InputDecoration(
                prefixIcon: Icon(AppIcons.buildings, size: 18),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'SHAPE ON THE FLOOR PLAN',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.06,
                color: AppColors.text3,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                FilterChipBtn(
                  label: 'Rectangle',
                  selected: shape == 0,
                  onTap: () => setDlg(() => shape = 0),
                ),
                const SizedBox(width: 8),
                FilterChipBtn(
                  label: 'Round',
                  selected: shape == 1,
                  onTap: () => setDlg(() => shape = 1),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dctx),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () async {
              final tableName = name.text.trim();
              final seatCount = int.tryParse(seats.text.trim()) ?? 0;
              if (tableName.isEmpty || seatCount < 1) return;
              final zone = demo.floors
                  .where((f) => f.name == selectedZone)
                  .firstOrNull;
              Navigator.pop(dctx);
              if (t == null) {
                await demo.addTable(
                  name: tableName,
                  seats: seatCount,
                  floorId: zone?.dbId,
                  shape: shape,
                );
                if (!context.mounted) return;
                demo.addAudit('Table $tableName created', 'create', '$seatCount seats');
                showToast(context, 'Table $tableName added', icon: AppIcons.check);
              } else {
                demo.editTable(
                  t,
                  name: tableName,
                  seats: seatCount,
                  shape: shape,
                );
                if ((zone?.dbId ?? '') != (t.floorId ?? '')) {
                  await demo.moveTableToFloor(t, zone?.dbId);
                }
                demo.addAudit('Table ${t.name} updated', 'update', '');
                if (!context.mounted) return;
                showToast(context, 'Table ${t.name} updated', icon: AppIcons.check);
              }
              if (mounted) setState(() {});
            },
            child: Text(t == null ? 'Add Table' : 'Save Changes'),
          ),
        ],
      ),
      ),
    );
  }

  /// Delete confirmation for a table (blocked when it has an open order).
  void _confirmDeleteTable(BuildContext context, DemoTable t) {
    showDialog<void>(
      context: context,
      builder: (dctx) => AlertDialog(
        title: Text('Delete Table ${t.name}?'),
        content: Text(
          'This removes ${t.name} (${t.seats} seats) permanently. '
          'Tables with open orders cannot be deleted.',
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
              final removed = demo.deleteTable(t);
              if (!removed) {
                showToast(
                  context,
                  'Table ${t.name} has an open order',
                  subtitle: 'Settle or free it before deleting',
                  icon: AppIcons.info,
                  kind: 'warn',
                );
                return;
              }
              demo.addAudit('Table ${t.name} deleted', 'delete', '');
              final idx = demo.tables.indexOf(t);
              final undo = demo.scheduleDbDelete(
                () => demo.deleteTableDb(t),
                undoUi: () {
                  if (idx >= 0) {
                    demo.tables.insert(idx.clamp(0, demo.tables.length), t);
                  } else {
                    demo.tables.add(t);
                  }
                },
              );
              showToast(
                context,
                'Table ${t.name} deleted',
                subtitle: 'Deleting in 5s',
                icon: AppIcons.trash,
                kind: 'danger',
                actionLabel: 'Undo',
                onAction: () {
                  undo();
                  demo.addAudit('Delete undone', 'update', t.name);
                },
                duration: const Duration(seconds: 5),
              );
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  /// Zone manager modal: list zones with rename / delete, and add new ones.
  void _showFloorManager(BuildContext context) {
    final newFloorCtrl = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (dctx) => StatefulBuilder(
        builder: (dctx, setDlg) => AlertDialog(
          title: const Text('Manage Zones'),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (demo.floors.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'No zones yet. Add one to start organising tables.',
                      style: TextStyle(color: AppColors.text3, fontSize: 13),
                    ),
                  ),
                for (final f in List<DemoFloor>.of(demo.floors))
                  Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? AppColors.darkCard2
                          : AppColors.card2,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          AppIcons.buildings,
                          size: 16,
                          color: AppColors.brand,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            f.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        Text(
                          '${demo.tables.where((t) => t.floorId == f.dbId).length} tables',
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: AppColors.text3,
                          ),
                        ),
                        const SizedBox(width: 6),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          tooltip: 'Rename zone',
                          onPressed: () => _renameFloor(context, f, setDlg),
                          icon: const Icon(
                            AppIcons.pencil,
                            size: 16,
                            color: AppColors.text3,
                          ),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          tooltip: 'Delete zone',
                          onPressed: () async {
                            Navigator.pop(dctx);
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (dctx2) => AlertDialog(
                                title: Text('Delete zone ${f.name}?'),
                                content: Text(
                                  'This removes the zone and every table in it. '
                                  'Tables with open orders block the deletion.',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(dctx2, false),
                                    child: const Text('Cancel'),
                                  ),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.red,
                                      foregroundColor: Colors.white,
                                    ),
                                    onPressed: () =>
                                        Navigator.pop(dctx2, true),
                                    child: const Text('Delete zone'),
                                  ),
                                ],
                              ),
                            );
                            if (confirmed != true) return;
                            final ok = await demo.deleteFloor(f);
                            if (!context.mounted) return;
                            if (!ok) {
                              showToast(
                                context,
                                'Zone ${f.name} has tables with open orders',
                                subtitle: 'Settle them before deleting the zone',
                                icon: AppIcons.info,
                                kind: 'warn',
                              );
                              return;
                            }
                            demo.addAudit('Zone ${f.name} deleted', 'delete', '');
                            final idx = demo.floors.indexOf(f);
                            final removedTables = demo.tables
                                .where((tb) => tb.floorId == f.dbId)
                                .toList();
                            final undo = demo.scheduleDbDelete(
                              () => demo.deleteFloorDb(f),
                              undoUi: () {
                                if (idx >= 0) {
                                  demo.floors
                                      .insert(idx.clamp(0, demo.floors.length), f);
                                } else {
                                  demo.floors.add(f);
                                }
                                for (final tb in removedTables) {
                                  if (!demo.tables.contains(tb)) {
                                    demo.tables.add(tb);
                                  }
                                }
                              },
                            );
                            showToast(
                              context,
                              'Zone ${f.name} deleted',
                              subtitle: 'Deleting in 5s',
                              icon: AppIcons.trash,
                              kind: 'danger',
                              actionLabel: 'Undo',
                              onAction: () {
                                undo();
                                demo.addAudit(
                                    'Delete undone', 'update', f.name);
                              },
                              duration: const Duration(seconds: 5),
                            );
                            if (mounted) setState(() {});
                          },
                          icon: const Icon(
                            AppIcons.trash,
                            size: 16,
                            color: AppColors.red,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: newFloorCtrl,
                        decoration: const InputDecoration(
                          hintText: 'New zone name…',
                          isDense: true,
                          prefixIcon: Icon(AppIcons.grid, size: 18),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () async {
                        final floorName = newFloorCtrl.text.trim();
                        if (floorName.isEmpty) return;
                        Navigator.pop(dctx);
                        await demo.addFloor(floorName);
                        if (!context.mounted) return;
                        demo.addAudit('Zone $floorName created', 'create', '');
                        showToast(
                          context,
                          'Zone $floorName added',
                          icon: AppIcons.check,
                        );
                        if (mounted) setState(() {});
                      },
                      icon: const Icon(AppIcons.plus, size: 16),
                      label: const Text('Add Zone'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dctx),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }

  /// Inline rename prompt for a zone.
  void _renameFloor(BuildContext context, DemoFloor f, StateSetter refresh) {
    final ctrl = TextEditingController(text: f.name);
    showDialog<void>(
      context: context,
      builder: (rctx) => AlertDialog(
        title: Text('Rename ${f.name}'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Zone name',
            prefixIcon: Icon(AppIcons.buildings, size: 18),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(rctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newName = ctrl.text.trim();
              Navigator.pop(rctx);
              Navigator.pop(context); // close the manager too
              if (newName.isEmpty || newName == f.name) return;
              await demo.editFloor(f, newName);
              if (!context.mounted) return;
              demo.addAudit('Zone $newName renamed', 'update', '');
              showToast(context, 'Zone renamed to $newName', icon: AppIcons.check);
              if (mounted) setState(() {});
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    );
  }

  /// Check-in modal: guest name + persons stepper + Reserve / Check In & Order.
  void _showCheckIn(DemoTable t) {
    final name = TextEditingController(text: t.guest ?? '');
    var persons = (t.persons ?? 2).clamp(1, 20);
    showDialog<void>(
      context: context,
      builder: (dctx) => StatefulBuilder(
        builder: (dctx, setDlg) => AlertDialog(
          title: Text('Table ${t.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'GUEST NAME',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.06,
                  color: AppColors.text3,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: name,
                decoration: const InputDecoration(
                  hintText: 'e.g. Jessica Alba',
                  prefixIcon: Icon(AppIcons.user, size: 18),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'PERSONS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.06,
                  color: AppColors.text3,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  _StepperBtn(
                    icon: AppIcons.minus,
                    onTap: () => setDlg(() => persons = (persons - 1).clamp(1, 20)),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      '$persons',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  _StepperBtn(
                    icon: AppIcons.plus,
                    onTap: () => setDlg(() => persons = (persons + 1).clamp(1, 20)),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dctx);
                demo.reserveTable(t, name.text, persons);
                showToast(
                  context,
                  'Table ${t.name} reserved',
                  icon: AppIcons.check,
                );
              },
              child: Text(
                'Reserve',
                style: TextStyle(color: AppColors.violet, fontWeight: FontWeight.w700),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dctx),
              child: const Text('Close'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dctx);
                _checkIn(t, name.text, persons);
              },
              child: const Text('Check In + Order'),
            ),
          ],
        ),
      ),
    );
  }

  void _checkIn(DemoTable t, String guest, int persons) {
    demo.checkIn(t, guest, persons);
    demo.cart.clear();
    demo.cartMeta = {
      'type': 'Dine In',
      'table': t.name,
      'customer': t.guest,
    };
    demo.addAudit(
      'Table ${t.name} checked in',
      'update',
      '$guest · $persons pax',
    );
    showToast(
      context,
      'Table ${t.name} ready — add items',
      subtitle: '$guest · $persons pax',
      icon: AppIcons.table,
    );
    ref.read(currentViewProvider.notifier).go(
      const ShellView('pos', 'New Order', 'Point of Sale terminal · Register A'),
    );
  }

  /// Actions modal for an occupied table: Free / Add Items / Settle Bill.
  void _showTableActions(DemoTable t) {
    final order = demo.orders
        .where((o) => o.table == t.name && o.status != 'Paid' && o.status != 'Cancelled' && o.status != 'Refunded')
        .firstOrNull;
    showDialog<void>(
      context: context,
      builder: (dctx) => AlertDialog(
        title: Text('Table ${t.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.brandT,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${t.guest ?? 'Walk-in'} · ${t.persons ?? 1} pax',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppColors.brand,
                    ),
                  ),
                  Text(
                    order != null
                        ? 'Open order #${order.id} · ${fmt(order.total)}'
                        : 'No open order on this table',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.brand,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dctx),
            child: const Text('Close'),
          ),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.pop(dctx);
              demo.freeTable(t);
              demo.addAudit('Table ${t.name} freed', 'update', '');
              showToast(context, 'Table ${t.name} is now free', icon: AppIcons.check);
            },
            icon: const Icon(AppIcons.x, size: 16),
            label: const Text('Free Table'),
            style: OutlinedButton.styleFrom(foregroundColor: AppColors.red),
          ),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.pop(dctx);
              // Only editable orders (not paid/cancelled/refunded) resume.
              final resumable = order != null &&
                  order.status != 'Paid' &&
                  order.status != 'Cancelled' &&
                  order.status != 'Refunded';
              if (resumable) {
                demo.cart
                  ..clear()
                  ..addAll(order.items
                      .map((l) => CartLine(l.productId, l.qty, note: l.note, discPct: l.discPct)));
                // Mark the cart as the SAME order (id stays stable) and bring
                // back its discount, matched by the amount it took off.
                final restored = demo.discounts
                    .where((x) =>
                        order.disc > 0 && (x.applyTo(order.sub) - order.disc).abs() < 0.01)
                    .firstOrNull;
                demo.cartMeta = {
                  'type': order.type,
                  'table': order.table,
                  'customer': order.customer,
                  // Keep the id-based attribution (duplicate-name safe).
                  'customerId': order.customerId != null &&
                          demo.customers.any((c) =>
                              c.dbId == order.customerId ||
                              c.id.toString() == order.customerId)
                      ? order.customerId
                      : null,
                  'resumedOrderId': order.id,
                  'discount': restored?.name,
                };
              } else {
                if (order != null) {
                  showToast(
                    context,
                    'Order #${order.id} is ${order.status.toLowerCase()} — starting a new order',
                    icon: AppIcons.info,
                    kind: 'warn',
                  );
                }
                demo.cart.clear();
                demo.cartMeta = {'type': 'Dine In', 'table': t.name, 'customer': t.guest};
              }
              ref.read(currentViewProvider.notifier).go(
                const ShellView('pos', 'New Order', 'Point of Sale terminal · Register A'),
              );
            },
            icon: const Icon(AppIcons.plus, size: 16),
            label: const Text('Add Items'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(dctx);
              _settleBill(t, order);
            },
            icon: const Icon(AppIcons.cash, size: 16),
            label: const Text('Settle Bill'),
          ),
        ],
      ),
    );
  }

  void _settleBill(DemoTable t, DemoOrder? order) {
    if (order == null) {
      showToast(
        context,
        'No open bill on table ${t.name}',
        icon: AppIcons.info,
        kind: 'warn',
      );
      return;
    }
    PaymentModal.show(
      context,
      PaySession(
        items: order.items,
        type: order.type,
        customer: order.customer,
        table: order.table,
        sub: order.sub,
        tax: order.tax,
        total: order.total,
        srcOrder: order,
      ),
    ).then((paid) {
      if (paid != null && mounted) {
        setState(() {});
        showToast(
          context,
          'Order #${paid.id} settled',
          subtitle: '${fmt(paid.total)} via ${paid.method}',
        );
      }
    });
  }
}

/// Small icon button used on table cards for edit / delete actions.
class _TableCardAction extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _TableCardAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(
          icon,
          size: 15,
          color: isDark ? AppColors.darkText3 : AppColors.text3,
          semanticLabel: tooltip,
        ),
      ),
    );
  }
}

class _StepperBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _StepperBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard2 : AppColors.card2,
          border: Border.all(
            color: isDark ? AppColors.darkLine : AppColors.line,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          size: 16,
          color: isDark ? AppColors.darkText2 : AppColors.text2,
        ),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).brightness == Brightness.dark
                ? AppColors.darkText2
                : AppColors.text2,
          ),
        ),
      ],
    );
  }
}

/// Draggable, resizable floor plan for one floor.
///
/// Geometry is kept in "design units" (a 1000-wide canvas) and scaled to the
/// available width, so a layout looks identical on any screen size. Drag
/// deltas are divided by the scale to stay unit-accurate. Positions snap to a
/// 10-unit grid and are saved per table on drop.
class _FloorPlanCanvas extends StatefulWidget {
  final String title;
  final List<DemoTable> tables;
  final bool editing;
  final ValueChanged<DemoTable> onTapTable;
  final ValueChanged<DemoTable> onEditTable;
  final VoidCallback onArrange;

  const _FloorPlanCanvas({
    super.key,
    required this.title,
    required this.tables,
    required this.editing,
    required this.onTapTable,
    required this.onEditTable,
    required this.onArrange,
  });

  @override
  State<_FloorPlanCanvas> createState() => _FloorPlanCanvasState();
}

class _FloorPlanCanvasState extends State<_FloorPlanCanvas> {
  /// Design-space width of the plan; height grows with the tables.
  static const double _designW = 1000;
  static const double _minH = 620;
  static const double _grid = 20;

  /// Most of the plan that may be shown at once, in screen pixels.
  static const double _maxPlanHeight = 520;

  static double _snap(double v) => (v / 10).round() * 10.0;

  /// Where a table sits: its saved spot, or a tidy auto slot if it has never
  /// been placed (all DB rows start at 0,0).
  Offset _slot(DemoTable t) {
    if (t.placed) return Offset(t.x, t.y);
    var i = widget.tables.indexOf(t);
    if (i < 0) i = 0;
    final s = AppStore.autoLayoutSlot(i);
    return Offset(s.x, s.y);
  }

  double get _designH {
    var bottom = _minH;
    for (final t in widget.tables) {
      final b = _slot(t).dy + t.height;
      if (b + 60 > bottom) bottom = b + 60;
    }
    return bottom;
  }

  /// True while the active drag is resizing rather than moving.
  bool _resizing = false;

  /// Side of the bottom-right corner zone that resizes instead of moving.
  static const double _handleZone = 28;

  // Drag state: the geometry the gesture started from, plus the raw pointer
  // travel. Deltas are accumulated against the base rather than the live
  // value, so grid snapping never stalls a slow drag.
  double _baseX = 0, _baseY = 0, _baseW = 0, _baseH = 0;
  double _accX = 0, _accY = 0, _accW = 0, _accH = 0;

  /// An auto-placed table gets real coordinates the moment it is dragged.
  void _beginDrag(DemoTable t) {
    if (t.placed) return;
    final o = _slot(t);
    t
      ..x = o.dx
      ..y = o.dy
      ..placed = true;
  }

  /// One drag zone decides between resizing and moving, so the corner handle
  /// is simply "where the pointer went down" — no competing gesture arenas.
  void _startPan(DemoTable t, Offset local, double scale) {
    final w = t.width * scale;
    final h = t.height * scale;
    _resizing = (w - local.dx) <= _handleZone && (h - local.dy) <= _handleZone;
    _beginDrag(t);
    _baseX = t.x;
    _baseY = t.y;
    _baseW = t.width;
    _baseH = t.height;
    _accX = _accY = _accW = _accH = 0;
  }

  void _panBy(DemoTable t, Offset delta, double scale) {
    if (_resizing) {
      _accW += delta.dx / scale;
      _accH += delta.dy / scale;
      t.width = _snap(_baseW + _accW).clamp(90, 460);
      t.height = _snap(_baseH + _accH).clamp(80, 460);
      return;
    }
    _accX += delta.dx / scale;
    _accY += delta.dy / scale;
    t.x = _snap(_baseX + _accX).clamp(0, _designW - t.width);
    t.y = _snap(_baseY + _accY).clamp(0, double.maxFinite);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? AppColors.darkText3 : AppColors.text3;
    return Container(
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
                Icon(AppIcons.map, size: 16, color: muted),
                const SizedBox(width: 8),
                Text(
                  widget.title,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${widget.tables.length} tables',
                  style: TextStyle(fontSize: 11.5, color: muted),
                ),
                const Spacer(),
                if (widget.editing) ...[
                  Text(
                    'Drag to move · corner handle to resize',
                    style: TextStyle(fontSize: 11.5, color: muted),
                  ),
                  const SizedBox(width: 12),
                  TextButton.icon(
                    onPressed: widget.onArrange,
                    icon: const Icon(AppIcons.squares, size: 15),
                    label: const Text('Arrange'),
                  ),
                ] else
                  Text(
                    'Tap a table to manage it',
                    style: TextStyle(fontSize: 11.5, color: muted),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Fit the plan to the card, capped so a plan never needs the
                // page to scroll while it is being arranged.
                final scale = (constraints.maxWidth / _designW)
                    .clamp(0.25, _maxPlanHeight / _designH)
                    .clamp(0.25, 1.0);
                final w = _designW * scale;
                final h = _designH * scale;
                return Center(
                  child: SizedBox(
                    width: w,
                    height: h,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _PlanGridPainter(
                              step: _grid * scale,
                              color: isDark
                                  ? AppColors.darkLine2
                                  : AppColors.line2,
                            ),
                          ),
                        ),
                        for (final t in widget.tables)
                          ..._tableBox(t, scale),
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

  List<Widget> _tableBox(DemoTable t, double scale) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final o = _slot(t);
    final fill = t.status == 'occ'
        ? AppColors.brandT
        : t.status == 'res'
        ? AppColors.violetT
        : (isDark ? AppColors.darkCard : AppColors.card2);
    final stroke = t.status == 'occ'
        ? AppColors.brand
        : t.status == 'res'
        ? AppColors.violet
        : (isDark ? AppColors.darkLine : AppColors.line);
    final fg = t.status == 'occ'
        ? AppColors.brand
        : t.status == 'res'
        ? AppColors.violet
        : (isDark ? AppColors.darkText2 : AppColors.text2);

    return [
      Positioned(
        left: o.dx * scale,
        top: o.dy * scale,
        width: t.width * scale,
        height: t.height * scale,
        child: MouseRegion(
          cursor: widget.editing
              ? SystemMouseCursors.move
              : SystemMouseCursors.click,
          child: GestureDetector(
            key: ValueKey('plan-box-${t.name}'),
            behavior: HitTestBehavior.opaque,
            onTap: () => widget.editing
                ? widget.onEditTable(t)
                : widget.onTapTable(t),
            onPanStart: widget.editing
                ? (d) => setState(() => _startPan(t, d.localPosition, scale))
                : null,
            onPanUpdate: widget.editing
                ? (d) => setState(() => _panBy(t, d.delta, scale))
                : null,
            onPanEnd: widget.editing
                ? (_) => setState(() {
                      _resizing = false;
                      demo.setTableLayout(t);
                    })
                : null,
            child: Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: fill,
                    border: Border.all(
                      color: widget.editing ? AppColors.brand : stroke,
                      width: 1.5,
                    ),
                    borderRadius:
                        BorderRadius.circular(t.shape == 1 ? 999 : 14),
                  ),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.all(6),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          t.name,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: t.status == 'free' ? null : fg,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${t.seats} seats',
                          style: TextStyle(fontSize: 11.5, color: fg),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: stroke.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Text(
                            t.status == 'occ'
                                ? 'OCCUPIED'
                                : t.status == 'res'
                                ? 'RESERVED'
                                : 'FREE',
                            style: TextStyle(
                              fontSize: 9.5,
                              letterSpacing: 0.06,
                              fontWeight: FontWeight.w800,
                              color: fg,
                            ),
                          ),
                        ),
                        if (t.status == 'occ') ...[
                          const SizedBox(height: 4),
                          Text(
                            '${t.guest ?? 'Walk-in'} · ${t.persons ?? 1} pax',
                            style: const TextStyle(
                              fontSize: 10.5,
                              color: AppColors.brand,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                if (widget.editing)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: IgnorePointer(
                      child: Container(
                        key: ValueKey('plan-handle-${t.name}'),
                        width: 24,
                        height: 24,
                        decoration: const BoxDecoration(
                          color: AppColors.brand,
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(9),
                            bottomRight: Radius.circular(14),
                          ),
                        ),
                        child: const Icon(
                          AppIcons.resize,
                          size: 13,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    ];
  }
}

/// Light dotted grid behind the plan so staff can line tables up.
class _PlanGridPainter extends CustomPainter {
  final double step;
  final Color color;

  const _PlanGridPainter({required this.step, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (step <= 0) return;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    for (var x = step; x < size.width; x += step) {
      for (var y = step; y < size.height; y += step) {
        canvas.drawCircle(Offset(x, y), 1, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_PlanGridPainter old) =>
      old.step != step || old.color != color;
}
