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
  // خط عربي واحد فقط
  late pw.Font arabicFont;
  pw.Image? logoImage;

  // تحميل الخط العربي والصورة
  Future<void> _loadResources() async {
    try {
      // تحميل الخط العربي
      final fontData = await rootBundle.load('fonts/Cairo-Regular.ttf');
      arabicFont = pw.Font.ttf(fontData);

      // تحميل صورة الشعار
      try {
        final logoData = await rootBundle.load('assets/images/shop_logo.png');
        final logoBytes = logoData.buffer.asUint8List();
        logoImage = pw.Image(pw.MemoryImage(logoBytes));
      } catch (e) {
        // تجاهل الخطأ إذا لم توجد الصورة
        logoImage = null;
      }
    } catch (e) {
      // استخدم خط PDF الافتراضي
      arabicFont = pw.Font.helvetica();
    }
  }

  Future<PDFExportResult> exportReport({
    required ReportData reportData,
    required String adminName,
    required String marketName,
  }) async {
    try {
      // تحميل الموارد أولاً
      await _loadResources();

      final pdf = pw.Document();

      // حساب عدد الصفوف في الجدول لتحديد إذا كنا نحتاج صفحة ثانية
      final statsCount = _getStatisticsCount(reportData.statistics);
      final needsTwoPages = statsCount > 10; // إذا كان هناك أكثر من 10 صفوف

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.all(12), // هامش معقول
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
                    needsTwoPages
                        ? _buildFirstPageContent(
                          reportData,
                          adminName,
                          marketName,
                        )
                        : _buildSinglePageContent(
                          reportData,
                          adminName,
                          marketName,
                        ),
              ),
            );
          },
        ),
      );

      // إذا احتجنا لصفحة ثانية للجدول
      if (needsTwoPages) {
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
                  child: _buildStatisticsPage(reportData, marketName),
                ),
              );
            },
          ),
        );
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

  // بناء محتوى الصفحة الأولى (للتقارير الكبيرة)
  pw.Widget _buildFirstPageContent(
    ReportData reportData,
    String adminName,
    String marketName,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // العنوان الرئيسي مع الشعار
        _buildHeader(marketName),
        pw.SizedBox(height: 12),

        // معلومات البرنامج واسم المتجر
        _buildProgramInfo(marketName),
        pw.SizedBox(height: 12),

        // معلومات المسؤول والتاريخ
        _buildAdminAndDateInfo(adminName),
        pw.SizedBox(height: 12),

        // معلومات الفترة
        _buildPeriodInfo(reportData),
        pw.SizedBox(height: 12),

        // ملاحظة أن الإحصائيات في الصفحة التالية
        pw.Container(
          width: double.infinity,
          padding: pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            color: PdfColors.yellow50,
            borderRadius: pw.BorderRadius.circular(8),
            border: pw.Border.all(color: PdfColors.yellow200),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.SizedBox(width: 8),
              pw.Text(
                'يتبع: الإحصائيات المالية في الصفحة التالية',
                style: pw.TextStyle(
                  font: arabicFont,
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.orange800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // بناء محتوى الصفحة الواحدة (للتقارير الصغيرة)
  pw.Widget _buildSinglePageContent(
    ReportData reportData,
    String adminName,
    String marketName,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // العنوان الرئيسي مع الشعار
        _buildHeader(marketName),
        pw.SizedBox(height: 12),

        // معلومات البرنامج واسم المتجر
        _buildProgramInfo(marketName),
        pw.SizedBox(height: 12),

        // معلومات المسؤول والتاريخ
        _buildAdminAndDateInfo(adminName),
        pw.SizedBox(height: 12),

        // معلومات الفترة
        _buildPeriodInfo(reportData),
        pw.SizedBox(height: 12),

        // الإحصائيات المالية
        _buildStatisticsTable(reportData, true),
      ],
    );
  }

  // بناء صفحة الإحصائيات
  pw.Widget _buildStatisticsPage(ReportData reportData, String marketName) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // عنوان الصفحة الثانية
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

        // الجدول الكامل
        _buildStatisticsTable(reportData, false),
      ],
    );
  }

  pw.Widget _buildHeader(String marketName) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        // الشعار إذا كان موجوداً
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

        // عنصر فارغ للموازنة
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

  // utils/pdf_exporter.dart (الجزء المعدل فقط)
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

          // استخدام Row بسيط مع Expanded
          pw.Column(
            children: [
              // نوع التقرير
              pw.Row(
                children: [
                  // الليبل على اليمين
                  pw.Expanded(
                    child: pw.Container(
                      padding: pw.EdgeInsets.symmetric(vertical: 4),
                      child: pw.Text(
                        'نوع التقرير:',
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
                  // الداتا على اليسار
                  pw.Expanded(
                    flex: 2,
                    child: pw.Container(
                      padding: pw.EdgeInsets.symmetric(vertical: 4),
                      child: pw.Text(
                        _getPeriodText(reportData.period),
                        style: pw.TextStyle(
                          font: arabicFont,
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.black,
                        ),
                        textAlign: pw.TextAlign.left, // محاذاة لليسار
                      ),
                    ),
                  ),
                ],
              ),

              // العملة
              pw.Row(
                children: [
                  // الليبل على اليمين
                  pw.Expanded(
                    child: pw.Container(
                      padding: pw.EdgeInsets.symmetric(vertical: 4),
                      child: pw.Text(
                        'العملة:',
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
                  // الداتا على اليسار
                  pw.Expanded(
                    flex: 2,
                    child: pw.Container(
                      padding: pw.EdgeInsets.symmetric(vertical: 4),
                      child: pw.Text(
                        reportData.currency,
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
              ),

              // من تاريخ
              pw.Row(
                children: [
                  // الليبل على اليمين
                  pw.Expanded(
                    child: pw.Container(
                      padding: pw.EdgeInsets.symmetric(vertical: 4),
                      child: pw.Text(
                        'من تاريخ:',
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
                  // الداتا على اليسار
                  pw.Expanded(
                    flex: 2,
                    child: pw.Container(
                      padding: pw.EdgeInsets.symmetric(vertical: 4),
                      child: pw.Text(
                        _formatDate(reportData.fromDate),
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
              ),

              // إلى تاريخ
              pw.Row(
                children: [
                  // الليبل على اليمين
                  pw.Expanded(
                    child: pw.Container(
                      padding: pw.EdgeInsets.symmetric(vertical: 4),
                      child: pw.Text(
                        'إلى تاريخ:',
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
                  // الداتا على اليسار
                  pw.Expanded(
                    flex: 2,
                    child: pw.Container(
                      padding: pw.EdgeInsets.symmetric(vertical: 4),
                      child: pw.Text(
                        _formatDate(reportData.toDate),
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
              ),
            ],
          ),
        ],
      ),
    );
  }

  // وإذا كنت تريد دالة عاملة يمكن استخدامها في أماكن أخرى

  pw.Widget _buildStatisticsTable(ReportData reportData, bool includeFooter) {
    final stats = reportData.statistics;
    final statsList = _prepareStatisticsList(stats);

    // بناء صفوف الجدول
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
          pw.Container(
            padding: pw.EdgeInsets.symmetric(vertical: 8, horizontal: 10),
            child: pw.Text(
              'القيمة',
              style: pw.TextStyle(
                font: arabicFont,
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blue900,
              ),
              textAlign: pw.TextAlign.right,
            ),
          ),
          pw.Container(
            padding: pw.EdgeInsets.symmetric(vertical: 8, horizontal: 10),
            child: pw.Text(
              'البند',
              style: pw.TextStyle(
                font: arabicFont,
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blue900,
              ),
              textAlign: pw.TextAlign.right,
            ),
          ),
        ],
      ),
    );

    // بيانات الجدول
    for (int i = 0; i < statsList.length; i++) {
      final stat = statsList[i];
      final label = stat['label'] as String;
      final value = stat['value'];
      final type = stat['type'] as String;
      final key = stat['key'] as String;

      final formattedValue = _formatStatValue(value, type, reportData.currency);
      final color = _getColorForStat(key, value);

      rows.add(
        pw.TableRow(
          decoration: pw.BoxDecoration(
            color: i % 2 == 0 ? PdfColors.white : PdfColors.grey50,
          ),
          children: [
            // القيمة (على اليسار)
            pw.Container(
              padding: pw.EdgeInsets.symmetric(vertical: 6, horizontal: 10),
              child: pw.Text(
                formattedValue,
                style: pw.TextStyle(
                  font: arabicFont,
                  fontSize: 11,
                  color: color,
                  fontWeight: pw.FontWeight.bold,
                ),
                textAlign: pw.TextAlign.right,
              ),
            ),
            // البند (على اليمين)
            pw.Container(
              padding: pw.EdgeInsets.symmetric(vertical: 6, horizontal: 10),
              child: pw.Text(
                label,
                style: pw.TextStyle(
                  font: arabicFont,
                  fontSize: 11,
                  color: PdfColors.grey800,
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
            border: null, // إزالة الحدود الداخلية للتحكم بها يدوياً
            columnWidths: {
              0: pw.FlexColumnWidth(1.8),
              1: pw.FlexColumnWidth(2.5),
            },
            children: rows,
          ),
        ),

        if (includeFooter) ...[pw.SizedBox(height: 15), _buildFooter()],
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

  // إعداد قائمة الإحصائيات
  List<Map<String, dynamic>> _prepareStatisticsList(
    Map<String, dynamic> stats,
  ) {
    List<Map<String, dynamic>> allStats = [];

    final basicStats = [
      {
        'key': 'totalSales',
        'label': 'إجمالي المبيعات',
        'type': 'currency',
        'priority': 1,
      },
      {
        'key': 'totalProfit',
        'label': 'إجمالي الأرباح',
        'type': 'currency',
        'priority': 1,
      },
      {
        'key': 'cashSales',
        'label': 'المبيعات النقدية',
        'type': 'currency',
        'priority': 2,
      },
      {
        'key': 'creditSales',
        'label': 'المبيعات الآجلة',
        'type': 'currency',
        'priority': 2,
      },
      {
        'key': 'salesCount',
        'label': 'عدد الفواتير',
        'type': 'count',
        'priority': 2,
      },
      {
        'key': 'averageSale',
        'label': 'متوسط الفاتورة',
        'type': 'currency',
        'priority': 3,
      },
      {
        'key': 'netProfit',
        'label': 'صافي الربح',
        'type': 'currency',
        'priority': 1,
      },
      {
        'key': 'totalExpensesAll',
        'label': 'إجمالي المصاريف',
        'type': 'currency',
        'priority': 1,
      },
      {
        'key': 'totalCashExpenses',
        'label': 'المصاريف النقدية',
        'type': 'currency',
        'priority': 2,
      },
      {
        'key': 'profitPercentage',
        'label': 'نسبة الربح',
        'type': 'percentage',
        'priority': 3,
      },
      {
        'key': 'netCashProfit',
        'label': 'صافي الربح الكاش',
        'type': 'currency',
        'priority': 2,
      },
      {
        'key': 'adjustedNetProfit',
        'label': 'صافي الربح المعدل',
        'type': 'currency',
        'priority': 3,
      },
      {
        'key': 'bestSalesDay',
        'label': 'أفضل يوم مبيعات',
        'type': 'text',
        'priority': 3,
      },
    ];

    // تصفية فقط الإحصائيات الموجودة
    for (var stat in basicStats) {
      final key = stat['key'] as String;
      if (stats.containsKey(key) && stats[key] != null) {
        allStats.add({
          'label': stat['label'],
          'value': stats[key],
          'type': stat['type'],
          'key': key,
          'priority': stat['priority'],
        });
      }
    }

    // ترتيب الإحصائيات حسب الأولوية
    allStats.sort(
      (a, b) => (a['priority'] as int).compareTo(b['priority'] as int),
    );

    return allStats;
  }

  // حساب عدد الإحصائيات
  int _getStatisticsCount(Map<String, dynamic> stats) {
    final basicStats = [
      'totalSales',
      'totalProfit',
      'cashSales',
      'creditSales',
      'salesCount',
      'averageSale',
      'netProfit',
      'totalExpensesAll',
      'totalCashExpenses',
      'profitPercentage',
      'netCashProfit',
      'adjustedNetProfit',
      'bestSalesDay',
    ];

    int count = 0;
    for (var key in basicStats) {
      if (stats.containsKey(key) && stats[key] != null) {
        count++;
      }
    }
    return count;
  }

  String _formatStatValue(dynamic value, String type, String currency) {
    if (value == null) return '-';

    if (value is num) {
      if (type == 'currency') {
        if (value % 1 == 0) {
          return '${value.toInt()} $currency';
        } else {
          return '${value.toStringAsFixed(2)} $currency';
        }
      } else if (type == 'percentage') {
        return '${value.toStringAsFixed(1)}%';
      } else if (type == 'count') {
        return value.toInt().toString();
      } else {
        return value.toString();
      }
    }

    // للقيم النصية (مثل bestSalesDay)
    return value.toString();
  }

  PdfColor _getColorForStat(String key, dynamic value) {
    if (key.contains('Profit')) {
      if (value is num && value < 0) {
        return PdfColors.red;
      }
      return PdfColors.green;
    }

    if (key.contains('Sales')) {
      return PdfColors.blue;
    }

    if (key.contains('Expenses')) {
      return PdfColors.red;
    }

    if (key.contains('Percentage')) {
      return PdfColors.purple;
    }

    if (key.contains('Count')) {
      return PdfColors.orange;
    }

    if (key == 'bestSalesDay') {
      return PdfColors.teal;
    }

    return PdfColors.black;
  }

  String _formatDate(DateTime date) {
    return DateFormat('yyyy/MM/dd').format(date);
  }

  String _getPeriodText(String period) {
    final periodMap = {
      'اليوم': 'يومي',
      'الأسبوع': 'أسبوعي',
      'الشهر': 'شهري',
      'السنة': 'سنوي',
    };
    return periodMap[period] ?? 'مخصص';
  }
}
