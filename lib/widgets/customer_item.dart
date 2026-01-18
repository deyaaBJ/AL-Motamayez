import 'package:flutter/material.dart';
import 'package:motamayez/models/customer.dart';

class CustomerItem extends StatelessWidget {
  final Customer customer;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const CustomerItem({
    super.key,
    required this.customer,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // الصورة/الأيقونة
            _buildAvatar(),

            const SizedBox(width: 16),

            // معلومات العميل
            Expanded(child: _buildCustomerInfo()),

            // أزرار الإجراءات
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: const Color(0xFFE1D4F7),
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.person, color: Color(0xFF6A3093), size: 24),
    );
  }

  Widget _buildCustomerInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // الاسم
        Text(
          customer.name,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF6A3093),
          ),
        ),

        const SizedBox(height: 4),

        // رقم الهاتف
        Text(
          customer.phone!,
          style: const TextStyle(fontSize: 14, color: Colors.grey),
        ),

        const SizedBox(height: 4),

        // تاريخ الإضافة
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        // زر التعديل
        IconButton(
          icon: const Icon(Icons.edit, color: Color(0xFF8B5FBF)),
          onPressed: onEdit,
          tooltip: 'تعديل',
        ),

        // زر الحذف
        IconButton(
          icon: const Icon(Icons.delete, color: Colors.red),
          onPressed: onDelete,
          tooltip: 'حذف',
        ),
      ],
    );
  }
}
