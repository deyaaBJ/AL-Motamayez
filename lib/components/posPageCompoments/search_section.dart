import 'package:flutter/material.dart';
import 'dart:async';

class SearchSection extends StatefulWidget {
  final TextEditingController searchController;
  final FocusNode searchFocusNode;

  final String searchType;
  final bool isSearching;

  final Function(String) performSearch;
  final Function(String)
  onEnterPressed; // هذه الدالة مسؤولة عن اختيار المنتج عند الضغط على Enter
  final VoidCallback clearSearch;

  final bool showSearchResults;
  final VoidCallback refreshState; // setState()
  final Function(String) onChangeSearchType;
  final VoidCallback addService;

  const SearchSection({
    super.key,
    required this.searchController,
    required this.searchFocusNode,
    required this.searchType,
    required this.isSearching,
    required this.performSearch,
    required this.onEnterPressed,
    required this.clearSearch,
    required this.showSearchResults,
    required this.refreshState,
    required this.onChangeSearchType,
    required this.addService,
  });

  @override
  State<SearchSection> createState() => _SearchSectionState();
}

class _SearchSectionState extends State<SearchSection> {
  Timer? _searchDebounce;

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      color: Colors.white,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 50,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F5FF),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE1D4F7)),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 12),
                      Icon(
                        widget.searchType == 'unit'
                            ? Icons.inventory_2
                            : Icons.search,
                        color: const Color(0xFF8B5FBF),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: widget.searchController,
                          focusNode: widget.searchFocusNode,
                          decoration: InputDecoration(
                            hintText:
                                widget.searchType == 'unit'
                                    ? 'أدخل باركود الوحدة...'
                                    : 'ابحث باسم المنتج أو الباركود...',
                            border: InputBorder.none,
                            hintStyle: const TextStyle(fontSize: 14),
                          ),
                          style: const TextStyle(fontSize: 14),
                          onChanged: (value) {
                            // مسح البحث السابق والبحث الجديد بـ debounce
                            _searchDebounce?.cancel();
                            if (value.isEmpty) {
                              widget.refreshState();
                            } else {
                              _searchDebounce = Timer(
                                const Duration(milliseconds: 500),
                                () {
                                  widget.performSearch(value.trim());
                                },
                              );
                            }
                          },
                          onSubmitted: (value) {
                            // ✅ عند الضغط على Enter، نختار المنتج مباشرة
                            _searchDebounce?.cancel();
                            if (value.isNotEmpty) {
                              widget.onEnterPressed(value);
                            }
                          },
                        ),
                      ),
                      if (widget.searchController.text.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: widget.clearSearch,
                        ),
                      const SizedBox(width: 8),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5FBF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  icon:
                      widget.isSearching
                          ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                          : const Icon(
                            Icons.search,
                            color: Colors.white,
                            size: 20,
                          ),
                  onPressed: () {
                    if (widget.searchController.text.isNotEmpty) {
                      _searchDebounce?.cancel();
                      widget.performSearch(widget.searchController.text);
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: const Color(0xFF2196F3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: IconButton(
                  icon: const Icon(Icons.design_services, color: Colors.white),
                  onPressed: widget.addService,
                  tooltip: 'إضافة خدمة',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
