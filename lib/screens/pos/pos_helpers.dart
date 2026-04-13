import 'package:motamayez/models/product_unit.dart';

List<ProductUnit> removeDuplicateUnits(List<ProductUnit> units) {
  final seen = <int>{};
  return units.where((unit) {
    if (unit.id == null) return false;
    if (seen.contains(unit.id)) return false;
    seen.add(unit.id!);
    return true;
  }).toList();
}
