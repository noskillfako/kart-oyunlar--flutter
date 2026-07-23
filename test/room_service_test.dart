import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kart_oyunu/services/room_service.dart';

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late MockUser mockUser;
  late MockFirebaseAuth mockAuth;
  late RoomService roomService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    fakeFirestore = FakeFirebaseFirestore();
    mockUser = MockUser(uid: 'player1', displayName: 'Ahmet');
    mockAuth = MockFirebaseAuth(mockUser: mockUser, signedIn: true);
    roomService = RoomService(firestore: fakeFirestore, auth: mockAuth);
  });

  group('createRoom', () {
    test('yeni bir oda dokümanı oluşturur', () async {
      final roomId = await roomService.createRoom();

      final doc = await fakeFirestore.collection('rooms').doc(roomId).get();
      expect(doc.exists, true);
      expect(doc.data()!['status'], 'waiting');
      expect(doc.data()!['gameType'], 'pisti');
    });

    test('oluşturan kişi hostId olarak atanır', () async {
      final roomId = await roomService.createRoom();
      final doc = await fakeFirestore.collection('rooms').doc(roomId).get();
      expect(doc.data()!['hostId'], 'player1');
    });

    test('oluşturan kişi players map\'ine eklenir', () async {
      final roomId = await roomService.createRoom();
      final doc = await fakeFirestore.collection('rooms').doc(roomId).get();
      final players = Map<String, dynamic>.from(doc.data()!['players']);
      expect(players.containsKey('player1'), true);
    });

    test('maxPlayers doğru şekilde kaydedilir', () async {
      final roomId = await roomService.createRoom(maxPlayers: 4);
      final doc = await fakeFirestore.collection('rooms').doc(roomId).get();
      expect(doc.data()!['maxPlayers'], 4);
    });

    test('totalRounds doğru şekilde kaydedilir', () async {
      final roomId = await roomService.createRoom(totalRounds: 5);
      final doc = await fakeFirestore.collection('rooms').doc(roomId).get();
      expect(doc.data()!['totalRounds'], 5);
    });
  });

  group('startGame', () {
    test('oda doluysa ve çağıran kişi host ise oyunu "playing" durumuna geçirir', () async {
      final roomId = await roomService.createRoom(maxPlayers: 2);

      final secondUser = MockUser(uid: 'player2', displayName: 'Mehmet');
      final secondAuth = MockFirebaseAuth(mockUser: secondUser, signedIn: true);
      final secondService = RoomService(firestore: fakeFirestore, auth: secondAuth);
      await secondService.joinRoom(roomId);

      await roomService.startGame(roomId);

      final doc = await fakeFirestore.collection('rooms').doc(roomId).get();
      expect(doc.data()!['status'], 'playing');
    });

    test('host olmayan kişi startGame çağırdığında hata fırlatır', () async {
      final roomId = await roomService.createRoom(maxPlayers: 2);

      final secondUser = MockUser(uid: 'player2', displayName: 'Mehmet');
      final secondAuth = MockFirebaseAuth(mockUser: secondUser, signedIn: true);
      final secondService = RoomService(firestore: fakeFirestore, auth: secondAuth);
      await secondService.joinRoom(roomId);

      expect(() => secondService.startGame(roomId), throwsA(isA<Exception>()));
    });
  });

  group('joinRoom', () {
    test('ikinci oyuncu players map\'ine eklenir', () async {
      final roomId = await roomService.createRoom();

      final secondUser = MockUser(uid: 'player2', displayName: 'Mehmet');
      final secondAuth = MockFirebaseAuth(mockUser: secondUser, signedIn: true);
      final secondService = RoomService(firestore: fakeFirestore, auth: secondAuth);

      await secondService.joinRoom(roomId);

      final doc = await fakeFirestore.collection('rooms').doc(roomId).get();
      final players = Map<String, dynamic>.from(doc.data()!['players']);
      expect(players.length, 2);
      expect(players.containsKey('player2'), true);
    });
  });

  group('leaveRoom', () {
    test('tek oyuncu ayrılırsa oda tamamen silinir', () async {
      final roomId = await roomService.createRoom();

      await roomService.leaveRoom(roomId);

      final doc = await fakeFirestore.collection('rooms').doc(roomId).get();
      expect(doc.exists, false);
    });

    test('birden fazla oyuncudan biri ayrılırsa oda silinmez, sadece oyuncu çıkar', () async {
      final roomId = await roomService.createRoom();

      final secondUser = MockUser(uid: 'player2', displayName: 'Mehmet');
      final secondAuth = MockFirebaseAuth(mockUser: secondUser, signedIn: true);
      final secondService = RoomService(firestore: fakeFirestore, auth: secondAuth);
      await secondService.joinRoom(roomId);

      await roomService.leaveRoom(roomId); // player1 (host) ayrılıyor

      final doc = await fakeFirestore.collection('rooms').doc(roomId).get();
      expect(doc.exists, true);
      final players = Map<String, dynamic>.from(doc.data()!['players']);
      expect(players.containsKey('player1'), false);
      expect(players.containsKey('player2'), true);
    });

    test('host ayrılırsa host başka bir oyuncuya devredilir', () async {
      final roomId = await roomService.createRoom();

      final secondUser = MockUser(uid: 'player2', displayName: 'Mehmet');
      final secondAuth = MockFirebaseAuth(mockUser: secondUser, signedIn: true);
      final secondService = RoomService(firestore: fakeFirestore, auth: secondAuth);
      await secondService.joinRoom(roomId);

      await roomService.leaveRoom(roomId); // player1 (host) ayrılıyor

      final doc = await fakeFirestore.collection('rooms').doc(roomId).get();
      expect(doc.data()!['hostId'], 'player2');
    });

    test('oyun devam ederken biri ayrılırsa oyuncu botControlledSeats listesine eklenir', () async {
      final roomId = await roomService.createRoom(maxPlayers: 2);

      final secondUser = MockUser(uid: 'player2', displayName: 'Mehmet');
      final secondAuth = MockFirebaseAuth(mockUser: secondUser, signedIn: true);
      final secondService = RoomService(firestore: fakeFirestore, auth: secondAuth);
      await secondService.joinRoom(roomId);
      await roomService.startGame(roomId);

      await secondService.leaveRoom(roomId); // player2 ayrılıyor

      final doc = await fakeFirestore.collection('rooms').doc(roomId).get();
      expect(doc.data()!['status'], 'playing');
      final botSeats = List<String>.from(doc.data()!['botControlledSeats'] ?? []);
      expect(botSeats.contains('player2'), true);
    });

    test('oyun devam ederken tüm oyuncular ayrılırsa status abandoned olur', () async {
      final roomId = await roomService.createRoom(maxPlayers: 2);

      final secondUser = MockUser(uid: 'player2', displayName: 'Mehmet');
      final secondAuth = MockFirebaseAuth(mockUser: secondUser, signedIn: true);
      final secondService = RoomService(firestore: fakeFirestore, auth: secondAuth);
      await secondService.joinRoom(roomId);
      await roomService.startGame(roomId);

      await roomService.leaveRoom(roomId); // player1 ayrılıyor
      await secondService.leaveRoom(roomId); // player2 ayrılıyor

      final doc = await fakeFirestore.collection('rooms').doc(roomId).get();
      expect(doc.exists, false);
    });

    test('reclaimSeat oyuncuyu botControlledSeats listesinden çıkarır', () async {
      final roomId = await roomService.createRoom(maxPlayers: 2);
      await fakeFirestore.collection('rooms').doc(roomId).update({
        'players.user_456': {'displayName': 'Oyuncu 2'},
      });
      await roomService.claimBotTakeover(roomId, 'user_123');

      final docBefore = await fakeFirestore.collection('rooms').doc(roomId).get();
      final seatsBefore = List<String>.from(docBefore.data()?['botControlledSeats'] ?? []);
      expect(seatsBefore.contains('user_123'), true);

      await roomService.reclaimSeat(roomId, 'user_123');

      final docAfter = await fakeFirestore.collection('rooms').doc(roomId).get();
      final seatsAfter = List<String>.from(docAfter.data()?['botControlledSeats'] ?? []);
      expect(seatsAfter.contains('user_123'), false);
    });
  });

  group('watchOpenRooms', () {
    test('sadece "waiting" durumundaki odaları listeler', () async {
      final roomId1 = await roomService.createRoom();
      final roomId2 = await roomService.createRoom();

      await fakeFirestore.collection('rooms').doc(roomId2).update({'status': 'playing'});

      final rooms = await roomService.watchOpenRooms().first;
      final ids = rooms.map((r) => r['id']).toList();

      expect(ids.contains(roomId1), true);
      expect(ids.contains(roomId2), false);
    });

    test('dolu odaları listeye dahil etmez', () async {
      final roomId = await roomService.createRoom(maxPlayers: 1);
      // maxPlayers 1 ve zaten 1 oyuncu (host) var, yani oda dolu sayılmalı

      final rooms = await roomService.watchOpenRooms().first;
      final ids = rooms.map((r) => r['id']).toList();

      expect(ids.contains(roomId), false);
    });
  });
}