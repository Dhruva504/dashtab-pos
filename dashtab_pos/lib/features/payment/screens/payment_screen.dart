import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/payment_provider.dart';
import '../../pos/providers/cart_provider.dart';

class PaymentScreen extends ConsumerStatefulWidget {
  const PaymentScreen({super.key});

  @override
  ConsumerState<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends ConsumerState<PaymentScreen> {
  String? _selectedMethodId;
  double _tenderedAmount = 0.0;
  final TextEditingController _amountController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Default tendered amount to total
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final cart = ref.read(cartProvider.notifier);
      setState(() {
        _tenderedAmount = cart.total;
        _amountController.text = _tenderedAmount.toStringAsFixed(2);
      });
    });
  }

  void _onNumpadPress(String value) {
    setState(() {
      if (value == 'C') {
        _amountController.text = '';
      } else if (value == '.' && _amountController.text.contains('.')) {
        return; // Only one decimal allowed
      } else {
        _amountController.text += value;
      }
      _tenderedAmount = double.tryParse(_amountController.text) ?? 0.0;
    });
  }

  void _quickAmount(double amount) {
    setState(() {
      _tenderedAmount = amount;
      _amountController.text = _tenderedAmount.toStringAsFixed(2);
    });
  }

  @override
  Widget build(BuildContext context) {
    final methodsAsync = ref.watch(paymentProvider);
    final cart = ref.watch(cartProvider.notifier);
    
    final double change = _tenderedAmount - cart.total;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/pos'),
        ),
        title: const Text('Payment'),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
      ),
      body: Row(
        children: [
          // Left: Payment Methods
          Expanded(
            flex: 1,
            child: Container(
              color: Colors.grey.shade100,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Select Method', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Expanded(
                    child: methodsAsync.when(
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (err, _) => Center(child: Text('Error: $err')),
                      data: (methods) {
                        if (methods.isEmpty) return const Text('No payment methods configured.');
                        return ListView.separated(
                          itemCount: methods.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final method = methods[index];
                            final isSelected = _selectedMethodId == method.id;
                            
                            IconData icon = Icons.money;
                            if (method.type == 1) icon = Icons.credit_card;
                            if (method.type == 2) icon = Icons.phone_android;

                            return InkWell(
                              onTap: () => setState(() => _selectedMethodId = method.id),
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: isSelected ? Colors.green.shade100 : Colors.white,
                                  border: Border.all(color: isSelected ? Colors.green : Colors.grey.shade300, width: 2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    Icon(icon, size: 32, color: isSelected ? Colors.green : Colors.grey),
                                    const SizedBox(width: 16),
                                    Text(method.name, style: TextStyle(fontSize: 18, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Center: Numpad & Input
          Expanded(
            flex: 1,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  TextField(
                    controller: _amountController,
                    readOnly: true,
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                    decoration: const InputDecoration(
                      prefixText: '€',
                      labelText: 'Tendered Amount',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Quick Amounts
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildQuickBtn(cart.total, 'Exact'),
                      _buildQuickBtn(10.0, '€10'),
                      _buildQuickBtn(20.0, '€20'),
                      _buildQuickBtn(50.0, '€50'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Numpad
                  Expanded(
                    child: GridView.count(
                      crossAxisCount: 3,
                      childAspectRatio: 1.5,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      children: [
                        '7', '8', '9',
                        '4', '5', '6',
                        '1', '2', '3',
                        '.', '0', 'C',
                      ].map((key) => ElevatedButton(
                            onPressed: () => _onNumpadPress(key),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey.shade200,
                              foregroundColor: Colors.black,
                              textStyle: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)
                            ),
                            child: Text(key),
                          )).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Right: Summary & Checkout
          Expanded(
            flex: 1,
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Text('Summary', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 24),
                  _buildSummaryRow('Total Due:', cart.total, isBold: true, fontSize: 24),
                  const Divider(height: 32),
                  _buildSummaryRow('Tendered:', _tenderedAmount, color: Colors.blue),
                  _buildSummaryRow('Change:', change > 0 ? change : 0.0, color: change > 0 ? Colors.green : Colors.black, isBold: change > 0),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    height: 64,
                    child: ElevatedButton(
                      onPressed: (_selectedMethodId != null && _tenderedAmount >= cart.total)
                          ? () async {
                              // Process Payment
                              final cmd = ProcessPaymentCommand(
                                orderId: 'mock-order-id',
                                paymentMethodId: _selectedMethodId!,
                                amount: _tenderedAmount,
                                tipAmount: 0,
                              );
                              final success = await ref.read(paymentProvider.notifier).processPayment(cmd);
                              
                              if (success && mounted) {
                                ref.read(cartProvider.notifier).clear(); // empty cart
                                if (!context.mounted) return;
                                showDialog(
                                  context: context,
                                  barrierDismissible: false,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('Payment Successful', style: TextStyle(color: Colors.green)),
                                    content: Text('Change due: €${(change > 0 ? change : 0).toStringAsFixed(2)}'),
                                    actions: [
                                      ElevatedButton(
                                        onPressed: () {
                                          Navigator.pop(ctx); // close dialog
                                          ctx.go('/floor'); // return to floor plan
                                        },
                                        child: const Text('DONE'),
                                      )
                                    ],
                                  ),
                                );
                              }
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey.shade300,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
                      ),
                      child: const Text('CONFIRM PAYMENT', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickBtn(double amount, String label) {
    return ElevatedButton(
      onPressed: () => _quickAmount(amount),
      child: Text(label),
    );
  }

  Widget _buildSummaryRow(String label, double amount, {bool isBold = false, Color color = Colors.black, double fontSize = 18}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: fontSize, fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: color)),
          Text('€${amount.toStringAsFixed(2)}', style: TextStyle(fontSize: fontSize, fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: color)),
        ],
      ),
    );
  }
}
