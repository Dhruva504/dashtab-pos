import 'package:flutter/material.dart';
import '../../../domain/entities/table.dart';

class TableWidget extends StatelessWidget {
  final RestaurantTable table;
  final VoidCallback onTap;

  const TableWidget({
    Key? key,
    required this.table,
    required this.onTap,
  }) : super(key: key);

  Color _getStatusColor() {
    switch (table.status) {
      case TableStatus.available:
        return Colors.green.shade400;
      case TableStatus.occupied:
        return Colors.red.shade400;
      case TableStatus.reserved:
        return Colors.orange.shade400;
      case TableStatus.billed:
        return Colors.blue.shade400;
      case TableStatus.dirty:
        return Colors.brown.shade400;
      case TableStatus.outOfService:
        return Colors.grey.shade400;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: table.x,
      top: table.y,
      width: table.width,
      height: table.height,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: _getStatusColor(),
            shape: table.shape == TableShape.circle ? BoxShape.circle : BoxShape.rectangle,
            borderRadius: table.shape == TableShape.rectangle ? BorderRadius.circular(8) : null,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 4,
                offset: const Offset(2, 2),
              ),
            ],
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  table.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  '${table.capacity} pax',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
