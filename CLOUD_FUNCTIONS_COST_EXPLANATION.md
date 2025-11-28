# הסבר עלויות Cloud Functions

## Free Tier (חינם):

Firebase/Google Cloud נותן **חינם**:
- ✅ **2 מיליון קריאות לחודש** (invocations)
- ✅ **400,000 GB-seconds** זמן ביצוע
- ✅ **200,000 GHz-seconds** CPU time

---

## העלויות:

### 1. **Invocation (קריאה לפונקציה):**
- **חינם**: עד 2 מיליון קריאות/חודש
- **אחרי**: $0.40 לכל מיליון קריאות

### 2. **Compute Time (זמן ביצוע):**
- **חינם**: עד 400,000 GB-seconds/חודש
- **אחרי**: $0.0000025 לשנייה (GB-second)

### 3. **Min Instances (instances תמיד פעילים):**
- **עלות קבועה**: ~$0.40 לחודש לכל instance
- **רק `sendCustomVerificationEmail`** יש לה `minInstances: 1`

---

## ניתוח הפונקציות שלך:

### חינמיות לחלוטין (עד free tier):

1. **`deleteUserFromAuth`** - 0 קריאות/24 שעות → **חינם**
2. **`sendNotification`** - 0 קריאות/24 שעות → **חינם**
3. **`notifyServiceProvidersOnNewRequ...`** - 1 קריאה/24 שעות → **חינם**
4. **`paymeWebhook`** - 0 קריאות/24 שעות → **חינם**
5. **`checkSubscriptionReminders`** - 1,437 קריאות/24 שעות → **חינם** (זה ~43,000/חודש, עדיין בתוך 2 מיליון)
6. **`sendNotificationFromCollection`** - 6 קריאות/24 שעות → **חינם**
7. **`onNewRequestCreated`** - 1 קריאה/24 שעות → **חינם**
8. **`checkGuestTrialExpiry`** - 1,437 קריאות/24 שעות → **חינם**
9. **`contactFormHandler`** - 0 קריאות/24 שעות → **חינם**
10. **`api`** - 0 קריאות/24 שעות → **חינם**
11. **`sendPushNotification`** - 0 קריאות/24 שעות → **חינם**
12. **`deleteAllUsersFromAuth`** - 0 קריאות/24 שעות → **חינם**

### בתשלום קבוע:

13. **`sendCustomVerificationEmail`** - 4 קריאות/24 שעות + `minInstances: 1` → **~$0.40/חודש**

---

## חישוב עלות חודשית:

### אם יש לך:
- **100 הרשמות בחודש** → 100 קריאות ל-`sendCustomVerificationEmail`
- **100 קריאות** = **חינם** (בתוך 2 מיליון)
- **`minInstances: 1`** = **$0.40/חודש**

### סה"כ:
- **$0.40/חודש** (רק בגלל `minInstances: 1`)

---

## אם תסיר `minInstances: 1`:

אם תשנה את `sendCustomVerificationEmail` ל-`minInstances: 0`:
- **כל הפונקציות חינמיות** (עד free tier)
- אבל יהיה **cold start** של 2-5 דקות

---

## סיכום:

| פונקציה | עלות |
|---------|------|
| **12 פונקציות** | **חינם** (עד free tier) |
| **`sendCustomVerificationEmail`** | **$0.40/חודש** (בגלל `minInstances: 1`) |
| **סה"כ** | **~$0.40/חודש** |

---

## המלצה:

אם יש לך פחות מ-100 הרשמות ביום:
- **$0.40/חודש** זה סביר מאוד
- האימייל נשלח תוך 5-10 שניות (ללא cold start)

אם יש לך יותר מ-100 הרשמות ביום:
- כדאי לשקול **SendGrid** (חינם עד 100/יום)
- או להסיר `minInstances: 1` ולסבול cold start

---

## הערה:

**כל הפונקציות האחרות חינמיות** - רק `sendCustomVerificationEmail` עולה כסף בגלל `minInstances: 1`.

