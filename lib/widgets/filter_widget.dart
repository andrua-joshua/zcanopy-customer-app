import 'package:flutter/material.dart';

class FilterWidget extends StatefulWidget {
  final List<String> categories;
  final Function(String) onCategorySelected;
  final String selectedCategory;

  const FilterWidget({
    Key? key,
    required this.categories,
    required this.onCategorySelected,
    required this.selectedCategory,
  }) : super(key: key);

  @override
  _FilterWidgetState createState() => _FilterWidgetState();
}

class _FilterWidgetState extends State<FilterWidget> {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: widget.categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          String category = widget.categories[index];
          bool isSelected = widget.selectedCategory == category;

          return GestureDetector(
            onTap: () {
              widget.onCategorySelected(category);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? Color.fromARGB(255, 169, 97, 14)
                    : Colors.grey[200],
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                category,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
