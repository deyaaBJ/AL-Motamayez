import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:flutter/material.dart';
import 'package:motamayez/models/cart_item.dart';
import 'package:path_provider/path_provider.dart'
    show getApplicationDocumentsDirectory;

class ThermalReceiptloger {
  // -------- تحويل النص العربي لـ CP1256 --------
  static Uint8List _encodeArabic(String text) {
    // CP1256 Arabic Windows encoding map
    const cp1256 = {
      'ء': 0xC1,
      'آ': 0xC2,
      'أ': 0xC3,
      'ؤ': 0xC4,
      'إ': 0xC5,
      'ئ': 0xC6,
      'ا': 0xC7,
      'ب': 0xC8,
      'ة': 0xC9,
      'ت': 0xCA,
      'ث': 0xCB,
      'ج': 0xCC,
      'ح': 0xCD,
      'خ': 0xCE,
      'د': 0xCF,
      'ذ': 0xD0,
      'ر': 0xD1,
      'ز': 0xD2,
      'س': 0xD3,
      'ش': 0xD4,
      'ص': 0xD5,
      'ض': 0xD6,
      'ط': 0xD7,
      'ظ': 0xD8,
      'ع': 0xD9,
      'غ': 0xDA,
      'ف': 0xE1,
      'ق': 0xE2,
      'ك': 0xE3,
      'ل': 0xE4,
      'م': 0xE5,
      'ن': 0xE6,
      'ه': 0xE7,
      'و': 0xE8,
      'ى': 0xE9,
      'ي': 0xEA,
      'ً': 0xEB,
      'ٌ': 0xEC,
      'ٍ': 0xED,
      'َ': 0xEE,
      'ُ': 0xEF,
      'ِ': 0xF0,
      'ّ': 0xF1,
      'ْ': 0xF2,
      ' ': 0x20,
      ':': 0x3A,
      '#': 0x23,
      '/': 0x2F,
      '.': 0x2E,
      '0': 0x30,
      '1': 0x31,
      '2': 0x32,
      '3': 0x33,
      '4': 0x34,
      '5': 0x35,
      '6': 0x36,
      '7': 0x37,
      '8': 0x38,
      '9': 0x39,
      '-': 0x2D,
      '+': 0x2B,
      '*': 0x2A,
      '(': 0x28,
      ')': 0x29,
    };

    final bytes = <int>[];
    for (final char in text.characters) {
      if (cp1256.containsKey(char)) {
        bytes.add(cp1256[char]!);
      } else {
        bytes.add(0x3F); // '?' للحروف غير المعروفة
      }
    }
    return Uint8List.fromList(bytes);
  }

  // -------- بناء سطر عربي بعرض محدد --------
  static List<int> _arabicLine(
    String text, {
    int width = 32,
    bool center = false,
    bool rightAlign = false,
    bool bold = false,
    bool doubleSize = false,
  }) {
    final List<int> result = [];

    // Bold on/off
    if (bold) result.addAll([0x1B, 0x45, 0x01]);
    // Double size
    if (doubleSize) result.addAll([0x1D, 0x21, 0x11]);

    // Alignment
    if (center) {
      result.addAll([0x1B, 0x61, 0x01]);
    } else if (rightAlign) {
      result.addAll([0x1B, 0x61, 0x02]);
    } else {
      result.addAll([0x1B, 0x61, 0x00]);
    }

    result.addAll(_encodeArabic(text));
    result.add(0x0A); // newline

    // Reset
    if (bold) result.addAll([0x1B, 0x45, 0x00]);
    if (doubleSize) result.addAll([0x1D, 0x21, 0x00]);

    return result;
  }

  // -------- سطر بعمودين (يسار + يمين) --------
  static List<int> _arabicRow(
    String leftText,
    String rightText, {
    int totalWidth = 32,
    bool bold = false,
  }) {
    final List<int> result = [];
    if (bold) result.addAll([0x1B, 0x45, 0x01]);
    result.addAll([0x1B, 0x61, 0x00]); // left align

    final leftBytes = _encodeArabic(leftText);
    final rightBytes = _encodeArabic(rightText);

    final spacesCount = (totalWidth - leftBytes.length - rightBytes.length)
        .clamp(0, totalWidth);
    final spaces = List.filled(spacesCount, 0x20);

    result.addAll(rightBytes); // العربي يبدأ من اليمين
    result.addAll(spaces);
    result.addAll(leftBytes);
    result.add(0x0A);

    if (bold) result.addAll([0x1B, 0x45, 0x00]);
    return result;
  }

  // -------- خط فاصل --------
  static List<int> _hr({int width = 32, String char = '-'}) {
    return [...List.filled(width, char.codeUnitAt(0)), 0x0A];
  }

  static Future<void> logReceipt({
    required List<CartItem> cartItems,
    required String marketName,
    String? adminPhone,
    required double totalAmount,
    required double finalAmount,
    double paidAmount = 0.0,
    double dueAmount = 0.0,
    double changeAmount = 0.0,
    String cashierName = 'غير معروف',
    String note = '',
    required bool isTotalModified,
    required DateTime dateTime,
    int? receiptNumber,
    required String currency,
    String paperSize = '58mm',
    required String logerIp,
    int logerPort = 9100,
  }) async {
    final int lineWidth = paperSize == '80mm' ? 42 : 32;
    final int maxNameLength = paperSize == '80mm' ? 18 : 10;

    final List<int> bytes = [];

    // -------- تفعيل CP1256 العربي --------
    bytes.addAll([0x1B, 0x40]); // reset
    bytes.addAll([0x1B, 0x74, 0x27]); // CP1256

    // -------- HEADER --------
    bytes.addAll(
      _arabicLine('المتميز', center: true, bold: true, doubleSize: true),
    );
    bytes.addAll(_arabicLine('نظام ادارة المبيعات', center: true));
    bytes.addAll(_hr(width: lineWidth));

    // -------- MARKET INFO --------
    bytes.addAll(_arabicLine(marketName, center: true, bold: true));
    if (adminPhone != null && adminPhone.isNotEmpty) {
      bytes.addAll(_arabicLine(adminPhone, center: true));
    }
    bytes.addAll(_hr(width: lineWidth));

    // -------- DATE / TIME / RECEIPT / CASHIER --------
    final dateStr =
        '${dateTime.year}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.day.toString().padLeft(2, '0')}';
    final timeStr =
        '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';

    bytes.addAll(_arabicRow('التاريخ:', dateStr, totalWidth: lineWidth));
    bytes.addAll(_arabicRow('الوقت:', timeStr, totalWidth: lineWidth));

    if (receiptNumber != null) {
      bytes.addAll(
        _arabicRow(
          'رقم الفاتورة:',
          '#${receiptNumber.toString().padLeft(5, '0')}',
          totalWidth: lineWidth,
          bold: true,
        ),
      );
    }

    bytes.addAll(_arabicRow('الكاشير:', cashierName, totalWidth: lineWidth));
    bytes.addAll(_hr(width: lineWidth));

    // -------- TABLE HEADER --------
    bytes.addAll(_arabicLine('الصنف        كمية  وحدة   سعر', bold: true));
    bytes.addAll(_hr(width: lineWidth, char: '-'));

    // -------- ITEMS --------
    for (final item in cartItems) {
      String unit = item.isService ? 'خدمة' : _translateUnit(item.unitName);
      String productName =
          item.isService ? (item.serviceName ?? 'خدمة') : item.product!.name;

      if (productName.length > maxNameLength) {
        productName = productName.substring(0, maxNameLength);
      }

      // بناء سطر الصنف يدوياً
      final qtyStr = item.quantity
          .toStringAsFixed(item.quantity == item.quantity.truncate() ? 0 : 2)
          .padRight(6);
      final unitStr = unit.padRight(6);
      final priceStr = item.totalPrice.toStringAsFixed(2);
      final nameStr = productName.padRight(maxNameLength);

      bytes.addAll(_arabicLine('$nameStr $qtyStr $unitStr $priceStr'));

      if (item.customPrice != null) {
        bytes.addAll(_arabicLine('  * سعر معدل', bold: true));
      }
    }

    bytes.addAll(_hr(width: lineWidth));

    // -------- TOTALS --------
    if (isTotalModified) {
      bytes.addAll(
        _arabicRow(
          'المجموع:',
          '$currency ${totalAmount.toStringAsFixed(2)}',
          totalWidth: lineWidth,
        ),
      );
      bytes.addAll(
        _arabicRow(
          'التعديل:',
          '$currency ${(finalAmount - totalAmount).toStringAsFixed(2)}',
          totalWidth: lineWidth,
        ),
      );
    }

    bytes.addAll(
      _arabicRow(
        'المجموع النهائي:',
        '$currency ${finalAmount.toStringAsFixed(2)}',
        totalWidth: lineWidth,
        bold: true,
      ),
    );

    bytes.addAll(_hr(width: lineWidth));

    // -------- PAYMENT --------
    bytes.addAll(
      _arabicRow(
        'المبلغ المدفوع:',
        '$currency ${paidAmount.toStringAsFixed(2)}',
        totalWidth: lineWidth,
        bold: true,
      ),
    );

    if (changeAmount > 0) {
      bytes.addAll(
        _arabicRow(
          'الباقي للزبون:',
          '$currency ${changeAmount.toStringAsFixed(2)}',
          totalWidth: lineWidth,
          bold: true,
        ),
      );
    }

    if (dueAmount > 0) {
      bytes.addAll(
        _arabicRow(
          'المبلغ المستحق:',
          '$currency ${dueAmount.toStringAsFixed(2)}',
          totalWidth: lineWidth,
          bold: true,
        ),
      );
    }

    // -------- NOTE --------
    if (note.isNotEmpty) {
      bytes.addAll(_hr(width: lineWidth));
      bytes.addAll(_arabicLine('ملاحظة: $note', rightAlign: true));
    }

    bytes.addAll(_hr(width: lineWidth));

    // -------- FOOTER --------
    bytes.addAll(_arabicLine('شكرا لتسوقكم معنا', center: true, bold: true));
    bytes.addAll(_arabicLine('نتمنى لكم يوما سعيدا', center: true));

    // Feed & Cut
    bytes.addAll([0x0A, 0x0A, 0x0A]);
    bytes.addAll([0x1D, 0x56, 0x41, 0x03]); // cut

    await _sendToNetworkloger(
      logerIp,
      Uint8List.fromList(bytes),
      port: logerPort,
    );
  }

  // -------- وضع التجربة: حفظ ملف بدل الطابعة --------

  // ✅ وضع الطابعة الحقيقية — أزل الـ comment لما تجيب الطابعة
  // try {
  //   final socket = await Socket.connect(ip, port,
  //       timeout: const Duration(seconds: 5));
  //   socket.add(bytes);
  //   await socket.flush();
  //   await socket.close();
  // } catch (e) {
  //   throw Exception('فشل الاتصال بالطابعة: $e');
  // }

  static Future<void> _sendToNetworkloger(
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

  static String _translateUnit(String unit) {
    final u = unit.toLowerCase();
    if (u.contains('piece')) return 'قطعة';
    if (u.contains('kg')) return 'كيلو';
    if (u.contains('g') && !u.contains('kg')) return 'غرام';
    if (u.contains('box')) return 'صندوق';
    if (u.contains('dozen')) return 'درزن';
    return unit;
  }
}
