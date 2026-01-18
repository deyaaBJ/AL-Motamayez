import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CustomTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData prefixIcon;
  final bool obscureText;
  final Widget? suffixIcon;
  final bool readOnly;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;

  // ✅ الجديد (اختياري)
  final List<TextInputFormatter>? inputFormatters;

  const CustomTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.prefixIcon,
    this.obscureText = false,
    this.suffixIcon,
    this.readOnly = false,
    this.keyboardType,
    this.validator,
    this.onChanged,
    this.inputFormatters, // ✅
  });

  @override
  Widget build(BuildContext context) {
    if (validator != null) {
      return TextFormField(
        controller: controller,
        obscureText: obscureText,
        readOnly: readOnly,
        keyboardType: keyboardType,
        validator: validator,
        onChanged: onChanged,
        inputFormatters: inputFormatters, // ✅
        decoration: _decoration(),
      );
    } else {
      return TextField(
        controller: controller,
        obscureText: obscureText,
        readOnly: readOnly,
        keyboardType: keyboardType,
        onChanged: onChanged,
        inputFormatters: inputFormatters, // ✅
        decoration: _decoration(),
      );
    }
  }

  InputDecoration _decoration() {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(prefixIcon, color: const Color(0xFF8B5FBF)),
      suffixIcon: suffixIcon,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE1D4F7)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF8B5FBF), width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red, width: 2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red, width: 2),
      ),
      filled: true,
      fillColor: readOnly ? Colors.grey[200] : const Color(0xFFF8F5FF),
      errorStyle: const TextStyle(color: Colors.red, fontSize: 12),
    );
  }
}
