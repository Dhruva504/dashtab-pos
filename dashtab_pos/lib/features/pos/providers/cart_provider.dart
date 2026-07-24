import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/entities/product.dart';

class CartItem {
  final Product product;
  final int quantity;

  CartItem({required this.product, this.quantity = 1});
  
  double get total => product.price * quantity;
}

class CartNotifier extends Notifier<List<CartItem>> {
  @override
  List<CartItem> build() {
    return [];
  }

  void addItem(Product product) {
    final existingIndex = state.indexWhere((item) => item.product.id == product.id);
    if (existingIndex >= 0) {
      final updatedState = [...state];
      final existingItem = updatedState[existingIndex];
      updatedState[existingIndex] = CartItem(
        product: existingItem.product,
        quantity: existingItem.quantity + 1,
      );
      state = updatedState;
    } else {
      state = [...state, CartItem(product: product)];
    }
  }

  void removeItem(Product product) {
    state = state.where((item) => item.product.id != product.id).toList();
  }

  void clear() {
    state = [];
  }

  double get subtotal {
    return state.fold(0, (sum, item) => sum + item.total);
  }
  
  double get tax => subtotal * 0.10; // 10% tax for demo
  
  double get total => subtotal + tax;
}

final cartProvider = NotifierProvider<CartNotifier, List<CartItem>>(CartNotifier.new);
