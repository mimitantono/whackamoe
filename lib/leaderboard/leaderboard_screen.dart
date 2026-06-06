import 'package:flutter/material.dart';
import 'country_helper.dart';
import 'leaderboard_entry.dart';
import 'leaderboard_service.dart';

class LeaderboardScreen extends StatefulWidget {
  final String gameId;
  final String? difficulty;
  final String? difficultyLabel;

  /// Optional list of (label, difficultyValue) pairs to show as tabs.
  /// If null, shows the single [difficulty].
  final List<({String label, String value})>? difficultyTabs;

  const LeaderboardScreen({
    super.key,
    required this.gameId,
    this.difficulty,
    this.difficultyLabel,
    this.difficultyTabs,
  });

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  late String? _selectedDifficulty;
  late Future<List<LeaderboardEntry>> _future;

  @override
  void initState() {
    super.initState();
    _selectedDifficulty = widget.difficultyTabs?.first.value ?? widget.difficulty;
    _refresh();
  }

  void _refresh() {
    _future = LeaderboardService.top(
      gameId: widget.gameId,
      difficulty: _selectedDifficulty,
    );
  }

  String _periodLabel() {
    final period = LeaderboardService.currentPeriod();
    final parts = period.split('-');
    const months = [
      'JANUARY', 'FEBRUARY', 'MARCH', 'APRIL', 'MAY', 'JUNE',
      'JULY', 'AUGUST', 'SEPTEMBER', 'OCTOBER', 'NOVEMBER', 'DECEMBER',
    ];
    final m = int.tryParse(parts[1]) ?? 1;
    return '${months[m - 1]} ${parts[0]}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D1A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white70),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          children: [
            const Text(
              'LEADERBOARD',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 3,
              ),
            ),
            Text(
              _periodLabel(),
              style: const TextStyle(
                color: Color(0xFFFFD700),
                fontSize: 10,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (widget.difficultyTabs != null) _buildTabs(),
            Expanded(
              child: FutureBuilder<List<LeaderboardEntry>>(
                future: _future,
                builder: (context, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const Center(
                      child: CircularProgressIndicator(color: Color(0xFFFFD700)),
                    );
                  }
                  if (snap.hasError) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.cloud_off, color: Colors.white24, size: 48),
                          const SizedBox(height: 12),
                          const Text('Could not load leaderboard',
                              style: TextStyle(color: Colors.white54)),
                          TextButton(
                            onPressed: () => setState(_refresh),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    );
                  }
                  final entries = snap.data ?? const [];
                  if (entries.isEmpty) {
                    return const Center(
                      child: Text('No scores this month yet.\nBe the first!',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white38, fontSize: 16, height: 1.5)),
                    );
                  }
                  return _buildList(entries);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabs() {
    final tabs = widget.difficultyTabs!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: tabs.map((t) {
          final isSelected = _selectedDifficulty == t.value;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() {
                _selectedDifficulty = t.value;
                _refresh();
              }),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF1A1A2E) : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected ? const Color(0xFFFFD700) : const Color(0xFF333333),
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Center(
                  child: Text(
                    t.label.toUpperCase(),
                    style: TextStyle(
                      color: isSelected ? const Color(0xFFFFD700) : Colors.white38,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildList(List<LeaderboardEntry> entries) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      itemCount: entries.length,
      itemBuilder: (_, i) => _Row(rank: i + 1, entry: entries[i]),
    );
  }
}

class _Row extends StatelessWidget {
  final int rank;
  final LeaderboardEntry entry;
  const _Row({required this.rank, required this.entry});

  @override
  Widget build(BuildContext context) {
    final flag = CountryHelper.toFlagEmoji(entry.countryCode) ?? '🏳️';
    final isTop3 = rank <= 3;
    final rankColor = switch (rank) {
      1 => const Color(0xFFFFD700),  // gold
      2 => const Color(0xFFC0C0C0),  // silver
      3 => const Color(0xFFCD7F32),  // bronze
      _ => Colors.white38,
    };

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isTop3 ? const Color(0xFF1A1A2E) : const Color(0x801A1A2E),
        borderRadius: BorderRadius.circular(12),
        border: isTop3
            ? Border.all(color: rankColor.withValues(alpha: 0.4), width: 1)
            : null,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: Text(
              '$rank',
              style: TextStyle(
                color: rankColor,
                fontSize: isTop3 ? 22 : 18,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(flag, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              entry.playerName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
                letterSpacing: 2,
              ),
            ),
          ),
          Text(
            '${entry.score}',
            style: TextStyle(
              color: isTop3 ? rankColor : Colors.white70,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}
