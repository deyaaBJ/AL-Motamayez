import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:motamayez/models/customer.dart';
import 'package:motamayez/providers/customer_provider.dart';
import 'package:motamayez/widgets/customer_form_dialog.dart';
import 'package:motamayez/helpers/helpers.dart';

Future<Customer?> showCustomerSelectionDialog(BuildContext context) async {
  final customerProvider = context.read<CustomerProvider>();
  await customerProvider.fetchCustomers(reset: true);
  if (!context.mounted) return null;

  return showDialog<Customer>(
    context: context,
    builder: (ctx) => const _CustomerSelectionDialogContent(),
  );
}

class _CustomerSelectionDialogContent extends StatefulWidget {
  const _CustomerSelectionDialogContent();

  @override
  State<_CustomerSelectionDialogContent> createState() =>
      _CustomerSelectionDialogContentState();
}

class _CustomerSelectionDialogContentState
    extends State<_CustomerSelectionDialogContent> {
  bool isLoadingMore = false;

  @override
  Widget build(BuildContext context) {
    return Consumer<CustomerProvider>(
      builder: (context, customerProvider, child) {
        final customers = customerProvider.displayedCustomers;
        final isLoading = customerProvider.isLoading;
        final hasMore = customerProvider.hasMore;

        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Color(0xFFF8F5FF),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.people, color: Color(0xFF6A3093)),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'اختر زبون',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF6A3093),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: NotificationListener<ScrollNotification>(
                    onNotification: (notification) {
                      if (notification is ScrollUpdateNotification &&
                          notification.metrics.pixels >=
                              notification.metrics.maxScrollExtent * 0.9 &&
                          hasMore &&
                          !isLoading &&
                          !isLoadingMore) {
                        isLoadingMore = true;
                        customerProvider.loadMoreCustomers().then((_) {
                          Future.delayed(const Duration(milliseconds: 300), () {
                            if (mounted) isLoadingMore = false;
                          });
                        });
                      }
                      return false;
                    },
                    child:
                        customers.isEmpty && !isLoading
                            ? const Center(
                              child: Text(
                                'لا توجد عملاء',
                                style: TextStyle(color: Colors.grey),
                              ),
                            )
                            : ListView.builder(
                              itemCount:
                                  customers.length +
                                  (hasMore && customers.isNotEmpty ? 1 : 0),
                              itemBuilder: (ctx, idx) {
                                if (idx == customers.length) {
                                  if (hasMore && !isLoadingMore) {
                                    return const Padding(
                                      padding: EdgeInsets.all(16),
                                      child: Center(
                                        child: CircularProgressIndicator(),
                                      ),
                                    );
                                  }
                                  return const SizedBox.shrink();
                                }
                                final customer = customers[idx];
                                return ListTile(
                                  leading: const Icon(
                                    Icons.person,
                                    color: Color(0xFF8B5FBF),
                                  ),
                                  title: Text(customer.name),
                                  subtitle: Text(customer.phone ?? 'بدون رقم'),
                                  onTap: () => Navigator.pop(context, customer),
                                );
                              },
                            ),
                  ),
                ),
                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF6A3093),
                          side: const BorderSide(color: Color(0xFF6A3093)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('إلغاء'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _showAddCustomerDialog(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6A3093),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('إضافة زبون جديد'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAddCustomerDialog(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (ctx) => CustomerFormDialog(
            onSave: (customer) async {
              try {
                await context.read<CustomerProvider>().addCustomer(customer);
                if (ctx.mounted) Navigator.pop(ctx);
              } catch (e) {
                if (ctx.mounted) {
                  showAppToast(ctx, 'خطأ في إضافة الزبون: $e', ToastType.error);
                }
              }
            },
          ),
    );
  }
}
