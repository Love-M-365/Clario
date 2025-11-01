/**
 * Daily Journal Reminder Function
 * - Runs via Cloud Scheduler once a day.
 * - Sends a push notification to all users reminding them to write their journal.
 */

const functions = require('@google-cloud/functions-framework');
const admin = require('firebase-admin');

// Initialize Firebase app if not already
if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
    databaseURL: 'https://YOUR_PROJECT_ID.firebaseio.com', // 🔹 replace with your Firebase DB URL
  });
}

exports.dailyJournalReminder = functions.http('dailyJournalReminder', async (req, res) => {
  try {
    console.log('Daily Journal Reminder triggered!');

    // Get all user FCM tokens stored in Firestore
    const usersSnapshot = await admin.firestore().collection('users').get();
    const tokens = [];

    usersSnapshot.forEach((doc) => {
      const data = doc.data();
      if (data.fcmToken) tokens.push(data.fcmToken);
    });

    if (tokens.length === 0) {
      console.log('No user tokens found.');
      return res.status(200).send('No tokens found. Reminder skipped.');
    }

    // Notification payload
    const payload = {
      notification: {
        title: '📝 Daily Journal Reminder',
        body: 'Take a moment to write your journal today and reflect on your day.',
      },
      data: {
        screen: 'journal', // optional: use this in Flutter to route user to Journal screen
      },
    };

    // Send notifications in batches
    const response = await admin.messaging().sendEachForMulticast({
      tokens,
      notification: payload.notification,
      data: payload.data,
    });

    console.log('Notifications sent:', response.successCount);
    res.status(200).send(`Daily Journal Reminder sent to ${response.successCount} users.`);
  } catch (error) {
    console.error('Error sending daily reminder:', error);
    res.status(500).send('Error sending reminders.');
  }
});
