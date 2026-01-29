// lib/widgets/batch_filter_bar.dart
import 'package:flutter/material.dart';
import 'package:motamayez/models/batch_filter.dart';

class BatchFilterBar extends StatefulWidget {
  final BatchFilter currentFilter;
  final Function(BatchFilter) onFilterChanged;

  const BatchFilterBar({
    super.key,
    required this.currentFilter,
    required this.onFilterChanged,
  });

  @override
  State<BatchFilterBar> createState() => _BatchFilterBarState();
}

class _BatchFilterBarState extends State<BatchFilterBar> {
  late BatchFilter _currentFilter;
  final List<String> _statusOptions = ['الكل', 'جيد', 'قريب', 'منتهي'];
  bool _showFilters = false;

  @override
  void initState() {
    super.initState();
    _currentFilter = widget.currentFilter;
  }

  @override
  void didUpdateWidget(covariant BatchFilterBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentFilter != oldWidget.currentFilter) {
      _currentFilter = widget.currentFilter;
    }
  }

  void _applyFilters() {
    widget.onFilterChanged(_currentFilter);
  }

  void _resetFilters() {
    setState(() {
      _currentFilter = BatchFilter();
    });
    widget.onFilterChanged(_currentFilter);
  }

  Widget _buildStatusFilter() {
    return Container(
      width: 120,
      child: DropdownButtonFormField<String?>(
        value: _currentFilter.status,
        decoration: InputDecoration(
          labelText: 'الحالة',
          border: OutlineInputBorder(),
          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          isDense: true,
        ),
        items:
            _statusOptions.map((status) {
              return DropdownMenuItem(
                value: status == 'الكل' ? null : status,
                child: Text(status, style: TextStyle(fontSize: 13)),
              );
            }).toList(),
        onChanged: (value) {
          setState(() {
            _currentFilter = _currentFilter.copyWith(status: value);
          });
          _applyFilters();
        },
      ),
    );
  }

  Widget _buildExpiryFilter() {
    return Container(
      width: 160,
      child: DropdownButtonFormField<String?>(
        value: _currentFilter.expiryFilter,
        decoration: InputDecoration(
          labelText: 'تاريخ الانتهاء',
          border: OutlineInputBorder(),
          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          isDense: true,
        ),
        items: [
          DropdownMenuItem(
            value: null,
            child: Text('الكل', style: TextStyle(fontSize: 13)),
          ),
          DropdownMenuItem(
            value: 'أسبوع',
            child: Text('ينتهي خلال أسبوع', style: TextStyle(fontSize: 13)),
          ),
          DropdownMenuItem(
            value: 'شهر',
            child: Text('ينتهي خلال شهر', style: TextStyle(fontSize: 13)),
          ),
          DropdownMenuItem(
            value: 'منتهي',
            child: Text('منتهي', style: TextStyle(fontSize: 13)),
          ),
          DropdownMenuItem(
            value: 'مستقبل',
            child: Text('لم ينته بعد', style: TextStyle(fontSize: 13)),
          ),
        ],
        onChanged: (value) {
          setState(() {
            _currentFilter = _currentFilter.copyWith(expiryFilter: value);
          });
          _applyFilters();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.filter_list, color: Color(0xFF6A3093), size: 20),
                    SizedBox(width: 6),
                    Text(
                      'فلاتر البحث',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF6A3093),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: _resetFilters,
                      icon: Icon(Icons.refresh, size: 16),
                      label: Text(
                        'إعادة تعيين',
                        style: TextStyle(fontSize: 12),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey.shade200,
                        foregroundColor: Colors.black,
                        padding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        minimumSize: Size(0, 30),
                      ),
                    ),
                    SizedBox(width: 8),
                    IconButton(
                      icon: Icon(
                        _showFilters ? Icons.expand_less : Icons.expand_more,
                        size: 20,
                      ),
                      onPressed: () {
                        setState(() {
                          _showFilters = !_showFilters;
                        });
                      },
                    ),
                  ],
                ),
              ],
            ),

            if (_showFilters) SizedBox(height: 12),

            if (_showFilters)
              Row(
                children: [
                  _buildStatusFilter(),
                  SizedBox(width: 12),
                  _buildExpiryFilter(),
                ],
              ),

            if (_currentFilter.hasActiveFilters)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Container(
                  padding: EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Color(0xFF6A3093).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'الفلاتر النشطة: ${_currentFilter.getActiveFiltersCount()}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6A3093),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.clear, size: 16),
                        onPressed: _resetFilters,
                        color: Color(0xFF6A3093),
                        padding: EdgeInsets.zero,
                        constraints: BoxConstraints(),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
