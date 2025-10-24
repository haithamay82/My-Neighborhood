import 'package:flutter/material.dart';
import '../models/request.dart';
import '../services/guest_auth_service.dart';
import '../services/audio_service.dart';
import 'home_screen.dart';

class GuestCategorySelectionScreen extends StatefulWidget {
  final String displayName;
  final String email;

  const GuestCategorySelectionScreen({
    super.key,
    required this.displayName,
    required this.email,
  });

  @override
  State<GuestCategorySelectionScreen> createState() => _GuestCategorySelectionScreenState();
}

class _GuestCategorySelectionScreenState extends State<GuestCategorySelectionScreen> {
  final Set<RequestCategory> _selectedCategories = <RequestCategory>{};
  bool _isLoading = false;

  // קבוצות קטגוריות לארגון טוב יותר
  final Map<String, List<RequestCategory>> _categoryGroups = {
    '🏠 בית וגן': [
      RequestCategory.cleaningServices,
      RequestCategory.gardening,
      RequestCategory.plumbing,
      RequestCategory.electrical,
      RequestCategory.carpentry,
      RequestCategory.paintingAndPlaster,
      RequestCategory.flooringAndCeramics,
      RequestCategory.roofsAndWalls,
      RequestCategory.elevatorsAndStairs,
    ],
    '🚗 רכב ותחבורה': [
      RequestCategory.carRepair,
      RequestCategory.carServices,
      RequestCategory.movingAndTransport,
      RequestCategory.ridesAndShuttles,
      RequestCategory.bicyclesAndScooters,
      RequestCategory.heavyVehicles,
    ],
    '👶 ילדים ומשפחה': [
      RequestCategory.babysitting,
      RequestCategory.privateLessons,
      RequestCategory.childrenActivities,
      RequestCategory.childrenHealth,
      RequestCategory.birthAndParenting,
      RequestCategory.specialEducation,
    ],
    '💼 עסקים ושירותים': [
      RequestCategory.officeServices,
      RequestCategory.marketingAndAdvertising,
      RequestCategory.consulting,
      RequestCategory.businessEvents,
      RequestCategory.security,
    ],
    '🎨 יצירה ואמנות': [
      RequestCategory.paintingAndSculpture,
      RequestCategory.handicrafts,
      RequestCategory.music,
      RequestCategory.photography,
      RequestCategory.design,
      RequestCategory.performingArts,
    ],
    '💪 בריאות וכושר': [
      RequestCategory.physiotherapy,
      RequestCategory.yogaAndPilates,
      RequestCategory.nutrition,
      RequestCategory.mentalHealth,
      RequestCategory.alternativeMedicine,
      RequestCategory.beautyAndCosmetics,
    ],
    '💻 טכנולוגיה': [
      RequestCategory.computersAndTechnology,
      RequestCategory.electricalAndElectronics,
      RequestCategory.internetAndCommunication,
      RequestCategory.appsAndDevelopment,
      RequestCategory.smartSystems,
      RequestCategory.medicalEquipment,
    ],
    '📚 חינוך והכשרה': [
      RequestCategory.privateLessonsEducation,
      RequestCategory.languages,
      RequestCategory.professionalTraining,
      RequestCategory.lifeSkills,
      RequestCategory.higherEducation,
      RequestCategory.vocationalTraining,
    ],
    '🎉 אירועים ופנאי': [
      RequestCategory.events,
      RequestCategory.entertainment,
      RequestCategory.sports,
      RequestCategory.tourism,
      RequestCategory.partiesAndEvents,
      RequestCategory.photographyAndVideo,
    ],
    '🌱 איכות הסביבה': [
      RequestCategory.environmentalCleaning,
      RequestCategory.cleaningServicesEnv,
      RequestCategory.environmentalQuality,
    ],
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('בחירת תחומי עיסוק'),
        backgroundColor: const Color(0xFF03A9F4),
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: Column(
        children: [
          // כותרת הסבר
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue.shade50, Colors.purple.shade50],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.stars,
                  size: 60,
                  color: Colors.amber.shade600,
                ),
                const SizedBox(height: 16),
                Text(
                  'ברוכים הבאים לתקופת אורח!',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'בחר תחומי עיסוק שמעניינים אותך כדי לקבל בקשות רלוונטיות',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.green.shade700),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'תקופת אורח: 30 ימים עם גישה מלאה כמו מנוי עסקי!',
                          style: TextStyle(
                            color: Colors.green.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // רשימת קטגוריות
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _categoryGroups.length,
              itemBuilder: (context, groupIndex) {
                final groupEntry = _categoryGroups.entries.toList()[groupIndex];
                final groupName = groupEntry.key;
                final categories = groupEntry.value;
                
                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: ExpansionTile(
                    title: Text(
                      groupName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: categories.map((category) {
                            final isSelected = _selectedCategories.contains(category);
                            return FilterChip(
                              label: Text(
                                category.categoryDisplayName,
                                style: TextStyle(
                                  color: isSelected ? Colors.white : Colors.grey.shade700,
                                ),
                              ),
                              selected: isSelected,
                              onSelected: (selected) {
                                setState(() {
                                  if (selected) {
                                    _selectedCategories.add(category);
                                  } else {
                                    _selectedCategories.remove(category);
                                  }
                                });
                                AudioService().playSound(AudioEvent.buttonClick);
                              },
                              selectedColor: const Color(0xFF03A9F4),
                              checkmarkColor: Colors.white,
                              backgroundColor: Colors.grey.shade100,
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          
          // כפתור המשך
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                if (_selectedCategories.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.blue.shade700),
                        const SizedBox(width: 8),
                        Text(
                          'נבחרו ${_selectedCategories.length} תחומים',
                          style: TextStyle(
                            color: Colors.blue.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _selectedCategories.isNotEmpty && !_isLoading
                        ? _continueAsGuest
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF03A9F4),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.rocket_launch),
                              const SizedBox(width: 8),
                              Text(
                                'התחל תקופת אורח (30 ימים)',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'תוכל לשנות את התחומים בכל עת בפרופיל',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.location_on, color: Colors.blue[700], size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '💡 טיפ: הגדר מיקום קבוע בפרופיל כדי להופיע במפות של בקשות גם כששירות המיקום כובה',
                          style: TextStyle(
                            color: Colors.blue[700],
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _continueAsGuest() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await AudioService().playSound(AudioEvent.buttonClick);
      
      // יצירת משתמש אורח
      await GuestAuthService.createGuestUser(
        displayName: widget.displayName,
        email: widget.email,
        selectedCategories: _selectedCategories.toList(),
      );

      // הצגת הודעת הצלחה
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ברוכים הבאים! תקופת האורח שלך החלה'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );

        // מעבר למסך הבית
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('שגיאה ביצירת משתמש אורח: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}
