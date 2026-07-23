import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'user_prefs_service.dart';

// ─── Sabit avatar listesi ─────────────────────────────────────────────────────
const Map<String, String> kAvatarEmojis = {
  'avatar_1': '🦁',
  'avatar_2': '🐯',
  'avatar_3': '🦊',
  'avatar_4': '🦅',
  'avatar_5': '🐲',
  'avatar_6': '🎭',
  'avatar_7': '👑',
  'avatar_8': '⚡',
};

const String kDefaultAvatarId = 'avatar_1';

// ─── Kullanıcı Profil Servisi ─────────────────────────────────────────────────
class UserService {
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  UserService({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _db = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  // Mevcut kullanıcının Firestore doküman referansı
  DocumentReference<Map<String, dynamic>> get _userRef {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('Kullanıcı giriş yapmamış');
    return _db.collection('users').doc(uid);
  }

  /// Kullanıcının Firestore profili yoksa oluşturur.
  /// Uygulama başlangıcında ve Google girişi sonrasında çağrılmalı.
  Future<void> ensureProfileExists() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final ref = _db.collection('users').doc(uid);
    final doc = await ref.get();

    if (doc.exists) return; // Profil zaten var, dokunma

    // Cihazda daha önce kaydedilmiş isim varsa onu kullan
    final existingName = await UserPrefsService().getDisplayName();

    await ref.set({
      'displayName': existingName ?? 'Oyuncu-${uid.substring(0, 5)}',
      'avatarId': kDefaultAvatarId,
      'createdAt': FieldValue.serverTimestamp(),
      'stats': {
        'totalGamesPlayed': 0,
        'totalGamesWon': 0,
        'longestWinStreak': 0,
        'currentWinStreak': 0,
        'abandonedGamesCount': 0,
        'gameStats': {
          'pisti': {
            'gamesPlayed': 0,
            'gamesWon': 0,
            'pistiCount': 0,
          },
          'batak': {
            'gamesPlayed': 0,
            'gamesWon': 0,
            'highestBid': 0,
          },
        },
      },
      'chipBalance': 0,
      'diamondBalance': 0,
      'dailyStreak': 0,
      'lastDailyRewardClaim': null,
    });
  }

  /// Kullanıcının görünen adını günceller.
  /// Hem Firestore'a hem de cihaz önbelleğine (UserPrefsService) yazar,
  /// böylece RoomService değiştirilmeden çalışmaya devam eder.
  Future<void> updateDisplayName(String name) async {
    final trimmed = name.trim();
    await _userRef.update({'displayName': trimmed});
    // RoomService'in okumaya devam etmesi için yerel önbelleği de güncelle
    await UserPrefsService().setDisplayName(trimmed);
  }

  /// Kullanıcının avatarını günceller.
  Future<void> updateAvatar(String avatarId) async {
    await _userRef.update({'avatarId': avatarId});
  }

  /// Belirtilen veya mevcut kullanıcının profilini gerçek zamanlı dinler.
  /// Auth durumu değiştiğinde veya farklı bir kullanıcı profilini görüntülerken
  /// stream yeniden oluşturulmalıdır.
  Stream<DocumentSnapshot<Map<String, dynamic>>> watchProfile({String? uid}) {
    final targetUid = uid ?? _auth.currentUser?.uid;
    if (targetUid == null) {
      // Giriş yapılmamışsa boş stream döner
      return const Stream.empty();
    }
    return _db.collection('users').doc(targetUid).snapshots();
  }

  /// Oyun sonu istatistiklerini artırır.
  /// [gameType]   — 'pisti' veya 'batak'
  /// [won]        — bu oyuncu kazandıysa true
  /// [pistiCount] — bu oyunda yapılan pişti sayısı (yalnızca pişti oyunu için)
  /// [batakBid]   — bu oyundaki Batak kontratı (yalnızca batak oyunu için)
  Future<void> incrementGameStats({
    required String gameType,
    required bool won,
    int pistiCount = 0,
    int batakBid = 0,
  }) async {
    final doc = await _userRef.get();
    if (!doc.exists) return;

    final data = doc.data() ?? {};
    final stats = Map<String, dynamic>.from(data['stats'] ?? {});

    int totalGamesPlayed = (stats['totalGamesPlayed'] as int?) ?? 0;
    int totalGamesWon = (stats['totalGamesWon'] as int?) ?? 0;
    int currentWinStreak = (stats['currentWinStreak'] as int?) ?? 0;
    int longestWinStreak = (stats['longestWinStreak'] as int?) ?? 0;

    totalGamesPlayed += 1;
    if (won) {
      totalGamesWon += 1;
      currentWinStreak += 1;
      if (currentWinStreak > longestWinStreak) {
        longestWinStreak = currentWinStreak;
      }
    } else {
      currentWinStreak = 0;
    }

    final gameStats = Map<String, dynamic>.from(stats['gameStats'] ?? {});
    final specificStats = Map<String, dynamic>.from(gameStats[gameType] ?? {});

    int gPlayed = (specificStats['gamesPlayed'] as int?) ?? 0;
    int gWon = (specificStats['gamesWon'] as int?) ?? 0;

    gPlayed += 1;
    if (won) {
      gWon += 1;
    }

    specificStats['gamesPlayed'] = gPlayed;
    specificStats['gamesWon'] = gWon;

    if (gameType == 'pisti') {
      int pCount = (specificStats['pistiCount'] as int?) ?? 0;
      pCount += pistiCount;
      specificStats['pistiCount'] = pCount;
    } else if (gameType == 'batak') {
      int hBid = (specificStats['highestBid'] as int?) ?? 0;
      if (batakBid > hBid) {
        specificStats['highestBid'] = batakBid;
      }
    }

    gameStats[gameType] = specificStats;

    await _userRef.update({
      'stats.totalGamesPlayed': totalGamesPlayed,
      'stats.totalGamesWon': totalGamesWon,
      'stats.currentWinStreak': currentWinStreak,
      'stats.longestWinStreak': longestWinStreak,
      'stats.gameStats': gameStats,
    });
  }
}
