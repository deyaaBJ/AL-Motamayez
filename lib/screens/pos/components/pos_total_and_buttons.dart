import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:motamayez/providers/settings_provider.dart';

class PosTotalAndButtons extends StatelessWidget {
  final double totalAmount;
  final double finalAmount;
  final bool isTotalModified;
  final VoidCallback onEditTotal;
  final bool isEditMode;
  final VoidCallback onEditSave;
  final VoidCallback onSaleAndPrint;
  final VoidCallback onCompleteSale;
  final VoidCallback onDeferredSale;
  final VoidCallback onClearCart;
  final bool cartIsEmpty;

  const PosTotalAndButtons({
    super.key,
    required this.totalAmount,
    required this.finalAmount,
    required this.isTotalModified,
    required this.onEditTotal,
    required this.isEditMode,
    required this.onEditSave,
    required this.onSaleAndPrint,
    required this.onCompleteSale,
    required this.onDeferredSale,
    required this.onClearCart,
    required this.cartIsEmpty,
  });

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            // ignore: deprecated_member_use
            color: Colors.grey.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: onEditTotal,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
              decoration: BoxDecoration(
                color:
                    isTotalModified
                        ? const Color(0xFFFFF8E1)
                        : const Color(0xFFF8F5FF),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color:
                      isTotalModified ? Colors.orange : const Color(0xFFE1D4F7),
                ),
              ),
              child: Column(
                children: [
                  if (isTotalModified) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('مجموع العناصر:'),
                        Text(
                          '${settings.currencyName} ${totalAmount.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isTotalModified ? 'المجموع النهائي:' : 'المجموع الكلي:',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Row(
                        children: [
                          Text(
                            '${settings.currencyName} ${finalAmount.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color:
                                  isTotalModified
                                      ? Colors.orange[800]
                                      : const Color(0xFF8B5FBF),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.edit,
                            size: 18,
                            color: Color(0xFF6A3093),
                          ),
                        ],
                      ),
                    ],
                  ),
                  if (isTotalModified)
                    const Text(
                      '(معدل)',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.orange,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              if (isEditMode) ...[
                _buildButton(
                  'حفظ التعديلات',
                  Icons.save,
                  Colors.blue,
                  onEditSave,
                  cartIsEmpty,
                ),
                const SizedBox(width: 8),
              ],
              _buildButton(
                'البيع وطباعة الفاتورة',
                Icons.check_circle,
                const Color.fromARGB(255, 102, 76, 175),
                onSaleAndPrint,
                cartIsEmpty,
              ),
              if (!isEditMode) ...[
                const SizedBox(width: 8),
                _buildButton(
                  'إتمام البيع',
                  Icons.check_circle,
                  const Color(0xFF4CAF50),
                  onCompleteSale,
                  cartIsEmpty,
                ),
                const SizedBox(width: 8),
                _buildButton(
                  'بيع مؤجل',
                  Icons.schedule,
                  const Color(0xFFFF9800),
                  onDeferredSale,
                  cartIsEmpty,
                ),
              ],
              const SizedBox(width: 8),
              _buildButton(
                'حذف',
                Icons.delete_sweep,
                const Color(0xFFF44336),
                onClearCart,
                cartIsEmpty,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildButton(
    String text,
    IconData icon,
    Color color,
    VoidCallback onPressed,
    bool disabled,
  ) {
    return Expanded(
      child: SizedBox(
        height: 44,
        child: ElevatedButton(
          onPressed: disabled ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            elevation: 2,
            padding: const EdgeInsets.symmetric(horizontal: 4),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16),
              const SizedBox(width: 4),
              Text(
                text,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
