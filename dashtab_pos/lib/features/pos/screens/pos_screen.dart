import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../menu/providers/menu_api_provider.dart';
import '../providers/cart_provider.dart';
import '../../auth/providers/auth_provider.dart';

class SelectedCategoryIndexNotifier extends Notifier<int> {
  @override
  int build() => 0;
  void setIndex(int index) => state = index;
}
final selectedCategoryIndexProvider = NotifierProvider<SelectedCategoryIndexNotifier, int>(SelectedCategoryIndexNotifier.new);
class PosScreen extends ConsumerWidget {
  const PosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final menuAsync = ref.watch(menuCategoryProvider);
    final cart = ref.watch(cartProvider);
    final cartNotifier = ref.read(cartProvider.notifier);
    final auth = ref.watch(authProvider);
    final selectedIndex = ref.watch(selectedCategoryIndexProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/floor'),
        ),
        title: Text('DashTab POS (${auth.tenantSlug ?? ""})'),
        actions: [
          IconButton(icon: const Icon(Icons.restaurant_menu), onPressed: () => context.go('/kitchen')),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              ref.read(authProvider.notifier).logout();
              context.go('/login');
            },
          ),
        ],
      ),
      body: menuAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (categories) {
          if (categories.isEmpty) {
            return const Center(child: Text('No menu categories found.'));
          }
          final currentCategory = categories[selectedIndex.clamp(0, categories.length - 1)];

          return Row(
            children: [
              // Left: Menu
              Expanded(
                flex: 2,
                child: Column(
                  children: [
                    // Category Tabs
                    SizedBox(
                      height: 56,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        itemCount: categories.length,
                        itemBuilder: (context, index) {
                          final cat = categories[index];
                          final isSelected = index == selectedIndex;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text('${cat.icon ?? ''} ${cat.name}'),
                              selected: isSelected,
                              onSelected: (_) => ref.read(selectedCategoryIndexProvider.notifier).setIndex(index),
                              selectedColor: Colors.green.shade100,
                            ),
                          );
                        },
                      ),
                    ),
                    // Product Grid
                    Expanded(
                      child: GridView.builder(
                        padding: const EdgeInsets.all(8),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          childAspectRatio: 1.0,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                        itemCount: currentCategory.products.length,
                        itemBuilder: (context, index) {
                          final product = currentCategory.products[index];
                          return Card(
                            elevation: 2,
                            child: InkWell(
                              onTap: () => cartNotifier.addItem(product),
                              borderRadius: BorderRadius.circular(12),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.fastfood, size: 36, color: Colors.orange),
                                  const SizedBox(height: 8),
                                  Text(
                                    product.name,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '€${product.price.toStringAsFixed(2)}',
                                    style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
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
              ),
              // Right: Cart
              Container(
                width: 350,
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  border: Border(left: BorderSide(color: Colors.grey.shade300)),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      color: Colors.green.withValues(alpha: 0.08),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Current Order', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          Text('#—', style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ),
                    Expanded(
                      child: cart.isEmpty
                          ? const Center(child: Text('Tap products to add', style: TextStyle(color: Colors.grey)))
                          : ListView.builder(
                              itemCount: cart.length,
                              itemBuilder: (context, index) {
                                final item = cart[index];
                                return ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: Colors.green,
                                    child: Text('${item.quantity}', style: const TextStyle(color: Colors.white)),
                                  ),
                                  title: Text(item.product.name),
                                  subtitle: Text('€${item.total.toStringAsFixed(2)}'),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                                    onPressed: () => cartNotifier.removeItem(item.product),
                                  ),
                                );
                              },
                            ),
                    ),
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          _buildTotalRow('Subtotal', '€${cartNotifier.subtotal.toStringAsFixed(2)}'),
                          _buildTotalRow('Tax (10%)', '€${cartNotifier.tax.toStringAsFixed(2)}'),
                          const SizedBox(height: 8),
                          _buildTotalRow(
                            'Total',
                            '€${cartNotifier.total.toStringAsFixed(2)}',
                            bold: true,
                            fontSize: 20,
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: cart.isNotEmpty ? () => context.go('/kitchen') : null,
                                  icon: const Icon(Icons.restaurant),
                                  label: const Text('KITCHEN'),
                                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.all(14)),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: cart.isNotEmpty ? () => context.go('/payment') : null,
                                  icon: const Icon(Icons.payment),
                                  label: const Text('PAY'),
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.all(14),
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTotalRow(String label, String value, {bool bold = false, double fontSize = 14}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal, fontSize: fontSize)),
        Text(value, style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal, fontSize: fontSize)),
      ],
    );
  }
}
