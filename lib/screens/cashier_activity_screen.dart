import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat, NumberFormat;
import 'package:motamayez/components/base_layout.dart';
import 'package:motamayez/providers/sales_provider.dart';
import 'package:motamayez/providers/settings_provider.dart'; // ⬅️ أضف هاد
import 'package:motamayez/widgets/SaleDetailsDialog.dart';
import 'package:provider/provider.dart';
import '../../providers/cashier_activity_provider.dart';
import '../../models/cashier_activity_model.dart';

class CashierActivityScreen extends StatefulWidget {
  const CashierActivityScreen({Key? key}) : super(key: key);

  @override
  State<CashierActivityScreen> createState() => _CashierActivityScreenState();
}

class _CashierActivityScreenState extends State<CashierActivityScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CashierActivityProvider>().loadCashierActivities();
    });
  }

  void _showSaleDetails(int saleId, BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => SaleDetailsDialog(saleId: saleId),
    );
  }

  Future<void> _selectSingleDay(BuildContext context) async {
    final provider = context.read<CashierActivityProvider>();

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: provider.customDay ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.indigo,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      provider.setCustomDay(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    // ⬅️ جديد: جلب العملة مرة واحدة هون
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final currencyName = settings.currencyName;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: BaseLayout(
        currentPage: 'cashier_activity',
        title: 'نشاط الكاشيرز',
        child: Consumer<CashierActivityProvider>(
          builder: (context, provider, child) {
            return Column(
              children: [
                _buildFilterSection(context, provider),
                const SizedBox(height: 16),
                Expanded(
                  child:
                      provider.isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : provider.error != null
                          ? _buildErrorWidget(provider.error!)
                          : provider.cashierActivities.isEmpty
                          ? _buildEmptyWidget()
                          : _buildActivityList(
                            provider,
                            currencyName,
                          ), // ⬅️ تمرير العملة
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildFilterSection(
    BuildContext context,
    CashierActivityProvider provider,
  ) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'اختر الفترة',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.indigo,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children:
                DateFilter.values.map((filter) {
                  final isSelected = provider.currentFilter == filter;
                  return ChoiceChip(
                    label: Text(
                      filter.displayName,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.w500,
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: Colors.indigo,
                    backgroundColor: Colors.grey[100],
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : Colors.black87,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    onSelected: (selected) {
                      if (selected) {
                        if (filter == DateFilter.customDay) {
                          _selectSingleDay(context);
                        } else {
                          provider.setFilter(filter);
                        }
                      }
                    },
                  );
                }).toList(),
          ),
          if (provider.currentFilter == DateFilter.customDay &&
              provider.customDay != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.indigo.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.calendar_today,
                    color: Colors.indigo,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    DateFormat('yyyy/MM/dd').format(provider.customDay!),
                    style: const TextStyle(
                      color: Colors.indigo,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActivityList(
    CashierActivityProvider provider,
    String currencyName,
  ) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: provider.cashierActivities.length,
      itemBuilder: (context, index) {
        final activity = provider.cashierActivities[index];
        return _buildCashierCard(activity, currencyName); // ⬅️ تمرير العملة
      },
    );
  }

  // ⬅️ تعديل: إضافة currencyName كـ parameter
  Widget _buildCashierCard(CashierActivityModel activity, String currencyName) {
    final currencyFormat = NumberFormat.currency(
      locale: 'ar',
      symbol: '', // ⬅️ فارغ لأننا بنعرض العملة منفصلة
      decimalDigits: 0,
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        childrenPadding: const EdgeInsets.all(16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        leading: CircleAvatar(
          backgroundColor: Colors.indigo,
          radius: 26,
          child: Text(
            activity.userName.substring(0, 1).toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          activity.userName,
          style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          activity.userEmail,
          style: TextStyle(color: Colors.grey[600], fontSize: 15),
        ),
        // ⬅️ تعديل: عرض المبلغ مع العملة كنص بدل أيقونة
        trailing: Container(
          constraints: const BoxConstraints(minWidth: 100),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ⬅️ جديد: عرض المبلغ + العملة معاً
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      currencyFormat.format(activity.totalSales),
                      style: const TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      currencyName, // ⬅️ هاي بدل أيقونة الشيكل
                      style: const TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${activity.totalInvoices} فاتورة',
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
        children: [
          const Divider(thickness: 1),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.receipt_long, color: Colors.indigo, size: 22),
              const SizedBox(width: 8),
              const Text(
                'الفواتير:',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Text(
                '${activity.invoices.length} فاتورة',
                style: TextStyle(
                  color: Colors.grey[700],
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildInvoicesGrid(
            activity.invoices,
            currencyName,
          ), // ⬅️ تمرير العملة
        ],
      ),
    );
  }

  // ⬅️ تعديل: إضافة currencyName
  Widget _buildInvoicesGrid(
    List<InvoiceSummary> invoices,
    String currencyName,
  ) {
    if (invoices.isEmpty) return const SizedBox.shrink();

    final displayCount = invoices.length > 8 ? 8 : invoices.length;

    return Column(
      children: [
        ...invoices
            .take(displayCount)
            .map(
              (invoice) => _buildCompactInvoiceItem(invoice, currencyName),
            ), // ⬅️
        if (invoices.length > 8) ...[
          const SizedBox(height: 10),
          ElevatedButton.icon(
            onPressed:
                () => _showAllInvoicesDialog(invoices, currencyName), // ⬅️
            icon: const Icon(Icons.expand_more, size: 22),
            label: Text(
              'عرض ${invoices.length - 8} فاتورة إضافية',
              style: const TextStyle(fontSize: 15),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo.withOpacity(0.1),
              foregroundColor: Colors.indigo,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ],
    );
  }

  // ⬅️ تعديل: إضافة currencyName
  Widget _buildCompactInvoiceItem(InvoiceSummary invoice, String currencyName) {
    final dateFormat = DateFormat('MM/dd HH:mm');
    final currencyFormat = NumberFormat.currency(
      locale: 'ar',
      symbol: '', // ⬅️ فارغ
      decimalDigits: 0,
    );

    Color paymentColor;
    IconData paymentIcon;
    String paymentText;

    switch (invoice.paymentType) {
      case 'cash':
        paymentColor = Colors.green;
        paymentIcon = Icons.money;
        paymentText = 'نقدي';
        break;
      case 'credit':
        paymentColor = Colors.orange;
        paymentIcon = Icons.credit_card;
        paymentText = 'آجل';
        break;
      default:
        paymentColor = Colors.grey;
        paymentIcon = Icons.payment;
        paymentText = invoice.paymentType;
    }

    return InkWell(
      onTap: () => _showSaleDetails(invoice.saleId, context),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.indigo.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '#${invoice.saleId}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: Colors.indigo,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dateFormat.format(invoice.date),
                    style: TextStyle(
                      color: Colors.grey[800],
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (invoice.customerName != null)
                    Text(
                      invoice.customerName!,
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: paymentColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(paymentIcon, size: 16, color: paymentColor),
                  const SizedBox(width: 4),
                  Text(
                    paymentText,
                    style: TextStyle(
                      color: paymentColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            // ⬅️ تعديل: عرض المبلغ + العملة
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  currencyFormat.format(invoice.totalAmount),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.indigo,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  currencyName, // ⬅️ هاي بدل أيقونة الشيكل
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.indigo,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  // ⬅️ تعديل: إضافة currencyName
  void _showAllInvoicesDialog(
    List<InvoiceSummary> invoices,
    String currencyName,
  ) {
    showDialog(
      context: context,
      builder:
          (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Container(
              width: 700,
              height: 600,
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.receipt_long,
                        color: Colors.indigo,
                        size: 28,
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'جميع الفواتير',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${invoices.length} فاتورة',
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 16),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close, size: 28),
                      ),
                    ],
                  ),
                  const Divider(thickness: 1),
                  Expanded(
                    child: ListView.builder(
                      itemCount: invoices.length,
                      itemBuilder: (context, index) {
                        return _buildCompactInvoiceItem(
                          invoices[index],
                          currencyName,
                        ); // ⬅️
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  Widget _buildErrorWidget(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 70, color: Colors.red),
          const SizedBox(height: 20),
          Text(
            error,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.red, fontSize: 16),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () {
              context.read<CashierActivityProvider>().refresh();
            },
            icon: const Icon(Icons.refresh, size: 24),
            label: const Text('إعادة المحاولة', style: TextStyle(fontSize: 16)),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long_outlined, size: 90, color: Colors.grey[400]),
          const SizedBox(height: 20),
          Text(
            'لا توجد مبيعات في الفترة المحددة',
            style: TextStyle(
              fontSize: 20,
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'حاول تغيير فترة التصفية',
            style: TextStyle(color: Colors.grey[600], fontSize: 16),
          ),
        ],
      ),
    );
  }
}
