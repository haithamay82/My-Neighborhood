const functions = require('firebase-functions');
const admin = require('firebase-admin');
const express = require('express');
const cors = require('cors');

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
      const { userId, title, body, payload, ...extraData } = notificationData;
      
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
      
      // Send FCM message
      const message = {
        token: fcmToken,
        notification: {
          title: title,
          body: body,
        },
        data: {
          payload: payload || '',
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
                body: body,
              },
            },
          },
        },
      };
      
      const response = await admin.messaging().send(message);
      console.log('Successfully sent message:', response);
      
      // Delete the notification document after sending
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

// PayMe Webhook Handler
exports.paymeWebhook = functions.https.onRequest(async (req, res) => {
  try {
    console.log('PayMe webhook received:', req.body);
    
    // Verify webhook signature (if PayMe provides one)
    const signature = req.headers['x-payme-signature'] || req.headers['x-signature'];
    const webhookSecret = 'YOUR_WEBHOOK_SECRET'; // Replace with actual secret
    
    // Basic validation
    if (req.method !== 'POST') {
      return res.status(405).send('Method not allowed');
    }
    
    const webhookData = req.body;
    const { payment_id, status, amount, currency, metadata } = webhookData;
    
    if (!payment_id || !status) {
      console.error('Invalid webhook data:', webhookData);
      return res.status(400).send('Invalid webhook data');
    }
    
    console.log(`Processing PayMe webhook: Payment ${payment_id}, Status: ${status}`);
    
    // Update payment status in Firestore
    await admin.firestore()
      .collection('payme_payments')
      .doc(payment_id)
      .update({
        status: status,
        updated_at: admin.firestore.FieldValue.serverTimestamp(),
        webhook_received_at: admin.firestore.FieldValue.serverTimestamp(),
      });
    
    // If payment is completed, activate subscription
    if (status === 'completed' || status === 'paid') {
      console.log(`Activating subscription for payment: ${payment_id}`);
      
      // Get payment details
      const paymentDoc = await admin.firestore()
        .collection('payme_payments')
        .doc(payment_id)
        .get();
      
      if (!paymentDoc.exists) {
        console.error('Payment document not found:', payment_id);
        return res.status(404).send('Payment not found');
      }
      
      const paymentData = paymentDoc.data();
      const userId = paymentData.user_id;
      const subscriptionType = paymentData.subscription_type;
      const userEmail = paymentData.user_email;
      const userName = paymentData.user_name;
      
      // Calculate subscription expiry (1 year from now)
      const subscriptionExpiry = new Date();
      subscriptionExpiry.setFullYear(subscriptionExpiry.getFullYear() + 1);
      
      // Get current user profile
      const userDoc = await admin.firestore()
        .collection('users')
        .doc(userId)
        .get();
      
      let currentBusinessCategories = [];
      if (userDoc.exists) {
        const userData = userDoc.data();
        currentBusinessCategories = userData.businessCategories || [];
      }
      
      // Prepare update data based on subscription type
      const updateData = {
        isSubscriptionActive: true,
        subscriptionStatus: 'active',
        subscriptionExpiry: admin.firestore.Timestamp.fromDate(subscriptionExpiry),
        approvedPaymentId: payment_id,
        approvedAt: admin.firestore.Timestamp.now(),
        paymentMethod: 'payme',
      };
      
      if (subscriptionType === 'business') {
        console.log('Setting user as BUSINESS subscription via PayMe webhook');
        if (currentBusinessCategories.length === 0) {
          // Add all business categories for new business users
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
        }
        updateData.userType = 'business';
        updateData.businessCategories = currentBusinessCategories;
      } else {
        console.log('Setting user as PERSONAL subscription via PayMe webhook');
        updateData.userType = 'personal';
        updateData.businessCategories = admin.firestore.FieldValue.delete();
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
      await admin.firestore()
        .collection('payme_payments')
        .doc(payment_id)
        .update({
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
    }
    
    // Respond to PayMe
    res.status(200).json({ success: true, message: 'Webhook processed successfully' });
    
  } catch (error) {
    console.error('Error processing PayMe webhook:', error);
    res.status(500).json({ success: false, error: error.message });
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