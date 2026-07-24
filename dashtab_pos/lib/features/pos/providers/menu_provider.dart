import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/entities/product.dart';

final menuProvider = Provider<List<Product>>((ref) {
  return [
    Product(id: '1', categoryId: 'c1', name: 'Cheeseburger', price: 12.50),
    Product(id: '2', categoryId: 'c1', name: 'Vegan Burger', price: 14.00),
    Product(id: '3', categoryId: 'c2', name: 'French Fries', price: 4.50),
    Product(id: '4', categoryId: 'c2', name: 'Onion Rings', price: 5.50),
    Product(id: '5', categoryId: 'c3', name: 'Cola', price: 3.00),
    Product(id: '6', categoryId: 'c3', name: 'Craft Beer', price: 6.50),
    Product(id: '7', categoryId: 'c4', name: 'Cheesecake', price: 7.00),
    Product(id: '8', categoryId: 'c4', name: 'Brownie', price: 6.00),
  ];
});
