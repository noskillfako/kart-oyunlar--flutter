import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:kart_oyunu/services/game_service.dart';
import 'package:kart_oyunu/models/playing_card.dart';

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late MockUser mockUser;
  late MockFirebaseAuth mockAuth;
  late GameService gameService;

  const roomId = 'test-room';

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    mockUser = MockUser(uid: 'player1', displayName: 'Ahmet');
    mockAuth = MockFirebaseAuth(mockUser: mockUser, signedIn: true);
    gameService = GameService(firestore: fakeFirestore, auth: mockAuth);
  });

  group('watchPublicState', () {
    test('gameState/public dokümanındaki veriyi doğru döner', () async {
      await fakeFirestore.doc('rooms/$roomId/gameState/public').set({
        'status': 'playing',
        'currentTurnPlayerId': 'player1',
      });

      final snap = await gameService.watchPublicState(roomId).first;
      expect(snap.exists, true);
      expect(snap.data()!['status'], 'playing');
    });
  });

  group('watchMyHand', () {
    test('kendi elimizdeki kartları doğru parse eder', () async {
      await fakeFirestore.doc('rooms/$roomId/hands/player1').set({
        'cards': [
          {'suit': 'hearts', 'rank': 'seven'},
          {'suit': 'clubs', 'rank': 'jack'},
        ],
      });

      final hand = await gameService.watchMyHand(roomId).first;

      expect(hand.length, 2);
      expect(hand[0], const PlayingCard(Suit.hearts, Rank.seven));
      expect(hand[1], const PlayingCard(Suit.clubs, Rank.jack));
    });

    test('el dokümanı yoksa boş liste döner', () async {
      final hand = await gameService.watchMyHand(roomId).first;
      expect(hand, isEmpty);
    });
  });

  group('playCard', () {
    test('moves koleksiyonuna doğru içerikte bir doküman ekler', () async {
      const card = PlayingCard(Suit.diamonds, Rank.ten);

      await gameService.playCard(roomId, card);

      final movesSnap = await fakeFirestore.collection('rooms/$roomId/moves').get();
      expect(movesSnap.docs.length, 1);

      final moveData = movesSnap.docs.first.data();
      expect(moveData['playerId'], 'player1');
      expect(moveData['status'], 'pending');
      expect(moveData['card']['suit'], 'diamonds');
      expect(moveData['card']['rank'], 'ten');
    });
  });
}