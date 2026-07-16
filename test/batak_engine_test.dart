import 'package:flutter_test/flutter_test.dart';
import 'package:kart_oyunu/models/playing_card.dart';
import 'package:kart_oyunu/models/game_room.dart';
import 'package:kart_oyunu/engine/batak/batak_engine.dart';
import 'package:kart_oyunu/engine/batak/batak_state.dart';
import 'package:kart_oyunu/engine/batak/batak_move.dart';

void main() {
  late BatakEngine engine;
  late GameRoom testRoom;

  setUp(() {
    engine = BatakEngine();
    testRoom = GameRoom(
      id: 'test-room',
      gameType: 'batak',
      status: 'playing',
      maxPlayers: 4,
      hostId: 'p1',
      players: {
        'p1': {'displayName': 'A'},
        'p2': {'displayName': 'B'},
        'p3': {'displayName': 'C'},
        'p4': {'displayName': 'D'},
      },
    );
  });

  group('initializeGame', () {
    test('her oyuncuya 13 kart dağıtır', () {
      final state = engine.initializeGame(testRoom);
      for (final id in state.playerOrder) {
        expect(state.hands[id]!.length, 13);
      }
    });

    test('3 oyunculu odada hata fırlatır', () {
      final invalidRoom = GameRoom(
        id: 'x', gameType: 'batak', status: 'playing', maxPlayers: 4,
        hostId: 'p1', players: {'p1': {}, 'p2': {}, 'p3': {}},
      );
      expect(() => engine.initializeGame(invalidRoom), throwsException);
    });

    test('ihale dealer sonrasındaki oyuncudan başlar', () {
      final state = engine.initializeGame(testRoom);
      expect(state.currentTurnPlayerId, 'p2');
    });
  });

  group('bidding', () {
    test('minimumdan düşük teklif geçersizdir', () {
      final state = engine.initializeGame(testRoom);
      final move = const BatakMove.bid(4);
      expect(engine.isValidMove(state, 'p2', move), false);
    });

    test('geçerli teklif kabul edilir ve sıra ilerler', () {
      final state = engine.initializeGame(testRoom);
      final newState = engine.applyMove(state, 'p2', const BatakMove.bid(5));
      expect(newState.highestBid, 5);
      expect(newState.highestBidderId, 'p2');
      expect(newState.currentTurnPlayerId, 'p3');
    });

    test('üç oyuncu pas geçince ihale biter, kalan elci olur', () {
      var state = engine.initializeGame(testRoom);
      state = engine.applyMove(state, 'p2', const BatakMove.bid(5));
      state = engine.applyMove(state, 'p3', const BatakMove.pass());
      state = engine.applyMove(state, 'p4', const BatakMove.pass());
      state = engine.applyMove(state, 'p1', const BatakMove.pass());

      expect(state.phase, BatakPhase.chooseTrump);
      expect(state.declarerId, 'p2');
    });

    test('herkes pas geçerse dealer minimum bid ile elci olur', () {
      var state = engine.initializeGame(testRoom);
      state = engine.applyMove(state, 'p2', const BatakMove.pass());
      state = engine.applyMove(state, 'p3', const BatakMove.pass());
      state = engine.applyMove(state, 'p4', const BatakMove.pass());
      state = engine.applyMove(state, 'p1', const BatakMove.pass());

      expect(state.phase, BatakPhase.chooseTrump);
      expect(state.declarerId, 'p1'); // dealer
      expect(state.highestBid, 5);
    });
  });

  group('chooseTrump', () {
    test('sadece elci koz seçebilir', () {
      var state = engine.initializeGame(testRoom);
      state = engine.applyMove(state, 'p2', const BatakMove.bid(5));
      state = engine.applyMove(state, 'p3', const BatakMove.pass());
      state = engine.applyMove(state, 'p4', const BatakMove.pass());
      state = engine.applyMove(state, 'p1', const BatakMove.pass());

      final move = const BatakMove.chooseTrump(Suit.hearts);
      expect(engine.isValidMove(state, 'p3', move), false);
      expect(engine.isValidMove(state, 'p2', move), true);
    });

    test('koz seçilince playing fazına geçilir, elci başlar', () {
      var state = engine.initializeGame(testRoom);
      state = engine.applyMove(state, 'p2', const BatakMove.bid(5));
      state = engine.applyMove(state, 'p3', const BatakMove.pass());
      state = engine.applyMove(state, 'p4', const BatakMove.pass());
      state = engine.applyMove(state, 'p1', const BatakMove.pass());
      state = engine.applyMove(state, 'p2', const BatakMove.chooseTrump(Suit.hearts));

      expect(state.phase, BatakPhase.playing);
      expect(state.trumpSuit, Suit.hearts);
      expect(state.currentTurnPlayerId, 'p2');
    });
  });

  group('trick-taking', () {
    test('renk takip zorunluluğu uygulanır', () {
      final state = BatakGameState(
        hands: {
          'p1': [const PlayingCard(Suit.hearts, Rank.king)],
          'p2': [const PlayingCard(Suit.clubs, Rank.ace)],
          'p3': [], 'p4': [],
        },
        playerOrder: ['p1', 'p2', 'p3', 'p4'],
        dealerId: 'p1',
        phase: BatakPhase.playing,
        bids: {}, passedPlayers: {},
        currentTurnPlayerId: 'p2',
        trumpSuit: Suit.spades,
        declarerId: 'p1',
        currentTrick: [const TrickCard('p1', PlayingCard(Suit.hearts, Rank.king))],
        tricksWon: {'p1': 0, 'p2': 0, 'p3': 0, 'p4': 0},
      );

      final move = const BatakMove.playCard(PlayingCard(Suit.clubs, Rank.ace));
      // p2'nin elinde hearts yok, bu yüzden geçerli
      expect(engine.isValidMove(state, 'p2', move), true);
    });

    test('trick tamamlanınca en yüksek koz kazanır', () {
      final state = BatakGameState(
        hands: {'p1': [], 'p2': [], 'p3': [], 'p4': []},
        playerOrder: ['p1', 'p2', 'p3', 'p4'],
        dealerId: 'p1',
        phase: BatakPhase.playing,
        bids: {}, passedPlayers: {},
        currentTurnPlayerId: 'p4',
        trumpSuit: Suit.spades,
        declarerId: 'p1',
        currentTrick: [
          const TrickCard('p1', PlayingCard(Suit.hearts, Rank.king)),
          const TrickCard('p2', PlayingCard(Suit.hearts, Rank.ace)),
          const TrickCard('p3', PlayingCard(Suit.spades, Rank.two)), // koz, düşük ama kazanır
        ],
        tricksWon: {'p1': 0, 'p2': 0, 'p3': 0, 'p4': 0},
      );

      final newHands = {
        'p1': <PlayingCard>[], 'p2': <PlayingCard>[],
        'p3': <PlayingCard>[], 'p4': [const PlayingCard(Suit.clubs, Rank.two)],
      };
      final testState = state.copyWith(hands: newHands);

      final move = const BatakMove.playCard(PlayingCard(Suit.clubs, Rank.two));
      final result = engine.applyMove(testState, 'p4', move);

      expect(result.tricksWon['p3'], 1); // koz oynayan p3 kazandı
      expect(result.currentTurnPlayerId, 'p3');
      expect(result.currentTrick, isEmpty);
    });

    test('koz yoksa açılan renkte en yüksek kart kazanır', () {
      final state = BatakGameState(
        hands: {'p1': [], 'p2': [], 'p3': [], 'p4': []},
        playerOrder: ['p1', 'p2', 'p3', 'p4'],
        dealerId: 'p1',
        phase: BatakPhase.playing,
        bids: {}, passedPlayers: {},
        currentTurnPlayerId: 'p4',
        trumpSuit: Suit.spades,
        declarerId: 'p1',
        currentTrick: [
          const TrickCard('p1', PlayingCard(Suit.hearts, Rank.king)),
          const TrickCard('p2', PlayingCard(Suit.hearts, Rank.ace)),
          const TrickCard('p3', PlayingCard(Suit.hearts, Rank.two)),
        ],
        tricksWon: {'p1': 0, 'p2': 0, 'p3': 0, 'p4': 0},
      );

      final newHands = {
        'p1': <PlayingCard>[], 'p2': <PlayingCard>[], 'p3': <PlayingCard>[],
        'p4': [const PlayingCard(Suit.hearts, Rank.queen)],
      };
      final testState = state.copyWith(hands: newHands);

      final move = const BatakMove.playCard(PlayingCard(Suit.hearts, Rank.queen));
      final result = engine.applyMove(testState, 'p4', move);

      expect(result.tricksWon['p2'], 1); // hearts ace en yüksekti
    });
  });

  group('calculateScores', () {
    test('elci taahhüdünü tutturursa pozitif puan alır', () {
      final state = BatakGameState(
        hands: {'p1': [], 'p2': [], 'p3': [], 'p4': []},
        playerOrder: ['p1', 'p2', 'p3', 'p4'],
        dealerId: 'p1',
        phase: BatakPhase.finished,
        bids: {}, passedPlayers: {},
        currentTurnPlayerId: 'p1',
        declarerId: 'p2',
        highestBid: 6,
        tricksWon: {'p1': 3, 'p2': 6, 'p3': 2, 'p4': 2},
      );

      final scores = engine.calculateScores(state);
      expect(scores['p2'], 60); // 6 * 10
    });

    test('elci taahhüdünü tutturamazsa negatif puan alır', () {
      final state = BatakGameState(
        hands: {'p1': [], 'p2': [], 'p3': [], 'p4': []},
        playerOrder: ['p1', 'p2', 'p3', 'p4'],
        dealerId: 'p1',
        phase: BatakPhase.finished,
        bids: {}, passedPlayers: {},
        currentTurnPlayerId: 'p1',
        declarerId: 'p2',
        highestBid: 8,
        tricksWon: {'p1': 3, 'p2': 5, 'p3': 3, 'p4': 2},
      );

      final scores = engine.calculateScores(state);
      expect(scores['p2'], -80);
    });

    test('hiç el alamayan oyuncu battı cezası alır', () {
      final state = BatakGameState(
        hands: {'p1': [], 'p2': [], 'p3': [], 'p4': []},
        playerOrder: ['p1', 'p2', 'p3', 'p4'],
        dealerId: 'p1',
        phase: BatakPhase.finished,
        bids: {}, passedPlayers: {},
        currentTurnPlayerId: 'p1',
        declarerId: 'p2',
        highestBid: 6,
        tricksWon: {'p1': 0, 'p2': 6, 'p3': 4, 'p4': 3},
      );

      final scores = engine.calculateScores(state);
      expect(scores['p1'], -10);
    });
  });
}