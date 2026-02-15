// widgets/settings/settings_password_field.dart
import 'package:flutter/material.dart';

class SettingsPasswordField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final bool enabled;
  final bool readOnly;
  final Color? color;

  const SettingsPasswordField({
    super.key,
    required this.controller,
    required this.label,
    this.enabled = true,
    this.readOnly = false,
    this.color,
  });

  @override
  State<SettingsPasswordField> createState() => _SettingsPasswordFieldState();
}

class _SettingsPasswordFieldState extends State<SettingsPasswordField> {
  bool _obscureText = true;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = widget.color ?? const Color(0xFF6A3093);

    return TextField(
      controller: widget.controller,
      enabled: widget.enabled,
      readOnly: widget.readOnly,
      obscureText: _obscureText,
      decoration: InputDecoration(
        labelText: widget.label,
        prefixIcon: Icon(Icons.lock_outline, color: effectiveColor),
        suffixIcon: IconButton(
          icon: Icon(
            _obscureText ? Icons.visibility_off : Icons.visibility,
            color: effectiveColor,
          ),
          onPressed: () => setState(() => _obscureText = !_obscureText),
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        filled: true,
        fillColor: widget.enabled ? Colors.white : Colors.grey[50],
      ),
    );
  }
}
