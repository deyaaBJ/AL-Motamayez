import 'package:flutter/material.dart';

AppBar buildCustomAppBar(BuildContext context) {
  return AppBar(
    backgroundColor: Colors.white,
    elevation: 3,
    leading: IconButton(
      icon: const Icon(Icons.arrow_back, color: Color(0xFF6A3093)),
      onPressed: () => Navigator.pop(context),
    ),
    title: const Text(
      'نقطة البيع',
      style: TextStyle(
        color: Color(0xFF6A3093),
        fontSize: 24,
        fontWeight: FontWeight.bold,
      ),
    ),
  );
}
