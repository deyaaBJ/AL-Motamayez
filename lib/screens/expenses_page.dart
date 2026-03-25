import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:motamayez/providers/settings_provider.dart';
import 'package:provider/provider.dart';
import 'package:motamayez/models/expense.dart';
import 'package:motamayez/providers/expense_provider.dart';
import 'package:motamayez/components/base_layout.dart';

class ExpensesPage extends StatefulWidget {
  const ExpensesPage({super.key});

  @override
  State<ExpensesPage> createState() => _ExpensesPageState();
}

class _ExpensesPageState extends State<ExpensesPage> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  // متغيرات الفلترة
  String? _selectedPaymentType;
  String? _activeTimeFilter; // اليوم أو الشهر أو null

  // فلتر خاص للتحقق من "الكل"
  bool _isAllSelected = true;
  double _overallTodayExpenses = 0.0;
  double _overallMonthExpenses = 0.0;
  double _overallTotalExpenses = 0.0;
  bool _isOverallStatsLoading = true;

  final List<String> _expenseTypes = [
    'كهرباء',
    'ماء',
    'صيانة',
    'إيجار',
    'رواتب',
    'إنترنت',
    'هاتف',
    'مواد مكتبية',
    'نقل',
    'أخرى',
  ];

  final List<String> _paymentTypes = ['نقدي', 'دين'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<ExpenseProvider>();
      _applyTodayFilter(provider);
      _loadOverallStatistics();
    });

    _scrollController.addListener(_scrollListener);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadOverallStatistics() async {
    if (!mounted) return;
    setState(() => _isOverallStatsLoading = true);

    final stats = await context.read<ExpenseProvider>().getOverallStatistics();
    if (!mounted) return;

    setState(() {
      _overallTodayExpenses = stats['today'] ?? 0.0;
      _overallMonthExpenses = stats['month'] ?? 0.0;
      _overallTotalExpenses = stats['total'] ?? 0.0;
      _isOverallStatsLoading = false;
    });
  }

  void _scrollListener() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 100) {
      // عندما نصل إلى 100 بكسل من النهاية، نحمّل المزيد
      if (!context.read<ExpenseProvider>().isLoading &&
          context.read<ExpenseProvider>().hasMore) {
        context.read<ExpenseProvider>().loadMore();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: BaseLayout(
        currentPage: 'المصاريف',
        floatingActionButton: FloatingActionButton(
          heroTag: 'add_expense_fab',
          onPressed: () => _showAddExpenseDialog(context),
          backgroundColor: Colors.red.shade600,
          child: const Icon(Icons.add, color: Colors.white),
        ),
        child: _buildMainContent(context),
      ),
    );
  }

  Widget _buildMainContent(BuildContext context) {
    final provider = context.watch<ExpenseProvider>();
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final currencyName = settings.currencyName;

    return Column(
      children: [
        // 🔹 شريط البحث والفلترة
        _buildSearchAndFilter(provider),

        // 🔹 إحصائيات
        _buildStatistics(),

        // 🔹 قائمة المصاريف
        Expanded(child: _buildExpensesList(provider, currencyName)),
      ],
    );
  }

  Widget _buildSearchAndFilter(ExpenseProvider provider) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: [
          // 🔍 شريط البحث
          TextField(
            controller: _searchController,
            onChanged: (value) {
              if (value.isEmpty) {
                _resetAllFilters(provider);
              } else {
                provider.filterBySearch(value);
                _selectedPaymentType = null;
                _activeTimeFilter = null;
                _isAllSelected = false;
              }
            },
            decoration: InputDecoration(
              hintText: 'ابحث في المصاريف...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              filled: true,
              fillColor: Colors.grey.shade50,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            ),
          ),

          const SizedBox(height: 12),

          // فلاتر سريعة مع cursor pointer وألوان متغيرة - فقط: اليوم، الشهر، الكل، نقدي، تحويل
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // فلتر اليوم
                _buildQuickFilter(
                  label: 'اليوم',
                  icon: Icons.today,
                  filterKey: 'today',
                  isSelected: _activeTimeFilter == 'اليوم',
                  onTap: () {
                    if (_activeTimeFilter == 'اليوم') {
                      // إذا كان مفتعلًا، نقوم بإلغائه
                      _resetAllFilters(provider);
                    } else {
                      _applyTodayFilter(provider);
                    }
                  },
                ),
                const SizedBox(width: 8),

                // فلتر الشهر
                _buildQuickFilter(
                  label: 'الشهر',
                  icon: Icons.calendar_month,
                  filterKey: 'month',
                  isSelected: _activeTimeFilter == 'الشهر',
                  onTap: () {
                    if (_activeTimeFilter == 'الشهر') {
                      // إلغاء التفعيل
                      _resetAllFilters(provider);
                    } else {
                      _applyMonthFilter(provider);
                    }
                  },
                ),
                const SizedBox(width: 8),

                // فلتر الكل
                _buildQuickFilter(
                  label: 'الكل',
                  icon: Icons.all_inclusive,
                  filterKey: 'all',
                  isSelected: _isAllSelected,
                  onTap: () {
                    _resetAllFilters(provider);
                  },
                ),
                const SizedBox(width: 8),

                // فلتر نقدي
                _buildQuickFilter(
                  label: 'نقدي',
                  icon: Icons.money,
                  filterKey: 'cash',
                  isSelected: _selectedPaymentType == 'نقدي',
                  onTap: () {
                    if (_selectedPaymentType == 'نقدي') {
                      // إلغاء التحديد
                      _resetAllFilters(provider);
                    } else {
                      _selectedPaymentType = 'نقدي';
                      _activeTimeFilter = null;
                      _isAllSelected = false;
                      provider.filterByPaymentType('نقدي');
                    }
                  },
                ),
                const SizedBox(width: 8),

                // فلتر تحويل
                _buildQuickFilter(
                  label: 'دين',
                  icon: Icons.account_balance,
                  filterKey: 'transfer',
                  isSelected: _selectedPaymentType == 'دين',
                  onTap: () {
                    if (_selectedPaymentType == 'دين') {
                      // إلغاء التحديد
                      _resetAllFilters(provider);
                    } else {
                      _selectedPaymentType = 'دين';
                      _activeTimeFilter = null;
                      _isAllSelected = false;
                      provider.filterByPaymentType('دين');
                    }
                  },
                ),
              ],
            ),
          ),

          // مؤشر الفلتر النشط
          if (!_isAllSelected || provider.currentFilterType != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.filter_alt,
                          size: 14,
                          color: Colors.orange.shade700,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _getActiveFilterText(),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.orange.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),

                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () {
                            _resetAllFilters(provider);
                          },
                          child: MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: Icon(
                              Icons.close,
                              size: 14,
                              color: Colors.orange.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildQuickFilter({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    required String filterKey,
    required bool isSelected,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? Colors.orange.shade100 : Colors.blue.shade50,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? Colors.orange.shade300 : Colors.blue.shade100,
              width: isSelected ? 1.5 : 1,
            ),
            boxShadow:
                isSelected
                    ? [
                      BoxShadow(
                        color: Colors.orange.withOpacity(0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ]
                    : [],
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 16,
                color:
                    isSelected ? Colors.orange.shade700 : Colors.blue.shade700,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  color:
                      isSelected
                          ? Colors.orange.shade700
                          : Colors.blue.shade700,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                ),
              ),
              if (isSelected) ...[
                const SizedBox(width: 4),
                Icon(
                  Icons.check_circle,
                  size: 14,
                  color: Colors.orange.shade700,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _getActiveFilterText() {
    if (_selectedPaymentType != null) {
      return 'دفع: $_selectedPaymentType';
    } else if (_activeTimeFilter != null) {
      return 'التاريخ: $_activeTimeFilter';
    }
    return 'فلاتر';
  }

  Widget _buildStatistics() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            'اليوم',
            _isOverallStatsLoading
                ? '...'
                : _overallTodayExpenses.toStringAsFixed(1),
            Icons.today,
            Colors.blue,
          ),
          _buildStatItem(
            'الشهر',
            _isOverallStatsLoading
                ? '...'
                : _overallMonthExpenses.toStringAsFixed(1),
            Icons.calendar_month,
            Colors.green,
          ),
          _buildStatItem(
            'المجموع',
            _isOverallStatsLoading
                ? '...'
                : _overallTotalExpenses.toStringAsFixed(1),
            Icons.attach_money,
            Colors.red,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 20, color: color),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(title, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }

  Widget _buildExpensesList(ExpenseProvider provider, String currencyName) {
    if (provider.isLoading && provider.expenses.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.expenses.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long, size: 60, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            const Text(
              'لا يوجد مصاريف',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => _showAddExpenseDialog(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'إضافة مصروف جديد',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (scrollNotification) {
        // 🔥 لا تحمل المزيد إذا كان هناك فلتر نشط
        if (_isAllSelected &&
            provider.currentFilterType?.isEmpty == true &&
            _selectedPaymentType == null &&
            _activeTimeFilter == null) {
          if (scrollNotification is ScrollEndNotification &&
              _scrollController.position.extentAfter == 0 &&
              provider.hasMore &&
              !provider.isLoading) {
            provider.loadMore();
          }
        }
        return false;
      },
      child: ListView.builder(
        controller: _scrollController,
        itemCount: provider.expenses.length + 1, // +1 للـ loading widget
        itemBuilder: (context, index) {
          // إذا وصلنا لنهاية القائمة، نعرض widget التحميل
          if (index >= provider.expenses.length) {
            return _buildLoadingMore(provider);
          }

          final expense = provider.expenses[index];
          return _buildExpenseCard(expense, provider, currencyName);
        },
      ),
    );
  }

  Widget _buildExpenseCard(
    Expense expense,
    ExpenseProvider provider,
    String currencyName,
  ) {
    final date = _parseDate(expense.date);
    final formattedDate = DateFormat('yyyy-MM-dd').format(date);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.grey.shade100, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // الأيقونة
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _getExpenseColor(expense.type),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                _getExpenseIcon(expense.type),
                color: Colors.white,
                size: 20,
              ),
            ),

            const SizedBox(width: 12),

            // التفاصيل
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        expense.type,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${expense.amount.toStringAsFixed(1)} $currencyName',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 6),

                  // التاريخ وطريقة الدفع
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 13,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        formattedDate,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),

                      if (expense.paymentType != null) ...[
                        const SizedBox(width: 12),
                        Icon(
                          Icons.payment,
                          size: 13,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          expense.paymentType!,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ],
                  ),

                  // الملاحظات إذا وجدت
                  if (expense.note != null && expense.note!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.note,
                            size: 12,
                            color: Colors.grey.shade500,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              expense.note!,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade700,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // قائمة الإجراءات
            PopupMenuButton(
              itemBuilder:
                  (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit, size: 18, color: Colors.blue),
                          SizedBox(width: 8),
                          Text('تعديل'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, size: 18, color: Colors.red),
                          SizedBox(width: 8),
                          Text('حذف'),
                        ],
                      ),
                    ),
                  ],
              onSelected: (value) {
                if (value == 'edit') {
                  _showEditExpenseDialog(context, expense, currencyName);
                } else if (value == 'delete') {
                  _showDeleteDialog(context, expense, provider, currencyName);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingMore(ExpenseProvider provider) {
    // دائماً نعرض تحميل المزيد إذا كان هناك المزيد من البيانات
    if (provider.hasMore) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Center(
          child:
              provider.isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                    onPressed: () => provider.loadMore(),
                    child: const Text('تحميل المزيد'),
                  ),
        ),
      );
    }

    // إذا لا يوجد المزيد ونحن في نهاية القائمة
    if (provider.expenses.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Text(
            'تم عرض كل المصاريف',
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ),
      );
    }

    return Container();
  }

  // ==================== دوال الفلترة ====================
  void _applyTodayFilter(ExpenseProvider provider) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);

    _selectedPaymentType = null;
    _activeTimeFilter = 'اليوم';
    _isAllSelected = false;
    _searchController.clear();

    // استخدام filterByDate التي تدعم pagination
    provider.filterByDate(from: todayStart, to: todayEnd);
  }

  void _applyMonthFilter(ExpenseProvider provider) {
    final now = DateTime.now();
    final firstDay = DateTime(now.year, now.month, 1);
    final lastDay = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

    _selectedPaymentType = null;
    _activeTimeFilter = 'الشهر';
    _isAllSelected = false;
    _searchController.clear();

    // استخدام filterByDate التي تدعم pagination
    provider.filterByDate(from: firstDay, to: lastDay);
  }

  void _resetAllFilters(ExpenseProvider provider) {
    _selectedPaymentType = null;
    _activeTimeFilter = null;
    _isAllSelected = true;
    _searchController.clear();
    provider.resetFilter();
  }

  // ==================== دوال الحوارات ====================
  void _showAddExpenseDialog(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final currencyName = settings.currencyName;
    final formKey = GlobalKey<FormState>();
    final amountController = TextEditingController();
    final noteController = TextEditingController();
    DateTime selectedDate = DateTime.now();
    String? selectedExpenseType = 'كهرباء';
    String? selectedPaymentType = 'نقدي';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.add_circle, color: Colors.red),
                  SizedBox(width: 8),
                  Text('إضافة مصروف جديد'),
                ],
              ),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // نوع المصروف
                      DropdownButtonFormField<String>(
                        value: selectedExpenseType,
                        decoration: const InputDecoration(
                          labelText: 'نوع المصروف',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12),
                        ),
                        items:
                            _expenseTypes
                                .map(
                                  (type) => DropdownMenuItem(
                                    value: type,
                                    child: Text(type),
                                  ),
                                )
                                .toList(),
                        onChanged: (value) {
                          setState(() {
                            selectedExpenseType = value;
                          });
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'الرجاء اختيار نوع المصروف';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 16),

                      // المبلغ
                      TextFormField(
                        controller: amountController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'المبلغ ($currencyName)',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.attach_money),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'الرجاء إدخال المبلغ';
                          }
                          if (double.tryParse(value) == null) {
                            return 'الرجاء إدخال رقم صحيح';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 16),

                      // طريقة الدفع
                      DropdownButtonFormField<String>(
                        value: selectedPaymentType,
                        decoration: const InputDecoration(
                          labelText: 'طريقة الدفع',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12),
                        ),
                        items:
                            _paymentTypes
                                .map(
                                  (type) => DropdownMenuItem(
                                    value: type,
                                    child: Text(type),
                                  ),
                                )
                                .toList(),
                        onChanged: (value) {
                          setState(() {
                            selectedPaymentType = value;
                          });
                        },
                      ),

                      const SizedBox(height: 16),

                      // التاريخ
                      InkWell(
                        onTap: () async {
                          final pickedDate = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (pickedDate != null) {
                            setState(() {
                              selectedDate = pickedDate;
                            });
                          }
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'التاريخ',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.calendar_today),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                DateFormat('yyyy-MM-dd').format(selectedDate),
                              ),
                              const Icon(Icons.arrow_drop_down),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // الملاحظات
                      TextFormField(
                        controller: noteController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'ملاحظات (اختياري)',
                          border: OutlineInputBorder(),
                          alignLabelWithHint: true,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('إلغاء'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (formKey.currentState!.validate()) {
                      final expense = Expense(
                        type: selectedExpenseType!,
                        amount: double.parse(amountController.text),
                        date: selectedDate.toIso8601String(),
                        paymentType: selectedPaymentType,
                        note:
                            noteController.text.isNotEmpty
                                ? noteController.text
                                : null,
                        createdAt: DateTime.now().toIso8601String(),
                      );
                      await context.read<ExpenseProvider>().addExpense(expense);
                      await _loadOverallStatistics();
                      Navigator.pop(context);

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('تم إضافة المصروف بنجاح'),
                          backgroundColor: Colors.green.shade600,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade600,
                  ),
                  child: const Text(
                    'حفظ المصروف',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showEditExpenseDialog(
    BuildContext context,
    Expense expense,
    String currencyName,
  ) {
    final formKey = GlobalKey<FormState>();
    final amountController = TextEditingController(
      text: expense.amount.toString(),
    );
    final noteController = TextEditingController(text: expense.note ?? '');
    DateTime selectedDate = DateTime.tryParse(expense.date) ?? DateTime.now();
    String? selectedExpenseType = expense.type;
    String? selectedPaymentType = expense.paymentType;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.edit, color: Colors.blue),
                  SizedBox(width: 8),
                  Text('تعديل المصروف'),
                ],
              ),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<String>(
                        value: selectedExpenseType,
                        decoration: const InputDecoration(
                          labelText: 'نوع المصروف',
                          border: OutlineInputBorder(),
                        ),
                        items:
                            _expenseTypes
                                .map(
                                  (type) => DropdownMenuItem(
                                    value: type,
                                    child: Text(type),
                                  ),
                                )
                                .toList(),
                        onChanged: (value) {
                          setState(() {
                            selectedExpenseType = value;
                          });
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'الرجاء اختيار نوع المصروف';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 16),

                      TextFormField(
                        controller: amountController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'المبلغ ($currencyName)',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.attach_money),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'الرجاء إدخال المبلغ';
                          }
                          if (double.tryParse(value) == null) {
                            return 'الرجاء إدخال رقم صحيح';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 16),

                      DropdownButtonFormField<String>(
                        value: selectedPaymentType,
                        decoration: const InputDecoration(
                          labelText: 'طريقة الدفع',
                          border: OutlineInputBorder(),
                        ),
                        items:
                            _paymentTypes
                                .map(
                                  (type) => DropdownMenuItem(
                                    value: type,
                                    child: Text(type),
                                  ),
                                )
                                .toList(),
                        onChanged: (value) {
                          setState(() {
                            selectedPaymentType = value;
                          });
                        },
                      ),

                      const SizedBox(height: 16),

                      InkWell(
                        onTap: () async {
                          final pickedDate = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (pickedDate != null) {
                            setState(() {
                              selectedDate = pickedDate;
                            });
                          }
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'التاريخ',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.calendar_today),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                DateFormat('yyyy-MM-dd').format(selectedDate),
                              ),
                              const Icon(Icons.arrow_drop_down),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      TextFormField(
                        controller: noteController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'ملاحظات (اختياري)',
                          border: OutlineInputBorder(),
                          alignLabelWithHint: true,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('إلغاء'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (formKey.currentState!.validate()) {
                      final updatedExpense = Expense(
                        id: expense.id,
                        type: selectedExpenseType!,
                        amount: double.parse(amountController.text),
                        date: selectedDate.toIso8601String(),
                        paymentType: selectedPaymentType,
                        note:
                            noteController.text.isNotEmpty
                                ? noteController.text
                                : null,
                        createdAt: expense.createdAt,
                      );
                      await context.read<ExpenseProvider>().updateExpense(
                        updatedExpense,
                      );
                      await _loadOverallStatistics();
                      Navigator.pop(context);

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('تم تعديل المصروف بنجاح'),
                          backgroundColor: Colors.green.shade600,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade600,
                  ),
                  child: const Text('حفظ التعديلات'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showDeleteDialog(
    BuildContext context,
    Expense expense,
    ExpenseProvider provider,
    String currencyName,
  ) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('حذف المصروف'),
          content: Text(
            'هل أنت متأكد من حذف مصروف "${expense.type}" بقيمة ${expense.amount.toStringAsFixed(1)} $currencyName؟',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () async {
                await provider.deleteExpense(expense.id!);
                await _loadOverallStatistics();
                Navigator.pop(context);

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('تم حذف المصروف بنجاح'),
                    backgroundColor: Colors.red.shade600,
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('حذف'),
            ),
          ],
        );
      },
    );
  }

  void _showFilterDialog(BuildContext context) {
    final provider = context.read<ExpenseProvider>();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('فلترة المصاريف'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // فلترة حسب النوع
                    DropdownButtonFormField<String>(
                      value: null,
                      decoration: const InputDecoration(
                        labelText: 'نوع المصروف',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('كل الأنواع'),
                        ),
                        ..._expenseTypes.map(
                          (type) =>
                              DropdownMenuItem(value: type, child: Text(type)),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          provider.filterByType(value);
                          _resetAllFilters(provider);
                          Navigator.pop(context);
                        }
                      },
                    ),

                    const SizedBox(height: 16),

                    // فلترة حسب طريقة الدفع
                    DropdownButtonFormField<String>(
                      value: null,
                      decoration: const InputDecoration(
                        labelText: 'طريقة الدفع',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('كل الطرق'),
                        ),
                        ..._paymentTypes.map(
                          (type) =>
                              DropdownMenuItem(value: type, child: Text(type)),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          _selectedPaymentType = value;
                          _activeTimeFilter = null;
                          _isAllSelected = false;
                          provider.filterByPaymentType(value);
                          Navigator.pop(context);
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    _resetAllFilters(provider);
                    Navigator.pop(context);
                  },
                  child: const Text('إعادة تعيين'),
                ),

                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('إلغاء'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ==================== دوال مساعدة ====================
  DateTime _parseDate(String dateString) {
    try {
      return DateTime.parse(dateString);
    } catch (e) {
      return DateTime.now();
    }
  }

  Color _getExpenseColor(String type) {
    switch (type) {
      case 'كهرباء':
        return Colors.blue.shade600;
      case 'ماء':
        return Colors.cyan.shade600;
      case 'صيانة':
        return Colors.orange.shade600;
      case 'إيجار':
        return Colors.purple.shade600;
      case 'رواتب':
        return Colors.green.shade600;
      case 'إنترنت':
        return Colors.indigo.shade600;
      case 'هاتف':
        return Colors.teal.shade600;
      case 'مواد مكتبية':
        return Colors.brown.shade600;
      case 'نقل':
        return Colors.deepOrange.shade600;
      default:
        return Colors.red.shade600;
    }
  }

  IconData _getExpenseIcon(String type) {
    switch (type) {
      case 'كهرباء':
        return Icons.bolt;
      case 'ماء':
        return Icons.water_drop;
      case 'صيانة':
        return Icons.build;
      case 'إيجار':
        return Icons.home;
      case 'رواتب':
        return Icons.people;
      case 'إنترنت':
        return Icons.wifi;
      case 'هاتف':
        return Icons.phone;
      case 'مواد مكتبية':
        return Icons.description;
      case 'نقل':
        return Icons.directions_car;
      default:
        return Icons.receipt;
    }
  }
}
