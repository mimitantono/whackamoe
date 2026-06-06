import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'leaderboard_entry.dart';

class LeaderboardService {
  static const _table = 'leaderboard_scores';
  static const _deviceIdKey = 'leaderboard_device_id';
  static const _topN = 10;

  /// Current monthly period key, e.g. '2026-06'. New month = fresh leaderboard.
  static String currentPeriod() {
    final now = DateTime.now().toUtc();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }

  static Future<String> _deviceId() async {
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(_deviceIdKey);
    if (id == null) {
      id = const Uuid().v4();
      await prefs.setString(_deviceIdKey, id);
    }
    return id;
  }

  /// Returns the score currently at position [_topN] for this period.
  /// If fewer than [_topN] entries exist, returns 0 (any score qualifies).
  static Future<int> _cutoffScore({
    required String gameId,
    String? difficulty,
  }) async {
    var query = Supabase.instance.client
        .from(_table)
        .select('score')
        .eq('game_id', gameId)
        .eq('period', currentPeriod());
    if (difficulty != null) {
      query = query.eq('difficulty', difficulty);
    } else {
      query = query.isFilter('difficulty', null);
    }
    final rows = await query.order('score', ascending: false).limit(_topN);
    if (rows.length < _topN) return 0;
    return rows.last['score'] as int;
  }

  /// Whether a [score] qualifies for the top [_topN] this month.
  static Future<bool> qualifies({
    required String gameId,
    String? difficulty,
    required int score,
  }) async {
    if (score <= 0) return false;
    try {
      final cutoff = await _cutoffScore(gameId: gameId, difficulty: difficulty);
      return score > cutoff;
    } catch (_) {
      return false;
    }
  }

  static Future<void> submit({
    required String gameId,
    String? difficulty,
    required String playerName,
    required int score,
    String? countryCode,
  }) async {
    final deviceId = await _deviceId();
    await Supabase.instance.client.from(_table).insert({
      'game_id': gameId,
      'difficulty': difficulty,
      'player_name': playerName.toUpperCase(),
      'score': score,
      'country_code': countryCode,
      'period': currentPeriod(),
      'device_id': deviceId,
    });
  }

  static Future<List<LeaderboardEntry>> top({
    required String gameId,
    String? difficulty,
    int limit = _topN,
  }) async {
    var query = Supabase.instance.client
        .from(_table)
        .select()
        .eq('game_id', gameId)
        .eq('period', currentPeriod());
    if (difficulty != null) {
      query = query.eq('difficulty', difficulty);
    } else {
      query = query.isFilter('difficulty', null);
    }
    final rows = await query.order('score', ascending: false).limit(limit);
    return rows.map((j) => LeaderboardEntry.fromJson(j)).toList();
  }
}
