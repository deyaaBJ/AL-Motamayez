// utils/pdf_exporter.dart
import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import '../models/report_data.dart';

class PDFExportResult {
  final bool success;
  final String? filePath;
  final String? error;

  PDFExportResult({required this.success, this.filePath, this.error});
}

class PDFExporter {
  late pw.Font arabicFont;
  pw.Image? logoImage;

  Future<void> _loadResources() async {
    try {
      final fontData = await rootBundle.load('fonts/Cairo-Regular.ttf');
      arabicFont = pw.Font.ttf(fontData);
      try {
        final logoData = await rootBundle.load('assets/images/shop_logo.png');
        final logoBytes = logoData.buffer.asUint8List();
        logoImage = pw.Image(pw.MemoryImage(logoBytes));
      } catch (e) {
        logoImage = null;
      }
    } catch (e) {
      arabicFont = pw.Font.helvetica();
    }
  }

  Future<PDFExportResult> exportReport({
    required ReportData reportData,
    required String adminName,
    required String marketName,
  }) async {
    try {
      await _loadResources();

      final pdf = pw.Document();

      // جلب كل الإحصائيات مرة واحدة وتقسيمها فعلياً
      final allStats = _prepareStatisticsList(reportData.statistics);

      // الصفحة الأولى: معلومات + أول 8 إحصائيات
      const int firstPageLimit = 8;
      final firstPageStats = allStats.take(firstPageLimit).toList();
      final remainingStats = allStats.skip(firstPageLimit).toList();

      // الصفحة الأولى دائماً
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.all(12),
          build: (pw.Context context) {
            return pw.Directionality(
              textDirection: pw.TextDirection.rtl,
              child: pw.Container(
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.blue, width: 1.5),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                padding: pw.EdgeInsets.all(15),
                child:
                    remainingStats.isEmpty
                        ? _buildSinglePageContent(
                          reportData,
                          adminName,
                          marketName,
                          firstPageStats,
                        )
                        : _buildFirstPageContent(
                          reportData,
                          adminName,
                          marketName,
                          firstPageStats,
                        ),
              ),
            );
          },
        ),
      );

      // باقي الإحصائيات موزعة على صفحات (15 لكل صفحة)
      if (remainingStats.isNotEmpty) {
        const int statsPerPage = 15;
        for (int i = 0; i < remainingStats.length; i += statsPerPage) {
          final pageStats = remainingStats.skip(i).take(statsPerPage).toList();
          final isLastPage = (i + statsPerPage) >= remainingStats.length;

          pdf.addPage(
            pw.Page(
              pageFormat: PdfPageFormat.a4,
              margin: pw.EdgeInsets.all(12),
              build: (pw.Context context) {
                return pw.Directionality(
                  textDirection: pw.TextDirection.rtl,
                  child: pw.Container(
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.blue, width: 1.5),
                      borderRadius: pw.BorderRadius.circular(8),
                    ),
                    padding: pw.EdgeInsets.all(15),
                    child: _buildStatisticsPage(
                      marketName,
                      pageStats,
                      reportData.currency,
                      isLastPage,
                    ),
                  ),
                );
              },
            ),
          );
        }
      }

      final dir = await getApplicationDocumentsDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final fileName = 'تقرير_مالي_$timestamp.pdf';
      final filePath = '${dir.path}/$fileName';
      final file = File(filePath);
      await file.writeAsBytes(await pdf.save());

      return PDFExportResult(success: true, filePath: filePath);
    } catch (e) {
      return PDFExportResult(success: false, error: e.toString());
    }
  }

  // صفحة واحدة فقط (إذا الإحصائيات قليلة)
  pw.Widget _buildSinglePageContent(
    ReportData reportData,
    String adminName,
    String marketName,
    List<Map<String, dynamic>> stats,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _buildHeader(marketName),
        pw.SizedBox(height: 12),
        _buildProgramInfo(marketName),
        pw.SizedBox(height: 12),
        _buildAdminAndDateInfo(adminName),
        pw.SizedBox(height: 12),
        _buildPeriodInfo(reportData),
        pw.SizedBox(height: 12),
        _buildStatisticsTableFromList(stats, reportData.currency, true),
      ],
    );
  }

  // الصفحة الأولى عند وجود صفحات إضافية
  pw.Widget _buildFirstPageContent(
    ReportData reportData,
    String adminName,
    String marketName,
    List<Map<String, dynamic>> stats,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _buildHeader(marketName),
        pw.SizedBox(height: 12),
        _buildProgramInfo(marketName),
        pw.SizedBox(height: 12),
        _buildAdminAndDateInfo(adminName),
        pw.SizedBox(height: 12),
        _buildPeriodInfo(reportData),
        pw.SizedBox(height: 12),
        _buildStatisticsTableFromList(stats, reportData.currency, false),
        pw.SizedBox(height: 10),
        pw.Container(
          width: double.infinity,
          padding: pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            color: PdfColors.yellow50,
            borderRadius: pw.BorderRadius.circular(8),
            border: pw.Border.all(color: PdfColors.yellow200),
          ),
          child: pw.Center(
            child: pw.Text(
              'يتبع: الإحصائيات المالية في الصفحة التالية',
              style: pw.TextStyle(
                font: arabicFont,
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.orange800,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // صفحة تكملة الإحصائيات
  pw.Widget _buildStatisticsPage(
    String marketName,
    List<Map<String, dynamic>> stats,
    String currency,
    bool includeFooter,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.center,
          children: [
            pw.Column(
              children: [
                pw.Text(
                  'الإحصائيات المالية',
                  style: pw.TextStyle(
                    font: arabicFont,
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  marketName.isNotEmpty ? marketName : 'السوبر ماركت',
                  style: pw.TextStyle(
                    font: arabicFont,
                    fontSize: 14,
                    color: PdfColors.grey600,
                  ),
                ),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 15),
        _buildStatisticsTableFromList(stats, currency, includeFooter),
      ],
    );
  }

  // الجدول - 3 أعمدة: البند | التوضيح | القيمة
  pw.Widget _buildStatisticsTableFromList(
    List<Map<String, dynamic>> statsList,
    String currency,
    bool includeFooter,
  ) {
    List<pw.TableRow> rows = [];

    // رأس الجدول
    rows.add(
      pw.TableRow(
        decoration: pw.BoxDecoration(
          color: PdfColors.blue100,
          borderRadius: pw.BorderRadius.only(
            topLeft: pw.Radius.circular(4),
            topRight: pw.Radius.circular(4),
          ),
        ),
        children: [
          _headerCell('القيمة'),
          _headerCell('التوضيح'),
          _headerCell('البند'),
        ],
      ),
    );

    for (int i = 0; i < statsList.length; i++) {
      final stat = statsList[i];
      final label = stat['label'] as String;
      final description = stat['description'] as String? ?? '';
      final value = stat['value'];
      final type = stat['type'] as String;
      final key = stat['key'] as String;

      final formattedValue = _formatStatValue(value, type, currency);
      final color = _getColorForStat(key, value);
      final bgColor = i % 2 == 0 ? PdfColors.white : PdfColors.grey50;

      rows.add(
        pw.TableRow(
          decoration: pw.BoxDecoration(color: bgColor),
          children: [
            // القيمة
            pw.Container(
              padding: pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
              child: pw.Text(
                formattedValue,
                style: pw.TextStyle(
                  font: arabicFont,
                  fontSize: 10,
                  color: color,
                  fontWeight: pw.FontWeight.bold,
                ),
                textAlign: pw.TextAlign.right,
              ),
            ),
            // التوضيح
            pw.Container(
              padding: pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
              child: pw.Text(
                description,
                style: pw.TextStyle(
                  font: arabicFont,
                  fontSize: 9,
                  color: PdfColors.grey600,
                  fontStyle: pw.FontStyle.italic,
                ),
                textAlign: pw.TextAlign.right,
              ),
            ),
            // البند
            pw.Container(
              padding: pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
              child: pw.Text(
                label,
                style: pw.TextStyle(
                  font: arabicFont,
                  fontSize: 10,
                  color: PdfColors.grey800,
                  fontWeight: pw.FontWeight.bold,
                ),
                textAlign: pw.TextAlign.right,
              ),
            ),
          ],
        ),
      );
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'الإحصائيات المالية',
          style: pw.TextStyle(
            font: arabicFont,
            fontSize: 16,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.black,
          ),
        ),
        pw.SizedBox(height: 10),
        pw.Container(
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey300),
            borderRadius: pw.BorderRadius.circular(6),
          ),
          child: pw.Table(
            border: null,
            columnWidths: {
              0: pw.FlexColumnWidth(2.0), // القيمة
              1: pw.FlexColumnWidth(2.8), // التوضيح
              2: pw.FlexColumnWidth(2.2), // البند
            },
            children: rows,
          ),
        ),
        if (includeFooter) ...[pw.SizedBox(height: 15), _buildFooter()],
      ],
    );
  }

  pw.Widget _headerCell(String text) {
    return pw.Container(
      padding: pw.EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          font: arabicFont,
          fontSize: 11,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.blue900,
        ),
        textAlign: pw.TextAlign.right,
      ),
    );
  }

  pw.Widget _buildHeader(String marketName) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        if (logoImage != null)
          pw.Container(width: 70, height: 70, child: logoImage!),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Text(
              'التقرير المالي',
              style: pw.TextStyle(
                font: arabicFont,
                fontSize: 20,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blue,
              ),
            ),
          ],
        ),
        if (logoImage != null) pw.Container(width: 70),
      ],
    );
  }

  pw.Widget _buildProgramInfo(String marketName) {
    return pw.Container(
      width: double.infinity,
      padding: pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColors.blue50,
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(color: PdfColors.blue100),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
        children: [
          pw.Column(
            children: [
              pw.Text(
                'المتميز',
                style: pw.TextStyle(
                  font: arabicFont,
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue,
                ),
              ),
              pw.Text(
                'نظام إدارة المتاجر',
                style: pw.TextStyle(
                  font: arabicFont,
                  fontSize: 11,
                  color: PdfColors.grey600,
                ),
              ),
            ],
          ),
          pw.VerticalDivider(color: PdfColors.blue200, width: 1),
          pw.Column(
            children: [
              pw.Text(
                'اسم المتجر',
                style: pw.TextStyle(
                  font: arabicFont,
                  fontSize: 11,
                  color: PdfColors.grey600,
                ),
              ),
              pw.Text(
                marketName.isNotEmpty ? marketName : 'غير محدد',
                style: pw.TextStyle(
                  font: arabicFont,
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.black,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _buildAdminAndDateInfo(String adminName) {
    final now = DateTime.now();
    final formattedDate = DateFormat('yyyy/MM/dd - HH:mm').format(now);

    return pw.Container(
      width: double.infinity,
      padding: pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey50,
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'المسؤول',
                style: pw.TextStyle(
                  font: arabicFont,
                  fontSize: 11,
                  color: PdfColors.grey600,
                ),
              ),
              pw.Text(
                adminName.isNotEmpty ? adminName : 'غير محدد',
                style: pw.TextStyle(
                  font: arabicFont,
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.black,
                ),
              ),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                'تاريخ التقرير',
                style: pw.TextStyle(
                  font: arabicFont,
                  fontSize: 11,
                  color: PdfColors.grey600,
                ),
              ),
              pw.Text(
                formattedDate,
                style: pw.TextStyle(
                  font: arabicFont,
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.black,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPeriodInfo(ReportData reportData) {
    return pw.Container(
      width: double.infinity,
      padding: pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'معلومات الفترة',
            style: pw.TextStyle(
              font: arabicFont,
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.black,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Divider(color: PdfColors.grey300, height: 1),
          pw.SizedBox(height: 8),
          pw.Column(
            children: [
              _buildPeriodRow(
                'نوع التقرير:',
                _getPeriodText(reportData.period),
              ),
              _buildPeriodRow('العملة:', reportData.currency),
              _buildPeriodRow('من تاريخ:', _formatDate(reportData.fromDate)),
              _buildPeriodRow('إلى تاريخ:', _formatDate(reportData.toDate)),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPeriodRow(String label, String value) {
    return pw.Row(
      children: [
        pw.Expanded(
          child: pw.Container(
            padding: pw.EdgeInsets.symmetric(vertical: 4),
            child: pw.Text(
              label,
              style: pw.TextStyle(
                font: arabicFont,
                fontSize: 12,
                color: PdfColors.grey600,
              ),
              textAlign: pw.TextAlign.right,
            ),
          ),
        ),
        pw.SizedBox(width: 10),
        pw.Expanded(
          flex: 2,
          child: pw.Container(
            padding: pw.EdgeInsets.symmetric(vertical: 4),
            child: pw.Text(
              value,
              style: pw.TextStyle(
                font: arabicFont,
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.black,
              ),
              textAlign: pw.TextAlign.left,
            ),
          ),
        ),
      ],
    );
  }

  pw.Widget _buildFooter() {
    return pw.Container(
      width: double.infinity,
      padding: pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey50,
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Center(
        child: pw.Text(
          'تم إنشاء هذا التقرير بواسطة نظام المتميز',
          style: pw.TextStyle(
            font: arabicFont,
            fontSize: 11,
            fontStyle: pw.FontStyle.italic,
            color: PdfColors.grey600,
          ),
        ),
      ),
    );
  }

  // ✅ كل الإحصائيات مع توضيح مستخرج من شاشة التقارير
  List<Map<String, dynamic>> _prepareStatisticsList(
    Map<String, dynamic> stats,
  ) {
    List<Map<String, dynamic>> allStats = [];

    final basicStats = [
      // ── المبيعات ──
      {
        'key': 'totalSales',
        'label': 'إجمالي المبيعات',
        'description': 'مجموع كل الفواتير المباعة',
        'type': 'currency',
        'priority': 1,
      },
      {
        'key': 'cashSales',
        'label': 'المبيعات النقدية',
        'description': 'المدفوعات نقداً فقط',
        'type': 'currency',
        'priority': 1,
      },
      {
        'key': 'creditSales',
        'label': 'المبيعات الآجلة',
        'description': 'مبيعات لم تُدفع بعد',
        'type': 'currency',
        'priority': 1,
      },
      {
        'key': 'salesCount',
        'label': 'عدد الفواتير',
        'description': 'إجمالي الفواتير الصادرة',
        'type': 'count',
        'priority': 1,
      },
      {
        'key': 'averageSale',
        'label': 'متوسط الفاتورة',
        'description': 'إجمالي المبيعات ÷ عدد الفواتير',
        'type': 'currency',
        'priority': 1,
      },
      // ── الأرباح ──
      {
        'key': 'totalProfit',
        'label': 'إجمالي الأرباح',
        'description': 'الربح من كل المبيعات (نقدية وآجلة)',
        'type': 'currency',
        'priority': 2,
      },
      {
        'key': 'totalCashProfit',
        'label': 'الأرباح النقدية',
        'description': 'أرباح المبيعات النقدية فقط',
        'type': 'currency',
        'priority': 2,
      },
      {
        'key': 'netProfit',
        'label': 'صافي الربح',
        'description': 'إجمالي الأرباح - المصاريف النقدية',
        'type': 'currency',
        'priority': 2,
      },
      {
        'key': 'netCashProfit',
        'label': 'صافي الربح الكاش',
        'description': 'الأرباح النقدية - المصاريف النقدية',
        'type': 'currency',
        'priority': 2,
      },
      {
        'key': 'adjustedNetProfit',
        'label': 'صافي الربح المعدل',
        'description': 'الربح بعد احتساب كل التعديلات',
        'type': 'currency',
        'priority': 2,
      },
      {
        'key': 'profitPercentage',
        'label': 'نسبة الربح',
        'description': 'الربح كنسبة من إجمالي المبيعات',
        'type': 'percentage',
        'priority': 2,
      },
      {
        'key': 'bestSalesDay',
        'label': 'أفضل يوم مبيعات',
        'description': 'اليوم الأعلى مبيعاً في الفترة',
        'type': 'text',
        'priority': 2,
      },
      // ── المصاريف ──
      {
        'key': 'totalExpensesAll',
        'label': 'إجمالي المصاريف',
        'description': 'كل المصاريف (نقدية وغير نقدية)',
        'type': 'currency',
        'priority': 3,
      },
      {
        'key': 'totalCashExpenses',
        'label': 'المصاريف النقدية',
        'description': 'المصاريف المدفوعة نقداً فقط',
        'type': 'currency',
        'priority': 3,
      },
      // ── الذمم ──
      {
        'key': 'currentDebtBalance',
        'label': 'إجمالي الذمم على الزبائن',
        'description': 'مجموع ما يستحق من الزبائن حتى الآن',
        'type': 'currency',
        'priority': 4,
      },
      {
        'key': 'periodCreditAdded',
        'label': 'ديون جديدة في الفترة',
        'description': 'مبيعات آجلة انضافت خلال هذه الفترة',
        'type': 'currency',
        'priority': 4,
      },
      {
        'key': 'periodDebtCollected',
        'label': 'مبالغ محصلة من الديون',
        'description': 'مدفوعات استُلمت من الزبائن في الفترة',
        'type': 'currency',
        'priority': 4,
      },
      {
        'key': 'debtNetChange',
        'label': 'صافي تغير الذمم',
        'description': 'الديون الجديدة - المبالغ المحصلة',
        'type': 'currency',
        'priority': 4,
      },
      // ── فواتير الشراء ──
      {
        'key': 'totalPurchaseInvoices',
        'label': 'إجمالي فواتير الشراء',
        'description': 'مجموع ما تم شراؤه من الموردين',
        'type': 'currency',
        'priority': 5,
      },
      {
        'key': 'cashPurchases',
        'label': 'المشتريات النقدية',
        'description': 'مشتريات مدفوعة نقداً للموردين',
        'type': 'currency',
        'priority': 5,
      },
      {
        'key': 'creditPurchases',
        'label': 'المشتريات الآجلة',
        'description': 'مشتريات آجلة من الموردين',
        'type': 'currency',
        'priority': 5,
      },
      {
        'key': 'purchaseInvoicesCount',
        'label': 'عدد فواتير الشراء',
        'description': 'عدد الفواتير الواردة من الموردين',
        'type': 'count',
        'priority': 5,
      },
      {
        'key': 'totalSupplierBalance',
        'label': 'رصيد الموردين',
        'description': 'ما يستحق للموردين حتى الآن',
        'type': 'currency',
        'priority': 5,
      },
    ];

    for (var stat in basicStats) {
      final key = stat['key'] as String;
      if (stats.containsKey(key) && stats[key] != null) {
        allStats.add({
          'label': stat['label'],
          'description': stat['description'],
          'value': stats[key],
          'type': stat['type'],
          'key': key,
          'priority': stat['priority'],
        });
      }
    }

    allStats.sort(
      (a, b) => (a['priority'] as int).compareTo(b['priority'] as int),
    );

    return allStats;
  }

  String _formatStatValue(dynamic value, String type, String currency) {
    if (value == null) return '-';
    if (value is num) {
      if (type == 'currency') {
        return value % 1 == 0
            ? '${value.toInt()} $currency'
            : '${value.toStringAsFixed(2)} $currency';
      } else if (type == 'percentage') {
        return '${value.toStringAsFixed(1)}%';
      } else if (type == 'count') {
        return value.toInt().toString();
      }
      return value.toString();
    }
    return value.toString();
  }

  PdfColor _getColorForStat(String key, dynamic value) {
    if (key.contains('Profit') || key.contains('profit')) {
      if (value is num && value < 0) return PdfColors.red;
      return PdfColors.green;
    }
    if (key.contains('Sales') || key == 'salesCount' || key == 'averageSale') {
      return PdfColors.blue;
    }
    if (key.contains('Expenses')) return PdfColors.red700;
    if (key.contains('Purchase') ||
        key.contains('purchase') ||
        key.contains('Supplier')) {
      return PdfColors.purple;
    }
    if (key.contains('Debt') || key.contains('debt')) {
      if (key == 'periodDebtCollected') return PdfColors.green;
      if (key == 'debtNetChange' && value is num && value < 0) {
        return PdfColors.green;
      }
      return PdfColors.orange;
    }
    if (key.contains('Percentage')) return PdfColors.purple;
    if (key == 'bestSalesDay') return PdfColors.teal;
    return PdfColors.black;
  }

  String _formatDate(DateTime date) => DateFormat('yyyy/MM/dd').format(date);

  String _getPeriodText(String period) {
    const periodMap = {
      'اليوم': 'يومي',
      'الأسبوع': 'أسبوعي',
      'الشهر': 'شهري',
      'السنة': 'سنوي',
    };
    return periodMap[period] ?? 'مخصص';
  }
}
