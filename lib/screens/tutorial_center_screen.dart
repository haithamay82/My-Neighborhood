import 'package:flutter/material.dart';
import '../services/tutorial_service.dart';

class TutorialCenterScreen extends StatefulWidget {
  const TutorialCenterScreen({super.key});

  @override
  State<TutorialCenterScreen> createState() => _TutorialCenterScreenState();
}

class _TutorialCenterScreenState extends State<TutorialCenterScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<TutorialCategory> _categories = [
    TutorialCategory(
      id: 'home',
      title: 'מסך הבית',
      icon: Icons.home,
      color: Colors.blue,
      tutorials: [
        TutorialItem(
          id: 'home_basics',
          title: 'תכולת מסך הבית',
          description: 'למד כיצד לנווט במסך הבית ולהשתמש בפונקציות הבסיסיות',
          content: '''
# יסודות מסך הבית

## מה תמצא במסך הבית:
• **רשימת בקשות** - כל הבקשות הזמינות בקהילה
• **חיפוש** - חפש בקשות לפי מילות מפתח
• **סינון** - סנן בקשות לפי קטגוריה, מיקום ומחיר
• **בקשות שלי** - בקשות שפרסמת או פנית אליהן

## איך להשתמש:
1. **לצפייה בבקשה** - לחץ על בקשה מהרשימה
2. **לחיפוש** - השתמש בשורת החיפוש העליונה
3. **לסינון** - לחץ על כפתור "סינון מתקדם"
4. **לבקשות שלי** - לחץ על "בקשות שפניתי אליהם"
          ''',
        ),
        TutorialItem(
          id: 'home_search',
          title: 'חיפוש וסינון',
          description: 'איך למצוא בקשות ספציפיות במהירות',
          content: '''
# חיפוש וסינון

## חיפוש:
• **מילות מפתח** - הזן מילים רלוונטיות
• **חיפוש בזמן אמת** - התוצאות מתעדכנות תוך כדי הקלדה
• **חיפוש בכל השדות** - שם, תיאור, קטגוריה

## סינון מתקדם:
• **קטגוריות** - בחר תחומי עיסוק ספציפיים
• **טווח מחיר** - הגדר מינימום ומקסימום
• **מיקום** - חפש בקרבת מקום מסוים
• **תאריך** - בקשות חדשות או ישנות

## טיפים:
• השתמש במילות מפתח קצרות וברורות
• נסה חיפושים שונים לאותה בקשה
• שמור סינונים מועדפים
          ''',
        ),
      ],
    ),
    TutorialCategory(
      id: 'requests',
      title: 'בקשות',
      icon: Icons.assignment,
      color: Colors.green,
      tutorials: [
        TutorialItem(
          id: 'create_request',
          title: 'יצירת בקשה חדשה',
          description: 'איך ליצור בקשה לעזרה או שירות',
          content: '''
# יצירת בקשה חדשה

## שלבים ליצירת בקשה:
1. **לחץ על +** - בפינה הימנית התחתונה
2. **בחר קטגוריה** - תחום העיסוק המתאים
3. **כתוב תיאור** - הסבר מה אתה צריך
4. **הגדר מחיר** - אם רלוונטי
5. **בחר מיקום** - איפה אתה נמצא
6. **פרסם** - שלח את הבקשה לקהילה

## טיפים לכתיבה טובה:
• **תיאור ברור** - הסבר בדיוק מה אתה צריך
• **פרטים חשובים** - זמן, מקום, דחיפות
• **תמונה** - הוסף תמונה אם זה עוזר להסביר
• **מחיר הוגן** - הצע מחיר סביר

## דוגמה טובה:
"צריך עזרה בהעברת רהיטים מדירה לדירה בירושלים. 
יש 3 ארונות, 2 שולחנות ומיטות. 
מוכן לשלם 200-300 שקל. 
מועד: סוף השבוע הקרוב."
          ''',
        ),
        TutorialItem(
          id: 'manage_requests',
          title: 'ניהול בקשות',
          description: 'איך לנהל את הבקשות שלך',
          content: '''
# ניהול בקשות

## בקשות שפרסמת:
• **צפייה בפניות** - ראה מי פנה אליך
• **עריכת בקשה** - עדכן פרטים או מחיר
• **סגירת בקשה** - כשהתקבל עזרה
• **מחיקת בקשה** - אם כבר לא רלוונטית

## בקשות שפנית אליהן:
• **מעקב סטטוס** - ראה אם התקבלת
• **צ'אט עם המפרסם** - תקשורת ישירה
• **ביטול פנייה** - אם שינית דעתך

## טיפים לניהול:
• **עדכן סטטוס** - סמן כשהבקשה הושלמה
• **תקשר בצ'אט** - שאל שאלות לפני התחייבות
• **בדוק פרופילים** - ראה דירוגים של נותני שירות
• **היה מנומס** - תגיב בזמן ובכבוד
          ''',
        ),
      ],
    ),
    TutorialCategory(
      id: 'chat',
      title: 'צ\'אט',
      icon: Icons.chat,
      color: Colors.orange,
      tutorials: [
        TutorialItem(
          id: 'chat_basics',
          title: 'תכולת הצ\'אט',
          description: 'איך להשתמש במערכת הצ\'אט',
          content: '''
# יסודות הצ'אט

## איך נכנסים לצ'אט:
1. **מבקשה שפרסמת** - לחץ על "צ'אט" ליד פנייה
2. **מבקשה שפנית אליה** - לחץ על "צ'אט" בבקשה
3. **מהמסך "בקשות שלי"** - לחץ על כפתור הצ'אט

## פונקציות הצ'אט:
• **שליחת הודעות** - טקסט, תמונות, קבצים
• **עריכת הודעות** - לחץ ארוך על הודעה ששלחת
• **מחיקת הודעות** - לחץ ארוך ובחר "מחק"
• **סגירת צ'אט** - אם לא רוצה יותר לתקשר

## סימני קריאה:
• **וי אחד** - הודעה נשלחה
• **שני וי** - הודעה נקראה על ידי הנמען
• **וי זוהר** - הודעה נקראה לאחרונה

## כללי התנהגות:
• **היה מנומס** - השתמש בשפה נאותה
• **תגיב בזמן** - אל תשאיר הודעות ללא מענה
• **היה ברור** - הסבר בדיוק מה אתה צריך
• **שמור על פרטיות** - אל תעביר מידע אישי
          ''',
        ),
        TutorialItem(
          id: 'chat_advanced',
          title: 'פונקציות מתקדמות',
          description: 'פונקציות מתקדמות של הצ\'אט',
          content: '''
# פונקציות מתקדמות

## עריכת הודעות:
1. **לחץ ארוך** על הודעה ששלחת
2. **בחר "ערוך"** מהתפריט
3. **ערוך את הטקסט** והשמור
4. **ההודעה תסומן** כ"נערכה"

## מחיקת הודעות:
1. **לחץ ארוך** על הודעה ששלחת
2. **בחר "מחק"** מהתפריט
3. **אשר את המחיקה**
4. **ההודעה תימחק** לצמיתות

## סגירת צ'אט:
• **מתי לסגור** - כשאתה לא רוצה יותר לתקשר
• **איך לסגור** - תפריט (3 נקודות) > "סגור צ'אט"
• **פתיחה מחדש** - אפשר לפתוח צ'אט סגור
• **הודעת מערכת** - תישלח הודעה על סגירת הצ'אט

## ניקוי צ'אט:
• **מחיקת היסטוריה** - תפריט > "נקה צ'אט"
• **השפעה** - מוחק את כל ההודעות
• **לא ניתן לשחזר** - פעולה סופית
          ''',
        ),
      ],
    ),
    TutorialCategory(
      id: 'profile',
      title: 'פרופיל',
      icon: Icons.person,
      color: Colors.purple,
      tutorials: [
        TutorialItem(
          id: 'profile_setup',
          title: 'הגדרת פרופיל',
          description: 'איך להגדיר את הפרופיל שלך',
          content: '''
# הגדרת פרופיל

## מידע בסיסי:
• **שם** - השם שלך (חובה)
• **אימייל** - כתובת אימייל (חובה)
• **תמונה** - תמונת פרופיל (אופציונלי)
• **מיקום** - איפה אתה נמצא (חובה)

## מידע עסקי (למנויים):
• **תחומי עיסוק** - מה אתה מציע
• **תיאור** - הסבר על השירותים שלך
• **מחירים** - מחירון כללי
• **זמינות** - מתי אתה זמין

## הגדרות פרטיות:
• **מספר טלפון** - אם רוצה שיוצג
• **הצגת טלפון** - הסכמה להציג במפה
• **הגדרות התראות** - איזה התראות לקבל

## טיפים לפרופיל טוב:
• **תמונה מקצועית** - תמונה ברורה ונעימה
• **תיאור מפורט** - הסבר מה אתה מציע
• **מידע אמיתי** - אל תכתוב דברים לא נכונים
• **עדכון קבוע** - עדכן מידע כשמשתנה
          ''',
        ),
        TutorialItem(
          id: 'subscription',
          title: 'מנויים ותשלומים',
          description: 'איך לנהל מנוי ותשלומים',
          content: '''
# מנויים ותשלומים

## סוגי מנויים:
• **פרטי חינם** - גישה בסיסית לאפליקציה
• **פרטי מנוי** - פונקציות מתקדמות
• **עסקי מנוי** - פרסום שירותים
• **מנהל** - גישה מלאה לכל הפונקציות

## מה כלול בכל מנוי:
### פרטי חינם:
• צפייה בבקשות
• פנייה לבקשות
• צ'אט בסיסי

### פרטי מנוי:
• כל מה שבחינם +
• פרסום בקשות
• סינון מתקדם
• התראות מותאמות

### עסקי מנוי:
• כל מה שבפרטי מנוי +
• פרסום שירותים
• הופעה במפה
• דירוגים מפורטים

## תשלומים:
• **אמצעי תשלום** - כרטיס אשראי, העברה בנקאית
• **חיוב חודשי** - אוטומטי
• **ביטול** - אפשר לבטל בכל עת
• **החזר כספי** - לפי מדיניות החברה
          ''',
        ),
      ],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _categories.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('מדריך משתמש'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: _categories.map((category) => Tab(
            icon: Icon(category.icon),
            text: category.title,
          )).toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _categories.map((category) => _buildCategoryContent(category)).toList(),
      ),
    );
  }

  Widget _buildCategoryContent(TutorialCategory category) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // כותרת הקטגוריה
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [category.color, category.color.withOpacity(0.7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Icon(category.icon, size: 48, color: Colors.white),
                const SizedBox(height: 12),
                Text(
                  category.title,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${category.tutorials.length} הדרכות זמינות',
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // רשימת הדרכות
          ...category.tutorials.map((tutorial) => _buildTutorialCard(tutorial, category.color)),
        ],
      ),
    );
  }

  Widget _buildTutorialCard(TutorialItem tutorial, Color categoryColor) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _showTutorialDetail(tutorial, categoryColor),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: categoryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.school,
                      color: categoryColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tutorial.title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          tutorial.description,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    color: Colors.grey[400],
                    size: 16,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showTutorialDetail(TutorialItem tutorial, Color categoryColor) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          constraints: const BoxConstraints(maxHeight: 600),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // כותרת
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [categoryColor, categoryColor.withOpacity(0.7)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.school, color: Colors.white, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        tutorial.title,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                  ],
                ),
              ),
              
              // תוכן
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    tutorial.content,
                    style: const TextStyle(fontSize: 16, height: 1.6),
                  ),
                ),
              ),
              
              // כפתורים
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('סגור'),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        // סמן כנקרא
                        await TutorialService.markTutorialAsRead(tutorial.id);
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('הדרכה סומנה כנקראה'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: categoryColor,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('קראתי'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TutorialCategory {
  final String id;
  final String title;
  final IconData icon;
  final Color color;
  final List<TutorialItem> tutorials;

  TutorialCategory({
    required this.id,
    required this.title,
    required this.icon,
    required this.color,
    required this.tutorials,
  });
}

class TutorialItem {
  final String id;
  final String title;
  final String description;
  final String content;

  TutorialItem({
    required this.id,
    required this.title,
    required this.description,
    required this.content,
  });
}
