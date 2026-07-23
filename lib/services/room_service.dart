import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'user_prefs_service.dart';

class RoomService {
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  RoomService({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _db = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  /// Yeni bir oda oluşturur, oluşturan kişiyi otomatik ekler, room id'sini döner
  Future<String> createRoom({String gameType = 'pisti', int maxPlayers = 2, int totalRounds = 1}) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Giriş yapılmamış, oda oluşturulamaz');
    }

    final displayName = await UserPrefsService().getDisplayName() ??
        'Oyuncu-${user.uid.substring(0, 5)}';

    final roomRef = _db.collection('rooms').doc();

    await roomRef.set({
      'gameType': gameType,
      'status': 'waiting',
      'maxPlayers': maxPlayers,
      'totalRounds': totalRounds,
      'hostId': user.uid,
      'players': {
        user.uid: {
          'displayName': displayName,
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
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Giriş yapılmamış, odaya katılınamaz');
    }

    final displayName = await UserPrefsService().getDisplayName() ??
        'Oyuncu-${user.uid.substring(0, 5)}';

    final roomRef = _db.collection('rooms').doc(roomId);

    await roomRef.update({
      'players.${user.uid}': {
        'displayName': displayName,
        'isReady': false,
        'joinedAt': DateTime.now().toIso8601String(),
      }
    });
  }

  /// Bir odayı gerçek zamanlı dinlemek için stream
  Stream<DocumentSnapshot<Map<String, dynamic>>> watchRoom(String roomId) {
    return _db.collection('rooms').doc(roomId).snapshots();
  }

  /// Bekleyen (dolu olmayan) odaları gerçek zamanlı dinler.
  /// [gameType] verilirse yalnızca o oyun türündeki odalar döner.
  Stream<List<Map<String, dynamic>>> watchOpenRooms({String? gameType}) {
    Query<Map<String, dynamic>> query = _db
        .collection('rooms')
        .where('status', isEqualTo: 'waiting')
        .orderBy('createdAt', descending: true);

    if (gameType != null) {
      query = query.where('gameType', isEqualTo: gameType);
    }

    return query.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            return data;
          })
          .where((room) {
            final players = Map<String, dynamic>.from(room['players'] ?? {});
            final maxPlayers = room['maxPlayers'] ?? 2;
            return players.length < maxPlayers;
          })
          .toList();
    });
  }

  /// Oyunu "playing" durumuna geçirir. Sadece oda kurucusu (host) çağırabilir.
  /// Transaction kullanır, birden fazla oyuncu aynı anda çağırsa bile güvenlidir.
  Future<void> startGame(String roomId) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Giriş yapılmamış, oyun başlatılamaz');
    }

    final roomRef = _db.collection('rooms').doc(roomId);

    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(roomRef);
      if (!snapshot.exists) return;

      final data = snapshot.data()!;
      final status = data['status'] as String? ?? 'waiting';
      final hostId = data['hostId'] as String?;
      final players = Map<String, dynamic>.from(data['players'] ?? {});
      final maxPlayers = data['maxPlayers'] ?? 2;

      if (user.uid != hostId) {
        throw Exception('Sadece oda kurucusu oyunu başlatabilir');
      }

      if (status == 'waiting' && players.length >= maxPlayers) {
        transaction.update(roomRef, {'status': 'playing'});
      }
    });
  }

  /// Odadan ayrılır. Oda beklemedeyse ve boş kalırsa siler, host ayrılırsa host'u devreder.
  /// Oyun devam ederken ayrılırsa, oyunu sonlandırmak yerine oyuncuyu botControlledSeats listesine ekler.
  Future<void> leaveRoom(String roomId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final roomRef = _db.collection('rooms').doc(roomId);

    final snapshot = await roomRef.get();
    if (!snapshot.exists) return;

    final data = snapshot.data()!;
    final status = data['status'] as String? ?? 'waiting';
    final players = Map<String, dynamic>.from(data['players'] ?? {});

    if (status == 'waiting') {
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

      await roomRef.update(updates);
    } else if (status == 'finished' || status == 'matchFinished' || status == 'abandoned') {
      // Oyun sonlanmışsa ve çıkış yapılıyorsa odayı sil
      await roomRef.delete();
    } else {
      // Oyun devam ederken veya tur arasındayken bir oyuncu ayrılırsa
      final botSeats = List<String>.from(data['botControlledSeats'] ?? []);
      if (!botSeats.contains(user.uid)) {
        botSeats.add(user.uid);
      }

      final allPlayersCount = players.length;
      final allBots = botSeats.length >= allPlayersCount;

      if (allBots) {
        // Tüm oyuncular bot olduysa veya çıktıysa odayı sil
        await roomRef.delete();
      } else {
        // Hala gerçek oyuncu var, koltuğu bota devret
        await roomRef.update({
          'botControlledSeats': FieldValue.arrayUnion([user.uid]),
        });
      }
    }
  }

  /// Odayı ve alt dökümanlarını tamamen siler.
  Future<void> deleteRoom(String roomId) async {
    final roomRef = _db.collection('rooms').doc(roomId);
    await roomRef.delete();
  }

  /// Süresi dolan veya inaktif kalan rakip oyuncunun koltuğunu bota devretme talebi gönderir.
  Future<void> claimBotTakeover(String roomId, String targetUid) async {
    final roomRef = _db.collection('rooms').doc(roomId);
    final snap = await roomRef.get();
    if (!snap.exists) return;

    final data = snap.data()!;
    final players = Map<String, dynamic>.from(data['players'] ?? {});
    final botSeats = List<String>.from(data['botControlledSeats'] ?? []);
    if (!botSeats.contains(targetUid)) {
      botSeats.add(targetUid);
    }

    if (botSeats.length >= players.length && players.isNotEmpty) {
      await roomRef.delete();
    } else {
      await roomRef.update({
        'botControlledSeats': FieldValue.arrayUnion([targetUid]),
      });
    }
  }

  /// Oyuncu oyuna tekrar katıldığında koltuğunu bot kontrolünden geri alır.
  Future<void> reclaimSeat(String roomId, String userUid) async {
    final roomRef = _db.collection('rooms').doc(roomId);
    final publicRef = _db.collection('rooms').doc(roomId).collection('gameState').doc('public');

    await roomRef.update({
      'botControlledSeats': FieldValue.arrayRemove([userUid]),
    });
    try {
      await publicRef.update({
        'botControlledSeats': FieldValue.arrayRemove([userUid]),
      });
    } catch (_) {}
  }

  /// Kullanıcının dahil olduğu ve henüz devam eden (status == 'playing' veya 'roundFinished') bir oda varsa stream döner.
  Stream<Map<String, dynamic>?> watchActiveRoomForUser() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value(null);

    return _db
        .collection('rooms')
        .where('status', whereIn: ['playing', 'roundFinished'])
        .snapshots()
        .asyncMap((snap) async {
      for (final doc in snap.docs) {
        final data = doc.data();
        final players = Map<String, dynamic>.from(data['players'] ?? {});
        final botSeats = List<String>.from(data['botControlledSeats'] ?? []);

        if (players.containsKey(user.uid)) {
          // Odadaki tüm koltuklar bot olduysa aktif oda olarak gösterme
          if (botSeats.length >= players.length && players.isNotEmpty) {
            continue;
          }

          int currentRound = data['currentRound'] ?? 1;
          try {
            final pubSnap = await _db.collection('rooms').doc(doc.id).collection('gameState').doc('public').get();
            if (pubSnap.exists && pubSnap.data()?.containsKey('currentRound') == true) {
              currentRound = pubSnap.data()!['currentRound'] ?? currentRound;
            }
          } catch (_) {}

          return {
            'roomId': doc.id,
            'gameType': data['gameType'] ?? 'pisti',
            ...data,
            'currentRound': currentRound,
          };
        }
      }
      return null;
    });
  }
}