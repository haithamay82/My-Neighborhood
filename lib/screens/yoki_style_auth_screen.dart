import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/audio_service.dart';
import '../services/google_auth_service.dart';
import '../services/auto_login_service.dart';
import '../services/terms_service.dart';
import '../widgets/remember_me_dialog.dart';
import 'terms_and_privacy_screen.dart';
import 'guest_category_selection_screen.dart';
import 'dart:math' as math;

class YokiStyleAuthScreen extends StatefulWidget {
  final VoidCallback? onLoginSuccess;

  const YokiStyleAuthScreen({super.key, this.onLoginSuccess});

  @override
  State<YokiStyleAuthScreen> createState() => _YokiStyleAuthScreenState();
}

class _YokiStyleAuthScreenState extends State<YokiStyleAuthScreen> 
    with AudioMixin, TickerProviderStateMixin {
  bool _isLoading = false;
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    );
    _animation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.linear,
    ));
    _animationController.repeat();
    
    // בדיקת התחברות אוטומטית
    _checkAutoLogin();
  }
  
  /// בדיקת התחברות אוטומטית
  Future<void> _checkAutoLogin() async {
    try {
      // בדיקה אם המשתמש בחר לא לזכור פרטי כניסה
      final shouldRemember = await AutoLoginService.shouldRememberMe();
      if (!shouldRemember) {
        debugPrint('User chose not to remember login, signing out');
        // אם המשתמש בחר לא לזכור, נתנתק אותו
        await FirebaseAuth.instance.signOut();
        return;
      }

      final userCredential = await AutoLoginService.autoLogin();
      if (userCredential != null && mounted) {
        // התחברות אוטומטית הצליחה
        await playSuccessSound();
        widget.onLoginSuccess?.call();
      }
    } catch (e) {
      debugPrint('Auto login failed: $e');
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // רקע אנימטיבי - תמונות זזות משמאל לימין
          AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              return Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF1A1A2E),
                      Color(0xFF16213E),
                      Color(0xFF0F3460),
                    ],
                  ),
                ),
                child: Stack(
                  children: [
                    // תמונות רקע אנימטיביות - תנועה משמאל לימין
                    ...List.generate(8, (index) {
                      final screenWidth = MediaQuery.of(context).size.width;
                      final animationOffset = _animation.value * (screenWidth + 200) - 100;
                      
                      return Positioned(
                        left: animationOffset + (index * 150),
                        top: 50 + (index * 80) % 300,
                        child: Transform.rotate(
                          angle: _animation.value * 0.5 * math.pi + index,
                          child: Container(
                            width: 120 + (index * 20),
                            height: 120 + (index * 20),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  Colors.purple.withOpacity(0.4),
                                  Colors.blue.withOpacity(0.3),
                                  Colors.pink.withOpacity(0.2),
                                  Colors.transparent,
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.purple.withOpacity(0.3),
                                  blurRadius: 20,
                                  spreadRadius: 5,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                    // תמונות מטושטשות נוספות - תנועה משמאל לימין
                    ...List.generate(6, (index) {
                      final screenWidth = MediaQuery.of(context).size.width;
                      final animationOffset = (_animation.value * (screenWidth + 300) - 150) * (index % 2 == 0 ? 1 : -1);
                      
                      return Positioned(
                        left: animationOffset + (index * 200),
                        top: 100 + (index * 120) % 400,
                        child: Transform.scale(
                          scale: 0.5 + (math.sin(_animation.value * 2 * math.pi + index) * 0.3),
                          child: Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  Colors.cyan.withOpacity(0.3),
                                  Colors.teal.withOpacity(0.2),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              );
            },
          ),
          
          // תוכן המסך
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // לוגו וכותרת
                    _buildLogoAndTitle(),
                    
                    const SizedBox(height: 25),
                    
                    // הודעה זמנית על פיתוח
                    _buildDevelopmentNotice(),
                    
                    const SizedBox(height: 20),
                    
                    // כפתורי כניסה חברתית (רק גוגל)
                    _buildGoogleButton(),
                    
                    const SizedBox(height: 15),
                    
                    // מפריד
                    _buildDivider(),
                    
                    const SizedBox(height: 15),
                    
                    // כניסה עם אימייל
                    _buildEmailLoginOption(),
                    
                    const SizedBox(height: 15),
                    
                    
                    const SizedBox(height: 20),
                    
                    // קישורים לתנאי שימוש ומדיניות פרטיות
                    _buildTermsAndPrivacyLinks(),
                    
                    // רווח נוסף בתחתית
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDevelopmentNotice() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.orange.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                Icons.construction,
                color: Colors.orange[700],
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'האפליקציה בתהליך פיתוח',
                style: TextStyle(
                  color: Colors.orange[700],
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'כרגע חלק מהפונקציות (כמו תשלומים) עדיין בפיתוח. אנחנו עובדים על זה!',
            style: TextStyle(
              color: Colors.orange[600],
              fontSize: 14,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildLogoAndTitle() {
    return Column(
      children: [
        // לוגו שכונתי
        Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // לב אדום במרכז
              const Icon(
                Icons.favorite,
                size: 20,
                color: Colors.red,
              ),
              // ידיים צבעוניות סביב הלב
              ...List.generate(6, (index) {
                final angle = (index * 60) * (3.14159 / 180);
                final radius = 25.0;
                final x = radius * math.cos(angle);
                final y = radius * math.sin(angle);
                
                return Positioned(
                  left: 40 + x - 6,
                  top: 40 + y - 6,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: [
                        Colors.blue,
                        Colors.green,
                        Colors.orange,
                        Colors.pink,
                        Colors.purple,
                        Colors.yellow,
                      ][index],
                      shape: BoxShape.circle,
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
        
        const SizedBox(height: 12),
        
        // כותרת
        const Text(
          'שכונתי',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        
        const SizedBox(height: 4),
        
        const Text(
          'ברוך הבא',
          style: TextStyle(
            fontSize: 14,
            color: Colors.white70,
          ),
        ),
      ],
    );
  }

  Widget _buildGoogleButton() {
    return _buildSocialButton(
      icon: null, // נשתמש בלוגו מותאם אישית
      customIcon: _buildGoogleLogo(),
      label: 'המשך עם גוגל',
      color: Colors.white,
      textColor: Colors.black87,
      onPressed: _handleGoogleLogin,
    );
  }

  Widget _buildGoogleLogo() {
    return SizedBox(
      width: 18,
      height: 18,
      child: Image.asset(
        'assets/images/google logo.png',
        fit: BoxFit.contain,
        colorBlendMode: BlendMode.dstATop,
      ),
    );
  }

  Widget _buildSocialButton({
    IconData? icon,
    Widget? customIcon,
    required String label,
    required Color color,
    Color textColor = Colors.white,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 42,
      child: ElevatedButton(
        onPressed: _isLoading ? null : () async {
          await playButtonSound();
          onPressed();
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: textColor,
          elevation: 8,
          shadowColor: Colors.black.withOpacity(0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (customIcon != null) 
              customIcon
            else if (icon != null)
              Icon(icon, size: 18, color: textColor),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 1,
            color: Colors.white.withOpacity(0.3),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'או',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 14,
            ),
          ),
        ),
        Expanded(
          child: Container(
            height: 1,
            color: Colors.white.withOpacity(0.3),
          ),
        ),
      ],
    );
  }


  Widget _buildEmailLoginOption() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: _isLoading ? null : () async {
              await playButtonSound();
              _showEmailLoginDialog();
            },
            icon: const Icon(Icons.email, size: 20, color: Colors.white),
            label: const Text(
              'התחבר עם שכונתי',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple.withOpacity(0.8),
              foregroundColor: Colors.white,
              elevation: 6,
              shadowColor: Colors.purple.withOpacity(0.3),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }


  Widget _buildTermsAndPrivacyLinks() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          Text(
            'על ידי המשך השימוש באפליקציה, אתה מסכים ל:',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withOpacity(0.8),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: () => _showTermsAndPrivacyDialog(),
                child: Text(
                  'תנאי שימוש',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.blue[300],
                    decoration: TextDecoration.underline,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Text(
                ' ו-',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.8),
                ),
              ),
              GestureDetector(
                onTap: () => _showTermsAndPrivacyDialog(),
                child: Text(
                  'מדיניות פרטיות',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.blue[300],
                    decoration: TextDecoration.underline,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showTermsAndPrivacyDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('תנאי שימוש ומדיניות פרטיות'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'תנאי שימוש',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'ברוכים הבאים לאפליקציית "שכונתי". השימוש באפליקציה כפוף לתנאים הבאים. אנא קרא אותם בעיון:',
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 10),
                _buildBulletPoint(
                    'גיל מינימלי: השימוש באפליקציה מיועד למשתמשים מעל גיל 18 בלבד. החברה שומרת על זכותה לבקש הוכחת גיל בכל שלב.'),
                _buildBulletPoint(
                    'עזרה הדדית: האפליקציה מיועדת לעזרה הדדית בין שכנים - חיבור בין מבקשי עזרה לנותני עזרה בקהילה המקומית.'),
                _buildBulletPoint(
                    'אחריות המשתמש: המשתמשים אחראים באופן בלעדי לתוכן שהם מפרסמים ולכל אינטראקציה עם משתמשים אחרים. שכונתי היא מתווכת בלבד.'),
                _buildBulletPoint(
                    'בטיחות: במקרה של חשד לסכנה או התנהגות לא הולמת, יש לדווח מיד לתמיכה או לרשויות הרלוונטיות.'),
                _buildBulletPoint(
                    'פרטיות: אנו מחויבים להגן על פרטיותך. המידע האישי שלך ישמש בהתאם למדיניות הפרטיות שלנו.'),
                _buildBulletPoint(
                    'הגבלת אחריות: האפליקציה ניתנת "כמות שהיא" (AS IS). אנו לא מתחייבים לזמינות רציפה, ללא תקלות או ללא שגיאות.'),
                _buildBulletPoint(
                    'ביטול בקשות: ניתן לבטל בקשה עד 30 דקות ממועד הפרסום. ביטול מאוחר יותר מותנה בהסכמת נותן השירות.'),
                _buildBulletPoint(
                    'שינויים בתנאים: אנו שומרים לעצמנו את הזכות לשנות את תנאי השימוש מעת לעת. שינויים ייכנסו לתוקף עם פרסומם באפליקציה.'),
                const SizedBox(height: 20),
                Text(
                  'מדיניות פרטיות',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'מדיניות פרטיות זו מתארת כיצד אנו אוספים, משתמשים ומגנים על המידע האישי שלך באפליקציית "שכונתי":',
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 10),
                _buildBulletPoint(
                    'איסוף מידע: אנו אוספים מידע שאתה מספק לנו ישירות (כגון שם, אימייל, מיקום גיאוגרפי) ומידע שנאסף אוטומטית (כגון נתוני שימוש).'),
                _buildBulletPoint(
                    'שימוש במידע: אנו משתמשים במידע כדי לספק, לתחזק ולשפר את השירותים שלנו, להתאים אישית את חווית המשתמש, ולתקשר איתך.'),
                _buildBulletPoint(
                    'שיתוף מידע: אנו לא נשתף את המידע האישי שלך עם צדדים שלישיים ללא הסכמתך, למעט במקרים הנדרשים על פי חוק או לצורך מתן השירותים.'),
                _buildBulletPoint(
                    'אבטחת מידע: אנו נוקטים באמצעי אבטחה סבירים כדי להגן על המידע שלך מפני גישה בלתי מורשית, שימוש או חשיפה. מיקום גיאוגרפי נשמר באופן מוצפן.'),
                _buildBulletPoint(
                    'בקרת פרטיות: יש לך בקרה מלאה על מי רואה את המידע שלך. תוכל להגדיר רמות פרטיות שונות עבור בקשות שונות.'),
                _buildBulletPoint(
                    'עוגיות וטכנולוגיות דומות: אנו עשויים להשתמש בעוגיות ובטכנולוגיות דומות כדי לשפר את חווית המשתמש ולנתח את השימוש באפליקציה.'),
                _buildBulletPoint(
                    'זכויותיך: יש לך זכות לגשת, לתקן או למחוק את המידע האישי שלך. למימוש זכויות אלו, אנא צור קשר איתנו.'),
                _buildBulletPoint(
                    'שינויים במדיניות: אנו רשאים לעדכן מדיניות פרטיות זו מעת לעת. שינויים ייכנסו לתוקף עם פרסומם באפליקציה.'),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning, color: Colors.red[600], size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'חשוב: עליך לאשר את תנאי השימוש ומדיניות הפרטיות כדי להמשיך להשתמש באפליקציה.',
                          style: TextStyle(
                              fontSize: 12, 
                              fontWeight: FontWeight.bold,
                              color: Colors.red[800]),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('הבנתי'),
          ),
        ],
      ),
    );
  }

  Widget _buildBulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(fontSize: 14)),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 14)),
          ),
        ],
      ),
    );
  }

  void _showEmailLoginDialog() {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    bool isSignUp = false;
    bool obscurePassword = true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(isSignUp ? 'הרשמה' : 'התחברות'),
          content: SizedBox(
            width: 300,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(
                    labelText: 'אימייל',
                    prefixIcon: Icon(Icons.email),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: passwordController,
                  decoration: InputDecoration(
                    labelText: 'סיסמה',
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(obscurePassword ? Icons.visibility : Icons.visibility_off),
                      onPressed: () => setState(() => obscurePassword = !obscurePassword),
                    ),
                    border: const OutlineInputBorder(),
                  ),
                  obscureText: obscurePassword,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Checkbox(
                      value: isSignUp,
                      onChanged: (value) => setState(() => isSignUp = value ?? false),
                    ),
                    const Text('הרשמה חדשה'),
                  ],
                ),
                if (!isSignUp) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _showForgotPasswordDialog();
                      },
                      child: const Text(
                        'שכחתי סיסמה',
                        style: TextStyle(
                          color: Colors.blue,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('ביטול'),
            ),
            ElevatedButton(
              onPressed: () async {
                // סגירת הדיאלוג לפני ההתחברות
                if (mounted) {
                  Navigator.pop(context);
                }
                await _handleEmailLogin(
                  emailController.text,
                  passwordController.text,
                  isSignUp,
                );
              },
              child: Text(isSignUp ? 'הרשמה' : 'התחברות'),
            ),
          ],
        ),
      ),
    );
  }

  void _showForgotPasswordDialog() {
    final emailController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('שכחתי סיסמה'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
            const Text(
              'הזן את כתובת האימייל שלך ונשלח לך קישור לאיפוס הסיסמה:',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(
                labelText: 'אימייל',
                prefixIcon: Icon(Icons.email),
                border: OutlineInputBorder(),
                hintText: 'example@email.com',
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning, color: Colors.orange[600], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'וודא שהאימייל שייך לך! אם תזין אימייל של מישהו אחר, הוא יקבל את קישור איפוס הסיסמה.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange[700],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ביטול'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (emailController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('אנא הזן כתובת אימייל'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              Navigator.pop(context);
              await _handleForgotPassword(emailController.text);
            },
            child: const Text('שלח קישור'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleForgotPassword(String email) async {
    try {
      setState(() => _isLoading = true);
      
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('קישור לאיפוס סיסמה נשלח ל-$email'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = 'שגיאה בשליחת אימייל איפוס סיסמה';
        
        if (e.toString().contains('user-not-found')) {
          errorMessage = 'לא נמצא משתמש עם כתובת אימייל זו';
        } else if (e.toString().contains('invalid-email')) {
          errorMessage = 'כתובת אימייל לא תקינה';
        } else if (e.toString().contains('too-many-requests')) {
          errorMessage = 'יותר מדי בקשות. נסה שוב מאוחר יותר';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
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

  Future<void> _handleEmailLogin(String email, String password, bool isSignUp) async {
    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('אנא מלא את כל השדות'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      if (isSignUp) {
        // בדיקה אם המשתמש כבר אישר את תנאי השימוש
        final hasAcceptedTerms = await TermsService.hasUserAcceptedTerms();
        
        if (!hasAcceptedTerms) {
          // הצגת מסך תנאי שימוש ומדיניות פרטיות
          if (mounted) {
            final result = await Navigator.push<bool>(
              context,
              MaterialPageRoute(
                builder: (context) => TermsAndPrivacyScreen(
                  onAccept: () async {
                    // שמירת אישור התנאים
                    await TermsService.acceptTerms();
                    Navigator.pop(context, true);
                  },
                  onDecline: () {
                    // המשתמש לא הסכים - ביטול הרשמה
                    Navigator.pop(context, false);
                  },
                ),
              ),
            );
            
            // אם המשתמש לא אישר את התנאים, לא נמשיך
            if (result != true) {
              return;
            }
          }
        }
        
        final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
        
        // יצירת פרופיל משתמש אורח ב-Firestore
        final now = DateTime.now();
        final guestTrialEndDate = now.add(const Duration(days: 30));
        
        final userData = {
          'uid': cred.user!.uid,
          'displayName': email.split('@')[0], // שם משתמש מהאימייל
          'email': email,
          'userType': 'guest', // כל המשתמשים החדשים נרשמים כאורחים
          'createdAt': Timestamp.fromDate(now),
          'isSubscriptionActive': true, // תקופת אורח פעילה
          'subscriptionStatus': 'active',
          'emailVerified': true, // זמנית - ללא אימות
          'accountStatus': 'active', // סטטוס חשבון פעיל
          'guestTrialStartDate': Timestamp.fromDate(now),
          'guestTrialEndDate': Timestamp.fromDate(guestTrialEndDate),
          'maxRequestsPerMonth': 10, // גבוה יותר לאורחים
          'maxRadius': 3.0, // 3 ק"מ לאורחים
          'canCreatePaidRequests': true, // אורחים יכולים ליצור בקשות בתשלום
          'businessCategories': [], // יבחרו במסך הבא
          'hasAcceptedTerms': true,
        };
        
        await FirebaseFirestore.instance
            .collection('users')
            .doc(cred.user!.uid)
            .set(userData);
        
        await playSuccessSound();
        
        // מעבר למסך בחירת קטגוריות
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
                builder: (context) => GuestCategorySelectionScreen(
                  displayName: userData['displayName'] as String,
                  email: userData['email'] as String,
                ),
            ),
          );
          return;
        }
      } else {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
        
        // המשך ישירות ללא בדיקת אימות אימייל (זמנית)
        
        await playSuccessSound();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('התחברות הושלמה בהצלחה!'),
            backgroundColor: Colors.green,
          ),
        );
        
        // הצגת דיאלוג "זכור אותי" רק בהתחברות (לא בהרשמה)
        if (mounted) {
          await showRememberMeDialog(
            context: context,
            loginMethod: 'email',
            onRemember: () async {
              await AutoLoginService.saveRememberMePreference(
                rememberMe: true,
                loginMethod: 'email',
                email: email,
                password: password,
              );
              await AutoLoginService.onSuccessfulLogin();
              widget.onLoginSuccess?.call();
            },
            onDontRemember: () async {
              await AutoLoginService.saveRememberMePreference(
                rememberMe: false,
                loginMethod: 'email',
              );
              await AutoLoginService.onSuccessfulLogin();
              widget.onLoginSuccess?.call();
            },
          );
        }
      }
      
      // אם זה הרשמה, לא נציג דיאלוג "זכור אותי"
      if (isSignUp) {
        await AutoLoginService.onSuccessfulLogin();
        widget.onLoginSuccess?.call();
      }
    } catch (e) {
      await playErrorSound();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('שגיאה: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }


  Future<void> _handleGoogleLogin() async {
    setState(() => _isLoading = true);
    try {
      final user = await GoogleAuthService.signInWithGoogle();
      if (user != null) {
        await playSuccessSound();
        
        // בדיקה אם המשתמש כבר קיים במערכת
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        
        if (!userDoc.exists) {
          // משתמש חדש - יצירת פרופיל אורח
          final now = DateTime.now();
          final guestTrialEndDate = now.add(const Duration(days: 30));
          
          final userData = {
            'uid': user.uid,
            'displayName': user.displayName ?? user.email?.split('@')[0] ?? 'משתמש',
            'email': user.email ?? '',
            'userType': 'guest', // משתמש חדש כאורח
            'createdAt': Timestamp.fromDate(now),
            'isSubscriptionActive': true, // תקופת אורח פעילה
            'subscriptionStatus': 'active',
            'emailVerified': user.emailVerified,
            'accountStatus': 'active',
            'guestTrialStartDate': Timestamp.fromDate(now),
            'guestTrialEndDate': Timestamp.fromDate(guestTrialEndDate),
            'maxRequestsPerMonth': 10, // גבוה יותר לאורחים
            'maxRadius': 3.0, // 3 ק"מ לאורחים
            'canCreatePaidRequests': true, // אורחים יכולים ליצור בקשות בתשלום
            'businessCategories': [], // יבחרו במסך הבא
            'hasAcceptedTerms': true,
          };
          
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .set(userData);
          
          // מעבר למסך בחירת קטגוריות
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => GuestCategorySelectionScreen(
                  displayName: userData['displayName'] as String,
                  email: userData['email'] as String,
                ),
              ),
            );
            return;
          }
        } else {
          // משתמש קיים - בדיקת תנאי שימוש
          final hasAcceptedTerms = await TermsService.hasUserAcceptedTerms();
          
          if (!hasAcceptedTerms) {
            // הצגת מסך תנאי שימוש ומדיניות פרטיות
            if (mounted) {
              final result = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (context) => TermsAndPrivacyScreen(
                    onAccept: () async {
                      // שמירת אישור התנאים
                      await TermsService.acceptTerms();
                      Navigator.pop(context, true);
                    },
                    onDecline: () {
                      // המשתמש לא הסכים - התנתקות
                      FirebaseAuth.instance.signOut();
                      Navigator.pop(context, false);
                    },
                  ),
                ),
              );
              
              // אם המשתמש לא אישר את התנאים, לא נמשיך
              if (result != true) {
                return;
              }
            }
          }
          
          // הצגת דיאלוג "זכור אותי"
          if (mounted) {
            await showRememberMeDialog(
              context: context,
              loginMethod: 'google',
              onRemember: () async {
                await AutoLoginService.saveRememberMePreference(
                  rememberMe: true,
                  loginMethod: 'google',
                  token: 'google_token', // כאן תצטרך לקבל את ה-token האמיתי
                );
                await AutoLoginService.onSuccessfulLogin();
                widget.onLoginSuccess?.call();
              },
              onDontRemember: () async {
                await AutoLoginService.saveRememberMePreference(
                  rememberMe: false,
                  loginMethod: 'google',
                );
                await AutoLoginService.onSuccessfulLogin();
                widget.onLoginSuccess?.call();
              },
            );
          }
        }
      } else {
        // הצג הודעת שגיאה ידידותית
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('התחברות נכשלה - נסה שוב'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      await playErrorSound();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('שגיאה בהתחברות: $e'),
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

}
