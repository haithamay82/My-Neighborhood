# מדריך יצירת צלילים לאפליקציה

## כלים מומלצים ליצירת צלילים:

### 1. **Audacity (חינמי)**
- הורדה: https://www.audacityteam.org/
- יצירת צלילים פשוטים:
  - Generate > Tone (צלילים בסיסיים)
  - Generate > Chirp (צלילי התראה)
  - Generate > Silence (הפסקות)

### 2. **Online Tone Generator**
- אתר: https://www.szynalski.com/tone-generator/
- יצירת צלילים פשוטים ישירות בדפדפן

### 3. **Bfxr (חינמי)**
- אתר: https://www.bfxr.net/
- יצירת צלילי משחקים ו-UI

## צלילים מומלצים ליצירה:

### **button_click.mp3**
- צליל קצר (0.1-0.3 שניות)
- תדר: 800-1200 Hz
- צורה: sine wave עם decay מהיר

### **success.mp3**
- צליל נעים (0.5-1.0 שניות)
- תדרים: 523-659-784 Hz (C-E-G)
- צורה: sine wave עם sustain

### **error.mp3**
- צליל חד (0.3-0.6 שניות)
- תדר: 200-400 Hz
- צורה: square wave או sawtooth

### **new_message.mp3**
- צליל התראה (0.4-0.8 שניות)
- תדרים: 800-1000-1200 Hz
- צורה: sine wave עם attack מהיר

## הגדרות מומלצות:
- **פורמט**: MP3
- **איכות**: 44.1 kHz, 16-bit
- **גודל**: עד 50KB לכל קובץ
- **משך**: 0.1-2.0 שניות
- **עוצמה**: -12dB עד -6dB

## הוראות שמירה:
1. צור את הצליל בכלי שבחרת
2. שמור כ-MP3
3. העבר לתיקייה `assets/sounds/`
4. ודא שהשם תואם ל-`AudioEvent` enum
