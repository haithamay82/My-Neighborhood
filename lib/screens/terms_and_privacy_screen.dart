import 'package:flutter/material.dart';

class TermsAndPrivacyScreen extends StatelessWidget {
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const TermsAndPrivacyScreen({
    Key? key,
    required this.onAccept,
    required this.onDecline,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('תנאי שימוש ומדיניות פרטיות'),
        centerTitle: true,
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // כותרת
            Center(
              child: Text(
                'ברוכים הבאים לאפליקציה שלנו',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[700],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // תנאי שימוש
            _buildSection(
              context,
              'תנאי שימוש',
              [
                '1. השימוש באפליקציה מותנה בקבלת תנאי השימוש הללו.',
                '2. השימוש באפליקציה מיועד למשתמשים מעל גיל 18 בלבד. החברה שומרת על זכותה לבקש הוכחת גיל בכל שלב.',
                '3. האפליקציה מיועדת לעזרה הדדית בין שכנים - חיבור בין מבקשי עזרה לנותני עזרה בקהילה המקומית.',
                '4. המשתמש מתחייב לספק מידע אמיתי ומדויק בלבד, לרבות פרטי מיקום ופרטי יצירת קשר.',
                '5. אסור להשתמש באפליקציה למטרות לא חוקיות, לא מוסריות או מסחריות. האפליקציה מיועדת לעזרה הדדית בלבד.',
                '6. המשתמשים אחראים באופן בלעדי לתוכן שהם מפרסמים ולכל אינטראקציה עם משתמשים אחרים.',
                '7. שכונתי היא מתווכת בלבד ואינה אחראית לאיכות השירותים, למהימנות המשתמשים או לנזקים כלשהם.',
                '8. המשתמש מתחייב לדווח על התנהגות לא הולמת, פוגענית או מסוכנת מיד לתמיכה או לרשויות הרלוונטיות.',
                '9. ניתן לבטל בקשה עד 30 דקות ממועד הפרסום. ביטול מאוחר יותר מותנה בהסכמת נותן השירות.',
                '10. החברה שומרת לעצמה את הזכות להפסיק את השירות, לחסום משתמשים או להסיר תוכן בכל עת.',
                '11. המשתמש אחראי לשמירה על סיסמת הכניסה שלו ולאבטחת המידע האישי שלו.',
                '12. כל מחלוקת תיפתר על פי החוק הישראלי ובהתאם לדיני מדינת ישראל.',
              ],
            ),

            const SizedBox(height: 24),

            // עזרה הדדית ובטיחות
            _buildSection(
              context,
              'עזרה הדדית ובטיחות',
              [
                '1. האפליקציה מיועדת לעזרה הדדית בין שכנים - עזרה מתוך רצון טוב ולא למטרות מסחריות.',
                '2. אין חובה חוקית לספק שירות, אך מומלץ לעמוד בהתחייבויות שניתנו לאחרים.',
                '3. מערכת הדירוגים והביקורות חייבת להיות אמיתית ומדויקת. דירוגים כוזבים או פוגעניים יובילו לחסימת המשתמש.',
                '4. במקרה של חשד לסכנה, התנהגות לא הולמת או ניצול, יש לדווח מיד לתמיכה או לרשויות הרלוונטיות.',
                '5. אנו שומרים לעצמנו את הזכות לחסום משתמשים שמפרים את הכללים או מתנהגים בצורה לא הולמת.',
                '6. התשלומים בין משתמשים הם באחריותם הבלעדית. שכונתי אינה אחראית לתשלומים או לעסקאות בין המשתמשים.',
                '7. מומלץ להיפגש במקומות ציבוריים או עם אנשים נוספים בעת מתן/קבלת עזרה.',
                '8. במקרה של בעיה או סכסוך, אנו ממליצים לנסות לפתור את הבעיה בדרכי שלום לפני פנייה לתמיכה.',
              ],
            ),

            const SizedBox(height: 24),

            // מדיניות פרטיות
            _buildSection(
              context,
              'מדיניות פרטיות',
              [
                '1. אנו מכבדים את פרטיות המשתמשים ומתחייבים להגן על המידע האישי שלך.',
                '2. המידע האישי נאסף לצורך מתן השירותים, לרבות מיקום גיאוגרפי לחיבור שכנים, פרטי יצירת קשר ומידע על בקשות עזרה.',
                '3. אנו לא נמכור או נשתף את המידע האישי עם צדדים שלישיים ללא הסכמה מפורשת, למעט במקרים הנדרשים על פי חוק.',
                '4. המידע נשמר בשרתים מאובטחים ומוצפנים. מיקום גיאוגרפי נשמר באופן מוצפן ולא מועבר לצדדים שלישיים.',
                '5. יש לך בקרה מלאה על מי רואה את המידע שלך. תוכל להגדיר רמות פרטיות שונות עבור בקשות שונות.',
                '6. המשתמש רשאי לבקש לגשת, לתקן או למחוק את המידע האישי שלו בכל עת.',
                '7. אנו משתמשים בעוגיות (cookies) ובטכנולוגיות דומות לשיפור חוויית המשתמש ולניתוח השימוש באפליקציה.',
                '8. המידע עשוי להיות מועבר לספקי שירותים חיצוניים (כגון Firebase) לצורך מתן השירותים, אך תמיד תחת הגנות אבטחה מתאימות.',
                '9. אנו נוקטים באמצעי אבטחה סבירים כדי להגן על המידע שלך מפני גישה בלתי מורשית, שימוש או חשיפה.',
                '10. במקרה של פריצת אבטחה או חשיפת מידע, נדווח על כך בהקדם האפשרי וננקוט בצעדים מתאימים.',
                '11. אנו מתחייבים לעדכן את המשתמשים על כל שינוי במדיניות הפרטיות באמצעות האפליקציה או בדרכים אחרות.',
                '12. האפליקציה עשויה להכיל קישורים לאתרים או שירותים של צדדים שלישיים. איננו אחראים למדיניות הפרטיות שלהם.',
              ],
            ),

            const SizedBox(height: 32),

            // אזהרה חשובה
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.warning, color: Colors.orange[600]),
                      const SizedBox(width: 8),
                      Text(
                        'חשוב לדעת',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.orange[700],
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'על ידי המשך השימוש באפליקציה, אתה מאשר שקראת והבנת את תנאי השימוש ומדיניות הפרטיות, ואתה מסכים להם.',
                    style: TextStyle(
                      color: Colors.orange[700],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // כפתורי פעולה
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: onDecline,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[400],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'לא מסכים',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onAccept,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[600],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'מסכים וממשיך',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // הודעה על עדכונים
            Center(
              child: Text(
                'תנאי השימוש ומדיניות הפרטיות עשויים להתעדכן מעת לעת.\nתוכל למצוא את הגרסה העדכנית ביותר באפליקציה.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(BuildContext context, String title, List<String> points) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.blue[700],
          ),
        ),
        const SizedBox(height: 12),
        ...points.map((point) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                point.split(' ')[0] + ' ',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Expanded(
                child: Text(
                  point.substring(point.indexOf(' ') + 1),
                  style: const TextStyle(height: 1.4),
                ),
              ),
            ],
          ),
        )),
      ],
    );
  }
}
