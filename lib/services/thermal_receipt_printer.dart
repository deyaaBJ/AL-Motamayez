import 'dart:io';
import 'dart:typed_data';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:motamayez/models/cart_item.dart';

class ThermalReceiptPrinter {
  static Future<void> printReceipt({
    required List<CartItem> cartItems,
    required String marketName,
    String? adminPhone,
    required double totalAmount,
    required double finalAmount,
    required bool isTotalModified,
    required DateTime dateTime,
    int? receiptNumber,
    required String currency,
    String paperSize = '58mm',
    required String printerIp,
    int printerPort = 9100,
  }) async {
    // ---------------- PRINTER PROFILE ----------------
    final profile = await CapabilityProfile.load();
    final paper = paperSize == '80mm' ? PaperSize.mm80 : PaperSize.mm58;
    final generator = Generator(paper, profile);

    // ---------------- CONFIG ----------------
    final int nameWidth = paperSize == '80mm' ? 6 : 4; // اسم المنتج
    final int qtyWidth = paperSize == '80mm' ? 3 : 2; // الكمية
    final int unitWidth = paperSize == '80mm' ? 3 : 3; // الوحدة
    final int priceWidth = paperSize == '80mm' ? 4 : 3; // السعر
    final int maxNameLength = paperSize == '80mm' ? 30 : 16;

    final List<int> bytes = [];

    // 🔹 دعم اللغة العربية
    bytes.addAll(generator.setGlobalCodeTable('CP864'));

    // ---------------- HEADER ----------------
    bytes.addAll(
      generator.text(
        'المتميز',
        styles: const PosStyles(
          align: PosAlign.center,
          bold: true,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
        ),
      ),
    );

    bytes.addAll(
      generator.text(
        'نظام إدارة المبيعات',
        styles: const PosStyles(align: PosAlign.center),
      ),
    );

    bytes.addAll(generator.hr());

    // ---------------- MARKET INFO ----------------
    bytes.addAll(
      generator.text(
        marketName,
        styles: const PosStyles(align: PosAlign.center, bold: true),
      ),
    );

    if (adminPhone != null && adminPhone.isNotEmpty) {
      bytes.addAll(
        generator.text(
          adminPhone,
          styles: const PosStyles(align: PosAlign.center),
        ),
      );
    }

    bytes.addAll(generator.hr());

    // ---------------- DATE / TIME ----------------
    bytes.addAll(
      generator.row([
        PosColumn(text: 'التاريخ:', width: 6),
        PosColumn(
          text:
              '${dateTime.year}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.day.toString().padLeft(2, '0')}',
          width: 6,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]),
    );

    bytes.addAll(
      generator.row([
        PosColumn(text: 'الوقت:', width: 6),
        PosColumn(
          text:
              '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}',
          width: 6,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]),
    );

    if (receiptNumber != null) {
      bytes.addAll(
        generator.row([
          PosColumn(text: 'رقم الفاتورة:', width: 6),
          PosColumn(
            text: '#${receiptNumber.toString().padLeft(5, '0')}',
            width: 6,
            styles: const PosStyles(align: PosAlign.right, bold: true),
          ),
        ]),
      );
    }

    bytes.addAll(generator.hr());

    // ---------------- ITEMS ----------------
    for (final item in cartItems) {
      String unit = _translateUnit(item.unitName);
      String productName = item.product.name;

      // قص الاسم حسب الورق
      if (productName.length > maxNameLength) {
        productName = productName.substring(0, maxNameLength);
      }

      bytes.addAll(
        generator.row([
          PosColumn(text: productName, width: nameWidth),
          PosColumn(
            text: item.quantity.toStringAsFixed(2),
            width: qtyWidth,
            styles: const PosStyles(align: PosAlign.center),
          ),
          PosColumn(
            text: unit,
            width: unitWidth,
            styles: const PosStyles(align: PosAlign.center),
          ),
          PosColumn(
            text: item.totalPrice.toStringAsFixed(2),
            width: priceWidth,
            styles: const PosStyles(align: PosAlign.right),
          ),
        ]),
      );

      if (item.customPrice != null) {
        bytes.addAll(
          generator.text('سعر معدل', styles: const PosStyles(bold: true)),
        );
      }
    }

    bytes.addAll(generator.hr());

    // ---------------- TOTALS ----------------
    if (isTotalModified) {
      bytes.addAll(
        generator.row([
          PosColumn(text: 'المجموع:', width: 6),
          PosColumn(
            text: '$currency ${totalAmount.toStringAsFixed(2)}',
            width: 6,
            styles: const PosStyles(align: PosAlign.right),
          ),
        ]),
      );

      bytes.addAll(
        generator.row([
          PosColumn(text: 'التعديل:', width: 6),
          PosColumn(
            text: '$currency ${(finalAmount - totalAmount).toStringAsFixed(2)}',
            width: 6,
            styles: const PosStyles(align: PosAlign.right),
          ),
        ]),
      );
    }

    bytes.addAll(
      generator.row([
        PosColumn(
          text: 'المجموع النهائي:',
          width: 6,
          styles: const PosStyles(bold: true),
        ),
        PosColumn(
          text: '$currency ${finalAmount.toStringAsFixed(2)}',
          width: 6,
          styles: const PosStyles(align: PosAlign.right, bold: true),
        ),
      ]),
    );

    bytes.addAll(generator.hr());

    // ---------------- FOOTER ----------------
    bytes.addAll(
      generator.text(
        'شكراً لتسوقكم معنا',
        styles: const PosStyles(align: PosAlign.center, bold: true),
      ),
    );

    bytes.addAll(
      generator.text(
        'نتمنى لكم يوماً سعيداً',
        styles: const PosStyles(align: PosAlign.center),
      ),
    );

    bytes.addAll(generator.feed(2));
    bytes.addAll(generator.cut());

    // ---------------- SEND TO PRINTER ----------------
    await _sendToNetworkPrinter(
      printerIp,
      Uint8List.fromList(bytes),
      port: printerPort,
    );
  }

  // ---------------- NETWORK PRINT ----------------
  static Future<void> _sendToNetworkPrinter(
    String ip,
    Uint8List bytes, {
    int port = 9100,
  }) async {
    try {
      final socket = await Socket.connect(
        ip,
        port,
        timeout: const Duration(seconds: 5),
      );
      socket.add(bytes);
      await socket.flush();
      await socket.close();
    } catch (e) {
      throw Exception('فشل الاتصال بالطابعة: $e');
    }
  }

  // ---------------- UNIT TRANSLATION ----------------
  static String _translateUnit(String unit) {
    final u = unit.toLowerCase();
    if (u.contains('piece')) return 'قطعة';
    if (u.contains('kg')) return 'كيلو';
    return unit;
  }
}
