import 'package:flutter/material.dart';

class UnitController {
  final TextEditingController unitNameController = TextEditingController();
  final TextEditingController barcodeController = TextEditingController();
  final TextEditingController containQtyController = TextEditingController();
  final TextEditingController sellPriceController = TextEditingController();
  final TextEditingController offerPriceController = TextEditingController();
  DateTime? offerStartDate;
  DateTime? offerEndDate;
  bool offerEnabled = false;

  void clearOffer() {
    offerEnabled = false;
    offerPriceController.clear();
    offerStartDate = null;
    offerEndDate = null;
  }

  void dispose() {
    unitNameController.dispose();
    barcodeController.dispose();
    containQtyController.dispose();
    sellPriceController.dispose();
    offerPriceController.dispose();
  }
}
