import 'package:flutter/material.dart';

class ProductTableHeader extends StatelessWidget {
  final List<HeaderColumn> columns;

  const ProductTableHeader({Key? key, required this.columns}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF6A3093),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children:
            columns
                .map(
                  (col) => Expanded(
                    flex: col.flex,
                    child: Text(
                      col.label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                )
                .toList(),
      ),
    );
  }
}

class HeaderColumn {
  final String label;
  final int flex;

  const HeaderColumn({required this.label, required this.flex});
}
