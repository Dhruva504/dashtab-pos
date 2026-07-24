import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/floor_provider.dart';
import '../widgets/table_widget.dart';
import '../../../domain/entities/table.dart';

class FloorPlanScreen extends ConsumerWidget {
  const FloorPlanScreen({Key? key}) : super(key: key);

  void _onTableTapped(BuildContext context, RestaurantTable table) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Table ${table.name}'),
        content: Text('Status: ${table.status.name.toUpperCase()}\nCapacity: ${table.capacity}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.go('/pos'); // Go to POS with this table active
            },
            child: const Text('OPEN POS'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final floorAsync = ref.watch(floorProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Floor Plan'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.go('/settings'),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(floorProvider.notifier).refresh(),
          ),
        ],
      ),
      body: floorAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error loading floors: $err')),
        data: (floors) {
          if (floors.isEmpty) {
            return const Center(child: Text('No floors configured.'));
          }
          
          final currentFloor = floors.first; // Hardcoded to first floor for now
          
          return InteractiveViewer(
            constrained: false,
            boundaryMargin: const EdgeInsets.all(100),
            minScale: 0.5,
            maxScale: 2.0,
            child: Container(
              width: 1200,
              height: 800,
              color: Colors.grey.shade200, // Background color
              child: Stack(
                children: currentFloor.tables.map((table) {
                  return TableWidget(
                    table: table,
                    onTap: () => _onTableTapped(context, table),
                  );
                }).toList(),
              ),
            ),
          );
        },
      ),
    );
  }
}
