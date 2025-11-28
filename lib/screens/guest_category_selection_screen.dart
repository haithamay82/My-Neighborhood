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
    '🏠 בנייה, תיקונים ותחזוקה': [
      RequestCategory.plumbing,
      RequestCategory.electrical,
      RequestCategory.renovations,
      RequestCategory.airConditioning,
      RequestCategory.carpentry,
      RequestCategory.drywall,
      RequestCategory.painting,
      RequestCategory.flooring,
      RequestCategory.frames,
      RequestCategory.waterproofing,
      RequestCategory.doorsAndWindows,
    ],
    '🚚 שליחויות, הובלות ושירותים מהירים': [
      RequestCategory.foodDelivery,
      RequestCategory.groceryDelivery,
      RequestCategory.smallMoving,
      RequestCategory.largeMoving,
    ],
    '🧖‍♀️ יופי, טיפוח וקוסמטיקה': [
      RequestCategory.manicurePedicure,
      RequestCategory.nailExtension,
      RequestCategory.hairstyling,
      RequestCategory.makeup,
      RequestCategory.eyebrowDesign,
      RequestCategory.facialTreatments,
      RequestCategory.massages,
      RequestCategory.hairRemoval,
      RequestCategory.beautyTreatments,
    ],
    '🛒 שיווק ומכירות': [
      // אוכל מהיר
      RequestCategory.shawarma,
      RequestCategory.falafel,
      RequestCategory.hamburger,
      RequestCategory.pizza,
      RequestCategory.toast,
      RequestCategory.sandwiches,
      // אוכל ביתי
      RequestCategory.homeFood,
      // מאפים וקינוחים
      RequestCategory.pastriesAndDesserts,
      // אלקטרוניקה
      RequestCategory.electronicsSales,
      // כלי תחבורה (מכירה)
      RequestCategory.vehiclesSales,
      // ריהוט
      RequestCategory.furniture,
      // אופנה
      RequestCategory.fashion,
      // גיימינג
      RequestCategory.gaming,
      // ילדים ותינוקות
      RequestCategory.kidsAndBabies,
      // ציוד לבית ולגן
      RequestCategory.homeAndGardenEquipment,
      // חיות מחמד (מכירה)
      RequestCategory.petsSales,
      // מוצרים מיוחדים
      RequestCategory.specialProducts,
    ],
    '🛠️ טכנולוגיה, מחשבים ואפליקציות': [
      RequestCategory.computerPhoneRepair,
      RequestCategory.networksAndInternet,
      RequestCategory.smartHomeInstallation,
      RequestCategory.camerasAndAlarms,
      RequestCategory.webAppDevelopment,
    ],
    '🚗 כלי תחבורה': [
      RequestCategory.carMechanic,
      RequestCategory.carElectrician,
      RequestCategory.motorcycles,
      RequestCategory.bicycles,
      RequestCategory.scooters,
      RequestCategory.towingServices,
    ],
    '🌱 גינון, ניקיון וסביבה': [
      RequestCategory.homeGardening,
      RequestCategory.yardCleaning,
      RequestCategory.postRenovationCleaning,
      RequestCategory.plantsAndPets,
    ],
    '🎓 חינוך, לימודים והדרכה': [
      RequestCategory.privateTutoring,
      RequestCategory.coursesAndAssignments,
      RequestCategory.translation,
      RequestCategory.languageLearning,
    ],
    '🧭 ייעוץ והכוונה מקצועית': [
      RequestCategory.nutritionConsulting,
      RequestCategory.careerConsulting,
      RequestCategory.travelConsulting,
      RequestCategory.financialConsulting,
      RequestCategory.educationConsulting,
      RequestCategory.personalTrainer,
      RequestCategory.familyCoupleCounseling,
    ],
    '🎨 יצירה, אומנות ומדיה': [
      RequestCategory.eventPhotography,
      RequestCategory.graphics,
      RequestCategory.video,
      RequestCategory.logoDesign,
      RequestCategory.smallEventProduction,
    ],
    '💡 שירותים מיוחדים ופתוחים': [
      RequestCategory.elderlyAssistance,
      RequestCategory.youthMentoring,
      RequestCategory.formFillingHelp,
      RequestCategory.donations,
      RequestCategory.volunteering,
      RequestCategory.petsCare,
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
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Theme.of(context).colorScheme.primary),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.location_on, color: Theme.of(context).colorScheme.primary, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '💡 טיפ: הגדר מיקום קבוע בפרופיל כדי להופיע במפות של בקשות גם כששירות המיקום כובה',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
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
