import '../models/game_room.dart';

/// Her oyun kendi State ve Move tipini tanımlar (örn. PistiGameState, PistiMove).
/// Bu sayede tip güvenliği korunurken, lobi/oda yönetimi tüm oyunlar için ortak kalır.
abstract class GameEngine<State, Move> {
  /// Oyun başında elleri dağıtır, masayı hazırlar
  State initializeGame(GameRoom room);

  /// Bir oyuncunun hamlesinin kurallara uygun olup olmadığını kontrol eder
  bool isValidMove(State state, String playerId, Move move);

  /// Hamleyi uygular, yeni state döner. SUNUCUDA (Cloud Function) çalışacak şekilde
  /// tasarlanmalı — client'a asla güvenilmez.
  State applyMove(State state, String playerId, Move move);

  /// Oyun bitti mi kontrolü
  bool isGameOver(State state);

  /// Oyun bittiğinde her oyuncunun skorunu hesaplar
  Map<String, int> calculateScores(State state);
}