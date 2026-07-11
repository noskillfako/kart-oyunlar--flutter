import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RoomService {
  final _db = FirebaseFirestore.instance;

  /// Yeni bir oda oluşturur, oluşturan kişiyi otomatik ekler, room id'sini döner
  Future<String> createRoom({String gameType = 'pisti', int maxPlayers = 2}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('Giriş yapılmamış, oda oluşturulamaz');
    }

    final roomRef = _db.collection('rooms').doc(); // otomatik id üretir

    await roomRef.set({
      'gameType': gameType,
      'status': 'waiting',
      'maxPlayers': maxPlayers,
      'hostId': user.uid,
      'players': {
        user.uid: {
          'displayName': 'Oyuncu-${user.uid.substring(0, 5)}',
          'isReady': false,
          'joinedAt': DateTime.now().toIso8601String(),
        }
      },
      'createdAt': FieldValue.serverTimestamp(),
    });

    return roomRef.id;
  }

  /// Bir odaya katılır
  Future<void> joinRoom(String roomId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('Giriş yapılmamış, odaya katılınamaz');
    }

    final roomRef = _db.collection('rooms').doc(roomId);

    await roomRef.update({
      'players.${user.uid}': {
        'displayName': 'Oyuncu-${user.uid.substring(0, 5)}',
        'isReady': false,
        'joinedAt': DateTime.now().toIso8601String(),
      }
    });
  }

  /// Bir odayı gerçek zamanlı dinlemek için stream
  Stream<DocumentSnapshot<Map<String, dynamic>>> watchRoom(String roomId) {
    return _db.collection('rooms').doc(roomId).snapshots();
  }
  /// Bekleyen (dolu olmayan) odaları gerçek zamanlı dinler
  Stream<List<Map<String, dynamic>>> watchOpenRooms() {
    return _db
        .collection('rooms')
        .where('status', isEqualTo: 'waiting')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            return data;
          })
          .where((room) {
            final players = Map<String, dynamic>.from(room['players'] ?? {});
            final maxPlayers = room['maxPlayers'] ?? 2;
            return players.length < maxPlayers; // dolu olmayan odalar
          })
          .toList();
    });
  }
  /// Oda doluysa ve hâlâ "waiting" durumundaysa, oyunu "playing" durumuna geçirir.
  /// Transaction kullanır, birden fazla oyuncu aynı anda çağırsa bile güvenlidir.
  Future<void> startGameIfFull(String roomId) async {
    final roomRef = _db.collection('rooms').doc(roomId);

    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(roomRef);
      if (!snapshot.exists) return;

      final data = snapshot.data()!;
      final status = data['status'] as String? ?? 'waiting';
      final players = Map<String, dynamic>.from(data['players'] ?? {});
      final maxPlayers = data['maxPlayers'] ?? 2;

      if (status == 'waiting' && players.length >= maxPlayers) {
        transaction.update(roomRef, {'status': 'playing'});
      }
    });
  }
  Future<void> leaveRoom(String roomId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final roomRef = _db.collection('rooms').doc(roomId);
    final snapshot = await roomRef.get();
    if (!snapshot.exists) return;

    final data = snapshot.data()!;
    final players = Map<String, dynamic>.from(data['players'] ?? {});
    players.remove(user.uid);

    if (players.isEmpty) {
      await roomRef.delete();
      return;
    }

    final updates = <String, dynamic>{
      'players.${user.uid}': FieldValue.delete(),
    };

    if (data['hostId'] == user.uid) {
      updates['hostId'] = players.keys.first;
    }

    if (data['status'] == 'playing') {
      updates['status'] = 'abandoned';
    }

    await roomRef.update(updates);
  }
}