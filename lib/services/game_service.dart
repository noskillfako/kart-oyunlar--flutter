import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/playing_card.dart';

class GameService {
  final _db = FirebaseFirestore.instance;

  /// Herkesin görebileceği oyun durumunu (masa, sıra, skorlar vb.) dinler
  Stream<DocumentSnapshot<Map<String, dynamic>>> watchPublicState(String roomId) {
    return _db.doc('rooms/$roomId/gameState/public').snapshots();
  }

  /// Sadece kendi elimizi dinler (Firestore rules sayesinde başkasının elini göremeyiz)
  Stream<List<PlayingCard>> watchMyHand(String roomId) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const Stream.empty();

    return _db.doc('rooms/$roomId/hands/$uid').snapshots().map((snap) {
      if (!snap.exists) return <PlayingCard>[];
      final data = snap.data();
      final rawCards = List<Map<String, dynamic>>.from(data?['cards'] ?? []);
      return rawCards.map((c) => PlayingCard.fromMap(c)).toList();
    });
  }

  /// Bir kart oynama isteği gönderir. Gerçek doğrulama ve uygulama Cloud Function'da olur.
  Future<void> playCard(String roomId, PlayingCard card) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception('Giriş yapılmamış');

    await _db.collection('rooms/$roomId/moves').add({
      'playerId': uid,
      'card': card.toMap(),
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}