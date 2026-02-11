// models/settings_route.dart
import 'dart:ui';

class SettingsRoute {
  final String title;
  final String subtitle;
  final String icon;
  final List<Color> gradient;
  final String routeName;

  const SettingsRoute({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradient,
    required this.routeName,
  });
}
