import 'difficulty.dart';

enum HoleContent { empty, mole, danger }

class GameState {
  final List<HoleContent> holes;
  final int score;
  // hp = half-hearts: 6 = 3 full hearts. Knife costs 2, missed mole costs 1.
  final int hp;
  final bool isGameOver;
  final Difficulty difficulty;

  static const int maxHp = 10;

  const GameState({
    required this.holes,
    required this.score,
    required this.hp,
    required this.isGameOver,
    required this.difficulty,
  });

  factory GameState.initial(Difficulty difficulty) => GameState(
        holes: List.filled(difficulty.holeCount, HoleContent.empty),
        score: 0,
        hp: maxHp,
        isGameOver: false,
        difficulty: difficulty,
      );

  // Time between spawns (ms) — speeds up as score rises.
  int get spawnIntervalMs => (1400 - score * 20).clamp(680, 1400);

  // How long a mole/danger stays visible (ms) — intentionally longer than spawnIntervalMs
  // so multiple characters can be on screen simultaneously at higher scores.
  int get visibilityMs => (1800 - score * 50).clamp(800, 1800);

  GameState copyWith({
    List<HoleContent>? holes,
    int? score,
    int? hp,
    bool? isGameOver,
  }) =>
      GameState(
        holes: holes ?? this.holes,
        score: score ?? this.score,
        hp: hp ?? this.hp,
        isGameOver: isGameOver ?? this.isGameOver,
        difficulty: difficulty,
      );
}
