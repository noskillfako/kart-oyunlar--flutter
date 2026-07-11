import 'package:flutter_test/flutter_test.dart';
import 'package:kart_oyunu/models/playing_card.dart';
import 'package:kart_oyunu/models/game_room.dart';
import 'package:kart_oyunu/engine/pisti/pisti_engine.dart';
import 'package:kart_oyunu/engine/pisti/pisti_state.dart';

void main() {
  late PistiEngine engine;
  late GameRoom testRoom;

  setUp(() {
    engine = PistiEngine();
    testRoom = GameRoom(
      id: 'test-room',
      gameType: 'pisti',
      status: 'playing',
      maxPlayers: 2,
      hostId: 'player1',
      players: {
        'player1': {'displayName': 'Ahmet'},
        'player2': {'displayName': 'Mehmet'},
      },
    );
  });

  group('initializeGame', () {
    test('her oyuncuya 4 kart dağıtır', () {
      final state = engine.initializeGame(testRoom);
      expect(state.hands['player1']!.length, 4);
      expect(state.hands['player2']!.length, 4);
    });

    test('masaya 4 kart açar', () {
      final state = engine.initializeGame(testRoom);
      expect(state.tableCards.length, 4);
    });

    test('desteden dağıtılan kartlar düşer (52 - 8 - 4 = 40)', () {
      final state = engine.initializeGame(testRoom);
      expect(state.deck.length, 40);
    });

    test('ilk sıra ilk oyuncuya aittir', () {
      final state = engine.initializeGame(testRoom);
      expect(state.currentTurnPlayerId, 'player1');
    });
  });

  group('isValidMove', () {
    test('sırası olmayan oyuncunun hamlesi geçersizdir', () {
      final state = engine.initializeGame(testRoom);
      final cardInHand = state.hands['player2']!.first;
      final move = PistiMove(cardInHand);
      expect(engine.isValidMove(state, 'player2', move), false);
    });

    test('elinde olmayan bir kart oynanamaz', () {
      final state = engine.initializeGame(testRoom);
      final cardNotInHand = const PlayingCard(Suit.spades, Rank.ace);
      final handHasIt = state.hands['player1']!.contains(cardNotInHand);
      if (!handHasIt) {
        final move = PistiMove(cardNotInHand);
        expect(engine.isValidMove(state, 'player1', move), false);
      }
    });

    test('sırası gelen oyuncunun elindeki kart geçerlidir', () {
      final state = engine.initializeGame(testRoom);
      final cardInHand = state.hands['player1']!.first;
      final move = PistiMove(cardInHand);
      expect(engine.isValidMove(state, 'player1', move), true);
    });
  });

  group('applyMove - eşleşme ile toplama', () {
    test('masadaki üst kartla aynı rank oynanırsa masa toplanır', () {
      final state = PistiGameState(
        hands: {
          'player1': [const PlayingCard(Suit.hearts, Rank.seven)],
          'player2': [const PlayingCard(Suit.clubs, Rank.two)],
        },
        tableCards: [const PlayingCard(Suit.spades, Rank.seven)],
        deck: [],
        playerOrder: ['player1', 'player2'],
        currentTurnPlayerId: 'player1',
        collectedCards: {'player1': [], 'player2': []},
        pistiCounts: {'player1': 0, 'player2': 0},
      );

      final move = PistiMove(const PlayingCard(Suit.hearts, Rank.seven));
      final newState = engine.applyMove(state, 'player1', move);

      expect(newState.tableCards, isEmpty);
      expect(newState.collectedCards['player1']!.length, 2);
      expect(newState.lastCollectorId, 'player1');
    });

    test('tek kartlık masayı toplamak Pişti bonusu verir', () {
      final state = PistiGameState(
        hands: {
          'player1': [const PlayingCard(Suit.hearts, Rank.seven)],
          'player2': [],
        },
        tableCards: [const PlayingCard(Suit.spades, Rank.seven)],
        deck: [],
        playerOrder: ['player1', 'player2'],
        currentTurnPlayerId: 'player1',
        collectedCards: {'player1': [], 'player2': []},
        pistiCounts: {'player1': 0, 'player2': 0},
      );

      final move = PistiMove(const PlayingCard(Suit.hearts, Rank.seven));
      final newState = engine.applyMove(state, 'player1', move);

      expect(newState.pistiCounts['player1'], 1);
    });

    test('birden fazla kart varken toplama Pişti bonusu VERMEZ', () {
      final state = PistiGameState(
        hands: {
          'player1': [const PlayingCard(Suit.hearts, Rank.seven)],
          'player2': [],
        },
        tableCards: [
          const PlayingCard(Suit.diamonds, Rank.three),
          const PlayingCard(Suit.spades, Rank.seven),
        ],
        deck: [],
        playerOrder: ['player1', 'player2'],
        currentTurnPlayerId: 'player1',
        collectedCards: {'player1': [], 'player2': []},
        pistiCounts: {'player1': 0, 'player2': 0},
      );

      final move = PistiMove(const PlayingCard(Suit.hearts, Rank.seven));
      final newState = engine.applyMove(state, 'player1', move);

      expect(newState.pistiCounts['player1'], 0);
      expect(newState.collectedCards['player1']!.length, 3);
    });

    test('eşleşme yoksa kart masaya bırakılır, toplama olmaz', () {
      final state = PistiGameState(
        hands: {
          'player1': [const PlayingCard(Suit.hearts, Rank.king)],
          'player2': [],
        },
        tableCards: [const PlayingCard(Suit.spades, Rank.seven)],
        deck: [],
        playerOrder: ['player1', 'player2'],
        currentTurnPlayerId: 'player1',
        collectedCards: {'player1': [], 'player2': []},
        pistiCounts: {'player1': 0, 'player2': 0},
      );

      final move = PistiMove(const PlayingCard(Suit.hearts, Rank.king));
      final newState = engine.applyMove(state, 'player1', move);

      expect(newState.tableCards.length, 2);
      expect(newState.collectedCards['player1'], isEmpty);
    });
  });

  group('applyMove - Vale (Bacak)', () {
    test('Vale, eşleşme olmasa bile masayı toplar', () {
      final state = PistiGameState(
        hands: {
          'player1': [const PlayingCard(Suit.hearts, Rank.jack)],
          'player2': [],
        },
        tableCards: [
          const PlayingCard(Suit.spades, Rank.three),
          const PlayingCard(Suit.diamonds, Rank.king),
        ],
        deck: [],
        playerOrder: ['player1', 'player2'],
        currentTurnPlayerId: 'player1',
        collectedCards: {'player1': [], 'player2': []},
        pistiCounts: {'player1': 0, 'player2': 0},
      );

      final move = PistiMove(const PlayingCard(Suit.hearts, Rank.jack));
      final newState = engine.applyMove(state, 'player1', move);

      expect(newState.tableCards, isEmpty);
      expect(newState.collectedCards['player1']!.length, 3);
    });

    test('Vale ile toplama Pişti bonusu vermez (masada tek kart olsa bile)', () {
      final state = PistiGameState(
        hands: {
          'player1': [const PlayingCard(Suit.hearts, Rank.jack)],
          'player2': [],
        },
        tableCards: [const PlayingCard(Suit.spades, Rank.three)],
        deck: [],
        playerOrder: ['player1', 'player2'],
        currentTurnPlayerId: 'player1',
        collectedCards: {'player1': [], 'player2': []},
        pistiCounts: {'player1': 0, 'player2': 0},
      );

      final move = PistiMove(const PlayingCard(Suit.hearts, Rank.jack));
      final newState = engine.applyMove(state, 'player1', move);

      expect(newState.pistiCounts['player1'], 0);
    });
  });

  group('applyMove - sıra ilerlemesi', () {
    test('hamleden sonra sıra diğer oyuncuya geçer', () {
      final state = engine.initializeGame(testRoom);
      final card = state.hands['player1']!.first;
      final newState = engine.applyMove(state, 'player1', PistiMove(card));
      expect(newState.currentTurnPlayerId, 'player2');
    });
  });

  group('isGameOver', () {
    test('eller ve deste boşsa oyun biter', () {
      final state = PistiGameState(
        hands: {'player1': [], 'player2': []},
        tableCards: [],
        deck: [],
        playerOrder: ['player1', 'player2'],
        currentTurnPlayerId: 'player1',
        collectedCards: {'player1': [], 'player2': []},
        pistiCounts: {'player1': 0, 'player2': 0},
      );
      expect(engine.isGameOver(state), true);
    });

    test('deste doluyken oyun bitmez', () {
      final state = PistiGameState(
        hands: {'player1': [], 'player2': []},
        tableCards: [],
        deck: [const PlayingCard(Suit.clubs, Rank.ace)],
        playerOrder: ['player1', 'player2'],
        currentTurnPlayerId: 'player1',
        collectedCards: {'player1': [], 'player2': []},
        pistiCounts: {'player1': 0, 'player2': 0},
      );
      expect(engine.isGameOver(state), false);
    });
  });

  group('calculateScores', () {
    test('en çok kart toplayan +3 puan alır', () {
      final state = PistiGameState(
        hands: {'player1': [], 'player2': []},
        tableCards: [],
        deck: [],
        playerOrder: ['player1', 'player2'],
        currentTurnPlayerId: 'player1',
        collectedCards: {
          'player1': List.generate(30, (_) => const PlayingCard(Suit.hearts, Rank.two)),
          'player2': List.generate(10, (_) => const PlayingCard(Suit.spades, Rank.three)),
        },
        pistiCounts: {'player1': 0, 'player2': 0},
      );

      final scores = engine.calculateScores(state);
      expect(scores['player1']! > scores['player2']!, true);
    });

    test('Pişti sayısı 10 puan olarak eklenir', () {
      final state = PistiGameState(
        hands: {'player1': [], 'player2': []},
        tableCards: [],
        deck: [],
        playerOrder: ['player1', 'player2'],
        currentTurnPlayerId: 'player1',
        collectedCards: {'player1': [], 'player2': []},
        pistiCounts: {'player1': 2, 'player2': 0},
      );

      final scores = engine.calculateScores(state);
      expect(scores['player1'], greaterThanOrEqualTo(20));
    });
  });
}