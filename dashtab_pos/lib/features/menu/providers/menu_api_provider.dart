import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/entities/product.dart';
import '../../../core/network/api_provider.dart';

class MenuCategory {
  final String id;
  final String name;
  final String? color;
  final String? icon;
  final List<Product> products;

  MenuCategory({
    required this.id,
    required this.name,
    this.color,
    this.icon,
    required this.products,
  });

  factory MenuCategory.fromJson(Map<String, dynamic> json) {
    var productsList = json['products'] as List? ?? [];
    return MenuCategory(
      id: json['id'],
      name: json['name'],
      color: json['color'],
      icon: json['icon'],
      products: productsList.map((p) => Product.fromJson(p)).toList(),
    );
  }
}

class MenuNotifier extends AsyncNotifier<List<MenuCategory>> {
  @override
  Future<List<MenuCategory>> build() async {
    try {
      final response =
          await ref.read(apiClientProvider).dio.get('/menu/categories');
      return (response.data as List)
          .map((c) => MenuCategory.fromJson(c))
          .toList();
    } catch (e) {
      // Return empty list on error — POS screen shows 'No menu categories found'
      return [];
    }
  }
}

final menuCategoryProvider = AsyncNotifierProvider<MenuNotifier, List<MenuCategory>>(MenuNotifier.new);
