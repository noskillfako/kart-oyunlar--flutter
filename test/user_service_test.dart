import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kart_oyunu/services/user_service.dart';

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late MockUser mockUser;
  late MockFirebaseAuth mockAuth;
  late UserService userService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    fakeFirestore = FakeFirebaseFirestore();
    mockUser = MockUser(uid: 'test_uid_1', displayName: 'Ahmet');
    mockAuth = MockFirebaseAuth(mockUser: mockUser, signedIn: true);
    userService = UserService(firestore: fakeFirestore, auth: mockAuth);
  });

  // ── ensureProfileExists ─────────────────────────────────────────────────
  group('ensureProfileExists', () {
    test('profil yoksa yeni bir doküman oluşturur', () async {
      await userService.ensureProfileExists();

      final doc =
          await fakeFirestore.collection('users').doc('test_uid_1').get();
      expect(doc.exists, true);
    });

    test('oluşturulan profil doğru alanları içerir', () async {
      await userService.ensureProfileExists();

      final data = (await fakeFirestore
              .collection('users')
              .doc('test_uid_1')
              .get())
          .data()!;

      expect(data['avatarId'], kDefaultAvatarId);
      expect(data['chipBalance'], 0);
      expect(data['diamondBalance'], 0);
      expect(data['dailyStreak'], 0);
      expect(data['lastDailyRewardClaim'], null);

      final stats = Map<String, dynamic>.from(data['stats'] as Map);
      expect(stats['totalGamesPlayed'], 0);
      expect(stats['totalGamesWon'], 0);
      expect(stats['longestWinStreak'], 0);
      expect(stats['currentWinStreak'], 0);
      expect(stats['abandonedGamesCount'], 0);

      final gameStats = Map<String, dynamic>.from(stats['gameStats'] as Map);
      final pisti = Map<String, dynamic>.from(gameStats['pisti'] as Map);
      expect(pisti['gamesPlayed'], 0);
      expect(pisti['gamesWon'], 0);
      expect(pisti['pistiCount'], 0);

      final batak = Map<String, dynamic>.from(gameStats['batak'] as Map);
      expect(batak['gamesPlayed'], 0);
      expect(batak['gamesWon'], 0);
      expect(batak['highestBid'], 0);
    });

    test('profil zaten varsa üzerine yazmaz', () async {
      // İlk oluşturma
      await userService.ensureProfileExists();
      // İsmi manuel değiştir
      await fakeFirestore
          .collection('users')
          .doc('test_uid_1')
          .update({'displayName': 'Değişmemeli'});

      // İkinci çağrı var olan profili değiştirmemeli
      await userService.ensureProfileExists();

      final data = (await fakeFirestore
              .collection('users')
              .doc('test_uid_1')
              .get())
          .data()!;
      expect(data['displayName'], 'Değişmemeli');
    });

    test('SharedPreferences\'ta isim varsa onu kullanır', () async {
      SharedPreferences.setMockInitialValues({'display_name': 'Önbellekten'});

      await userService.ensureProfileExists();

      final data = (await fakeFirestore
              .collection('users')
              .doc('test_uid_1')
              .get())
          .data()!;
      expect(data['displayName'], 'Önbellekten');
    });

    test('SharedPreferences boşsa uid\'den varsayılan isim üretir', () async {
      await userService.ensureProfileExists();

      final data = (await fakeFirestore
              .collection('users')
              .doc('test_uid_1')
              .get())
          .data()!;
      // UID'nin ilk 5 karakteri: 'test_'
      expect(data['displayName'], startsWith('Oyuncu-'));
    });
  });

  // ── updateDisplayName ───────────────────────────────────────────────────
  group('updateDisplayName', () {
    setUp(() async {
      await userService.ensureProfileExists();
    });

    test('Firestore\'daki displayName güncellenir', () async {
      await userService.updateDisplayName('Yeni İsim');

      final data = (await fakeFirestore
              .collection('users')
              .doc('test_uid_1')
              .get())
          .data()!;
      expect(data['displayName'], 'Yeni İsim');
    });

    test('baş/sondaki boşluklar kırpılır', () async {
      await userService.updateDisplayName('  Boşluk  ');

      final data = (await fakeFirestore
              .collection('users')
              .doc('test_uid_1')
              .get())
          .data()!;
      expect(data['displayName'], 'Boşluk');
    });

    test('SharedPreferences (yerel önbellek) de güncellenir', () async {
      await userService.updateDisplayName('Önbellek Testi');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('display_name'), 'Önbellek Testi');
    });
  });

  // ── updateAvatar ────────────────────────────────────────────────────────
  group('updateAvatar', () {
    setUp(() async {
      await userService.ensureProfileExists();
    });

    test('avatarId Firestore\'da güncellenir', () async {
      await userService.updateAvatar('avatar_5');

      final data = (await fakeFirestore
              .collection('users')
              .doc('test_uid_1')
              .get())
          .data()!;
      expect(data['avatarId'], 'avatar_5');
    });

    test('diğer alanlar bozulmaz', () async {
      await userService.updateDisplayName('Korunacak');
      await userService.updateAvatar('avatar_3');

      final data = (await fakeFirestore
              .collection('users')
              .doc('test_uid_1')
              .get())
          .data()!;
      expect(data['displayName'], 'Korunacak');
      expect(data['avatarId'], 'avatar_3');
    });
  });

  // ── watchProfile ─────────────────────────────────────────────────────────
  group('watchProfile', () {
    test('stream mevcut profil dokümanını dinler', () async {
      await userService.ensureProfileExists();

      final snapshot = await userService.watchProfile().first;
      expect(snapshot.exists, true);
      expect(snapshot.data()?['avatarId'], kDefaultAvatarId);
    });

    test('güncelleme stream\'e yansır', () async {
      await userService.ensureProfileExists();

      // İsim değişikliğini dinle
      final streamFuture = userService
          .watchProfile()
          .where((s) => s.data()?['displayName'] == 'Stream Testi')
          .first;

      await userService.updateDisplayName('Stream Testi');

      final snapshot = await streamFuture;
      expect(snapshot.data()?['displayName'], 'Stream Testi');
    });
  });

  // ── incrementGameStats ───────────────────────────────────────────────────
  group('incrementGameStats', () {
    setUp(() async {
      await userService.ensureProfileExists();
    });

    test('her çağrıda totalGamesPlayed ve oyun-özel gamesPlayed 1 artar', () async {
      await userService.incrementGameStats(gameType: 'pisti', won: false);
      await userService.incrementGameStats(gameType: 'batak', won: false);

      final data = (await fakeFirestore
              .collection('users')
              .doc('test_uid_1')
              .get())
          .data()!;
      final stats = Map<String, dynamic>.from(data['stats'] as Map);
      expect(stats['totalGamesPlayed'], 2);

      final gameStats = Map<String, dynamic>.from(stats['gameStats'] as Map);
      final pisti = Map<String, dynamic>.from(gameStats['pisti'] as Map);
      final batak = Map<String, dynamic>.from(gameStats['batak'] as Map);
      expect(pisti['gamesPlayed'], 1);
      expect(batak['gamesPlayed'], 1);
    });

    test('won:true ise totalGamesWon, oyun-özel gamesWon ve galibiyet serisi artar', () async {
      await userService.incrementGameStats(gameType: 'pisti', won: true);
      await userService.incrementGameStats(gameType: 'pisti', won: false);

      final data = (await fakeFirestore
              .collection('users')
              .doc('test_uid_1')
              .get())
          .data()!;
      final stats = Map<String, dynamic>.from(data['stats'] as Map);
      expect(stats['totalGamesWon'], 1);
      expect(stats['totalGamesPlayed'], 2);
      expect(stats['currentWinStreak'], 0); // Kaybedince sıfırlandı
      expect(stats['longestWinStreak'], 1); // En yüksek 1'di

      final gameStats = Map<String, dynamic>.from(stats['gameStats'] as Map);
      final pisti = Map<String, dynamic>.from(gameStats['pisti'] as Map);
      expect(pisti['gamesPlayed'], 2);
      expect(pisti['gamesWon'], 1);
    });

    test('aktif galibiyet serisi ve en uzun seri takibi doğru çalışır', () async {
      await userService.incrementGameStats(gameType: 'pisti', won: true); // current=1, longest=1
      await userService.incrementGameStats(gameType: 'batak', won: true); // current=2, longest=2
      await userService.incrementGameStats(gameType: 'batak', won: true); // current=3, longest=3

      var data = (await fakeFirestore.collection('users').doc('test_uid_1').get()).data()!;
      var stats = Map<String, dynamic>.from(data['stats'] as Map);
      expect(stats['currentWinStreak'], 3);
      expect(stats['longestWinStreak'], 3);

      await userService.incrementGameStats(gameType: 'pisti', won: false); // current=0, longest=3

      data = (await fakeFirestore.collection('users').doc('test_uid_1').get()).data()!;
      stats = Map<String, dynamic>.from(data['stats'] as Map);
      expect(stats['currentWinStreak'], 0);
      expect(stats['longestWinStreak'], 3);

      await userService.incrementGameStats(gameType: 'batak', won: true); // current=1, longest=3

      data = (await fakeFirestore.collection('users').doc('test_uid_1').get()).data()!;
      stats = Map<String, dynamic>.from(data['stats'] as Map);
      expect(stats['currentWinStreak'], 1);
      expect(stats['longestWinStreak'], 3);
    });

    test('pistiCount doğru miktarda artar', () async {
      await userService.incrementGameStats(gameType: 'pisti', won: false, pistiCount: 3);

      final data = (await fakeFirestore
              .collection('users')
              .doc('test_uid_1')
              .get())
          .data()!;
      final stats = Map<String, dynamic>.from(data['stats'] as Map);
      final gameStats = Map<String, dynamic>.from(stats['gameStats'] as Map);
      final pisti = Map<String, dynamic>.from(gameStats['pisti'] as Map);
      expect(pisti['pistiCount'], 3);
    });

    test('yeni batakBid mevcut highestBid\'den büyükse güncellenir', () async {
      await userService.incrementGameStats(gameType: 'batak', won: false, batakBid: 5);

      final data = (await fakeFirestore
              .collection('users')
              .doc('test_uid_1')
              .get())
          .data()!;
      final stats = Map<String, dynamic>.from(data['stats'] as Map);
      final gameStats = Map<String, dynamic>.from(stats['gameStats'] as Map);
      final batak = Map<String, dynamic>.from(gameStats['batak'] as Map);
      expect(batak['highestBid'], 5);
    });

    test('yeni batakBid mevcut highestBid\'den küçükse güncellenmez', () async {
      await userService.incrementGameStats(gameType: 'batak', won: false, batakBid: 7);
      await userService.incrementGameStats(gameType: 'batak', won: false, batakBid: 3);

      final data = (await fakeFirestore
              .collection('users')
              .doc('test_uid_1')
              .get())
          .data()!;
      final stats = Map<String, dynamic>.from(data['stats'] as Map);
      final gameStats = Map<String, dynamic>.from(stats['gameStats'] as Map);
      final batak = Map<String, dynamic>.from(gameStats['batak'] as Map);
      expect(batak['highestBid'], 7);
    });
  });
}
