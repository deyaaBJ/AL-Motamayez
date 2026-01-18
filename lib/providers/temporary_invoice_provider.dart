import 'package:flutter/material.dart';

class TemporaryInvoiceProvider extends ChangeNotifier {
  int? invoiceId;
  int? selectedSupplierId;
  String selectedPaymentType = 'cash';
  double invoiceTotal = 0.0;
  List<Map<String, dynamic>> invoiceItems = [];

  void addItem(Map<String, dynamic> item) {
    invoiceItems.add(item);
    invoiceTotal +=
        (item['quantity'] as double) * (item['cost_price'] as double);
    notifyListeners();
  }

  void removeItem(int index) {
    if (index < 0 || index >= invoiceItems.length) return;
    final removedItem = invoiceItems.removeAt(index);
    invoiceTotal -=
        (removedItem['quantity'] as double) *
        (removedItem['cost_price'] as double);
    notifyListeners();
  }

  void clearInvoice() {
    invoiceId = null;
    selectedSupplierId = null;
    selectedPaymentType = 'cash';
    invoiceTotal = 0.0;
    invoiceItems.clear();
    notifyListeners();
  }
}
