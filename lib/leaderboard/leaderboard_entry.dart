class LeaderboardEntry {
  final String playerName;
  final int score;
  final String? countryCode;
  final String? difficulty;
  final DateTime createdAt;

  const LeaderboardEntry({
    required this.playerName,
    required this.score,
    required this.createdAt,
    this.countryCode,
    this.difficulty,
  });

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return LeaderboardEntry(
      playerName: json['player_name'] as String,
      score: json['score'] as int,
      countryCode: json['country_code'] as String?,
      difficulty: json['difficulty'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
