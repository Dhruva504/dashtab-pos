import 'table.dart';

class Floor {
  final String id;
  final String name;
  final String backgroundColor;
  final String? backgroundImageUrl;
  final List<RestaurantTable> tables;

  Floor({
    required this.id,
    required this.name,
    required this.backgroundColor,
    this.backgroundImageUrl,
    required this.tables,
  });

  factory Floor.fromJson(Map<String, dynamic> json) {
    var tablesList = json['tables'] as List? ?? [];
    return Floor(
      id: json['id'],
      name: json['name'],
      backgroundColor: json['backgroundColor'] ?? '#FFFFFF',
      backgroundImageUrl: json['backgroundImageUrl'],
      tables: tablesList.map((t) => RestaurantTable.fromJson(t)).toList(),
    );
  }
}
