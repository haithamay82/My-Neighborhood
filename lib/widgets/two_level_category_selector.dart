import 'package:flutter/material.dart';
import '../models/request.dart';
import '../l10n/app_localizations.dart';
import '../services/categories_service.dart';

class TwoLevelCategorySelector extends StatefulWidget {
  final List<RequestCategory>? selectedCategories;
  final int maxSelections;
  final Function(List<RequestCategory>) onSelectionChanged;
  final Function(Map<RequestCategory, String>)? onCustomCategoryNamesChanged; // callback לעדכון שמות קטגוריות מותאמות
  final String title;
  final String instruction;

  const TwoLevelCategorySelector({
    super.key,
    this.selectedCategories,
    this.maxSelections = 2,
    required this.onSelectionChanged,
    this.onCustomCategoryNamesChanged,
    required this.title,
    required this.instruction,
  });

  @override
  State<TwoLevelCategorySelector> createState() => _TwoLevelCategorySelectorState();
}

class _TwoLevelCategorySelectorState extends State<TwoLevelCategorySelector> {
  List<RequestCategory> _selectedCategories = [];
  List<Map<String, dynamic>> _mainCategoriesFromFirestore = [];
  List<Map<String, dynamic>> _subCategoriesFromFirestore = [];
  bool _isLoadingCategories = true;
  // Map לשמירת שמות קטגוריות חדשות (שאינן ב-enum) - key הוא enum fallback, value הוא שם הקטגוריה המקורי
  Map<RequestCategory, String> _customCategoryNames = {};

  @override
  void initState() {
    super.initState();
    _selectedCategories = List.from(widget.selectedCategories ?? []);
    _loadCategoriesFromFirestore();
  }

  Future<void> _loadCategoriesFromFirestore() async {
    try {
      final mainCategories = await CategoriesService.getMainCategories();
      final subCategories = await CategoriesService.getSubCategories();
      
      debugPrint('📥 [TwoLevelCategorySelector] Loaded ${mainCategories.length} main categories');
      debugPrint('📥 [TwoLevelCategorySelector] Loaded ${subCategories.length} sub categories');
      debugPrint('📋 [TwoLevelCategorySelector] Main categories: ${mainCategories.map((c) => '${c['nameHebrew']} (${c['id']})').toList()}');
      debugPrint('📋 [TwoLevelCategorySelector] Sub categories: ${subCategories.map((c) => '${c['name']} (${c['nameHebrew']}) -> ${c['mainCategoryId']}').toList()}');
      
      setState(() {
        _mainCategoriesFromFirestore = mainCategories;
        _subCategoriesFromFirestore = subCategories;
        _isLoadingCategories = false;
      });
    } catch (e) {
      debugPrint('❌ [TwoLevelCategorySelector] Error loading categories from Firestore: $e');
      setState(() {
        _isLoadingCategories = false;
      });
    }
  }
  
  @override
  void didUpdateWidget(TwoLevelCategorySelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    // עדכון הרשימה הפנימית אם הרשימה החיצונית השתנתה
    if (widget.selectedCategories != oldWidget.selectedCategories) {
      _selectedCategories = List.from(widget.selectedCategories ?? []);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
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
                widget.maxSelections >= 999
                    ? 'בחר תחומי משנה:'
                    : l10n.selectSubCategoriesUpTo(widget.maxSelections),
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
              label: Text(l10n.clearSelection),
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        
        // רשימת כל התחומים הראשיים עם תחומי המשנה שלהם
        SizedBox(
          height: 400,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(8),
            ),
            child: _isLoadingCategories
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: _mainCategoriesFromFirestore.isNotEmpty 
                        ? _mainCategoriesFromFirestore.length 
                        : MainCategory.values.length,
                    itemBuilder: (context, mainIndex) {
                      // אם יש קטגוריות מ-Firestore, נשתמש בהן, אחרת נשתמש ב-enum
                      if (_mainCategoriesFromFirestore.isNotEmpty) {
                        final mainCategoryData = _mainCategoriesFromFirestore[mainIndex];
                        final mainCategoryId = mainCategoryData['id'] as String;
                        final mainCategoryNameHebrew = mainCategoryData['nameHebrew'] as String? ?? '';
                        final subCategories = _getSubCategoriesForMainCategoryFromFirestore(mainCategoryId);
                        
                        debugPrint('🔍 [TwoLevelCategorySelector] Main category: $mainCategoryNameHebrew (ID: $mainCategoryId), Sub categories: ${subCategories.length}');
                        debugPrint('📋 [TwoLevelCategorySelector] Sub categories for "$mainCategoryNameHebrew": ${subCategories.map((c) => '${c['name']} (${c['nameHebrew']})').toList()}');
                        
                        return ExpansionTile(
                          title: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  mainCategoryData['nameHebrew'] ?? '',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                              Text(
                                mainCategoryData['icon'] ?? '',
                                style: const TextStyle(fontSize: 20),
                              ),
                            ],
                          ),
                          children: subCategories.map((subCategoryData) {
                            final categoryName = subCategoryData['name'] as String;
                            final category = CategoriesService.categoryNameToEnum(categoryName);
                            
                            // אם הקטגוריה לא קיימת ב-enum, נשתמש ב-enum fallback (plumbing)
                            // אבל נשמור את שם הקטגוריה המקורי כדי שנוכל לשמור אותו ב-Firestore
                            final categoryToUse = category ?? RequestCategory.plumbing;
                            final isNewCategory = category == null;
                            
                            // אם זו קטגוריה חדשה, נשמור את השם המקורי ב-map
                            if (isNewCategory) {
                              _customCategoryNames[categoryToUse] = categoryName;
                            }
                            
                            // בדוק אם הקטגוריה נבחרה
                            // עבור קטגוריות חדשות, נבדוק לפי השם המקורי
                            final isSelected = isNewCategory 
                                ? _selectedCategories.any((c) => _customCategoryNames[c] == categoryName)
                                : _selectedCategories.contains(categoryToUse);
                            final canSelect = _selectedCategories.length < widget.maxSelections || isSelected;
                            
                            return CheckboxListTile(
                              title: Text(subCategoryData['nameHebrew'] ?? categoryName),
                              value: isSelected,
                              enabled: canSelect,
                              onChanged: (bool? value) {
                                setState(() {
                                  if (value == true && _selectedCategories.length < widget.maxSelections) {
                                    // הוסף את הקטגוריה (עם fallback אם צריך)
                                    if (!_selectedCategories.contains(categoryToUse)) {
                                      _selectedCategories.add(categoryToUse);
                                      if (isNewCategory) {
                                        _customCategoryNames[categoryToUse] = categoryName;
                                      }
                                    }
                                  } else if (value == false) {
                                    // הסר את הקטגוריה
                                    _selectedCategories.remove(categoryToUse);
                                    if (isNewCategory) {
                                      _customCategoryNames.remove(categoryToUse);
                                    }
                                  }
                                });
                                widget.onSelectionChanged(_selectedCategories);
                                // עדכן את ה-callback עם שמות הקטגוריות המותאמות
                                if (widget.onCustomCategoryNamesChanged != null) {
                                  widget.onCustomCategoryNamesChanged!(_customCategoryNames);
                                }
                              },
                            );
                          }).toList(),
                        );
                      } else {
                        // Fallback ל-enum אם אין קטגוריות מ-Firestore
                        final mainCategory = MainCategory.values[mainIndex];
                        final subCategories = _getSubCategoriesForMainCategory(mainCategory);
                        
                        return ExpansionTile(
                          title: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  mainCategory.displayName,
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                              Text(
                                mainCategory.icon,
                                style: const TextStyle(fontSize: 20),
                              ),
                            ],
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
                      }
                    },
                  ),
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

  List<Map<String, dynamic>> _getSubCategoriesForMainCategoryFromFirestore(String mainCategoryId) {
    final filtered = _subCategoriesFromFirestore.where((subCategory) {
      return subCategory['mainCategoryId'] == mainCategoryId;
    }).toList();
    debugPrint('🔍 [TwoLevelCategorySelector] Filtered sub categories for mainCategoryId $mainCategoryId: ${filtered.length} found');
    debugPrint('📋 [TwoLevelCategorySelector] Sub categories: ${filtered.map((c) => '${c['name']} (${c['nameHebrew']})').toList()}');
    return filtered;
  }
}

