import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

/// Widget שמציג אייקונים מפוזרים ברקע עבור web
class BackgroundIconsWidget extends StatelessWidget {
  final Widget child;
  
  const BackgroundIconsWidget({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) {
      return child;
    }

    final screenSize = MediaQuery.of(context).size;
    final random = math.Random(42); // seed קבוע כדי שהאייקונים יישארו באותו מקום
    
    // רשימת אייקונים מכל הקטגוריות
    final icons = [
      // בנייה ותיקונים
      Icons.build,
      Icons.home_repair_service,
      Icons.construction,
      Icons.electrical_services,
      Icons.plumbing,
      // שליחויות
      Icons.local_shipping,
      Icons.delivery_dining,
      Icons.directions_car,
      // יופי
      Icons.face,
      Icons.spa,
      Icons.content_cut,
      // שיווק
      Icons.shopping_cart,
      Icons.store,
      Icons.restaurant,
      // טכנולוגיה
      Icons.computer,
      Icons.phone_android,
      Icons.code,
      // רכב
      Icons.two_wheeler,
      Icons.pedal_bike,
      // גינון
      Icons.local_florist,
      Icons.cleaning_services,
      Icons.eco,
      // חינוך
      Icons.school,
      Icons.menu_book,
      Icons.language,
      // ייעוץ
      Icons.psychology,
      Icons.business_center,
      Icons.fitness_center,
      // אמנות
      Icons.palette,
      Icons.camera_alt,
      Icons.videocam,
      // שירותים מיוחדים
      Icons.favorite,
      Icons.volunteer_activism,
      Icons.pets,
      Icons.elderly,
    ];

    // צבעים שונים לאייקונים - עם שקיפות גבוהה יותר כדי שיהיו נראים
    final colors = [
      Colors.blue.withOpacity(0.25),
      Colors.green.withOpacity(0.25),
      Colors.orange.withOpacity(0.25),
      Colors.purple.withOpacity(0.25),
      Colors.pink.withOpacity(0.25),
      Colors.teal.withOpacity(0.25),
      Colors.amber.withOpacity(0.25),
      Colors.indigo.withOpacity(0.25),
      Colors.grey.withOpacity(0.2),
    ];

    // חישוב רוחב האזור המרכזי (80% מהמסך, מקסימום 1200px)
    final centerWidth = math.min(screenSize.width * 0.8, 1200);
    final sideWidth = (screenSize.width - centerWidth) / 2; // רוחב כל צד
    
    // מספר אייקונים - יותר במסכים גדולים
    final iconCount = ((sideWidth * 2 * screenSize.height) / 5000).round().clamp(20, 50);
    
    // יצירת רשימת אייקונים מפוזרים רק באזורים הצדדיים
    final backgroundIcons = <Widget>[];
    
    for (int i = 0; i < iconCount; i++) {
      final icon = icons[random.nextInt(icons.length)];
      final iconSize = (random.nextDouble() * 30 + 20); // 20-50px
      final color = colors[random.nextInt(colors.length)];
      final rotation = random.nextDouble() * 2 * math.pi; // סיבוב אקראי
      
      // החלטה: אייקון בצד שמאל או ימין
      final isLeftSide = random.nextBool();
      double x;
      
      if (isLeftSide) {
        // צד שמאל: 0 עד sideWidth
        x = random.nextDouble() * sideWidth;
      } else {
        // צד ימין: centerWidth + sideWidth עד screenSize.width
        x = centerWidth + sideWidth + random.nextDouble() * sideWidth;
      }
      
      final y = random.nextDouble() * screenSize.height;
      
      backgroundIcons.add(
        Positioned(
          left: x,
          top: y,
          child: Transform.rotate(
            angle: rotation,
            child: Icon(
              icon,
              size: iconSize,
              color: color,
            ),
          ),
        ),
      );
    }

    return Stack(
      children: backgroundIcons,
    );
  }
}

