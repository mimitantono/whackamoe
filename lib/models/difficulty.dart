enum Difficulty {
  easy(holeCount: 4, label: 'Easy', description: '4 holes'),
  medium(holeCount: 6, label: 'Medium', description: '6 holes'),
  hard(holeCount: 9, label: 'Hard', description: '9 holes');

  const Difficulty({
    required this.holeCount,
    required this.label,
    required this.description,
  });

  final int holeCount;
  final String label;
  final String description;

  String get bestScoreKey => 'whackamoe_best_$name';
}
