import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import '../models/request.dart';
import '../services/categories_service.dart';
import '../l10n/app_localizations.dart';

class AdminCategoriesManagementScreen extends StatefulWidget {
  const AdminCategoriesManagementScreen({super.key});

  @override
  State<AdminCategoriesManagementScreen> createState() => _AdminCategoriesManagementScreenState();
}

class _AdminCategoriesManagementScreenState extends State<AdminCategoriesManagementScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();
  
  List<Map<String, dynamic>> _mainCategories = [];
  List<Map<String, dynamic>> _subCategories = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedMainCategoryId = '';
  bool _showMainCategories = true;

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Load main categories
      final mainCategoriesSnapshot = await _firestore
          .collection('categories')
          .where('type', isEqualTo: 'main')
          .orderBy('order', descending: false)
          .get();

      _mainCategories = mainCategoriesSnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name': data['name'] ?? '',
          'nameHebrew': data['nameHebrew'] ?? '',
          'nameArabic': data['nameArabic'] ?? '',
          'nameEnglish': data['nameEnglish'] ?? '',
          'icon': data['icon'] ?? '',
          'order': data['order'] ?? 0,
        };
      }).toList();

      // Load sub categories
      final subCategoriesSnapshot = await _firestore
          .collection('categories')
          .where('type', isEqualTo: 'sub')
          .orderBy('mainCategoryId')
          .orderBy('order', descending: false)
          .get();

      _subCategories = subCategoriesSnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name': data['name'] ?? '',
          'nameHebrew': data['nameHebrew'] ?? '',
          'nameArabic': data['nameArabic'] ?? '',
          'nameEnglish': data['nameEnglish'] ?? '',
          'mainCategoryId': data['mainCategoryId'] ?? '',
          'order': data['order'] ?? 0,
        };
      }).toList();

      // If no categories exist, initialize with default enum values
      if (_mainCategories.isEmpty && _subCategories.isEmpty) {
        await _initializeDefaultCategories();
        await _loadCategories(); // Reload after initialization
      }
    } catch (e) {
      debugPrint('Error loading categories: $e');
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.errorLoadingCategories}: $e')),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _initializeDefaultCategories() async {
    try {
      // Initialize main categories from enum
      final mainCategoryMap = {
        MainCategory.constructionAndMaintenance: {
          'name': 'constructionAndMaintenance',
          'nameHebrew': 'בנייה, תיקונים ותחזוקה',
          'nameArabic': 'البناء والإصلاحات والصيانة',
          'nameEnglish': 'Construction, Repairs and Maintenance',
          'icon': '🏠',
          'order': 1,
        },
        MainCategory.deliveriesAndMoving: {
          'name': 'deliveriesAndMoving',
          'nameHebrew': 'שליחויות, הובלות ושירותים מהירים',
          'nameArabic': 'التوصيل والنقل والخدمات السريعة',
          'nameEnglish': 'Deliveries, Moving and Fast Services',
          'icon': '🚚',
          'order': 2,
        },
        MainCategory.beautyAndCosmetics: {
          'name': 'beautyAndCosmetics',
          'nameHebrew': 'יופי, טיפוח וקוסמטיקה',
          'nameArabic': 'الجمال والعناية ومستحضرات التجميل',
          'nameEnglish': 'Beauty, Grooming and Cosmetics',
          'icon': '🧖‍♀️',
          'order': 3,
        },
        MainCategory.marketingAndSales: {
          'name': 'marketingAndSales',
          'nameHebrew': 'שיווק ומכירות',
          'nameArabic': 'التسويق والمبيعات',
          'nameEnglish': 'Marketing and Sales',
          'icon': '🛒',
          'order': 4,
        },
        MainCategory.technologyAndComputers: {
          'name': 'technologyAndComputers',
          'nameHebrew': 'טכנולוגיה, מחשבים ואפליקציות',
          'nameArabic': 'التكنولوجيا وأجهزة الكمبيوتر والتطبيقات',
          'nameEnglish': 'Technology, Computers and Applications',
          'icon': '🛠️',
          'order': 5,
        },
        MainCategory.vehicles: {
          'name': 'vehicles',
          'nameHebrew': 'כלי תחבורה',
          'nameArabic': 'وسائل النقل',
          'nameEnglish': 'Vehicles',
          'icon': '🚗',
          'order': 6,
        },
        MainCategory.gardeningAndCleaning: {
          'name': 'gardeningAndCleaning',
          'nameHebrew': 'גינון, ניקיון וסביבה',
          'nameArabic': 'البستنة والتنظيف والبيئة',
          'nameEnglish': 'Gardening, Cleaning and Environment',
          'icon': '🌱',
          'order': 7,
        },
        MainCategory.educationAndTraining: {
          'name': 'educationAndTraining',
          'nameHebrew': 'חינוך, לימודים והדרכה',
          'nameArabic': 'التعليم والتدريب',
          'nameEnglish': 'Education and Training',
          'icon': '🎓',
          'order': 8,
        },
        MainCategory.professionalConsulting: {
          'name': 'professionalConsulting',
          'nameHebrew': 'ייעוץ והכוונה מקצועית',
          'nameArabic': 'الاستشارة والتوجيه المهني',
          'nameEnglish': 'Professional Consulting and Guidance',
          'icon': '🧭',
          'order': 9,
        },
        MainCategory.artsAndMedia: {
          'name': 'artsAndMedia',
          'nameHebrew': 'יצירה, אומנות ומדיה',
          'nameArabic': 'الإبداع والفن والإعلام',
          'nameEnglish': 'Creativity, Art and Media',
          'icon': '🎨',
          'order': 10,
        },
        MainCategory.specialServices: {
          'name': 'specialServices',
          'nameHebrew': 'שירותים מיוחדים ופתוחים',
          'nameArabic': 'خدمات خاصة ومفتوحة',
          'nameEnglish': 'Special and Open Services',
          'icon': '💡',
          'order': 11,
        },
      };

      // Create main categories in Firestore
      final batch = _firestore.batch();
      int mainOrder = 1;
      final Map<String, String> mainCategoryIdMap = {};

      for (final entry in mainCategoryMap.entries) {
        final mainCategory = entry.key;
        final data = entry.value;
        final mainCategoryRef = _firestore.collection('categories').doc();
        mainCategoryIdMap[mainCategory.name] = mainCategoryRef.id;
        
        batch.set(mainCategoryRef, {
          'type': 'main',
          'name': data['name'],
          'nameHebrew': data['nameHebrew'],
          'nameArabic': data['nameArabic'],
          'nameEnglish': data['nameEnglish'],
          'icon': data['icon'],
          'order': mainOrder++,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      // Initialize sub categories from enum
      int subOrder = 1;
      for (final category in RequestCategory.values) {
        final mainCategory = category.mainCategory;
        final mainCategoryId = mainCategoryIdMap[mainCategory.name];
        
        if (mainCategoryId != null) {
          final subCategoryRef = _firestore.collection('categories').doc();
          batch.set(subCategoryRef, {
            'type': 'sub',
            'name': category.name,
            'nameHebrew': category.categoryDisplayName,
            'nameArabic': category.categoryDisplayName, // TODO: Add Arabic translations
            'nameEnglish': category.name, // TODO: Add English translations
            'mainCategoryId': mainCategoryId,
            'order': subOrder++,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      }

      await batch.commit();
      debugPrint('✅ Default categories initialized successfully');
    } catch (e) {
      debugPrint('❌ Error initializing default categories: $e');
      rethrow;
    }
  }

  List<Map<String, dynamic>> get _filteredMainCategories {
    if (_searchQuery.isEmpty) {
      return _mainCategories;
    }
    return _mainCategories.where((category) {
      return category['nameHebrew'].toString().toLowerCase().contains(_searchQuery) ||
          category['nameArabic'].toString().toLowerCase().contains(_searchQuery) ||
          category['nameEnglish'].toString().toLowerCase().contains(_searchQuery) ||
          category['name'].toString().toLowerCase().contains(_searchQuery);
    }).toList();
  }

  List<Map<String, dynamic>> get _filteredSubCategories {
    final filtered = _subCategories.where((category) {
      if (_selectedMainCategoryId.isNotEmpty) {
        if (category['mainCategoryId'] != _selectedMainCategoryId) {
          return false;
        }
      }
      if (_searchQuery.isNotEmpty) {
        return category['nameHebrew'].toString().toLowerCase().contains(_searchQuery) ||
            category['nameArabic'].toString().toLowerCase().contains(_searchQuery) ||
            category['nameEnglish'].toString().toLowerCase().contains(_searchQuery) ||
            category['name'].toString().toLowerCase().contains(_searchQuery);
      }
      return true;
    }).toList();
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.categoriesManagementTitle),
        backgroundColor: const Color(0xFF03A9F4),
        foregroundColor: Colors.white,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadCategories,
            tooltip: l10n.refresh,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Search bar
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: l10n.searchCategories,
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                
                // Tabs for Main Categories and Sub Categories
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _showMainCategories = true;
                            _selectedMainCategoryId = '';
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _showMainCategories
                              ? const Color(0xFF03A9F4)
                              : Colors.grey[300],
                          foregroundColor: _showMainCategories
                              ? Colors.white
                              : Colors.black87,
                        ),
                        child: Text(l10n.mainCategories),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _showMainCategories = false;
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: !_showMainCategories
                              ? const Color(0xFF03A9F4)
                              : Colors.grey[300],
                          foregroundColor: !_showMainCategories
                              ? Colors.white
                              : Colors.black87,
                        ),
                        child: Text(l10n.subCategories),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 8),
                
                // Add button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => _showAddCategoryDialog(context),
                        icon: const Icon(Icons.add),
                        label: Text(_showMainCategories ? l10n.addMainCategory : l10n.addSubCategory),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 8),
                
                // Categories list
                Expanded(
                  child: _showMainCategories
                      ? _buildMainCategoriesList()
                      : _buildSubCategoriesList(),
                ),
              ],
            ),
    );
  }

  Widget _buildMainCategoriesList() {
    final filtered = _filteredMainCategories;
    
    if (filtered.isEmpty) {
      final l10n = AppLocalizations.of(context);
      return Center(
        child: Text(_searchQuery.isNotEmpty
            ? l10n.noResults
            : l10n.noMainCategories),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final category = filtered[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: Text(
              category['icon'] ?? '',
              style: const TextStyle(fontSize: 24),
            ),
            title: Text(category['nameHebrew'] ?? ''),
            subtitle: Text(
              '${category['nameArabic'] ?? ''} / ${category['nameEnglish'] ?? ''}',
              style: const TextStyle(fontSize: 12),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.blue),
                  onPressed: () => _showEditMainCategoryDialog(context, category),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _showDeleteMainCategoryConfirmation(context, category),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSubCategoriesList() {
    final l10n = AppLocalizations.of(context);
    // Filter selector for main category
    if (_selectedMainCategoryId.isEmpty && _mainCategories.isNotEmpty) {
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: DropdownButtonFormField<String>(
              decoration: InputDecoration(
                labelText: l10n.selectMainCategory,
                border: const OutlineInputBorder(),
              ),
              value: null,
              items: [
                DropdownMenuItem<String>(
                  value: '',
                  child: Text(l10n.allMainCategories),
                ),
                ..._mainCategories.map<DropdownMenuItem<String>>((mainCategory) {
                  return DropdownMenuItem<String>(
                    value: mainCategory['id'] as String,
                    child: Text(mainCategory['nameHebrew'] ?? ''),
                  );
                }),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedMainCategoryId = value ?? '';
                });
              },
            ),
          ),
          Expanded(
            child: Center(
              child: Text(l10n.selectMainCategoryToViewSub),
            ),
          ),
        ],
      );
    }

    final filtered = _filteredSubCategories;
    
    if (filtered.isEmpty) {
      final l10n = AppLocalizations.of(context);
      return Center(
        child: Text(_searchQuery.isNotEmpty
            ? l10n.noResults
            : l10n.noSubCategories),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final category = filtered[index];
        final l10n = AppLocalizations.of(context);
        final mainCategory = _mainCategories.firstWhere(
          (main) => main['id'] == category['mainCategoryId'],
          orElse: () => {'nameHebrew': l10n.unknown},
        );
        
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            title: Text(category['nameHebrew'] ?? ''),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${l10n.mainCategory}: ${mainCategory['nameHebrew'] ?? ''}',
                  style: const TextStyle(fontSize: 12),
                ),
                Text(
                  '${category['nameArabic'] ?? ''} / ${category['nameEnglish'] ?? ''}',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.blue),
                  onPressed: () => _showEditSubCategoryDialog(context, category),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _showDeleteSubCategoryConfirmation(context, category),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAddCategoryDialog(BuildContext context) {
    if (_showMainCategories) {
      _showAddMainCategoryDialog(context);
    } else {
      if (_mainCategories.isEmpty) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.mustCreateMainCategoryFirst)),
        );
        return;
      }
      _showAddSubCategoryDialog(context);
    }
  }

  void _showAddMainCategoryDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final nameController = TextEditingController();
    final nameHebrewController = TextEditingController();
    final nameArabicController = TextEditingController();
    final nameEnglishController = TextEditingController();
    final iconController = TextEditingController();
    final orderController = TextEditingController(
      text: (_mainCategories.length + 1).toString(),
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.addMainCategoryTitle),
        contentPadding: const EdgeInsets.fromLTRB(24.0, 20.0, 24.0, 24.0),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: l10n.categoryName,
                    hintText: 'constructionAndMaintenance',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameHebrewController,
                  decoration: InputDecoration(
                    labelText: l10n.categoryNameHebrew,
                    hintText: 'בנייה, תיקונים ותחזוקה',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameArabicController,
                  decoration: InputDecoration(
                    labelText: l10n.categoryNameArabic,
                    hintText: 'البناء والإصلاحات والصيانة',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameEnglishController,
                  decoration: InputDecoration(
                    labelText: l10n.categoryNameEnglish,
                    hintText: 'Construction, Repairs and Maintenance',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: iconController,
                  decoration: InputDecoration(
                    labelText: l10n.categoryIcon,
                    hintText: '🏠',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: orderController,
                  decoration: InputDecoration(
                    labelText: l10n.displayOrder,
                    hintText: '1',
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isEmpty ||
                  nameHebrewController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l10n.categoryNameRequired)),
                );
                return;
              }

              try {
                await _firestore.collection('categories').add({
                  'type': 'main',
                  'name': nameController.text.trim(),
                  'nameHebrew': nameHebrewController.text.trim(),
                  'nameArabic': nameArabicController.text.trim(),
                  'nameEnglish': nameEnglishController.text.trim(),
                  'icon': iconController.text.trim(),
                  'order': int.tryParse(orderController.text) ?? _mainCategories.length + 1,
                  'createdAt': FieldValue.serverTimestamp(),
                });

                if (mounted) {
                  Navigator.pop(context);
                  CategoriesService.clearCache(); // Clear cache after adding
                  _loadCategories();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.mainCategoryAdded)),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${l10n.errorAddingMainCategory}: $e')),
                  );
                }
              }
            },
            child: Text(l10n.addMainCategory),
          ),
        ],
      ),
    );
  }

  void _showAddSubCategoryDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final nameController = TextEditingController();
    final nameHebrewController = TextEditingController();
    final nameArabicController = TextEditingController();
    final nameEnglishController = TextEditingController();
    String? selectedMainCategoryId = _selectedMainCategoryId.isEmpty && _mainCategories.isNotEmpty
        ? _mainCategories.first['id']
        : _selectedMainCategoryId.isEmpty
            ? null
            : _selectedMainCategoryId;
    final orderController = TextEditingController(
      text: (_subCategories.length + 1).toString(),
    );

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(l10n.addSubCategoryTitle),
          contentPadding: const EdgeInsets.fromLTRB(24.0, 20.0, 24.0, 24.0),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    labelText: l10n.mainCategory,
                  ),
                  value: selectedMainCategoryId,
                  items: _mainCategories.map<DropdownMenuItem<String>>((mainCategory) {
                    return DropdownMenuItem<String>(
                      value: mainCategory['id'] as String,
                      child: Text(mainCategory['nameHebrew'] ?? ''),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setDialogState(() {
                      selectedMainCategoryId = value;
                    });
                  },
                ),
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: l10n.categoryName,
                    hintText: 'plumbing',
                  ),
                ),
                TextField(
                  controller: nameHebrewController,
                  decoration: InputDecoration(
                    labelText: l10n.categoryNameHebrew,
                    hintText: 'אינסטלציה',
                  ),
                ),
                TextField(
                  controller: nameArabicController,
                  decoration: InputDecoration(
                    labelText: l10n.categoryNameArabic,
                    hintText: 'السباكة',
                  ),
                ),
                TextField(
                  controller: nameEnglishController,
                  decoration: InputDecoration(
                    labelText: l10n.categoryNameEnglish,
                    hintText: 'Plumbing',
                  ),
                ),
                TextField(
                  controller: orderController,
                  decoration: InputDecoration(
                    labelText: l10n.displayOrder,
                    hintText: '1',
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.cancel),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.isEmpty ||
                    nameHebrewController.text.isEmpty ||
                    selectedMainCategoryId == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.allFieldsRequired)),
                  );
                  return;
                }

                try {
                  await _firestore.collection('categories').add({
                    'type': 'sub',
                    'name': nameController.text.trim(),
                    'nameHebrew': nameHebrewController.text.trim(),
                    'nameArabic': nameArabicController.text.trim(),
                    'nameEnglish': nameEnglishController.text.trim(),
                    'mainCategoryId': selectedMainCategoryId,
                    'order': int.tryParse(orderController.text) ?? _subCategories.length + 1,
                    'createdAt': FieldValue.serverTimestamp(),
                  });

                  if (mounted) {
                    Navigator.pop(context);
                    CategoriesService.clearCache(); // Clear cache after adding
                    _loadCategories();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l10n.subCategoryAdded)),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${l10n.errorAddingSubCategory}: $e')),
                    );
                  }
                }
              },
              child: Text(l10n.addSubCategory),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditMainCategoryDialog(BuildContext context, Map<String, dynamic> category) {
    final l10n = AppLocalizations.of(context);
    final nameController = TextEditingController(text: category['name']);
    final nameHebrewController = TextEditingController(text: category['nameHebrew']);
    final nameArabicController = TextEditingController(text: category['nameArabic'] ?? '');
    final nameEnglishController = TextEditingController(text: category['nameEnglish'] ?? '');
    final iconController = TextEditingController(text: category['icon'] ?? '');
    final orderController = TextEditingController(text: category['order'].toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.editMainCategory),
        contentPadding: const EdgeInsets.fromLTRB(24.0, 20.0, 24.0, 24.0),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: l10n.categoryName,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameHebrewController,
                  decoration: InputDecoration(
                    labelText: l10n.categoryNameHebrew,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameArabicController,
                  decoration: InputDecoration(
                    labelText: l10n.categoryNameArabic,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameEnglishController,
                  decoration: InputDecoration(
                    labelText: l10n.categoryNameEnglish,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: iconController,
                  decoration: InputDecoration(
                    labelText: l10n.categoryIcon,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: orderController,
                  decoration: InputDecoration(
                    labelText: l10n.displayOrder,
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isEmpty ||
                  nameHebrewController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l10n.categoryNameRequired)),
                );
                return;
              }

              try {
                await _firestore.collection('categories').doc(category['id']).update({
                  'name': nameController.text.trim(),
                  'nameHebrew': nameHebrewController.text.trim(),
                  'nameArabic': nameArabicController.text.trim(),
                  'nameEnglish': nameEnglishController.text.trim(),
                  'icon': iconController.text.trim(),
                  'order': int.tryParse(orderController.text) ?? category['order'],
                  'updatedAt': FieldValue.serverTimestamp(),
                });

                if (mounted) {
                  Navigator.pop(context);
                  CategoriesService.clearCache(); // Clear cache after updating
                  _loadCategories();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.mainCategoryUpdated)),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${l10n.errorUpdatingMainCategory}: $e')),
                  );
                }
              }
            },
            child: Text(l10n.save),
          ),
        ],
      ),
    );
  }

  void _showEditSubCategoryDialog(BuildContext context, Map<String, dynamic> category) {
    final l10n = AppLocalizations.of(context);
    final nameController = TextEditingController(text: category['name']);
    final nameHebrewController = TextEditingController(text: category['nameHebrew']);
    final nameArabicController = TextEditingController(text: category['nameArabic'] ?? '');
    final nameEnglishController = TextEditingController(text: category['nameEnglish'] ?? '');
    String? selectedMainCategoryId = category['mainCategoryId'];
    final orderController = TextEditingController(text: category['order'].toString());

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(l10n.editSubCategory),
          contentPadding: const EdgeInsets.fromLTRB(24.0, 20.0, 24.0, 24.0),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: l10n.mainCategory,
                    ),
                    value: selectedMainCategoryId,
                    items: _mainCategories.map<DropdownMenuItem<String>>((mainCategory) {
                      return DropdownMenuItem<String>(
                        value: mainCategory['id'] as String,
                        child: Text(mainCategory['nameHebrew'] ?? ''),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setDialogState(() {
                        selectedMainCategoryId = value;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: l10n.categoryName,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameHebrewController,
                    decoration: InputDecoration(
                      labelText: l10n.categoryNameHebrew,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameArabicController,
                    decoration: InputDecoration(
                      labelText: l10n.categoryNameArabic,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameEnglishController,
                    decoration: InputDecoration(
                      labelText: l10n.categoryNameEnglish,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: orderController,
                    decoration: InputDecoration(
                      labelText: l10n.displayOrder,
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.cancel),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.isEmpty ||
                    nameHebrewController.text.isEmpty ||
                    selectedMainCategoryId == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.allFieldsRequired)),
                  );
                  return;
                }

                try {
                  await _firestore.collection('categories').doc(category['id']).update({
                    'name': nameController.text.trim(),
                    'nameHebrew': nameHebrewController.text.trim(),
                    'nameArabic': nameArabicController.text.trim(),
                    'nameEnglish': nameEnglishController.text.trim(),
                    'mainCategoryId': selectedMainCategoryId,
                    'order': int.tryParse(orderController.text) ?? category['order'],
                    'updatedAt': FieldValue.serverTimestamp(),
                  });

                  if (mounted) {
                    Navigator.pop(context);
                    CategoriesService.clearCache(); // Clear cache after updating
                    _loadCategories();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l10n.subCategoryUpdated)),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${l10n.errorUpdatingSubCategory}: $e')),
                    );
                  }
                }
              },
              child: Text(l10n.save),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteMainCategoryConfirmation(BuildContext context, Map<String, dynamic> category) {
    final l10n = AppLocalizations.of(context);
    // Check if there are sub categories
    final hasSubCategories = _subCategories.any(
      (sub) => sub['mainCategoryId'] == category['id'],
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteMainCategory),
        content: Text(
          hasSubCategories
              ? l10n.cannotDeleteMainCategoryWithSub
              : l10n.confirmDeleteMainCategory(category['nameHebrew'] ?? ''),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          if (!hasSubCategories)
            ElevatedButton(
              onPressed: () async {
                try {
                  await _firestore.collection('categories').doc(category['id']).delete();
                  if (mounted) {
                    Navigator.pop(context);
                    CategoriesService.clearCache(); // Clear cache after deleting
                    _loadCategories();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l10n.mainCategoryDeleted)),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${l10n.errorDeletingMainCategory}: $e')),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: Text(l10n.delete),
            ),
        ],
      ),
    );
  }

  void _showDeleteSubCategoryConfirmation(BuildContext context, Map<String, dynamic> category) {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteSubCategory),
        content: Text(
          l10n.confirmDeleteSubCategory(category['nameHebrew'] ?? ''),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await _firestore.collection('categories').doc(category['id']).delete();
                if (mounted) {
                  Navigator.pop(context);
                  CategoriesService.clearCache(); // Clear cache after deleting
                  _loadCategories();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.subCategoryDeleted)),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${l10n.errorDeletingSubCategory}: $e')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
  }
}

