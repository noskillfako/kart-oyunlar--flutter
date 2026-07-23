import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PresenceService {
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  Timer? _timer;

  PresenceService({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _db = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  /// Periyodik (5s) varlık sinyalini (heartbeat) başlatır
  void startHeartbeat(String roomId) {
    stopHeartbeat();
    _sendHeartbeat(roomId);
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      _sendHeartbeat(roomId);
    });
  }

  /// Varlık sinyalini durdurur
  void stopHeartbeat() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _sendHeartbeat(String roomId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _db.collection('rooms').doc(roomId).collection('presence').doc(user.uid).set({
        'lastActiveAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // Hata durumunda sessizce yutulur (ağ kesintisi vb.)
    }
  }
}
