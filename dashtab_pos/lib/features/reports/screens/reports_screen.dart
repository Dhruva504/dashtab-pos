import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/reports_provider.dart';

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportsAsync = ref.watch(reportsProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/settings'),
        ),
        title: const Text('Reports & Analytics'),
        backgroundColor: Colors.blueGrey,
        foregroundColor: Colors.white,
      ),
      body: reportsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (reports) {
          if (reports.isEmpty) return const Center(child: Text('No data available.'));
          
          final today = reports.last;
          
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Today\'s Overview', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _buildStatCard('Revenue', '€${today.totalRevenue.toStringAsFixed(2)}', Icons.attach_money, Colors.green),
                    const SizedBox(width: 16),
                    _buildStatCard('Orders', '${today.orderCount}', Icons.receipt_long, Colors.blue),
                    const SizedBox(width: 16),
                    _buildStatCard('Avg Ticket', '€${today.averageTicketSize.toStringAsFixed(2)}', Icons.analytics, Colors.orange),
                  ],
                ),
                const SizedBox(height: 32),
                const Text('Recent History', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.builder(
                    itemCount: reports.length,
                    itemBuilder: (context, index) {
                      final r = reports[reports.length - 1 - index]; // reverse chronological
                      return Card(
                        child: ListTile(
                          leading: const Icon(Icons.calendar_today),
                          title: Text('${r.date.day}/${r.date.month}/${r.date.year}'),
                          trailing: Text('€${r.totalRevenue.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          subtitle: Text('${r.orderCount} orders'),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Card(
        elevation: 4,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              Icon(icon, size: 48, color: color),
              const SizedBox(height: 16),
              Text(title, style: const TextStyle(fontSize: 18, color: Colors.grey)),
              const SizedBox(height: 8),
              Text(value, style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: color)),
            ],
          ),
        ),
      ),
    );
  }
}
