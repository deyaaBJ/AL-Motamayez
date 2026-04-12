import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat, NumberFormat;
import 'package:motamayez/components/base_layout.dart';
import 'package:motamayez/providers/settings_provider.dart'; // ⬅️ أضف هاد
import 'package:motamayez/widgets/sale_details_dialog.dart';
import 'package:provider/provider.dart';
import '../../providers/cashier_activity_provider.dart';
import '../../models/cashier_activity_model.dart';

class CashierActivityScreen extends StatefulWidget {
  const CashierActivityScreen({super.key});

  @override
  State<CashierActivityScreen> createState() => _CashierActivityScreenState();
}

class _CashierActivityScreenState extends State<CashierActivityScreen> {
  // ⬅️ جديد: تتبع عدد الفواتير المعروضة لكل كاشير
  final Map<int, int> _displayedInvoicesCount = {};
  static const int _invoicesPerPage = 20;

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

  String _getRoleLabel(String role) {
    switch (role) {
      case 'admin':
        return 'أدمن';
      case 'tax':
        return 'حساب ضريبة';
      case 'cashier':
      default:
        return 'كاشير';
    }
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'admin':
        return Colors.deepOrange;
      case 'tax':
        return Colors.teal;
      case 'cashier':
      default:
        return Colors.indigo;
    }
  }

  IconData _getRoleIcon(String role) {
    switch (role) {
      case 'admin':
        return Icons.admin_panel_settings;
      case 'tax':
        return Icons.receipt_long;
      case 'cashier':
      default:
        return Icons.point_of_sale;
    }
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
            // ignore: deprecated_member_use
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
                // ignore: deprecated_member_use
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
        // ⬅️ تأكد من أن هناك entry في map لكل كاشير
        _displayedInvoicesCount.putIfAbsent(
          activity.userId,
          () => _invoicesPerPage,
        );
        return _buildCashierCard(activity, currencyName);
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
    final roleColor = _getRoleColor(activity.userRole);
    final roleLabel = _getRoleLabel(activity.userRole);
    final roleIcon = _getRoleIcon(activity.userRole);

    final provider = context.watch<CashierActivityProvider>();
    final invoices = provider.invoicesForUser(activity.userId);
    final isInvoicesLoading = provider.isInvoicesLoading(activity.userId);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ExpansionTile(
        onExpansionChanged: (expanded) {
          if (expanded) {
            context.read<CashierActivityProvider>().loadInvoicesForUser(
              activity.userId,
            );
          }
        },
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        childrenPadding: const EdgeInsets.all(16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        leading: CircleAvatar(
          backgroundColor: roleColor,
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
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              activity.userEmail,
              style: TextStyle(color: Colors.grey[600], fontSize: 15),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                // ignore: deprecated_member_use
                color: roleColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(roleIcon, size: 14, color: roleColor),
                  const SizedBox(width: 6),
                  Text(
                    roleLabel,
                    style: TextStyle(
                      color: roleColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        // ⬅️ تعديل: عرض المبلغ مع العملة كنص بدل أيقونة
        trailing: Container(
          constraints: const BoxConstraints(minWidth: 100),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          decoration: BoxDecoration(
            // ignore: deprecated_member_use
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
                '${activity.totalInvoices} فاتورة',
                style: TextStyle(
                  color: Colors.grey[700],
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (isInvoicesLoading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            )
          else
            _buildInvoicesGrid(invoices, currencyName, activity.userId),
        ],
      ),
    );
  }

  // ⬅️ تعديل: إضافة currencyName
  Widget _buildInvoicesGrid(
    List<InvoiceSummary> invoices,
    String currencyName,
    int userId,
  ) {
    if (invoices.isEmpty) return const SizedBox.shrink();

    // ⬅️ جديد: الحصول على عدد الفواتير المعروضة لهذا الكاشير
    int displayedCount = _displayedInvoicesCount[userId] ?? _invoicesPerPage;
    displayedCount = displayedCount.clamp(0, invoices.length);

    return Column(
      children: [
        ...invoices
            .take(displayedCount)
            .map((invoice) => _buildCompactInvoiceItem(invoice, currencyName)),
        // ⬅️ تعديل: زر "حمل المزيد" بدل "اعرض الكل"
        if (displayedCount < invoices.length) ...[
          const SizedBox(height: 10),
          ElevatedButton.icon(
            onPressed: () {
              setState(() {
                _displayedInvoicesCount[userId] = (displayedCount +
                        _invoicesPerPage)
                    .clamp(0, invoices.length);
              });
            },
            icon: const Icon(Icons.download, size: 22),
            label: Text(
              'حمل ${(invoices.length - displayedCount).clamp(0, _invoicesPerPage)} فاتورة إضافية',
              style: const TextStyle(fontSize: 15),
            ),
            style: ElevatedButton.styleFrom(
              // ignore: deprecated_member_use
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
                // ignore: deprecated_member_use
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
                // ignore: deprecated_member_use
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
