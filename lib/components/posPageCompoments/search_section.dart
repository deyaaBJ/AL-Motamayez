import 'package:flutter/material.dart';

class SearchSection extends StatelessWidget {
  final TextEditingController searchController;
  final FocusNode searchFocusNode;

  final String searchType;
  final bool isSearching;

  final Function(String) performSearch;
  final Function(String) onEnterPressed;
  final VoidCallback clearSearch;

  final bool showSearchResults;
  final VoidCallback refreshState; // setState()
  final Function(String) onChangeSearchType;

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
  });

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
                        searchType == 'unit' ? Icons.inventory_2 : Icons.search,
                        color: const Color(0xFF8B5FBF),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: searchController,
                          focusNode: searchFocusNode,
                          decoration: InputDecoration(
                            hintText:
                                searchType == 'unit'
                                    ? 'أدخل باركود الوحدة...'
                                    : 'ابحث باسم المنتج أو الباركود...',
                            border: InputBorder.none,
                            hintStyle: const TextStyle(fontSize: 14),
                          ),
                          style: const TextStyle(fontSize: 14),
                          onChanged: (value) {
                            if (value.length >= 1) {
                              performSearch(value);
                            } else {
                              refreshState();
                            }
                          },
                          onSubmitted: (value) {
                            if (value.isNotEmpty) {
                              onEnterPressed(value);
                            }
                          },
                        ),
                      ),
                      if (searchController.text.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: clearSearch,
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
                      isSearching
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
                    if (searchController.text.isNotEmpty) {
                      performSearch(searchController.text);
                    }
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // _buildSearchTypeButtons(),
        ],
      ),
    );
  }
}
