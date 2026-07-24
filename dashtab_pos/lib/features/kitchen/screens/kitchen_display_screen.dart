import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/kitchen_provider.dart';
import 'dart:async';

class KitchenDisplayScreen extends ConsumerStatefulWidget {
  const KitchenDisplayScreen({super.key});

  @override
  ConsumerState<KitchenDisplayScreen> createState() => _KitchenDisplayScreenState();
}

class _KitchenDisplayScreenState extends ConsumerState<KitchenDisplayScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Refresh every minute to update times
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatDuration(DateTime start) {
    final diff = DateTime.now().difference(start);
    return '${diff.inMinutes}m';
  }

  @override
  Widget build(BuildContext context) {
    final ticketsAsync = ref.watch(kitchenProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/pos'),
        ),
        title: const Text('Kitchen Display (KDS)'),
        backgroundColor: Colors.orange.shade800,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(kitchenProvider.notifier).build(), // Refresh data
          ),
        ],
      ),
      body: ticketsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (tickets) {
          if (tickets.isEmpty) {
            return const Center(child: Text('No active tickets.', style: TextStyle(fontSize: 24, color: Colors.grey)));
          }
          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              childAspectRatio: 0.7,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: tickets.length,
            itemBuilder: (context, index) {
              final ticket = tickets[index];
              final isWarning = DateTime.now().difference(ticket.createdAt).inMinutes > 10;
              final isDanger = DateTime.now().difference(ticket.createdAt).inMinutes > 20;
              
              Color headerColor = Colors.green.shade600;
              if (isDanger) {
                headerColor = Colors.red.shade600;
              } else if (isWarning) {
                headerColor = Colors.orange.shade600;
              }

              return Card(
                elevation: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      color: headerColor,
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(ticket.tableName ?? 'Takeaway', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                              Text(_formatDuration(ticket.createdAt), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(ticket.ticketNumber, style: const TextStyle(color: Colors.white70)),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.separated(
                        itemCount: ticket.items.length,
                        separatorBuilder: (context, index) => const Divider(height: 1),
                        itemBuilder: (context, idx) {
                          final item = ticket.items[idx];
                          return ListTile(
                            leading: Text('${item.quantity}x', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            title: Text(item.productName, style: const TextStyle(fontSize: 16)),
                            subtitle: item.notes != null ? Text(item.notes!, style: const TextStyle(color: Colors.red)) : null,
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ticket.status == 0 ? Colors.orange : Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        onPressed: () {
                           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ticket updated!')));
                        },
                        child: Text(ticket.status == 0 ? 'START PREPARING' : 'MARK READY', style: const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
