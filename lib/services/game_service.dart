import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/playing_card.dart';

class GameService {
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  GameService({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _db = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchPublicState(String roomId) {
    return _db.doc('rooms/$roomId/gameState/public').snapshots();
  }

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

  Future<void> playCard(String roomId, PlayingCard card) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('Giriş yapılmamış');

    await _db.collection('rooms/$roomId/moves').add({
      'playerId': uid,
      'card': card.toMap(),
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}