import 'package:flutter/material.dart';
import '../models/request.dart';

class TwoLevelCategorySelector extends StatefulWidget {
  final List<RequestCategory>? selectedCategories;
  final int maxSelections;
  final Function(List<RequestCategory>) onSelectionChanged;
  final String title;
  final String instruction;

  const TwoLevelCategorySelector({
    Key? key,
    this.selectedCategories,
    this.maxSelections = 2,
    required this.onSelectionChanged,
    required this.title,
    required this.instruction,
  }) : super(key: key);

  @override
  State<TwoLevelCategorySelector> createState() => _TwoLevelCategorySelectorState();
}

class _TwoLevelCategorySelectorState extends State<TwoLevelCategorySelector> {
  List<RequestCategory> _selectedCategories = [];

  @override
  void initState() {
    super.initState();
    _selectedCategories = widget.selectedCategories ?? [];
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.instruction,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        
        
        // בחירת תחומי משנה מכל התחומים הראשיים
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'בחר תחומי משנה (עד ${widget.maxSelections} מכל התחומים):',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _selectedCategories.clear();
                });
                widget.onSelectionChanged(_selectedCategories);
              },
              icon: const Icon(Icons.clear, size: 16),
              label: const Text('נקה בחירה'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        
        // רשימת כל התחומים הראשיים עם תחומי המשנה שלהם
        Container(
          height: 300, // גובה גדול יותר לכל התחומים
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(8),
          ),
          child: ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: MainCategory.values.length,
            itemBuilder: (context, mainIndex) {
              final mainCategory = MainCategory.values[mainIndex];
              final subCategories = _getSubCategoriesForMainCategory(mainCategory);
              
              return ExpansionTile(
                title: Text(
                  mainCategory.displayName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                children: subCategories.map((category) {
                  final isSelected = _selectedCategories.contains(category);
                  final canSelect = _selectedCategories.length < widget.maxSelections || isSelected;
                  
                  return CheckboxListTile(
                    title: Text(category.categoryDisplayName),
                    value: isSelected,
                    enabled: canSelect,
                    onChanged: (bool? value) {
                      setState(() {
                        if (value == true && _selectedCategories.length < widget.maxSelections) {
                          _selectedCategories.add(category);
                        } else if (value == false) {
                          _selectedCategories.remove(category);
                        }
                      });
                      widget.onSelectionChanged(_selectedCategories);
                    },
                  );
                }).toList(),
              );
            },
          ),
        ),
      ],
    );
  }

  List<RequestCategory> _getSubCategoriesForMainCategory(MainCategory? mainCategory) {
    if (mainCategory == null) return [];
    
    return RequestCategory.values.where((category) {
      return category.mainCategory == mainCategory;
    }).toList();
  }
}

