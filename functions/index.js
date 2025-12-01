const functions = require('firebase-functions');
const admin = require('firebase-admin');
const express = require('express');
const cors = require('cors');
const nodemailer = require('nodemailer');

// Initialize Firebase Admin
admin.initializeApp();

// Create Express app for CORS proxy
const app = express();
app.use(cors({
  origin: ['https://nearme-970f3.web.app', 'https://nearme-970f3.firebaseapp.com'],
  methods: ['GET', 'HEAD', 'OPTIONS'],
  allowedHeaders: ['Content-Type'],
  credentials: true
}));

// Handle OPTIONS requests for CORS
app.options('/storage-proxy/:bucket/:path(*)', (req, res) => {
  res.set({
    'Access-Control-Allow-Origin': 'https://nearme-970f3.web.app',
    'Access-Control-Allow-Methods': 'GET, HEAD, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type',
    'Access-Control-Allow-Credentials': 'true',
  });
  res.status(200).end();
});

// Proxy for Firebase Storage images to handle CORS
app.get('/storage-proxy/:bucket/:path(*)', async (req, res) => {
  try {
    const { bucket, path } = req.params;
    const file = admin.storage().bucket(bucket).file(decodeURIComponent(path));
    
    const [exists] = await file.exists();
    if (!exists) {
      return res.status(404).send('File not found');
    }
    
    const [metadata] = await file.getMetadata();
    const [contents] = await file.download();
    
    res.set({
      'Content-Type': metadata.contentType,
      'Cache-Control': 'public, max-age=3600',
      'Access-Control-Allow-Origin': 'https://nearme-970f3.web.app',
      'Access-Control-Allow-Methods': 'GET, HEAD, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type',
      'Access-Control-Allow-Credentials': 'true',
    });
    
    res.send(contents);
  } catch (error) {
    console.error('Proxy error:', error);
    res.status(500).send('Internal server error');
  }
});

// Export the Express app as a Firebase Function
exports.api = functions.https.onRequest(app);

// Cloud Function למחיקת משתמש מ-Firebase Authentication
exports.deleteUserFromAuth = functions.https.onCall(async (data, context) => {
  try {
    // בדיקה שהמשתמש הוא מנהל
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
    }

    const userEmail = context.auth.token.email;
    const adminEmails = ['admin@gmail.com', 'haitham.ay82@gmail.com'];
    
    if (!adminEmails.includes(userEmail)) {
      throw new functions.https.HttpsError('permission-denied', 'Only admins can delete users');
    }

    const { userId } = data;
    
    if (!userId) {
      throw new functions.https.HttpsError('invalid-argument', 'userId is required');
    }

    // בדיקה שהמשתמש לא מנהל
    const userDoc = await admin.firestore().collection('users').doc(userId).get();
    if (userDoc.exists) {
      const userData = userDoc.data();
      const email = userData.email;
      if (adminEmails.includes(email)) {
        throw new functions.https.HttpsError('permission-denied', 'Cannot delete admin users');
      }
    }

    // מחיקת המשתמש מ-Firebase Authentication
    await admin.auth().deleteUser(userId);
    
    console.log(`Successfully deleted user ${userId} from Authentication`);
    
    return { success: true, userId: userId };
  } catch (error) {
    console.error('Error deleting user from Authentication:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});

// Cloud Function למחיקת כל המשתמשים חוץ ממנהלים מ-Firebase Authentication
exports.deleteAllUsersFromAuth = functions.https.onCall(async (data, context) => {
  try {
    // בדיקה שהמשתמש הוא מנהל
    if (!context.auth) {
      console.error('UNAUTHENTICATED: No auth context provided');
      throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
    }

    if (!context.auth.token || !context.auth.token.email) {
      console.error('UNAUTHENTICATED: No email in auth token');
      throw new functions.https.HttpsError('unauthenticated', 'User email not found in token');
    }

    const userEmail = context.auth.token.email;
    const adminEmails = ['admin@gmail.com', 'haitham.ay82@gmail.com'];
    
    console.log('Checking admin access for user:', userEmail);
    
    if (!adminEmails.includes(userEmail)) {
      console.error('PERMISSION DENIED: User is not admin:', userEmail);
      throw new functions.https.HttpsError('permission-denied', 'Only admins can delete users');
    }
    
    console.log('Admin access granted for:', userEmail);

    // קבלת כל המשתמשים ישירות מ-Firebase Authentication
    const adminEmailsSet = new Set(adminEmails);
    let deletedCount = 0;
    const errors = [];
    let nextPageToken;

    // מחיקת כל המשתמשים חוץ ממנהלים
    do {
      // קבלת רשימת משתמשים מ-Authentication (עד 1000 בכל פעם)
      const listUsersResult = await admin.auth().listUsers(1000, nextPageToken);
      
      for (const userRecord of listUsersResult.users) {
        const email = userRecord.email;
        
        // דילוג על מנהלים
        if (email && adminEmailsSet.has(email)) {
          console.log(`Skipping admin user: ${email} (${userRecord.uid})`);
          continue;
        }

        const userId = userRecord.uid;
        
        try {
          // מחיקת המשתמש מ-Firebase Authentication
          await admin.auth().deleteUser(userId);
          deletedCount++;
          console.log(`Successfully deleted user ${userId} (${email || 'no email'}) from Authentication`);
        } catch (error) {
          console.error(`Error deleting user ${userId} from Authentication:`, error);
          errors.push({ userId, email: email || 'no email', error: error.message });
        }
      }

      nextPageToken = listUsersResult.pageToken;
    } while (nextPageToken);

    console.log(`Successfully deleted ${deletedCount} users from Authentication`);
    
    return { 
      success: true, 
      deletedCount: deletedCount,
      errors: errors.length > 0 ? errors : undefined
    };
  } catch (error) {
    console.error('Error deleting all users from Authentication:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});

// Cloud Function for sending push notifications from notifications collection
exports.sendNotificationFromCollection = functions.firestore
  .document('notifications/{notificationId}')
  .onCreate(async (snap, context) => {
    try {
      const notificationData = snap.data();
      const { toUserId, title, message, type, ...extraData } = notificationData;
      
      console.log('Sending notification from collection to user:', toUserId);
      
      // Get user's FCM token
      const userDoc = await admin.firestore().collection('users').doc(toUserId).get();
      if (!userDoc.exists) {
        console.error('User not found:', toUserId);
        return;
      }
      
      const userData = userDoc.data();
      const fcmToken = userData.fcmToken;
      
      if (!fcmToken) {
        console.error('No FCM token for user:', toUserId);
        return;
      }
      
      // Send FCM message
      const fcmMessage = {
        token: fcmToken,
        notification: {
          title: title,
          body: message,
        },
        data: {
          type: type || 'general',
          ...extraData,
        },
        android: {
          priority: 'high',
          notification: {
            sound: 'default',
            channelId: 'subscription_channel',
            clickAction: 'FLUTTER_NOTIFICATION_CLICK',
            icon: 'ic_launcher',
            color: '#FFD700',
          },
        },
        apns: {
          payload: {
            aps: {
              sound: 'default',
              badge: 1,
              alert: {
                title: title,
                body: message,
              },
            },
          },
        },
      };
      
      const response = await admin.messaging().send(fcmMessage);
      console.log('Successfully sent notification from collection:', response);
      
    } catch (error) {
      console.error('Error sending notification from collection:', error);
    }
  });

// Cloud Function for sending push notifications
exports.sendPushNotification = functions.firestore
  .document('push_notifications/{notificationId}')
  .onCreate(async (snap, context) => {
    try {
      const notificationData = snap.data();
      const { userId, title, body, payload, createdAt, ...extraData } = notificationData;
      
      // Flatten payload object to string key-value pairs
      let payloadData = {};
      if (payload && typeof payload === 'object') {
        payloadData = {
          type: payload.type || 'general',
          screen: payload.screen || 'home',
        };
        // Add requestId if it exists in extraData
        if (extraData.requestId) {
          payloadData.requestId = extraData.requestId;
        }
      } else {
        payloadData = {
          type: 'general',
          screen: 'home',
        };
      }
      
      console.log('Sending push notification to user:', userId);
      
      // Get user's FCM token
      const userDoc = await admin.firestore().collection('users').doc(userId).get();
      if (!userDoc.exists) {
        console.error('User not found:', userId);
        return;
      }
      
      const userData = userDoc.data();
      const fcmToken = userData.fcmToken;
      
      if (!fcmToken) {
        console.error('No FCM token for user:', userId);
        return;
      }
      
      // Handle chat message notifications
      let fcmNotificationData = {
        type: payloadData.type,
        screen: payloadData.screen,
        click_action: 'FLUTTER_NOTIFICATION_CLICK',
        sound: 'default',
      };
      
      // Add chatId if it exists in extraData
      if (extraData.data && extraData.data.chatId) {
        fcmNotificationData.chatId = extraData.data.chatId;
        fcmNotificationData.senderName = extraData.data.senderName || '';
        fcmNotificationData.requestTitle = extraData.data.requestTitle || '';
      }
      
      // Send FCM message
      const message = {
        token: fcmToken,
        notification: {
          title: title || 'התראה חדשה',
          body: body || 'יש לך הודעה חדשה באפליקציה שכונתי',
        },
        data: fcmNotificationData,
        android: {
          priority: 'high',
          notification: {
            sound: 'default',
            channelId: 'subscription_channel',
            clickAction: 'FLUTTER_NOTIFICATION_CLICK',
            icon: 'ic_launcher',
            color: '#FFD700',
          },
        },
        apns: {
          payload: {
            aps: {
              sound: 'default',
              badge: 1,
              alert: {
                title: title,
                body: body,
              },
            },
          },
        },
      };
      
      const response = await admin.messaging().send(message);
      console.log('✅ Successfully sent message:', response);

      // Delete notification document after sending
      await snap.ref.delete();
      
    } catch (error) {
      console.error('Error sending push notification:', error);
    }
  });

// Simple notification function
exports.sendNotification = functions.https.onCall(async (data, context) => {
  try {
    const { userId, title, body, payload } = data;
    
    console.log('Sending notification to user:', userId);
    
    // Get user's FCM token
    const userDoc = await admin.firestore().collection('users').doc(userId).get();
    if (!userDoc.exists) {
      throw new Error('User not found');
    }
    
    const userData = userDoc.data();
    const fcmToken = userData.fcmToken;
    
    if (!fcmToken) {
      throw new Error('No FCM token for user');
    }
    
    // Send notification
    const message = {
      token: fcmToken,
      notification: {
        title: title,
        body: body,
      },
      data: {
        payload: payload || '',
        click_action: 'FLUTTER_NOTIFICATION_CLICK',
      },
      android: {
        priority: 'high',
        notification: {
          sound: 'default',
          channelId: 'subscription_channel',
          clickAction: 'FLUTTER_NOTIFICATION_CLICK',
        },
      },
    };
    
    const response = await admin.messaging().send(message);
    console.log('Successfully sent message:', response);
    
    return { success: true, messageId: response };
  } catch (error) {
    console.error('Error sending notification:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});

// Helper function to create receipt via PayMe Documents API
async function createReceiptForPayment(transactionId, paymentData, webhookData, amountIls, buyerEmail, buyerName) {
  try {
    console.log(`🧾 Starting receipt creation for payment: ${transactionId}`);
    
    // Check idempotency - if receipt already exists, skip creation
    const paymentRef = admin.firestore().collection('payments').doc(transactionId);
    const paymentDoc = await paymentRef.get();
    
    if (!paymentDoc.exists) {
      console.error(`❌ Payment document not found for receipt creation: ${transactionId}`);
      return;
    }
    
    const existingPaymentData = paymentDoc.data();
    if (existingPaymentData.receipt_url) {
      console.log(`✅ Receipt already exists for payment ${transactionId}, skipping creation`);
      return;
    }
    
    // Get PayMe API key from environment (for Authorization header)
    const paymeApiKey = process.env.PAYME_API_KEY || functions.config().payme?.api_key;
    console.log(`🔑 PAYME_API_KEY check: ${paymeApiKey ? 'Found (length: ' + paymeApiKey.length + ')' : 'NOT FOUND'}`);
    if (!paymeApiKey) {
      console.error('❌ PAYME_API_KEY not configured');
      await paymentRef.update({
        receipt_error: 'PAYME_API_KEY not configured',
        receipt_error_at: admin.firestore.FieldValue.serverTimestamp(),
      });
      return;
    }
    
    // Get PayMe Client Key (different from API key - this is the client identifier)
    // According to PayMe support: should be 'paid_vA3PGRAL' and NOT the API key
    const paymeClientKey = 'paid_vA3PGRAL';
    console.log(`🔑 PayMe Client Key: ${paymeClientKey}`);
    
    // Get PayMe Seller ID - according to PayMe support, we should use seller_payme_id
    const sellerPaymeId = 'MPL17601-96851APW-EG42UA4J-RPUPW2AZ';
    console.log(`🔑 Seller PayMe ID: ${sellerPaymeId}`);
    console.log(`🔑 PayMe API Key (first 10 chars): ${paymeApiKey ? paymeApiKey.substring(0, 10) + '...' : 'NOT FOUND'}`);
    
    // Extract buyer information - PRIORITIZE PayMe webhook data (from payment form) over app user data
    // PayMe webhook may contain: buyer_name, buyer_email, first_name, last_name, email, etc.
    // BIT payment form also sends email in the webhook - check all possible email fields
    const paymeBuyerName = webhookData.buyer_name || 
                           (webhookData.first_name && webhookData.last_name ? `${webhookData.first_name} ${webhookData.last_name}` : null) ||
                           webhookData.first_name || 
                           webhookData.last_name ||
                           webhookData.customer_name ||
                           webhookData.name;
    // Check all possible email fields from PayMe/BIT webhook
    const paymeBuyerEmail = webhookData.buyer_email || 
                           webhookData.email || 
                           webhookData.customer_email ||
                           webhookData.user_email ||
                           webhookData.payer_email ||
                           webhookData.billing_email;
    
    // Use PayMe data first, then fallback to function parameters, then payment data, then user data
    const buyerNameFinal = paymeBuyerName || 
                          buyerName || 
                          paymentData.buyer_name || 
                          paymentData.userName || 
                          paymentData.name || 
                          'לקוח';
    
    // For email, prioritize PayMe webhook email (from payment form) over app user email
    const buyerEmailFinal = paymeBuyerEmail || 
                           buyerEmail || 
                           paymentData.buyer_email || 
                           paymentData.email || 
                           paymentData.userEmail || 
                           '';
    
    console.log(`👤 Buyer info extraction:`);
    console.log(`   - PayMe webhook name: ${paymeBuyerName || 'NOT FOUND'}`);
    console.log(`   - PayMe webhook email: ${paymeBuyerEmail || 'NOT FOUND'}`);
    console.log(`   - Function param name: ${buyerName || 'NOT FOUND'}`);
    console.log(`   - Function param email: ${buyerEmail || 'NOT FOUND'}`);
    console.log(`   - Final name: ${buyerNameFinal}`);
    console.log(`   - Final email: ${buyerEmailFinal}`);
    if (!buyerEmailFinal) {
      console.warn(`⚠️ WARNING: No buyer email found for receipt! Available data:`, {
        buyerEmail,
        webhookEmail: webhookData.buyer_email,
        paymentDataEmail: paymentData.email,
        paymentDataUserEmail: paymentData.userEmail,
        paymentDataKeys: Object.keys(paymentData || {}),
      });
    }
    
    // Get product name from payment data (not hardcoded)
    const productName = paymentData.productName || 'מנוי שכונתי';
    console.log(`📦 Product name: ${productName}, Amount: ${amountIls} ILS`);
    
    // Get payme_sale_id from webhook or payment data to link receipt to the original sale
    const paymeSaleId = webhookData.payme_sale_id || webhookData['payme_sale_id'] || 
                        paymentData.payme_sale_id || existingPaymentData.payme_sale_id;
    console.log(`🔗 PayMe Sale ID: ${paymeSaleId || 'NOT FOUND'}`);
    
    // Build receipt document payload according to PayMe Documents API documentation
    // https://docs.payme.io/docs/payments/0bfed756bfbe1-create-document
    // According to the API, we need to use cash, credit_card, bank_transfer, paypal, or cheques objects
    // Since payment was made via PayMe (which can be card or Bit), we'll use credit_card
    // PayMe API requires both seller_payme_id AND payme_client_key in the payload
    // According to PayMe support: payme_client_key should be 'paid_vA3PGRAL' (NOT the API key)
    // Adding payme_sale_id to link the receipt to the original sale
    const receiptPayload = {
      seller_payme_id: sellerPaymeId,
      payme_client_key: paymeClientKey, // PayMe Client Key: 'paid_vA3PGRAL' (NOT the API key)
      doc_type: 100, // Receipt (קבלה) - 100 for receipt, 200 for invoice
      buyer_name: buyerNameFinal,
      buyer_email: buyerEmailFinal,
      currency: 'ILS',
      doc_title: 'קבלה מס\' על תשלום שכונתי', // Changed from "הזמנה" to "קבלה מס'"
      // Try to add seller/business information if PayMe API supports it
      // Note: Some fields may need to be configured in PayMe Console
      seller_name: 'שכונתי - Extreme Technologies', // Business name with company name
      language: 'he',
      total_sum_including_vat: amountIls,
      total_paid: amountIls,
      items: [
        {
          description: productName,
          quantity: 1,
          unit_price_with_vat: amountIls,
        },
      ],
      // According to PayMe API: cash is required object
      // Since payments are made via PayMe (card or Bit), we'll use credit_card for card/Bit payments
      // and cash with 0 (required by API)
      credit_card: {
        sum: amountIls, // Payment via PayMe (card or Bit)
      },
      cash: {
        sum: 0, // Required by API, but payment was via card/Bit
      },
    };
    
    // Add payme_sale_id if available (to link receipt to original sale)
    if (paymeSaleId) {
      receiptPayload.payme_sale_id = paymeSaleId;
      console.log(`✅ Added payme_sale_id to receipt payload: ${paymeSaleId}`);
    }
    
    console.log(`📤 Sending receipt creation request to PayMe Documents API for payment: ${transactionId}`);
    console.log(`📋 Receipt payload:`, JSON.stringify(receiptPayload, null, 2));
    console.log(`🔑 PayMe Client Key in payload: ${receiptPayload.payme_client_key}`);
    console.log(`🔑 PayMe Seller ID in payload: ${receiptPayload.seller_payme_id}`);
    
    // Call PayMe Documents API - according to new documentation
    // Note: The documentation shows sandbox.payme.io, but we're using live.payme.io for production
    // If this fails, we might need to check if the endpoint is correct or if we need different credentials
    const documentsApiUrl = 'https://live.payme.io/api/documents';
    console.log(`🌐 Calling PayMe Documents API: ${documentsApiUrl}`);
    console.log(`🔐 Authorization header: Bearer ${paymeApiKey ? paymeApiKey.substring(0, 10) + '...' : 'NOT SET'}`);
    const response = await fetch(documentsApiUrl, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${paymeApiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(receiptPayload),
    });
    
    if (!response.ok) {
      const errorText = await response.text();
      console.error(`❌ PayMe API error (${response.status}):`, errorText);
      throw new Error(`PayMe API error: ${response.status} - ${errorText}`);
    }
    
    const receiptResponse = await response.json();
    console.log(`✅ Receipt created successfully:`, JSON.stringify(receiptResponse, null, 2));
    
    // Extract receipt URL and ID according to PayMe API response format
    // The API returns: { doc_id, doc_url, status, etc. }
    const receiptUrl = receiptResponse.doc_url || receiptResponse.url || receiptResponse.document_url;
    const receiptId = receiptResponse.doc_id || receiptResponse.id || receiptResponse.document_id;
    
    if (!receiptUrl || !receiptId) {
      console.error('❌ Receipt response missing doc_url or doc_id:', JSON.stringify(receiptResponse, null, 2));
      throw new Error(`Receipt response missing doc_url or doc_id. Response: ${JSON.stringify(receiptResponse)}`);
    }
    
    console.log(`📄 Receipt details - ID: ${receiptId}, URL: ${receiptUrl}`);
    
    // Save receipt details to Firestore
    await paymentRef.update({
      receipt_url: receiptUrl,
      receipt_id: receiptId,
      receipt_created_at: admin.firestore.FieldValue.serverTimestamp(),
    });
    
    console.log(`💾 Receipt details saved to Firestore for payment: ${transactionId}`);
    
    // Send receipt email to buyer
    if (buyerEmailFinal) {
      await sendReceiptEmail(buyerEmailFinal, buyerNameFinal, receiptUrl, receiptId);
    } else {
      console.warn(`⚠️ No buyer email found for payment ${transactionId}, skipping email`);
    }
    
  } catch (error) {
    console.error(`❌ Error creating receipt for payment ${transactionId}:`, error);
    
    // Save error to Firestore but don't stop webhook processing
    try {
      const paymentRef = admin.firestore().collection('payments').doc(transactionId);
      await paymentRef.update({
        receipt_error: error.message,
        receipt_error_at: admin.firestore.FieldValue.serverTimestamp(),
      });
    } catch (updateError) {
      console.error(`❌ Error updating receipt error in Firestore:`, updateError);
    }
    
    // Don't throw - we don't want to stop webhook processing if receipt creation fails
  }
}

// Helper function to send receipt email
async function sendReceiptEmail(buyerEmail, buyerName, receiptUrl, receiptId) {
  try {
    console.log(`📧 Sending receipt email to: ${buyerEmail}`);
    
    const transporter = createTransporter();
    if (!transporter) {
      console.error('❌ Email transporter not configured, cannot send receipt email');
      return;
    }
    
    const emailHtml = `
      <div dir="rtl" style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
        <h2 style="color: #333;">שלום ${buyerName || 'לקוח'},</h2>
        <p style="font-size: 16px; color: #333; margin: 20px 0;">
          התשלום שלך התקבל בהצלחה ✔
        </p>
        <!-- Removed receipt number from email - doc_id is internal UUID, not the actual receipt number -->
        <p style="font-size: 16px; color: #333; margin: 20px 0;">
           הקבלה:
        </p>
        <p style="margin: 20px 0;">
          <a href="${receiptUrl}" 
             style="display: inline-block; padding: 12px 24px; background-color: #4CAF50; color: white; text-decoration: none; border-radius: 5px; font-weight: bold;">
            צפה בקבלה
          </a>
        </p>
        <p style="font-size: 14px; color: #666; margin-top: 30px;">
        תודה  
        ובהצלחה בשכונה החכמה שלך!
        שכונתי
        </p>
      </div>
    `;
    
    const emailText = `
שלום ${buyerName || 'לקוח'},

התשלום שלך התקבל בהצלחה ✔

הקבלה: ${receiptUrl}

תודה  
        ובהצלחה בשכונה החכמה שלך!
        שכונתי 
           `;
    
    const mailOptions = {
      from: `"My Neighborhood" <${functions.config().email?.user || process.env.EMAIL_USER}>`,
      to: buyerEmail,
      subject: 'קבלה על תשלום - שכונתי',
      text: emailText,
      html: emailHtml,
      replyTo: functions.config().email?.user || process.env.EMAIL_USER,
    };
    
    await transporter.sendMail(mailOptions);
    console.log(`✅ Receipt email sent successfully to: ${buyerEmail}`);
    
  } catch (error) {
    console.error(`❌ Error sending receipt email to ${buyerEmail}:`, error);
    // Don't throw - email failure shouldn't stop receipt creation
  }
}

// PayMe Webhook Handler
// ⚠️ IMPORTANT: PayMe sends callbacks as x-www-form-urlencoded, not JSON!
// Uses Express with bodyParser to handle the correct format
const paymeWebhookApp = express();
paymeWebhookApp.use(express.urlencoded({ extended: true })); // Handle x-www-form-urlencoded
paymeWebhookApp.use(express.json()); // Also JSON for future compatibility

paymeWebhookApp.post('/', async (req, res) => {
  try {
    console.log('PayMe webhook received');
    console.log('Content-Type:', req.headers['content-type']);
    console.log('Body:', req.body);
    
    // PayMe sends callbacks as x-www-form-urlencoded
    // Express bodyParser already converts this to an object automatically
    const webhookData = req.body;
    
    // Log all webhook data to see what PayMe sends (for debugging buyer info)
    console.log('📋 Full webhook data keys:', Object.keys(webhookData));
    console.log('📋 Webhook data for buyer info:', {
      buyer_name: webhookData.buyer_name,
      buyer_email: webhookData.buyer_email,
      first_name: webhookData.first_name,
      last_name: webhookData.last_name,
      email: webhookData.email,
      name: webhookData.name,
      customer_name: webhookData.customer_name,
      customer_email: webhookData.customer_email,
      user_email: webhookData.user_email,
      payer_email: webhookData.payer_email,
      billing_email: webhookData.billing_email,
      // Log all keys to see what PayMe/BIT actually sends
      allKeys: Object.keys(webhookData),
    });
    
    // Extract data (PayMe webhook format)
    // PayMe sends notify_type (sale-complete, sale-authorized, sale-failure, etc.) and sale_status (completed, etc.)
    const transaction_id = webhookData.transaction_id || webhookData['transaction_id'];
    const sale_id = webhookData.payme_sale_id || webhookData['payme_sale_id'] || webhookData.sale_id || webhookData['sale_id'];
    const notify_type = webhookData.notify_type || webhookData['notify_type'];
    const sale_status = webhookData.sale_status || webhookData['sale_status'];
    const status = sale_status || notify_type || webhookData.status || webhookData['status']; // Use sale_status first, then notify_type, then status
    const amount = webhookData.price ? parseFloat(webhookData.price) / 100 : (webhookData.amount ? parseFloat(webhookData.amount) : null); // PayMe sends price in agorot (cents)
    
    // Validate required fields - PayMe sends transaction_id and either notify_type or sale_status
    if (!transaction_id) {
      console.error('Invalid webhook data:', webhookData);
      return res.status(400).json({ success: false, error: 'Missing transaction_id' });
    }
    
    if (!notify_type && !sale_status && !status) {
      console.error('Invalid webhook data - missing notify_type, sale_status, or status:', webhookData);
      return res.status(400).json({ success: false, error: 'Missing notify_type, sale_status, or status' });
    }
    
    console.log(`Processing PayMe webhook: Transaction ${transaction_id}, notify_type: ${notify_type}, sale_status: ${sale_status}, status: ${status}`);
    
    // Update payment status in Firestore (using payments collection)
    const paymentRef = admin.firestore().collection('payments').doc(transaction_id);
    const paymentDoc = await paymentRef.get();
    
    if (!paymentDoc.exists) {
      console.error('Payment document not found:', transaction_id);
      return res.status(404).json({ success: false, error: 'Payment not found' });
    }
    
    // Normalize status based on PayMe callback format
    // PayMe sends: notify_type (sale-complete, sale-authorized, sale-failure, etc.) and sale_status (completed, etc.)
    console.log(`📊 PayMe webhook data:`);
    console.log(`   - notify_type: "${notify_type}"`);
    console.log(`   - sale_status: "${sale_status}"`);
    console.log(`   - status: "${status}"`);
    console.log(`📊 Full webhook data:`, JSON.stringify(webhookData, null, 2));
    
    let normalizedStatus = 'pending';
    
    // Check notify_type first (PayMe's primary indicator)
    if (notify_type) {
      const notifyTypeLower = notify_type.toLowerCase();
      if (notifyTypeLower === 'sale-complete' || notifyTypeLower === 'sale-authorized') {
      normalizedStatus = 'completed';
        console.log(`✅ notify_type "${notify_type}" indicates success - setting to completed`);
      } else if (notifyTypeLower === 'sale-failure' || notifyTypeLower === 'refund') {
      normalizedStatus = 'failed';
        console.log(`❌ notify_type "${notify_type}" indicates failure - setting to failed`);
    } else {
        console.log(`⚠️ notify_type "${notify_type}" - keeping as pending`);
      }
    }
    
    // Also check sale_status as fallback
    if (normalizedStatus === 'pending' && sale_status) {
      const saleStatusLower = sale_status.toLowerCase();
      if (saleStatusLower === 'completed' || saleStatusLower === 'authorized') {
        normalizedStatus = 'completed';
        console.log(`✅ sale_status "${sale_status}" indicates success - setting to completed`);
      } else if (saleStatusLower === 'failed' || saleStatusLower === 'declined') {
        normalizedStatus = 'failed';
        console.log(`❌ sale_status "${sale_status}" indicates failure - setting to failed`);
      }
    }
    
    // Fallback to old status check if notify_type and sale_status are not available
    if (normalizedStatus === 'pending' && status) {
      const statusLower = status.toLowerCase();
      const successKeywords = ['approve', 'success', 'complete', 'paid', 'confirmed', 'authorized', 'captured', 'settled'];
      const failureKeywords = ['decline', 'fail', 'cancel', 'reject', 'error', 'void'];
      
      const isSuccess = successKeywords.some(keyword => statusLower.includes(keyword));
      const isFailure = failureKeywords.some(keyword => statusLower.includes(keyword));
      
      if (isSuccess) {
        normalizedStatus = 'completed';
        console.log(`✅ Status "${status}" indicates success - setting to completed`);
      } else if (isFailure) {
        normalizedStatus = 'failed';
        console.log(`❌ Status "${status}" indicates failure - setting to failed`);
      } else {
        console.log(`⚠️ Status "${status}" unclear - keeping as pending`);
      }
    }
    
    // Update payment status
    await paymentRef.update({
      status: normalizedStatus,
      payme_sale_id: sale_id || paymentDoc.data().payme_sale_id,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      webhook_received_at: admin.firestore.FieldValue.serverTimestamp(),
      webhook_data: webhookData,
    });
    
    console.log(`💾 Payment status updated to: ${normalizedStatus}`);
    
    // If payment is completed, activate subscription
    if (normalizedStatus === 'completed') {
      console.log(`🎉 Activating subscription for payment: ${transaction_id}`);
      
      const paymentData = paymentDoc.data();
      const userId = paymentData.userId;
      
      if (!userId) {
        console.error('Payment missing userId');
        return res.status(400).json({ success: false, error: 'Payment missing userId' });
      }
      
      // Get user data
      const userDoc = await admin.firestore().collection('users').doc(userId).get();
      if (!userDoc.exists) {
        console.error('User not found:', userId);
        return res.status(404).json({ success: false, error: 'User not found' });
      }
      
      const userData = userDoc.data();
      const userEmail = userData.email || '';
      const userName = userData.displayName || userData.name || 'משתמש';
      
      // Log user data for debugging
      console.log('👤 User data from Firestore:', {
        email: userEmail,
        name: userName,
        displayName: userData.displayName,
        name_field: userData.name,
      });
      
      // Determine subscription type based on amount
      // TODO: Return to production prices after testing: personal=30 ILS, business=70 ILS
      // Testing: Both are 5 ILS, so we need to check businessCategories or payment data
      const amountPaid = paymentData.amount || 0;
      // During testing (both 5 ILS), check if businessCategories exist to determine type
      const hasBusinessCategories = paymentData.businessCategories && 
        Array.isArray(paymentData.businessCategories) && 
        paymentData.businessCategories.length > 0;
      // For testing: if amount is 5 ILS and no businessCategories, it's personal
      // For production: if amount >= 70 ILS or has businessCategories, it's business
      const subscriptionType = (amountPaid >= 70 || hasBusinessCategories) ? 'business' : 'personal';
      
      // Calculate subscription expiry (1 year from now)
      const subscriptionExpiry = new Date();
      subscriptionExpiry.setFullYear(subscriptionExpiry.getFullYear() + 1);
      
      // Get current user profile (userDoc already defined above, reuse it)
      let currentBusinessCategories = [];
      if (userDoc.exists) {
        const userProfileData = userDoc.data();
        currentBusinessCategories = userProfileData.businessCategories || [];
      }
      
      // קבלת הקטגוריות מבקשת התשלום (אם יש)
      let paymentRequestCategories = [];
      if (paymentData.businessCategories) {
        paymentRequestCategories = Array.isArray(paymentData.businessCategories) 
          ? paymentData.businessCategories 
          : [];
        console.log('📋 Found business categories in payment: ' + JSON.stringify(paymentRequestCategories));
      }
      
      // Prepare update data based on subscription type
      const updateData = {
        isSubscriptionActive: true,
        subscriptionStatus: 'active',
        subscriptionExpiry: admin.firestore.Timestamp.fromDate(subscriptionExpiry),
        approvedPaymentId: transaction_id,
        approvedAt: admin.firestore.Timestamp.now(),
        paymentMethod: 'payme',
      };
      
      if (subscriptionType === 'business') {
        console.log('Setting user as BUSINESS subscription via PayMe webhook');
        // אם יש קטגוריות בבקשת התשלום - השתמש בהן
        if (paymentRequestCategories.length > 0) {
          currentBusinessCategories = paymentRequestCategories;
          console.log('✅ Using categories from payment: ' + JSON.stringify(currentBusinessCategories));
        } else if (currentBusinessCategories.length === 0) {
          // רק אם אין קטגוריות בבקשת התשלום ואין קטגוריות קיימות - הוסף את כל הקטגוריות
          currentBusinessCategories = [
            'flooringAndCeramics', 'paintingAndPlaster', 'plumbing', 'electrical', 'carpentry',
            'roofsAndWalls', 'elevatorsAndStairs', 'carRepair', 'carServices', 'movingAndTransport',
            'ridesAndShuttles', 'bicyclesAndScooters', 'heavyVehicles', 'babysitting', 'privateLessons',
            'childrenActivities', 'childrenHealth', 'birthAndParenting', 'specialEducation',
            'officeServices', 'marketingAndAdvertising', 'consulting', 'businessEvents',
            'cleaningServices', 'security', 'paintingAndSculpture', 'handicrafts', 'music',
            'photography', 'design', 'performingArts', 'physiotherapy', 'yogaAndPilates',
            'nutrition', 'mentalHealth', 'alternativeMedicine', 'beautyAndCosmetics',
            'computersAndTechnology', 'electricalAndElectronics', 'internetAndCommunication',
            'appsAndDevelopment', 'smartSystems', 'medicalEquipment', 'privateLessonsEducation',
            'languages', 'professionalTraining', 'lifeSkills', 'higherEducation',
            'vocationalTraining', 'events', 'entertainment', 'sports', 'tourism',
            'partiesAndEvents', 'photographyAndVideo', 'gardening', 'environmentalCleaning',
            'cleaningServicesEnv', 'environmentalQuality'
          ];
          console.log('⚠️ No categories in payment, using all categories: ' + JSON.stringify(currentBusinessCategories));
        }
        updateData.userType = 'business';
        updateData.businessCategories = currentBusinessCategories;
      } else {
        console.log('Setting user as PERSONAL subscription via PayMe webhook');
        updateData.userType = 'personal';
        updateData.businessCategories = admin.firestore.FieldValue.delete();
      }
      
      // Remove guest trial fields if user was a guest
      const currentUserType = userDoc.exists ? userDoc.data().userType : null;
      if (currentUserType === 'guest') {
        console.log('Removing guest trial fields for user:', userId);
        updateData.guestTrialStartDate = admin.firestore.FieldValue.delete();
        updateData.guestTrialEndDate = admin.firestore.FieldValue.delete();
      }
      
      // Update user profile
      await admin.firestore()
        .collection('users')
        .doc(userId)
        .update(updateData);
      
      // Update user_profiles collection if it exists
      try {
        const userProfilesDoc = await admin.firestore()
          .collection('user_profiles')
          .doc(userId)
          .get();
        
        if (userProfilesDoc.exists) {
          await admin.firestore()
            .collection('user_profiles')
            .doc(userId)
            .update(updateData);
        }
      } catch (e) {
        console.log('Warning: Could not update user_profiles collection:', e);
      }
      
      // Update payment status
      await paymentRef.update({
        status: 'completed',
        subscription_activated: true,
        activated_at: admin.firestore.FieldValue.serverTimestamp(),
      });
      
      // Send notifications
      const typeName = subscriptionType === 'business' ? 'עסקי' : 'פרטי';
      const amountText = amount ? `₪${amount}` : '';
      
      // Notify user
      await admin.firestore().collection('notifications').add({
        toUserId: userId,
        title: 'תשלום אושר! 🎉',
        message: `המנוי ${typeName} שלך הופעל בהצלחה ${amountText}`,
        type: 'payment_success',
        read: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      
      // Notify admins
      const adminUsers = await admin.firestore()
        .collection('users')
        .where('isAdmin', '==', true)
        .get();
      
      for (const adminDoc of adminUsers.docs) {
        const adminId = adminDoc.id;
        await admin.firestore().collection('notifications').add({
          toUserId: adminId,
          title: 'תשלום חדש התקבל 💰',
          message: `${userName} (${userEmail}) שילם עבור מנוי ${typeName} ${amountText}`,
          type: 'admin_payment_received',
          read: false,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }
      
      console.log('Subscription activated successfully via PayMe webhook');
      
      // Create receipt for completed payment
      console.log(`🧾 Calling createReceiptForPayment for transaction: ${transaction_id}`);
      console.log(`📧 Buyer email: ${userEmail}, Buyer name: ${userName}, Amount: ${amount}`);
      await createReceiptForPayment(transaction_id, paymentData, webhookData, amount, userEmail, userName);
      console.log(`✅ createReceiptForPayment completed for transaction: ${transaction_id}`);
    }
    
    // Respond to PayMe
    res.status(200).json({ success: true, message: 'Webhook processed successfully' });
    
  } catch (error) {
    console.error('Error processing PayMe webhook:', error);
    res.status(500).json({ success: false, error: error.message });
  }
});

// Export PayMe webhook handler
exports.paymeWebhook = functions
  .runWith({
    secrets: ['PAYME_API_KEY'], // Use Secret Manager for API key
    timeoutSeconds: 60,
  })
  .https.onRequest(paymeWebhookApp);

// Manual receipt creation function (for testing or fixing missing receipts)
exports.createReceiptManually = functions
  .runWith({
    secrets: ['PAYME_API_KEY', 'EMAIL_USER', 'EMAIL_PASS'],
    timeoutSeconds: 60,
  })
  .https.onCall(async (data, context) => {
    // Only admins can create receipts manually
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
    }
    
    const adminDoc = await admin.firestore().collection('users').doc(context.auth.uid).get();
    if (!adminDoc.exists || !adminDoc.data().isAdmin) {
      throw new functions.https.HttpsError('permission-denied', 'Only admins can create receipts manually');
    }
    
    const transactionId = data.transactionId;
    if (!transactionId) {
      throw new functions.https.HttpsError('invalid-argument', 'transactionId is required');
    }
    
    try {
      console.log(`🔧 Manual receipt creation requested for transaction: ${transactionId}`);
      
      // Get payment data
      const paymentDoc = await admin.firestore().collection('payments').doc(transactionId).get();
      if (!paymentDoc.exists) {
        throw new functions.https.HttpsError('not-found', 'Payment not found');
      }
      
      const paymentData = paymentDoc.data();
      
      // Get user data
      const userId = paymentData.userId;
      if (!userId) {
        throw new functions.https.HttpsError('invalid-argument', 'Payment missing userId');
      }
      
      const userDoc = await admin.firestore().collection('users').doc(userId).get();
      if (!userDoc.exists) {
        throw new functions.https.HttpsError('not-found', 'User not found');
      }
      
      const userData = userDoc.data();
      const userEmail = userData.email || '';
      const userName = userData.name || 'משתמש';
      const amount = paymentData.amount || 0;
      
      console.log(`📧 Creating receipt for: ${userName} (${userEmail}), Amount: ${amount}`);
      
      // Create receipt
      await createReceiptForPayment(transactionId, paymentData, {}, amount, userEmail, userName);
      
      return {
        success: true,
        message: 'Receipt created successfully',
        transactionId: transactionId,
      };
    } catch (error) {
      console.error('❌ Error creating receipt manually:', error);
      throw new functions.https.HttpsError('internal', error.message);
    }
  });

// Contact Form Handler
exports.contactFormHandler = functions.firestore
  .document('contact_inquiries/{inquiryId}')
  .onCreate(async (snap, context) => {
    try {
      console.log('New contact inquiry received:', snap.data());

      const inquiryData = snap.data();
      const inquiryId = context.params.inquiryId;

      // Get admin users
      const adminUsers = await admin.firestore()
        .collection('users')
        .where('isAdmin', '==', true)
        .get();

      // Send notification to all admins
      for (const adminDoc of adminUsers.docs) {
        const adminId = adminDoc.id;
        await admin.firestore().collection('notifications').add({
          toUserId: adminId,
          title: 'פנייה חדשה - צור קשר',
          message: `${inquiryData.name} (${inquiryData.email}) שלח פנייה חדשה`,
          type: 'contact_inquiry',
          read: false,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          data: {
            inquiryId: inquiryId,
            inquiryData: inquiryData
          }
        });
      }

      console.log('Contact inquiry notifications sent to admins');

    } catch (error) {
      console.error('Error processing contact inquiry:', error);
    }
  });

// Cloud Function for checking guest trial expiry (runs every minute)
exports.checkGuestTrialExpiry = functions.pubsub
  .schedule('every 1 minutes')
  .onRun(async (context) => {
    try {
      console.log('🔍 ===== GUEST TRIAL EXPIRY CHECK START =====');
      const now = new Date();
      console.log('🔍 Current time:', now);
      
      // Find all guest users
      const guestsQuery = await admin.firestore()
        .collection('users')
        .where('userType', '==', 'guest')
        .get();

      console.log('🔍 Found', guestsQuery.docs.length, 'guest users total');
      
      for (const guestDoc of guestsQuery.docs) {
        const data = guestDoc.data();
        const guestTrialEndDate = data.guestTrialEndDate;
        const guestTrialStartDate = data.guestTrialStartDate;
        
        console.log('🔍 Checking guest', guestDoc.id + ':');
        console.log('   - Trial start:', guestTrialStartDate);
        console.log('   - Trial end:', guestTrialEndDate);
        
        if (!guestTrialEndDate) {
          console.log('❌ Guest', guestDoc.id, 'has no trial end date - skipping');
          continue;
        }
        
        const trialEndDate = guestTrialEndDate.toDate();
        const timeUntilExpiry = trialEndDate - now;
        
        console.log('   - Trial end date:', trialEndDate);
        console.log('   - Time until expiry:', timeUntilExpiry);
        console.log('   - Is now after trial end:', now > trialEndDate);
        
        if (now > trialEndDate) {
          console.log('✅ Guest', guestDoc.id, 'trial expired - sending notification first');
          
          // Send push notification to user FIRST
          await admin.firestore().collection('push_notifications').add({
            userId: guestDoc.id,
            title: 'המנוי שלך עבר לסוג "פרטי חינם"',
            body: 'שדרג עכשיו למנוי "פרטי מנוי" או "עסקי"',
            payload: {
              type: 'guest_trial_expired',
              screen: 'profile'
            },
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
          });
          
          // Also save to notifications collection for in-app display
          await admin.firestore().collection('notifications').add({
            toUserId: guestDoc.id,
            title: 'המנוי שלך עבר לסוג "פרטי חינם"',
            message: 'שדרג עכשיו למנוי "פרטי מנוי" או "עסקי"',
            type: 'guest_trial_expired',
            read: false,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
          });
          
          console.log('📱 Notification sent to guest', guestDoc.id);
          
          // THEN transition to personal free
          await admin.firestore()
            .collection('users')
            .doc(guestDoc.id)
            .update({
              userType: 'personal',
              isSubscriptionActive: true,
              subscriptionStatus: 'active',
              businessCategories: admin.firestore.FieldValue.delete(),
              guestTrialStartDate: admin.firestore.FieldValue.delete(),
              guestTrialEndDate: admin.firestore.FieldValue.delete(),
              maxRequestsPerMonth: 5,
              maxRadius: 1.0,
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            });
          
          console.log('✅ Guest', guestDoc.id, 'transitioned to personal free');
        } else {
          console.log('⏰ Guest', guestDoc.id, 'trial still active until', trialEndDate);
        }
      }
      
      console.log('🔍 ===== GUEST TRIAL EXPIRY CHECK END =====');
      
    } catch (error) {
      console.error('❌ Error checking guest trial expiry:', error);
    }
  });

// Cloud Function לבדיקת תזכורות סיום מנוי
exports.checkSubscriptionReminders = functions.pubsub
  .schedule('every 1 minutes')
  .onRun(async (context) => {
    try {
      console.log('🔔 ===== SUBSCRIPTION REMINDERS CHECK START =====');
      const now = new Date();
      
      // תזכורת שבוע לפני סיום מנוי (6-7 ימים)
      const usersSnapshot = await admin.firestore()
        .collection('users')
        .where('isSubscriptionActive', '==', true)
        .where('subscriptionExpiry', '!=', null)
        .get();
      
      console.log(`📊 Found ${usersSnapshot.size} users with active subscriptions`);
      
      for (const userDoc of usersSnapshot.docs) {
        const data = userDoc.data();
        const userId = userDoc.id;
        const subscriptionExpiry = data.subscriptionExpiry;
        
        if (!subscriptionExpiry) continue;
        
        const expiryDate = subscriptionExpiry.toDate();
        const daysUntilExpiry = Math.floor((expiryDate - now) / (1000 * 60 * 60 * 24));
        
        console.log(`🔍 User ${userId}: expires in ${daysUntilExpiry} days`);
        
        // תזכורת שבוע לפני (6-7 ימים)
        if (daysUntilExpiry >= 6 && daysUntilExpiry <= 7) {
          // בדיקה אם כבר נשלחה תזכורת
          const reminderQuery = await admin.firestore()
            .collection('notifications')
            .where('toUserId', '==', userId)
            .where('type', '==', 'subscription_reminder')
            .where('data.reminderType', '==', 'one_week_before')
            .get();
          
          if (reminderQuery.empty) {
            console.log(`📧 Sending subscription reminder to user ${userId}`);
            
            await admin.firestore().collection('push_notifications').add({
              userId: userId,
              title: 'תזכורת: המנוי שלך מסתיים בקרוב 🔔',
              body: `המנוי שלך יסתיים בעוד ${daysUntilExpiry} ימים. הרחב את המנוי להמשך גישה מלאה!`,
              payload: {
                type: 'subscription_reminder',
                screen: 'profile',
              },
              createdAt: admin.firestore.FieldValue.serverTimestamp(),
            });
            
            await admin.firestore().collection('notifications').add({
              toUserId: userId,
              title: 'תזכורת: המנוי שלך מסתיים בקרוב 🔔',
              message: `המנוי שלך יסתיים בעוד ${daysUntilExpiry} ימים. הרחב את המנוי להמשך גישה מלאה!`,
              type: 'subscription_reminder',
              read: false,
              data: {
                reminderType: 'one_week_before',
                daysUntilExpiry: daysUntilExpiry,
              },
              createdAt: admin.firestore.FieldValue.serverTimestamp(),
            });
            
            console.log(`✅ Subscription reminder sent to user ${userId}`);
          } else {
            console.log(`⏭️ Reminder already sent to user ${userId} - skipping`);
          }
        }
      }
      
      console.log('🔔 ===== SUBSCRIPTION REMINDERS CHECK END =====');
    } catch (error) {
      console.error('❌ Error checking subscription reminders:', error);
    }
  });

// Cloud Function לבדיקת בקשות חדשות והתראות סינון
exports.onNewRequestCreated = functions.firestore
  .document('requests/{requestId}')
  .onCreate(async (snap, context) => {
  try {
    console.log('🔔 ===== NEW REQUEST CREATED - CHECKING FILTER NOTIFICATIONS =====');
    
    const request = snap.data();
    const requestId = context.params.requestId;
    
    console.log(`📊 New request: ${requestId} - ${request.title}`);
    console.log(`📊 Request category: ${request.category}`);
    console.log(`📊 Request type: ${request.type || 'free'}`);
    console.log(`📊 Request location: ${request.latitude}, ${request.longitude}`);
    console.log(`📊 Request exposure radius: ${request.exposureRadius || 0} km`);
    console.log(`📊 Request status: ${request.status}`);
    console.log(`📊 Request created by: ${request.createdBy}`);
    
    // בדיקה שהבקשה פתוחה
    if (request.status !== 'open') {
      console.log(`❌ Request ${requestId} is not open, skipping`);
      return;
    }
    
    // קבלת כל המשתמשים שיש להם את הקטגוריה הזו בתחומי העיסוק שלהם
    // תמיכה גם בערכים ישנים שנשמרו בשם הפנימי של ה-enum וגם בתצוגה בעברית
    const categoryDisplayName = getCategoryDisplayName(request.category);
    const categoryInternalName = request.category;
    
    console.log(`🔍 Searching users with category: "${categoryDisplayName}" or "${categoryInternalName}"`);
    
    // חיפוש משתמשים לפי קטגוריה (תמיכה בשני הפורמטים)
    const queryByDisplayName = await admin.firestore()
      .collection('users')
      .where('businessCategories', 'array-contains', categoryDisplayName)
      .get();
    
    const queryByInternalName = await admin.firestore()
      .collection('users')
      .where('businessCategories', 'array-contains', categoryInternalName)
      .get();
    
    // מיזוג התוצאות ללא כפילויות
    const userDocsMap = new Map();
    queryByDisplayName.docs.forEach(doc => userDocsMap.set(doc.id, doc));
    queryByInternalName.docs.forEach(doc => userDocsMap.set(doc.id, doc));
    
    console.log(`📊 Found ${userDocsMap.size} unique users with matching category`);
    
    if (userDocsMap.size === 0) {
      console.log('📭 No users with matching category found');
      return;
    }
    
    // בדיקה לכל משתמש
    for (const [userId, userDoc] of userDocsMap.entries()) {
      const userData = userDoc.data();
      const userType = userData.userType || 'personal';
      
      console.log(`👤 Checking user ${userId} (type: ${userType})`);
      console.log(`   User email: ${userData.email || 'N/A'}`);
      console.log(`   User businessCategories: ${JSON.stringify(userData.businessCategories || [])}`);
      console.log(`   User fixed location: ${userData.latitude || 'N/A'}, ${userData.longitude || 'N/A'}`);
      console.log(`   User mobile location: ${userData.mobileLatitude || 'N/A'}, ${userData.mobileLongitude || 'N/A'}`);
      
      // לא לשלוח התראה למשתמש שיצר את הבקשה
      if (userId === request.createdBy) {
        console.log(`⏭️ Skipping user ${userId} - is the creator of the request`);
        continue;
      }
      
      // בדיקה למשתמשים עסקיים - רק עם מנוי פעיל
      if (userType === 'business') {
        const isSubscriptionActive = userData.isSubscriptionActive || false;
        console.log(`   User subscription active: ${isSubscriptionActive}`);
        if (!isSubscriptionActive) {
          console.log(`⏭️ Skipping user ${userId} - business user without active subscription`);
        continue;
      }
      }
      
      // בדיקה למשתמשי אורח - רק אם יש להם תחומי עיסוק
      if (userType === 'guest') {
        const businessCategories = userData.businessCategories || [];
        console.log(`   User businessCategories count: ${businessCategories.length}`);
        if (businessCategories.length === 0) {
          console.log(`⏭️ Skipping user ${userId} - guest user without business categories`);
        continue;
      }
      }
      
      // בדיקת העדפות התראות
      const notificationPrefsDoc = await admin.firestore()
        .collection('notification_preferences')
        .doc(userId)
        .get();
      
      const notificationPrefs = notificationPrefsDoc.exists 
        ? notificationPrefsDoc.data()
        : {
            newRequestsUseFixedLocation: true, // ברירת מחדל
            newRequestsUseMobileLocation: false,
            newRequestsUseBothLocations: false
          };
      
      console.log(`   Notification preferences:`);
      console.log(`     - newRequestsUseFixedLocation: ${notificationPrefs.newRequestsUseFixedLocation}`);
      console.log(`     - newRequestsUseMobileLocation: ${notificationPrefs.newRequestsUseMobileLocation}`);
      console.log(`     - newRequestsUseBothLocations: ${notificationPrefs.newRequestsUseBothLocations}`);
      
      // בדיקה אם יש FilterPreferences עם התראות מופעלות
      const filterPrefsDoc = await admin.firestore()
        .collection('filter_preferences')
        .doc(userId)
        .get();
      
      const filterPrefs = filterPrefsDoc.exists ? filterPrefsDoc.data() : null;
      
      // בדיקה אם המשתמש רוצה התראות על בקשות חדשות
      // ✅ בדיקה ראשונה: העדפות מיקום רגילות (קבוע/נייד)
      const wantsRegularNotifications = 
        notificationPrefs.newRequestsUseFixedLocation ||
        notificationPrefs.newRequestsUseMobileLocation ||
        notificationPrefs.newRequestsUseBothLocations;
      
      // ✅ בדיקה שנייה: FilterPreferences עם התראות מופעלות (כולל מיקום נוסף)
      const wantsFilterNotifications = filterPrefs && 
        filterPrefs.isEnabled &&
        (filterPrefs.categories && filterPrefs.categories.length > 0 ||
         filterPrefs.maxRadius ||
         filterPrefs.urgency ||
         filterPrefs.requestType ||
         (filterPrefs.useAdditionalLocation && 
          filterPrefs.additionalLocationLatitude &&
          filterPrefs.additionalLocationLongitude &&
          filterPrefs.additionalLocationRadius));
      
      const wantsNotifications = wantsRegularNotifications || wantsFilterNotifications;
      
      if (!wantsNotifications) {
        console.log(`⏭️ Skipping user ${userId} - notification preferences disabled`);
        continue;
      }
      
      // בדיקת מיקום וטווח
      const shouldNotify = await checkShouldNotifyUser(
        userId,
        userData,
        request,
        notificationPrefs,
        filterPrefs // ✅ העברת FilterPreferences לפונקציה
      );
      
      if (shouldNotify) {
        console.log(`✅ User ${userId} should receive notification - sending...`);
        await sendDefaultNotification(userId, request, requestId);
      } else {
        console.log(`❌ User ${userId} should not receive notification - location/distance check failed`);
      }
    }
    
    console.log('🔔 ===== FILTER NOTIFICATIONS CHECK COMPLETED =====');
    
  } catch (error) {
    console.error('❌ Error checking new requests for filter notifications:', error);
  }
});

// פונקציה לבדיקה אם צריך לשלוח התראה למשתמש לפי מיקום וטווח
async function checkShouldNotifyUser(userId, userData, request, notificationPrefs, filterPrefs) {
  try {
    console.log(`🔍 checkShouldNotifyUser for user ${userId}:`);
    console.log(`   Request ID: ${request.requestId || requestId || 'N/A'}`);
    console.log(`   Request location: ${request.latitude || 'N/A'}, ${request.longitude || 'N/A'}`);
    console.log(`   Request exposure radius: ${request.exposureRadius || 0} km`);
    
    // אם אין מיקום לבקשה, תמיד לשלוח (אם לא בוטל ב-prefs)
    if (!request.latitude || !request.longitude) {
      console.log(`⚠️ Request ${request.requestId || 'N/A'} has no location, notifying by default for user ${userId}`);
      return true;
    }
    
    const requestLat = request.latitude;
    const requestLng = request.longitude;
    const exposureRadius = request.exposureRadius || 0.0; // קילומטרים
    
    // קבלת העדפות הסינון של המשתמש
    // ✅ אם FilterPreferences לא הועבר, נטען אותו
    let finalFilterPrefs = filterPrefs;
    if (!finalFilterPrefs) {
      const filterPrefsDoc = await admin.firestore()
        .collection('filter_preferences')
        .doc(userId)
        .get();
      
      finalFilterPrefs = filterPrefsDoc.exists ? filterPrefsDoc.data() : null;
    }
    
    const userFilterRadiusKm = finalFilterPrefs?.maxRadius || 0.0;
    const filterIsEnabled = finalFilterPrefs?.isEnabled || false;
    const userFilterCategories = finalFilterPrefs?.categories || [];
    const userFilterRequestType = finalFilterPrefs?.requestType;
    
    // בדיקת מיקום קבוע
    let fixedLocationMatch = false;
    if (notificationPrefs.newRequestsUseFixedLocation || notificationPrefs.newRequestsUseBothLocations) {
      const userFixedLat = userData.latitude;
      const userFixedLng = userData.longitude;
      
      if (userFixedLat && userFixedLng) {
        const distanceFromFixed = calculateDistance(
          userFixedLat,
          userFixedLng,
          requestLat,
          requestLng
        );
        
        if (distanceFromFixed <= exposureRadius) {
          fixedLocationMatch = true;
          console.log(`✅ Fixed location match for user ${userId}: distance = ${distanceFromFixed.toFixed(2)} km, exposure radius = ${exposureRadius.toFixed(2)} km`);
        }
      }
    }
    
    // בדיקת מיקום נייד
    let mobileLocationMatch = false;
    if (notificationPrefs.newRequestsUseMobileLocation || notificationPrefs.newRequestsUseBothLocations) {
      let userMobileLat = userData.mobileLatitude;
      let userMobileLng = userData.mobileLongitude;
      
      // אם אין מיקום נייד שמור, נריץ ניסיון אחד נוסף (לכל היותר)
      if (!userMobileLat || !userMobileLng) {
        console.log(`⚠️ No mobile location stored for user ${userId}. Attempting one more fetch...`);
        // ניסיון אחד נוסף (לא נחכה 30 שניות, פשוט נבדוק שוב)
        const updatedUserDoc = await admin.firestore().collection('users').doc(userId).get();
        if (updatedUserDoc.exists) {
          const updated = updatedUserDoc.data();
          userMobileLat = updated.mobileLatitude;
          userMobileLng = updated.mobileLongitude;
          if (userMobileLat && userMobileLng) {
            console.log(`✅ Mobile location fetched for user ${userId}`);
          }
        }
      }
      
      if (userMobileLat && userMobileLng) {
        const distanceFromMobile = calculateDistance(
          userMobileLat,
          userMobileLng,
          requestLat,
          requestLng
        );
        
        if (distanceFromMobile <= exposureRadius) {
          mobileLocationMatch = true;
          console.log(`✅ Mobile location match for user ${userId}: distance = ${distanceFromMobile.toFixed(2)} km, exposure radius = ${exposureRadius.toFixed(2)} km`);
        } else {
          console.log(`❌ Mobile location NOT in range for user ${userId}: distance = ${distanceFromMobile.toFixed(2)} km > exposure radius = ${exposureRadius.toFixed(2)} km`);
        }
      } else {
        console.log(`⚠️ No mobile location stored for user ${userId} after retries`);
        // אם אין מיקום נייד אך יש העדפה "מיקום נייד בלבד" - ניפול חזרה למיקום קבוע
        if (notificationPrefs.newRequestsUseMobileLocation && !notificationPrefs.newRequestsUseBothLocations && !fixedLocationMatch) {
          console.log(`⚠️ User ${userId} prefers mobile location only, but no mobile location available and fixed location does not match`);
        return false;
      }
    }
    }
    
    // בדיקה לפי טווח הסינון של המשתמש (אם הוגדר)
    let userFilterRadiusMatch = false;
    if (userFilterRadiusKm > 0) {
      // בחר מיקום משתמש מועדף לפי ההעדפות: נייד -> קבוע
      let bestLat = null;
      let bestLng = null;
      let bestLocationSource = 'none';
      
      if (notificationPrefs.newRequestsUseMobileLocation || notificationPrefs.newRequestsUseBothLocations) {
        bestLat = userData.mobileLatitude;
        bestLng = userData.mobileLongitude;
        if (bestLat && bestLng) {
          bestLocationSource = 'mobile';
        }
      }
      
      if ((!bestLat || !bestLng) && (notificationPrefs.newRequestsUseFixedLocation || notificationPrefs.newRequestsUseBothLocations)) {
        bestLat = userData.latitude;
        bestLng = userData.longitude;
        if (bestLat && bestLng) {
          bestLocationSource = 'fixed';
        }
      }
      
      if (bestLat && bestLng) {
        const distFromBest = calculateDistance(bestLat, bestLng, requestLat, requestLng);
        console.log(`🔍 Checking user filter radius for user ${userId}: filterMaxRadius = ${userFilterRadiusKm} km, best location source: ${bestLocationSource}`);
        console.log(`   Distance from best location: ${distFromBest.toFixed(2)} km`);
        
        if (distFromBest <= userFilterRadiusKm) {
          userFilterRadiusMatch = true;
          console.log(`✅ User filter radius match: distance = ${distFromBest.toFixed(2)} km (<= ${userFilterRadiusKm} km)`);
        } else {
          console.log(`❌ User filter radius NOT in range: distance = ${distFromBest.toFixed(2)} km (> ${userFilterRadiusKm} km)`);
        }
      }
    }
    
    // בדיקת קטגוריה מול סינון (אם המשתמש הגדיר קטגוריות בסינון)
    let categoryFilterMatch = true; // ברירת מחדל – אם לא הגדיר קטגוריות
    if (filterIsEnabled && userFilterCategories.length > 0) {
      const categoryDisplayName = getCategoryDisplayName(request.category);
      const categoryInternalName = request.category;
      const filterCategoriesMatch = userFilterCategories.includes(categoryDisplayName) || 
                                  userFilterCategories.includes(categoryInternalName);

      // התאמה מול תחומי העיסוק של המשתמש (כגיבוי אם הפילטרים מצמצמים מדי)
      const userBusinessCats = new Set((userData.businessCategories || []).map((e) => String(e)));
      const businessCategoriesMatch = userBusinessCats.has(categoryDisplayName) || userBusinessCats.has(categoryInternalName);

      categoryFilterMatch = filterCategoriesMatch || businessCategoriesMatch;
      console.log(`🔍 Category filter decision: filterMatch=${filterCategoriesMatch}, businessMatch=${businessCategoriesMatch} => final=${categoryFilterMatch}`);
    }
    
    // בדיקת סוג בקשה מול סינון (אם הוגדר)
    let requestTypeFilterMatch = true;
    if (filterIsEnabled && userFilterRequestType) {
      if (userFilterRequestType === 'paid') {
        requestTypeFilterMatch = request.type === 'paid';
      } else if (userFilterRequestType === 'free') {
        requestTypeFilterMatch = request.type === 'free';
      }
    }
    
    // בדיקת מיקום נוסף (אם הוגדר בסינון)
    let additionalLocationMatch = false;
    if (finalFilterPrefs &&
        finalFilterPrefs.useAdditionalLocation &&
        finalFilterPrefs.additionalLocationLatitude &&
        finalFilterPrefs.additionalLocationLongitude &&
        finalFilterPrefs.additionalLocationRadius) {
      const additionalLat = finalFilterPrefs.additionalLocationLatitude;
      const additionalLng = finalFilterPrefs.additionalLocationLongitude;
      const additionalRadius = finalFilterPrefs.additionalLocationRadius;
      
      console.log(`🔍 Checking additional location for user ${userId}:`);
      console.log(`   Additional location: ${additionalLat}, ${additionalLng}`);
      console.log(`   Additional location radius: ${additionalRadius} km`);
      console.log(`   Request location: ${requestLat}, ${requestLng}`);
      
      const distFromAdditional = calculateDistance(
        additionalLat,
        additionalLng,
        requestLat,
        requestLng
      );
      
      console.log(`   Distance from additional location: ${distFromAdditional.toFixed(2)} km`);
      console.log(`   Additional location radius: ${additionalRadius} km`);
      
      if (distFromAdditional <= additionalRadius) {
        additionalLocationMatch = true;
        console.log(`✅ Additional location match: distance = ${distFromAdditional.toFixed(2)} km (<= ${additionalRadius} km)`);
      } else {
        console.log(`❌ Additional location NOT in range: distance = ${distFromAdditional.toFixed(2)} km (> ${additionalRadius} km)`);
      }
    }
    
    // החזרת תוצאה: התאמת מיקום לפי ההעדפות OR התאמה לטווח הסינון שהמשתמש הגדיר OR מיקום נוסף
    let finalResult = false;
    if (notificationPrefs.newRequestsUseBothLocations) {
      finalResult = ((fixedLocationMatch || mobileLocationMatch) || userFilterRadiusMatch || additionalLocationMatch) && 
                    categoryFilterMatch && 
                    requestTypeFilterMatch;
      console.log(`📊 Final check for user ${userId}: ((${fixedLocationMatch} || ${mobileLocationMatch}) || ${userFilterRadiusMatch} || ${additionalLocationMatch}) && ${categoryFilterMatch} && ${requestTypeFilterMatch} = ${finalResult}`);
    } else if (notificationPrefs.newRequestsUseFixedLocation) {
      finalResult = (fixedLocationMatch || userFilterRadiusMatch || additionalLocationMatch) && 
                    categoryFilterMatch && 
                    requestTypeFilterMatch;
      console.log(`📊 Final check for user ${userId}: (${fixedLocationMatch} || ${userFilterRadiusMatch} || ${additionalLocationMatch}) && ${categoryFilterMatch} && ${requestTypeFilterMatch} = ${finalResult}`);
    } else if (notificationPrefs.newRequestsUseMobileLocation) {
      finalResult = (mobileLocationMatch || userFilterRadiusMatch || additionalLocationMatch) && 
                    categoryFilterMatch && 
                    requestTypeFilterMatch;
      console.log(`📊 Final check for user ${userId}: (${mobileLocationMatch} || ${userFilterRadiusMatch} || ${additionalLocationMatch}) && ${categoryFilterMatch} && ${requestTypeFilterMatch} = ${finalResult}`);
    } else {
      // גם אם אין העדפות מיקום, נבדוק מיקום נוסף
      finalResult = additionalLocationMatch && categoryFilterMatch && requestTypeFilterMatch;
      console.log(`📊 Final check for user ${userId} (additional location only): ${additionalLocationMatch} && ${categoryFilterMatch} && ${requestTypeFilterMatch} = ${finalResult}`);
      if (!additionalLocationMatch) {
        console.log(`⚠️ No location preference enabled and no additional location match - returning false`);
        return false;
      }
    }
    
    console.log(`🎯 Final notification decision for user ${userId}: ${finalResult}`);
    return finalResult;
    
  } catch (error) {
    console.error(`❌ Error checking notification location for user ${userId}:`, error);
    return false;
  }
}

// פונקציה לחישוב מרחק
function calculateDistance(lat1, lng1, lat2, lng2) {
  const R = 6371; // רדיוס כדור הארץ בק"מ
  const dLat = (lat2 - lat1) * Math.PI / 180;
  const dLng = (lng2 - lng1) * Math.PI / 180;
  const a = Math.sin(dLat/2) * Math.sin(dLat/2) +
    Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) *
    Math.sin(dLng/2) * Math.sin(dLng/2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));
  return R * c;
}

// המרת שם קטגוריה קוד לשם תצוגה בעברית
function getCategoryDisplayName(categoryCode) {
  const categoryMap = {
    // בנייה ותיקונים
    'electrical': 'חשמל',
    'plumbing': 'אינסטלציה',
    'carpentry': 'נגרות',
    'paintingAndPlaster': 'צבע וטיח',
    'flooringAndCeramics': 'ריצוף וקרמיקה',
    'roofsAndWalls': 'גגות וקירות',
    'elevatorsAndStairs': 'מעליות ומדרגות',
    
    // רכב
    'carRepair': 'תיקון רכב',
    'carServices': 'שירותי רכב',
    
    // מעבר ותחבורה
    'movingAndTransport': 'מעבר והובלה',
    'ridesAndShuttles': 'נסיעות וטיולים',
    'bicyclesAndScooters': 'אופניים וקורקינטים',
    'heavyVehicles': 'כלי רכב כבדים',
    
    // לילדים
    'babysitting': 'בייביסיטר',
    'privateLessons': 'שיעורים פרטיים',
    'childrenActivities': 'פעילויות ילדים',
    'childrenHealth': 'בריאות ילדים',
    'birthAndParenting': 'לידה והורות',
    'specialEducation': 'חינוך מיוחד',
    
    // עסקים
    'officeServices': 'שירותי משרד',
    'marketingAndAdvertising': 'שיווק ופרסום',
    'consulting': 'ייעוץ',
    'businessEvents': 'אירועי עסקים',
    
    // שירותים
    'cleaningServices': 'שירותי ניקיון',
    'security': 'אבטחה',
    
    // אמנות ותרבות
    'paintingAndSculpture': 'ציור ופיסול',
    'handicrafts': 'מלאכות יד',
    'music': 'מוזיקה',
    'photography': 'צילום',
    'design': 'עיצוב',
    'performingArts': 'אמנויות הבמה',
    
    // בריאות וכושר
    'physiotherapy': 'פיזיותרפיה',
    'yogaAndPilates': 'יוגה ופילאטיס',
    'nutrition': 'תזונה',
    'mentalHealth': 'בריאות נפשית',
    'alternativeMedicine': 'רפואה משלימה',
    'beautyAndCosmetics': 'יופי וקוסמטיקה',
    
    // טכנולוגיה
    'computersAndTechnology': 'מחשבים וטכנולוגיה',
    'electricalAndElectronics': 'חשמל ואלקטרוניקה',
    'internetAndCommunication': 'אינטרנט ותקשורת',
    'appsAndDevelopment': 'אפליקציות ופיתוח',
    'smartSystems': 'מערכות חכמות',
    'medicalEquipment': 'ציוד רפואי',
    
    // חינוך
    'privateLessonsEducation': 'שיעורים פרטיים בחינוך',
    'languages': 'שפות',
    'professionalTraining': 'הכשרה מקצועית',
    'lifeSkills': 'כישורי חיים',
    'higherEducation': 'השכלה גבוהה',
    'vocationalTraining': 'הכשרה מקצועית',
    
    // בידור ופנאי
    'events': 'אירועים',
    'entertainment': 'בידור',
    'sports': 'ספורט',
    'tourism': 'תיירות',
    'partiesAndEvents': 'מסיבות ואירועים',
    'photographyAndVideo': 'צילום וידאו',
    
    // גינון וסביבה
    'gardening': 'גינון',
    'environmentalCleaning': 'ניקיון סביבתי',
    'cleaningServicesEnv': 'שירותי ניקיון סביבתי',
    'environmentalQuality': 'איכות סביבה',
  };
  
  return categoryMap[categoryCode] || categoryCode;
}

// פונקציה לשליחת התראה רגילה לבקשה חדשה
async function sendDefaultNotification(userId, request, requestId) {
  try {
    // קבלת שם המשתמש שיצר את הבקשה
    const creatorDoc = await admin.firestore().collection('users').doc(request.createdBy).get();
    let creatorName = 'משתמש';
    if (creatorDoc.exists) {
      const u = creatorDoc.data();
      const displayName = u.displayName;
      const email = u.email;
      // זיהוי ערך UID שגוי כשם תצוגה (רצף ארוך של תווים ללא רווחים)
      const looksLikeUid = (val) => typeof val === 'string' && /^[A-Za-z0-9_-]{20,}$/.test(val) && !val.includes(' ');
      if (displayName && !looksLikeUid(displayName)) {
        creatorName = displayName;
      } else if (typeof email === 'string' && email.includes('@')) {
        creatorName = email.split('@')[0];
      }
    }
    
    // קבלת שם הקטגוריה בעברית
    const categoryDisplayName = getCategoryDisplayName(request.category);
    
    // יצירת התראה
    const notificationTitle = 'בקשה חדשה';
    const notificationBody = `${request.title}\nקטגוריה: ${categoryDisplayName}\nמאת: ${creatorName}`;
    
    // שמירת ההתראה ב-Firestore (notifications collection)
    await admin.firestore().collection('notifications').add({
      toUserId: userId,
      title: notificationTitle,
      message: notificationBody,
      type: 'new_request',
      data: {
        requestId: requestId,
        requestTitle: request.title,
        requestCategory: categoryDisplayName,
        creatorName: creatorName,
      },
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      read: false,
    });
    
    // שליחת push notification
    const userDoc = await admin.firestore().collection('users').doc(userId).get();
    if (userDoc.exists) {
      const userData = userDoc.data();
      const fcmToken = userData.fcmToken;
      
      if (fcmToken) {
        await admin.firestore().collection('push_notifications').add({
          userId: userId,
          title: notificationTitle,
          body: notificationBody,
          payload: {
            type: 'new_request',
            requestId: requestId,
          },
          data: {
            type: 'new_request',
            requestId: requestId,
          },
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }
    }
    
    console.log(`✅ Default notification sent to user ${userId} for request ${requestId}`);
    
  } catch (error) {
    console.error(`❌ Error sending default notification to user ${userId}:`, error);
  }
}

// פונקציה לשליחת התראה לסינון
async function sendFilterNotification(userId, request, requestId) {
  try {
    // קבלת FCM token של המשתמש
    const userDoc = await admin.firestore().collection('users').doc(userId).get();
    if (!userDoc.exists) {
      console.log(`❌ User ${userId} not found for notification`);
      return;
    }
    
    const userData = userDoc.data();
    const fcmToken = userData.fcmToken;
    
    if (!fcmToken) {
      console.log(`❌ No FCM token for user ${userId}`);
      return;
    }
    
    // יצירת תוכן ההתראה
    const urgencyText = getUrgencyText(request.urgency);
    const locationText = getLocationText(request.address);
    
    const notificationTitle = 'בקשה חדשה מתאימה לסינון שלך';
    const notificationBody = `${request.title}\nדחיפות: ${urgencyText}\nמיקום: ${locationText}`;
    
    // שליחת התראה דרך push_notifications collection
    await admin.firestore().collection('push_notifications').add({
      userId: userId,
      title: notificationTitle,
      body: notificationBody,
      payload: {
        type: 'filter_match',
        screen: 'home',
        requestId: requestId,
      },
      data: {
        type: 'filter_match',
        screen: 'home',
        requestId: requestId,
      },
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    
    console.log(`📱 Filter notification sent to user ${userId} for request ${requestId}`);
    
  } catch (error) {
    console.error('❌ Error sending filter notification:', error);
  }
}

// פונקציה לקבלת טקסט דחיפות
function getUrgencyText(urgency) {
  switch (urgency) {
    case 'low': return 'נמוכה';
    case 'medium': return 'בינונית';
    case 'high': return 'גבוהה';
    case 'urgent': return 'דחוף';
    default: return 'לא צוין';
  }
}

// פונקציה לקבלת טקסט מיקום
function getLocationText(address) {
  if (!address) return 'מיקום לא צוין';
  
  // חיתוך כתובת אם היא ארוכה מדי
  if (address.length > 30) {
    return address.substring(0, 30) + '...';
  }
  
  return address;
}

// Cloud Function להתראת נותני שירות כשבקשה חדשה נוצרת
exports.notifyServiceProvidersOnNewRequest = functions.firestore
  .document('requests/{requestId}')
  .onCreate(async (snap, context) => {
    try {
      console.log('🚀 ===== NOTIFYING SERVICE PROVIDERS - NEW REQUEST CREATED =====');

      const request = snap.data();
      const requestId = context.params.requestId;

      // בדיקת תנאים בסיסיים:
      // 1. בקשה בתשלום (רק בקשות בתשלום מופיעות במפה)
      if (request.type !== 'paid') {
        console.log(`❌ Request ${requestId} is not paid type, skipping service provider notifications`);
        return;
      }

      // 2. בקשה פתוחה
      if (request.status !== 'open') {
        console.log(`❌ Request ${requestId} is not open, skipping`);
        return;
      }

      // 3. מיקום וטווח חשיפה קיימים
      if (!request.latitude || !request.longitude || !request.exposureRadius) {
        console.log(`❌ Request ${requestId} missing location or exposure radius, skipping`);
        return;
      }

      console.log(`📊 New request: ${requestId} - ${request.title}`);
      console.log(`📍 Location: ${request.latitude}, ${request.longitude}`);
      console.log(`📏 Exposure radius: ${request.exposureRadius} km`);
      console.log(`🏷️ Category: ${request.category}`);

      // מציאת נותני שירות רלוונטיים
      // התראות נשלחות לשני סוגי משתמשים:
      // 1. עסקי מנוי - עם מנוי פעיל ותחומי עיסוק מתאימים
      // 2. אורח - בשבוע הראשון רואה הכל, אחרי שבוע רק תחומי עיסוק מתאימים
      const notifiedUsers = new Set();
      
      // 1. משתמשים עסקיים עם מנוי פעיל
      console.log('🔍 Querying business users...');
      const businessUsersSnapshot = await admin.firestore()
        .collection('users')
        .where('userType', '==', 'business')
        .where('isSubscriptionActive', '==', true)
        .get();

      console.log(`📊 Found ${businessUsersSnapshot.size} business users with active subscription`);

      for (const userDoc of businessUsersSnapshot.docs) {
        const userData = userDoc.data();
        const userId = userDoc.id;

        console.log(`🔍 Checking business user: ${userId} (${userData.displayName || userData.email || 'Unknown'})`);

        // בדיקה אם זה יוצר הבקשה
        if (userId === request.createdBy) {
          console.log(`   ❌ User ${userId} is the request creator - skipping`);
          continue;
        }

        // בדיקת קטגוריה
        const userCategories = userData.businessCategories || [];
        const requestCategory = request.category;
        
        console.log(`   🔍 Checking category: request="${requestCategory}", user categories=${JSON.stringify(userCategories)}`);
        
        let hasMatchingCategory = false;
        for (const cat of userCategories) {
          if (cat === requestCategory) {
            hasMatchingCategory = true;
            break;
          }
        }

        if (!hasMatchingCategory) {
          console.log(`   ❌ Category mismatch - user does not have category "${requestCategory}"`);
          continue;
        }

        console.log(`   ✅ Category match found`);

        // קבלת העדפות התראות של המשתמש
        const notificationPrefs = await admin.firestore()
          .collection('notification_preferences')
          .doc(userId)
          .get();
        
        const hasPrefs = notificationPrefs.exists && notificationPrefs.data();
        const useFixedLocation = hasPrefs ? (notificationPrefs.data().newRequestsUseFixedLocation || false) : true;
        const useMobileLocation = hasPrefs ? (notificationPrefs.data().newRequestsUseMobileLocation || false) : false;
        const useBothLocations = hasPrefs ? (notificationPrefs.data().newRequestsUseBothLocations || false) : false;
        
        console.log(`   📍 Location preferences: fixed=${useFixedLocation}, mobile=${useMobileLocation}, both=${useBothLocations}`);
        
        // בדיקה אם המשתמש בחר במפורש "לא לקבל התראות" (כל הערכים false)
        if (hasPrefs && !useFixedLocation && !useMobileLocation && !useBothLocations) {
          console.log(`   ⛔ User ${userId} opted out of receiving new paid request notifications`);
          continue;
        }

        // בדיקת מיקום לפי העדפות
        let hasValidLocation = false;
        let userLat = userData.latitude;
        let userLng = userData.longitude;
        
        // אם לא בחר אופציה ספציפית או בחר מיקום קבוע או שניהם
        if (useFixedLocation || useBothLocations) {
          if (userData.latitude && userData.longitude) {
            hasValidLocation = true;
            userLat = userData.latitude;
            userLng = userData.longitude;
            console.log(`   📍 Using fixed location: ${userLat}, ${userLng}`);
          }
        }
        
        // אם בחר מיקום נייד או שניהם - לבדוק את currentLocation
        if (!hasValidLocation && (useMobileLocation || useBothLocations)) {
          const currentLoc = userData.currentLocation || userData.currentLatLng;
          if (currentLoc && currentLoc.latitude && currentLoc.longitude) {
            hasValidLocation = true;
            userLat = currentLoc.latitude;
            userLng = currentLoc.longitude;
            console.log(`   📍 Using mobile location: ${userLat}, ${userLng}`);
          }
        }
        
        if (!hasValidLocation) {
          console.log(`   ❌ No valid location data according to preferences`);
          continue;
        }

        // חישוב מרחק
        const distance = calculateDistance(
          request.latitude,
          request.longitude,
          userLat,
          userLng
        );

        console.log(`   📏 Distance: ${distance.toFixed(2)} km, Exposure radius: ${request.exposureRadius} km`);

        if (distance > request.exposureRadius) {
          console.log(`   ❌ Distance too far (${distance.toFixed(2)} km > ${request.exposureRadius} km)`);
          continue;
        }

        console.log(`   ✅ Within radius`);

        // בדיקת דרישות דירוג
        const meetsRatingRequirements = checkRatingRequirements(request, userData);
        
        if (!meetsRatingRequirements) {
          console.log(`   ❌ Does not meet rating requirements`);
          continue;
        }

        console.log(`   ✅ Meets rating requirements`);

        // שליחת התראה
        if (!notifiedUsers.has(userId)) {
          await sendServiceProviderNotification(userId, request, requestId);
          notifiedUsers.add(userId);
          console.log(`✅ Notified service provider: ${userId}`);
        }
      }

      // 2. משתמשי אורח
      console.log('🔍 Querying guest users...');
      const allUsersSnapshot = await admin.firestore()
        .collection('users')
        .get();
      
      const guestUsersDocs = allUsersSnapshot.docs.filter(doc => {
        const userData = doc.data();
        return userData.userType === 'guest';
      });

      console.log(`📊 Found ${guestUsersDocs.length} guest users`);
      
      if (guestUsersDocs.length === 0) {
        console.log(`❌ No guest users found to check`);
      }

      for (const userDoc of guestUsersDocs) {
        try {
          const userData = userDoc.data();
          const userId = userDoc.id;

          console.log(`🔍 Checking guest user: ${userId} (${userData.displayName || userData.email || 'Unknown'})`);
          console.log(`   📊 User data: businessCategories=${JSON.stringify(userData.businessCategories)}, lat=${userData.latitude}, lng=${userData.longitude}`);

        // בדיקה אם זה יוצר הבקשה
        if (userId === request.createdBy) {
          console.log(`   ❌ User ${userId} is the request creator - skipping`);
          continue;
        }

        // בדיקת תנאים למשתמש אורח:
        // א. בשבוע ראשון - רואה כל הבקשות בתשלום (ללא בדיקת קטגוריה)
        // ב. אחרי שבוע - רק אם התחומי עיסוק שלו מתאימים לקטגוריה של הבקשה
        const guestTrialStartDate = userData.guestTrialStartDate;
        let isInFirstWeek = false;
        
        if (guestTrialStartDate) {
          const now = new Date();
          const trialStart = guestTrialStartDate.toDate();
          const daysSinceStart = Math.floor((now - trialStart) / (1000 * 60 * 60 * 24));
          isInFirstWeek = daysSinceStart < 7;
          console.log(`   🕐 Guest trial: ${daysSinceStart} days since start, isInFirstWeek: ${isInFirstWeek}`);
        }

        // שבוע ראשון - רואה כל הבקשות בתשלום
        if (isInFirstWeek) {
          console.log(`   ✅ Guest in first week - checking location only`);
        } else {
          // אחרי שבוע - רק אם בחר תחומי עיסוק והבקשה מתאימה
          const userCategories = userData.businessCategories || [];
          const requestCategory = request.category;
          
          console.log(`   🔍 Checking category (after first week): request="${requestCategory}", user categories=${JSON.stringify(userCategories)}`);
          
          let hasMatchingCategory = false;
          for (const cat of userCategories) {
            if (cat === requestCategory) {
              hasMatchingCategory = true;
              break;
            }
          }

          if (!hasMatchingCategory) {
            console.log(`   ❌ Category mismatch - user does not have category "${requestCategory}"`);
            continue;
          }
          console.log(`   ✅ Category match found`);
        }

        // קבלת העדפות התראות של המשתמש
        const notificationPrefs = await admin.firestore()
          .collection('notification_preferences')
          .doc(userId)
          .get();
        
        const hasPrefs = notificationPrefs.exists && notificationPrefs.data();
        const useFixedLocation = hasPrefs ? (notificationPrefs.data().newRequestsUseFixedLocation || false) : true;
        const useMobileLocation = hasPrefs ? (notificationPrefs.data().newRequestsUseMobileLocation || false) : false;
        const useBothLocations = hasPrefs ? (notificationPrefs.data().newRequestsUseBothLocations || false) : false;
        
        console.log(`   📍 Location preferences: fixed=${useFixedLocation}, mobile=${useMobileLocation}, both=${useBothLocations}`);
        
        // בדיקה אם המשתמש בחר במפורש "לא לקבל התראות" (כל הערכים false)
        if (hasPrefs && !useFixedLocation && !useMobileLocation && !useBothLocations) {
          console.log(`   ⛔ User ${userId} opted out of receiving new paid request notifications`);
          continue;
        }

        // בדיקת מיקום לפי העדפות
        let hasValidLocation = false;
        let userLat = userData.latitude;
        let userLng = userData.longitude;
        
        // אם לא בחר אופציה ספציפית או בחר מיקום קבוע או שניהם
        if (useFixedLocation || useBothLocations) {
          if (userData.latitude && userData.longitude) {
            hasValidLocation = true;
            userLat = userData.latitude;
            userLng = userData.longitude;
            console.log(`   📍 Using fixed location: ${userLat}, ${userLng}`);
          }
        }
        
        // אם בחר מיקום נייד או שניהם - לבדוק את currentLocation
        if (!hasValidLocation && (useMobileLocation || useBothLocations)) {
          const currentLoc = userData.currentLocation || userData.currentLatLng;
          if (currentLoc && currentLoc.latitude && currentLoc.longitude) {
            hasValidLocation = true;
            userLat = currentLoc.latitude;
            userLng = currentLoc.longitude;
            console.log(`   📍 Using mobile location: ${userLat}, ${userLng}`);
          }
        }
        
        // אם אין מיקום ויש העדפות - בדוק רק אם זה שבוע ראשון
        if (!hasValidLocation) {
          console.log(`   ⚠️ No location data according to preferences`);
          // אם זה משתמש אורח בשבוע הראשון, שלח התראה גם בלי מיקום
          if (isInFirstWeek && (!useFixedLocation && !useMobileLocation && !useBothLocations)) {
            console.log(`   ✅ Guest in first week without preferences - sending notification anyway`);
          } else {
            console.log(`   ❌ No valid location according to preferences`);
            continue;
          }
        } else {
          // חישוב מרחק רק אם יש מיקום תקף
          const distance = calculateDistance(
            request.latitude,
            request.longitude,
            userLat,
            userLng
          );

          console.log(`   📏 Distance: ${distance.toFixed(2)} km, Exposure radius: ${request.exposureRadius} km`);

          if (distance > request.exposureRadius) {
            console.log(`   ❌ Distance too far (${distance.toFixed(2)} km > ${request.exposureRadius} km)`);
            continue;
          }

          console.log(`   ✅ Within radius`);
        }

        // 4. בדיקת דרישות דירוג - המשתמש חייב לעמוד בדרישות הדירוג של הבקשה
        const meetsRatingRequirements = checkRatingRequirements(request, userData);
        
        if (!meetsRatingRequirements) {
          console.log(`   ❌ Does not meet rating requirements`);
          continue;
        }

        console.log(`   ✅ Meets rating requirements`);

        // שליחת התראה
        if (!notifiedUsers.has(userId)) {
          await sendServiceProviderNotification(userId, request, requestId);
          notifiedUsers.add(userId);
          console.log(`✅ Notified guest service provider: ${userId}`);
        }
        } catch (error) {
          console.error(`❌ Error checking guest user ${userId}:`, error);
        }
      }

      console.log(`✅ Total service providers notified: ${notifiedUsers.size}`);
      console.log('🚀 ===== SERVICE PROVIDER NOTIFICATIONS COMPLETED =====');

    } catch (error) {
      console.error('❌ Error notifying service providers:', error);
    }
  });

// פונקציה לבדיקת דרישות דירוג
function checkRatingRequirements(request, userData) {
  console.log(`   🔍 Checking rating requirements:`);
  
  // בדיקת דירוג כללי
  if (request.minRating) {
    console.log(`      - minRating required: ${request.minRating}, user: ${userData.averageRating || 0}`);
    if (!userData.averageRating || userData.averageRating < request.minRating) {
      console.log(`      ❌ Rating requirement not met`);
      return false;
    }
  }
  
  // בדיקת אמינות
  if (request.minReliability) {
    console.log(`      - minReliability required: ${request.minReliability}, user: ${userData.reliability || 0}`);
    if (!userData.reliability || userData.reliability < request.minReliability) {
      console.log(`      ❌ Reliability requirement not met`);
      return false;
    }
  }
  
  // בדיקת זמינות
  if (request.minAvailability) {
    console.log(`      - minAvailability required: ${request.minAvailability}, user: ${userData.availability || 0}`);
    if (!userData.availability || userData.availability < request.minAvailability) {
      console.log(`      ❌ Availability requirement not met`);
      return false;
    }
  }
  
  // בדיקת יחס
  if (request.minAttitude) {
    console.log(`      - minAttitude required: ${request.minAttitude}, user: ${userData.attitude || 0}`);
    if (!userData.attitude || userData.attitude < request.minAttitude) {
      console.log(`      ❌ Attitude requirement not met`);
      return false;
    }
  }
  
  // בדיקת מחיר הוגן
  if (request.minFairPrice) {
    console.log(`      - minFairPrice required: ${request.minFairPrice}, user: ${userData.fairPrice || 0}`);
    if (!userData.fairPrice || userData.fairPrice < request.minFairPrice) {
      console.log(`      ❌ Fair price requirement not met`);
      return false;
    }
  }
  
  console.log(`      ✅ All rating requirements met`);
  return true;
}

// פונקציה לשליחת התראה לנותן שירות
async function sendServiceProviderNotification(userId, request, requestId) {
  try {
    // בדיקה שההתראה לא נשלחה כבר למניעת כפילות
    console.log(`🔍 Checking if notification already sent to ${userId} for request ${requestId}`);
    const existingNotification = await admin.firestore()
      .collection('notifications')
      .where('toUserId', '==', userId)
      .where('data.requestId', '==', requestId)
      .where('type', '==', 'service_provider_match')
      .limit(1)
      .get();

    if (!existingNotification.empty) {
      console.log(`⏭️ Notification already sent to ${userId} for request ${requestId} - skipping`);
      return;
    }
    console.log(`✅ No existing notification found - proceeding to send`);

    // קבלת FCM token של המשתמש
    const userDoc = await admin.firestore().collection('users').doc(userId).get();
    if (!userDoc.exists) {
      console.log(`❌ User ${userId} not found for notification`);
      return;
    }

    const userData = userDoc.data();
    const fcmToken = userData.fcmToken;

    if (!fcmToken) {
      console.log(`❌ No FCM token for user ${userId}`);
      return;
    }

    // יצירת תוכן ההתראה
    // בדיקה אם הבקשה דחופה
    const isUrgent = request.isUrgent || request.urgencyLevel === 'urgent' || request.urgencyLevel === 'emergency' || request.urgencyLevel === 'urgent24h';
    
    // קבלת שם הקטגוריה
    const categoryName = getCategoryDisplayName(request.category);
    
    const notificationTitle = isUrgent ? `בקשה דחופה 🚨🎯` : `בקשה חדשה 🎯`;
    const notificationBody = `"${request.title}" - תחום: ${categoryName}${isUrgent ? ' (דחופה!)' : ''}`;

    // שליחת התראה דרך notifications collection (להודעות באפליקציה)
    await admin.firestore().collection('notifications').add({
      toUserId: userId,
      title: notificationTitle,
      message: notificationBody,
      type: 'service_provider_match',
      read: false,
      data: {
        requestId: requestId,
        requestTitle: request.title,
        category: request.category,
      },
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // שליחת התראה דרך push_notifications collection (עבור Push גם כשהאפליקציה סגורה)
    await admin.firestore().collection('push_notifications').add({
      userId: userId,
      title: notificationTitle,
      body: notificationBody,
      payload: {
        type: 'service_provider_match',
        screen: 'home',
      },
      requestId: requestId,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    console.log(`📱 Service provider notification sent to user ${userId} for request ${requestId}`);

  } catch (error) {
    console.error('❌ Error sending service provider notification:', error);
  }
}

// הגדרת nodemailer transporter
// ⚠️ חשוב: הגדר את המשתנים הבאים ב-Firebase Console > Functions > Configuration:
// - EMAIL_USER: כתובת Gmail שלך (לדוגמה: your-email@gmail.com)
// - EMAIL_PASS: App Password של Gmail (לא הסיסמה הרגילה!)
// 
// איך ליצור App Password ב-Gmail:
// 1. היכנס ל-Google Account > Security
// 2. הפעל 2-Step Verification אם לא מופעל
// 3. עבור ל-App passwords
// 4. צור App Password חדש בשם "Firebase Functions"
// 5. העתק את הסיסמה והדבק ב-EMAIL_PASS

function createTransporter() {
  // משתמש ב-Environment Variables החדש (תמיכה גם ב-functions.config() הישן לגיבוי)
  const emailUser = process.env.EMAIL_USER || functions.config().email?.user;
  const emailPass = process.env.EMAIL_PASS || functions.config().email?.pass;

  if (!emailUser || !emailPass) {
    console.error('❌ Email credentials not configured. Please set EMAIL_USER and EMAIL_PASS as environment variables.');
    console.error('   You can set them via: firebase functions:secrets:set EMAIL_USER EMAIL_PASS');
    return null;
  }

  return nodemailer.createTransport({
    service: 'gmail',
    auth: {
      user: emailUser,
      pass: emailPass,
    },
  });
}

// Cloud Function לשליחת אימייל אימות מותאם אישית
// משתמש ב-Google Secret Manager לביטחון (מומלץ) או Environment Variables
exports.sendCustomVerificationEmail = functions
  .runWith({
    secrets: ['EMAIL_USER', 'EMAIL_PASS'], // Google Secret Manager
    minInstances: 1, // תמיד פעיל - מונע cold start (מהיר יותר)
    timeoutSeconds: 60, // timeout של 60 שניות
  })
  .https.onCall(async (data, context) => {
  const startTime = Date.now();
  try {
    console.log('📧 sendCustomVerificationEmail called');
    console.log('📧 Timestamp:', new Date().toISOString());
    console.log('📧 Data:', JSON.stringify(data));
    console.log('📧 Context auth:', context.auth ? context.auth.uid : 'no auth');
    
    const email = data.email;
    const userId = data.userId; // Optional - אם לא מסופק, נשתמש ב-context.auth
    const password = data.password; // הסיסמה להוספה לאימייל

    if (!email) {
      console.error('❌ Email is required');
      throw new functions.https.HttpsError('invalid-argument', 'Email is required');
    }

    console.log(`📧 Processing verification email for: ${email}`);

    // אם יש userId, נבדוק שהאימייל תואם (אבל לא נדרש authentication)
    if (userId) {
      try {
        const user = await admin.auth().getUser(userId);
        if (user.email !== email) {
          console.error(`❌ Email mismatch: ${user.email} !== ${email}`);
          throw new functions.https.HttpsError('permission-denied', 'Email does not match user email');
        }
        console.log(`✅ Email matches user: ${userId}`);
      } catch (error) {
        console.error(`❌ Error getting user ${userId}:`, error);
        // לא נזרוק שגיאה - נמשיך לשלוח אימייל
      }
    } else if (context.auth) {
      // אם יש context.auth, נשתמש בו
      try {
        const user = await admin.auth().getUser(context.auth.uid);
        if (user.email !== email) {
          console.error(`❌ Email mismatch: ${user.email} !== ${email}`);
          throw new functions.https.HttpsError('permission-denied', 'Email does not match authenticated user');
        }
        console.log(`✅ Email matches authenticated user: ${context.auth.uid}`);
      } catch (error) {
        console.error(`❌ Error getting authenticated user:`, error);
        // לא נזרוק שגיאה - נמשיך לשלוח אימייל
      }
    } else {
      console.log('⚠️ No userId or context.auth - sending email anyway (registration flow)');
    }

    // יצירת קישור אימות - מחזיר למקום שממנו נרשם
    const platform = data.platform || 'web'; // web, android, ios
    console.log(`📧 Platform detected: ${platform}`);
    
    // יצירת URL עם הודעה מותאמת - ללא כפתור CONTINUE
    // Firebase Auth יראה דף "Your email has been verified" אבל עם הודעה מותאמת
    let actionCodeSettings;
    const customMessage = 'האימייל שלך אומת. התחבר שוב לשכונתי עם הפרטים שנרשמת בהם.';
    if (platform === 'android' || platform === 'ios') {
      // אם נרשם דרך אפליקציה - מנסה לפתוח באפליקציה
      actionCodeSettings = {
        url: `https://nearme-970f3.web.app/email-verified?email=${encodeURIComponent(email)}&message=${encodeURIComponent(customMessage)}`,
        handleCodeInApp: true, // מנסה לפתוח באפליקציה
        androidPackageName: 'com.example.flutter1',
        iOSBundleId: 'com.example.flutter1',
      };
      console.log('📱 Using mobile app redirect');
    } else {
      // אם נרשם דרך web - מחזיר לאתר עם הודעה מותאמת
      actionCodeSettings = {
        url: `https://nearme-970f3.web.app/email-verified?email=${encodeURIComponent(email)}&message=${encodeURIComponent(customMessage)}`,
        handleCodeInApp: false, // נשאר באתר
      };
      console.log('🌐 Using web redirect');
    }

    console.log('📧 Generating verification link...');
    const verificationLink = await admin.auth().generateEmailVerificationLink(email, actionCodeSettings);
    console.log('✅ Verification link generated');

    // יצירת transporter
    console.log('📧 Creating email transporter...');
    const transporter = createTransporter();
    if (!transporter) {
      console.error('❌ Email transporter not configured');
      throw new Error('Email transporter not configured');
    }
    console.log('✅ Email transporter created');

    // תוכן האימייל בעברית ובאנגלית
    const emailHtml = `
<!DOCTYPE html>
<html dir="rtl" lang="he">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>אימות אימייל - MyNeighborhood</title>
</head>
<body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333; max-width: 600px; margin: 0 auto; padding: 20px;">
  <div style="background-color: #f4f4f4; padding: 20px; border-radius: 10px;">
    <!-- לוגו שכונתי -->
    <div style="text-align: center; margin-bottom: 20px;">
      <img src="https://nearme-970f3.web.app/images/logo.png" 
           alt="שכונתי" 
           style="width: 120px; height: 120px; border-radius: 20px; background-color: white; padding: 15px; box-shadow: 0 4px 6px rgba(0,0,0,0.1);">
    </div>
    
    <h2 style="color: #2c3e50; text-align: center; margin-top: 10px;">אימות אימייל - אפליקציית "שכונתי"</h2>
    
    <div style="background-color: white; padding: 30px; border-radius: 8px; margin-top: 20px;">
      <p style="font-size: 16px;">שלום,</p>
      
      <p style="font-size: 16px;">אנא לחץ על הקישור הבא כדי לאמת את כתובת האימייל שלך:</p>
      
      <div style="text-align: center; margin: 30px 0;">
        <a href="${verificationLink}" 
           style="background-color: #3498db; color: white; padding: 15px 30px; text-decoration: none; border-radius: 5px; display: inline-block; font-size: 16px; font-weight: bold;">
          אמת את האימייל שלי
        </a>
      </div>
      
      <p style="font-size: 14px; color: #666;">או העתק והדבק את הקישור הבא בדפדפן שלך:</p>
      <p style="font-size: 12px; color: #999; word-break: break-all;">${verificationLink}</p>
      
      ${password ? `
      <div style="background-color: #f9f9f9; padding: 20px; border-radius: 5px; margin-top: 30px; border-left: 4px solid #3498db;">
        <p style="font-size: 16px; font-weight: bold; color: #2c3e50; margin-bottom: 15px;">פרטי ההתחברות שלך:</p>
        <p style="font-size: 14px; color: #333; margin: 5px 0;"><strong>אימייל:</strong> ${email}</p>
        <p style="font-size: 14px; color: #333; margin: 5px 0;"><strong>סיסמה:</strong> ${password}</p>
        <p style="font-size: 12px; color: #666; margin-top: 15px;">שמור את הפרטים האלה - תצטרך אותם להתחברות.</p>
      </div>
      ` : ''}
      
      <p style="font-size: 14px; color: #666; margin-top: 30px;">אם לא ביקשת לאמת כתובת זו, תוכל להתעלם מהאימייל הזה.</p>
      
      <hr style="border: none; border-top: 1px solid #eee; margin: 30px 0;">
      
      <div dir="ltr" style="text-align: left;">
        <p style="font-size: 16px;">Hello,</p>
        
        <p style="font-size: 16px;">Please click the following link to verify your email address:</p>
        
        <div style="text-align: center; margin: 30px 0;">
          <a href="${verificationLink}" 
             style="background-color: #3498db; color: white; padding: 15px 30px; text-decoration: none; border-radius: 5px; display: inline-block; font-size: 16px; font-weight: bold;">
            Verify my email
          </a>
        </div>
        
        <p style="font-size: 14px; color: #666;">Or copy and paste this link into your browser:</p>
        <p style="font-size: 12px; color: #999; word-break: break-all;">${verificationLink}</p>
        
        ${password ? `
        <div style="background-color: #f9f9f9; padding: 20px; border-radius: 5px; margin-top: 30px; border-left: 4px solid #3498db;">
          <p style="font-size: 16px; font-weight: bold; color: #2c3e50; margin-bottom: 15px;">Your login details:</p>
          <p style="font-size: 14px; color: #333; margin: 5px 0;"><strong>Email:</strong> ${email}</p>
          <p style="font-size: 14px; color: #333; margin: 5px 0;"><strong>Password:</strong> ${password}</p>
          <p style="font-size: 12px; color: #666; margin-top: 15px;">Save these details - you'll need them to log in.</p>
        </div>
        ` : ''}
        
        <p style="font-size: 14px; color: #666; margin-top: 30px;">If you didn't ask to verify this address, you can ignore this email.</p>
      </div>
    </div>
    
    <p style="text-align: center; color: #666; font-size: 14px; margin-top: 20px;">
      תודה,<br>
      צוות אפליקציית "שכונתי"
    </p>
    <p style="text-align: center; color: #666; font-size: 14px; margin-top: 10px;" dir="ltr">
      Thanks,<br>
      MyNeighborhood team
    </p>
  </div>
</body>
</html>
    `;

    const emailText = `
שלום,

אנא לחץ על הקישור הבא כדי לאמת את כתובת האימייל שלך:

${verificationLink}

${password ? `
פרטי ההתחברות שלך:
אימייל: ${email}
סיסמה: ${password}

שמור את הפרטים האלה - תצטרך אותם להתחברות.
` : ''}

אם לא ביקשת לאמת כתובת זו, תוכל להתעלם מהאימייל הזה.

תודה,
צוות אפליקציית "שכונתי"

---

Hello,

Please click the following link to verify your email address:

${verificationLink}

${password ? `
Your login details:
Email: ${email}
Password: ${password}

Save these details - you'll need them to log in.
` : ''}

If you didn't ask to verify this address, you can ignore this email.

Thanks,
MyNeighborhood team
    `;

    // שליחת האימייל
    const mailOptions = {
      from: `"MyNeighborhood" <${functions.config().email?.user || process.env.EMAIL_USER}>`,
      to: email,
      subject: 'Verify your email for MyNeighborhood App',
      text: emailText,
      html: emailHtml,
      replyTo: functions.config().email?.user || process.env.EMAIL_USER,
    };

    console.log(`📧 Sending email to: ${email}`);
    console.log(`📧 From: ${mailOptions.from}`);
    console.log(`📧 Subject: ${mailOptions.subject}`);
    
    const sendStartTime = Date.now();
    const emailResult = await transporter.sendMail(mailOptions);
    const sendEndTime = Date.now();
    const sendDuration = sendEndTime - sendStartTime;
    
    const totalDuration = Date.now() - startTime;
    
    console.log(`✅ Custom verification email sent successfully to: ${email}`);
    console.log(`✅ Email result:`, emailResult);
    console.log(`⏱️ Email send duration: ${sendDuration}ms`);
    console.log(`⏱️ Total function duration: ${totalDuration}ms`);

    return {
      success: true,
      message: 'Verification email sent successfully',
      duration: totalDuration,
    };
  } catch (error) {
    const totalDuration = Date.now() - startTime;
    console.error('❌ Error sending custom verification email:', error);
    console.error(`⏱️ Function failed after: ${totalDuration}ms`);
    throw new functions.https.HttpsError('internal', error.message);
  }
});