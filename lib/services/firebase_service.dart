import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirebaseService {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  FirebaseFirestore get firestore => _firestore;

  Future<void> logSensorEvent(String type, double value) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    await _firestore.collection('sensorEvents').add({
      'userId': uid,
      'type': type,
      'value': value,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Future<void> logAppUsage(String appName, double minutes) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    await _firestore.collection('appUsage').add({
      'userId': uid,
      'app': appName,
      'minutes': minutes,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateDailySummary(int steps, int shakes) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('sensorSummary')
        .doc('today')
        .set({
      'steps': steps,
      'shakes': shakes,
      'lastUpdated': FieldValue.serverTimestamp(),
    });
  }
}
