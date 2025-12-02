import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class BusinessServicesEditScreen extends StatefulWidget {
  final List<Map<String, dynamic>> initialServices;

  const BusinessServicesEditScreen({
    super.key,
    required this.initialServices,
  });

  @override
  State<BusinessServicesEditScreen> createState() => _BusinessServicesEditScreenState();
}

// מודל מרכיב
class _Ingredient {
  final TextEditingController nameController;
  final TextEditingController costController;

  _Ingredient({
    required this.nameController,
    required this.costController,
  });

  void dispose() {
    nameController.dispose();
    costController.dispose();
  }
}

class _Service {
  final TextEditingController nameController;
  final TextEditingController priceController;
  File? imageFile;
  String? imageUrl;
  bool isCustomPrice;
  final List<_Ingredient> ingredients;

  _Service({
    required this.nameController,
    required this.priceController,
    this.imageFile,
    this.imageUrl,
    this.isCustomPrice = false,
    List<_Ingredient>? ingredients,
  }) : ingredients = ingredients ?? [];

  void dispose() {
    nameController.dispose();
    priceController.dispose();
    for (final ingredient in ingredients) {
      ingredient.dispose();
    }
  }
}

class _BusinessServicesEditScreenState extends State<BusinessServicesEditScreen> {
  final List<_Service> _services = [];
  final ImagePicker _imagePicker = ImagePicker();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // טעינת השירותים הקיימים
    for (var serviceData in widget.initialServices) {
      final ingredients = <_Ingredient>[];
      if (serviceData['ingredients'] != null) {
        final ingredientsData = serviceData['ingredients'] as List<dynamic>?;
        if (ingredientsData != null) {
          for (var ingredientData in ingredientsData) {
            ingredients.add(_Ingredient(
              nameController: TextEditingController(
                text: ingredientData['name'] as String? ?? '',
              ),
              costController: TextEditingController(
                text: ingredientData['cost'] != null
                    ? (ingredientData['cost'] as num).toString()
                    : '0',
              ),
            ));
          }
        }
      }
      
      _services.add(_Service(
        nameController: TextEditingController(text: serviceData['name'] as String? ?? ''),
        priceController: TextEditingController(
          text: serviceData['price'] != null 
              ? (serviceData['price'] as num).toString() 
              : '',
        ),
        imageUrl: serviceData['imageUrl'] as String?,
        isCustomPrice: serviceData['isCustomPrice'] as bool? ?? false,
        ingredients: ingredients,
      ));
    }
  }

  @override
  void dispose() {
    for (var service in _services) {
      service.dispose();
    }
    super.dispose();
  }

  void _addService() {
    setState(() {
      _services.add(_Service(
        nameController: TextEditingController(),
        priceController: TextEditingController(),
      ));
    });
  }

  void _removeService(int index) {
    setState(() {
      _services[index].dispose();
      _services.removeAt(index);
    });
  }

  Future<void> _pickServiceImage(int index) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      
      if (image != null) {
        setState(() {
          _services[index].imageFile = File(image.path);
          _services[index].imageUrl = null; // נקה את ה-URL הישן אם יש תמונה חדשה
        });
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  Future<String?> _uploadServiceImage(File imageFile, String userId, int serviceIndex) async {
    try {
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('business_services')
          .child(userId)
          .child('service_$serviceIndex.jpg');
      
      await storageRef.putFile(imageFile);
      final downloadUrl = await storageRef.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      debugPrint('Error uploading service image: $e');
      return null;
    }
  }

  Future<void> _saveServices() async {
    if (_isLoading) return;

    // בדיקת תקינות השירותים
    for (var service in _services) {
      if (service.nameController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('אנא מלא את שם השירות'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      if (!service.isCustomPrice && service.priceController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('אנא הזן מחיר או סמן "בהתאמה אישית"'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('משתמש לא מחובר');
      }

      final List<Map<String, dynamic>> servicesData = [];
      for (int i = 0; i < _services.length; i++) {
        final service = _services[i];
        // שמירת isAvailable אם קיים, אחרת ברירת מחדל true
        final existingService = widget.initialServices.length > i ? widget.initialServices[i] : {};
        final serviceData = <String, dynamic>{
          'name': service.nameController.text.trim(),
          'isCustomPrice': service.isCustomPrice,
          'isAvailable': existingService['isAvailable'] as bool? ?? true, // שמירת ערך קיים או ברירת מחדל
        };
        
        if (!service.isCustomPrice && service.priceController.text.trim().isNotEmpty) {
          serviceData['price'] = double.tryParse(service.priceController.text.trim()) ?? 0.0;
        }
        
        // העלאת תמונה אם קיימת
        if (service.imageFile != null) {
          final imageUrl = await _uploadServiceImage(service.imageFile!, user.uid, i);
          if (imageUrl != null) {
            serviceData['imageUrl'] = imageUrl;
          }
        } else if (service.imageUrl != null) {
          // שמירת ה-URL הקיים אם אין תמונה חדשה
          serviceData['imageUrl'] = service.imageUrl;
        }
        
        // שמירת מרכיבים
        if (service.ingredients.isNotEmpty) {
          serviceData['ingredients'] = service.ingredients.map((ingredient) {
            return {
              'name': ingredient.nameController.text.trim(),
              'cost': double.tryParse(ingredient.costController.text.trim()) ?? 0.0,
            };
          }).toList();
        }
        
        servicesData.add(serviceData);
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'businessServices': servicesData,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('השירותים נשמרו בהצלחה'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('Error saving services: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('שגיאה בשמירת השירותים: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildServiceCard(int index, _Service service) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'שירות ${index + 1}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _removeService(index),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: service.nameController,
              decoration: const InputDecoration(
                labelText: 'שם השירות',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.business_center),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: service.priceController,
                    enabled: !service.isCustomPrice,
                    decoration: const InputDecoration(
                      labelText: 'מחיר',
                      hintText: 'לדוגמה: 100',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.attach_money),
                      suffixText: '₪',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
                const SizedBox(width: 16),
                Row(
                  children: [
                    Checkbox(
                      value: service.isCustomPrice,
                      onChanged: (value) {
                        setState(() {
                          service.isCustomPrice = value ?? false;
                          if (service.isCustomPrice) {
                            service.priceController.clear();
                          }
                        });
                      },
                    ),
                    const Text('בהתאמה אישית'),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (service.imageUrl != null || service.imageFile != null)
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey),
                    ),
                    child: service.imageFile != null
                        ? Image.file(
                            service.imageFile!,
                            fit: BoxFit.cover,
                          )
                        : Image.network(
                            service.imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return const Icon(Icons.image);
                            },
                          ),
                  ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: () => _pickServiceImage(index),
                  icon: const Icon(Icons.image),
                  label: const Text('בחר תמונה'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // מרכיבים
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'מרכיבים',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          service.ingredients.add(_Ingredient(
                            nameController: TextEditingController(),
                            costController: TextEditingController(text: '0'),
                          ));
                        });
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('הוסף מרכיב'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...service.ingredients.asMap().entries.map((entry) {
                  final ingredientIndex = entry.key;
                  final ingredient = entry.value;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    color: Colors.grey[50],
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: ingredient.nameController,
                              decoration: const InputDecoration(
                                labelText: 'שם מרכיב',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              controller: ingredient.costController,
                              decoration: const InputDecoration(
                                labelText: 'עלות',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.attach_money, size: 18),
                                suffixText: '₪',
                                isDense: true,
                              ),
                              keyboardType: TextInputType.numberWithOptions(decimal: true),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () {
                              setState(() {
                                ingredient.dispose();
                                service.ingredients.removeAt(ingredientIndex);
                              });
                            },
                            tooltip: 'מחק מרכיב',
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('עריכת שירותים'),
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _saveServices,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ..._services.asMap().entries.map((entry) {
              final index = entry.key;
              final service = entry.value;
              return _buildServiceCard(index, service);
            }).toList(),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _addService,
              icon: const Icon(Icons.add),
              label: const Text('הוסף שירות'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

