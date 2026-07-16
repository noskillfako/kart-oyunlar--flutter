import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/playing_card.dart';

class BatakGameService {
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  BatakGameService({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _db = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  /// Herkesin görebileceği oyun durumunu dinler (faz, ihale, koz, trick, skorlar)
  Stream<DocumentSnapshot<Map<String, dynamic>>> watchPublicState(String roomId) {
    return _db.doc('rooms/$roomId/gameState/public').snapshots();
  }

  /// Sadece kendi elimizi dinler
  Stream<List<PlayingCard>> watchMyHand(String roomId) {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return const Stream.empty();

    return _db.doc('rooms/$roomId/hands/$uid').snapshots().map((snap) {
      if (!snap.exists) return <PlayingCard>[];
      final data = snap.data();
      final rawCards = List<Map<String, dynamic>>.from(data?['cards'] ?? []);
      return rawCards.map((c) => PlayingCard.fromMap(c)).toList();
    });
  }

  Future<void> _sendMove(String roomId, Map<String, dynamic> moveData) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('Giriş yapılmamış');

    await _db.collection('rooms/$roomId/moves').add({
      'playerId': uid,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      ...moveData,
    });
  }

  Future<void> bid(String roomId, int amount) {
    return _sendMove(roomId, {'type': 'bid', 'bidAmount': amount});
  }

  Future<void> pass(String roomId) {
    return _sendMove(roomId, {'type': 'pass'});
  }

  Future<void> chooseTrump(String roomId, Suit suit) {
    return _sendMove(roomId, {'type': 'chooseTrump', 'trumpSuit': suit.name});
  }

  Future<void> playCard(String roomId, PlayingCard card) {
    return _sendMove(roomId, {'type': 'playCard', 'card': card.toMap()});
  }
}