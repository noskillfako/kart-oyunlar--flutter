import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:kart_oyunu/services/batak_game_service.dart';
import 'package:kart_oyunu/models/playing_card.dart';

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late MockUser mockUser;
  late MockFirebaseAuth mockAuth;
  late BatakGameService gameService;

  const roomId = 'test-room';

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    mockUser = MockUser(uid: 'player1', displayName: 'Ahmet');
    mockAuth = MockFirebaseAuth(mockUser: mockUser, signedIn: true);
    gameService = BatakGameService(firestore: fakeFirestore, auth: mockAuth);
  });

  group('watchPublicState', () {
    test('gameState/public dokümanındaki veriyi doğru döner', () async {
      await fakeFirestore.doc('rooms/$roomId/gameState/public').set({
        'phase': 'bidding',
        'currentTurnPlayerId': 'player1',
      });

      final snap = await gameService.watchPublicState(roomId).first;
      expect(snap.exists, true);
      expect(snap.data()!['phase'], 'bidding');
    });
  });

  group('watchMyHand', () {
    test('kendi elimizdeki kartları doğru parse eder', () async {
      await fakeFirestore.doc('rooms/$roomId/hands/player1').set({
        'cards': [
          {'suit': 'spades', 'rank': 'ace'},
          {'suit': 'diamonds', 'rank': 'king'},
        ],
      });

      final hand = await gameService.watchMyHand(roomId).first;

      expect(hand.length, 2);
      expect(hand[0], const PlayingCard(Suit.spades, Rank.ace));
      expect(hand[1], const PlayingCard(Suit.diamonds, Rank.king));
    });

    test('el dokümanı yoksa boş liste döner', () async {
      final hand = await gameService.watchMyHand(roomId).first;
      expect(hand, isEmpty);
    });
  });

  group('bid', () {
    test('moves koleksiyonuna doğru type ve bidAmount ile doküman ekler', () async {
      await gameService.bid(roomId, 6);

      final movesSnap = await fakeFirestore.collection('rooms/$roomId/moves').get();
      expect(movesSnap.docs.length, 1);

      final moveData = movesSnap.docs.first.data();
      expect(moveData['playerId'], 'player1');
      expect(moveData['type'], 'bid');
      expect(moveData['bidAmount'], 6);
      expect(moveData['status'], 'pending');
    });
  });

  group('pass', () {
    test('moves koleksiyonuna doğru type ile doküman ekler', () async {
      await gameService.pass(roomId);

      final movesSnap = await fakeFirestore.collection('rooms/$roomId/moves').get();
      expect(movesSnap.docs.length, 1);

      final moveData = movesSnap.docs.first.data();
      expect(moveData['playerId'], 'player1');
      expect(moveData['type'], 'pass');
      expect(moveData.containsKey('bidAmount'), false);
    });
  });

  group('chooseTrump', () {
    test('moves koleksiyonuna doğru type ve trumpSuit ile doküman ekler', () async {
      await gameService.chooseTrump(roomId, Suit.hearts);

      final movesSnap = await fakeFirestore.collection('rooms/$roomId/moves').get();
      expect(movesSnap.docs.length, 1);

      final moveData = movesSnap.docs.first.data();
      expect(moveData['playerId'], 'player1');
      expect(moveData['type'], 'chooseTrump');
      expect(moveData['trumpSuit'], 'hearts');
    });
  });

  group('playCard', () {
    test('moves koleksiyonuna doğru type ve card ile doküman ekler', () async {
      const card = PlayingCard(Suit.clubs, Rank.jack);

      await gameService.playCard(roomId, card);

      final movesSnap = await fakeFirestore.collection('rooms/$roomId/moves').get();
      expect(movesSnap.docs.length, 1);

      final moveData = movesSnap.docs.first.data();
      expect(moveData['playerId'], 'player1');
      expect(moveData['type'], 'playCard');
      expect(moveData['card']['suit'], 'clubs');
      expect(moveData['card']['rank'], 'jack');
    });
  });

  group('birden fazla hamle', () {
    test('her hamle ayrı bir doküman olarak eklenir', () async {
      await gameService.bid(roomId, 6);
      await gameService.pass(roomId);
      await gameService.chooseTrump(roomId, Suit.spades);

      final movesSnap = await fakeFirestore.collection('rooms/$roomId/moves').get();
      expect(movesSnap.docs.length, 3);

      final types = movesSnap.docs.map((d) => d.data()['type']).toList();
      expect(types, containsAll(['bid', 'pass', 'chooseTrump']));
    });
  });
}