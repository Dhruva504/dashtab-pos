enum TableStatus {
  available,
  occupied,
  reserved,
  billed,
  dirty,
  outOfService
}

enum TableShape {
  rectangle,
  circle
}

class RestaurantTable {
  final String id;
  final String name;
  final int capacity;
  final TableStatus status;
  final double x;
  final double y;
  final double width;
  final double height;
  final TableShape shape;

  RestaurantTable({
    required this.id,
    required this.name,
    required this.capacity,
    required this.status,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.shape,
  });

  factory RestaurantTable.fromJson(Map<String, dynamic> json) {
    return RestaurantTable(
      id: json['id'],
      name: json['name'],
      capacity: json['capacity'],
      status: TableStatus.values[json['status'] ?? 0],
      x: json['x'].toDouble(),
      y: json['y'].toDouble(),
      width: json['width'].toDouble(),
      height: json['height'].toDouble(),
      shape: TableShape.values[json['shape'] ?? 0],
    );
  }
}
