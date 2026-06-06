import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../leaderboard/leaderboard_screen.dart';
import '../models/difficulty.dart';
import '../services/interest_service.dart';
import 'game_screen.dart';

class StartScreen extends StatefulWidget {
  const StartScreen({super.key});

  @override
  State<StartScreen> createState() => _StartScreenState();
}

class _StartScreenState extends State<StartScreen> {
  Difficulty _difficulty = Difficulty.medium;
  final Map<Difficulty, int> _bestScores = {
    for (final d in Difficulty.values) d: 0,
  };
  bool _interestRegistered = false;
  bool _interestLoading = false;

  @override
  void initState() {
    super.initState();
    _loadBestScores();
    InterestService.hasRegistered().then((v) {
      if (mounted) setState(() => _interestRegistered = v);
    });
  }

  Future<void> _loadBestScores() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      for (final d in Difficulty.values) {
        _bestScores[d] = prefs.getInt(d.bestScoreKey) ?? 0;
      }
    });
  }

  void _play() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => GameScreen(difficulty: _difficulty)),
    ).then((_) => _loadBestScores());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const Spacer(flex: 2),
              const Text(
                'WHACK\nA MOE',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 56,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 4,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 8),
              const Text('🦔💨', style: TextStyle(fontSize: 32)),
              const Spacer(flex: 2),
              const Text(
                'DIFFICULTY',
                style: TextStyle(color: Colors.white54, fontSize: 12, letterSpacing: 2),
              ),
              const SizedBox(height: 12),
              _DifficultyPicker(
                selected: _difficulty,
                bestScores: _bestScores,
                onSelect: (d) => setState(() => _difficulty = d),
              ),
              const SizedBox(height: 20),
              Text(
                'BEST: ${_bestScores[_difficulty] ?? 0}',
                style: const TextStyle(
                  color: Colors.amber,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
              const Spacer(flex: 3),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F3460),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: _play,
                  child: const Text(
                    'PLAY',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 3,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => LeaderboardScreen(
                      gameId: 'whackamoe',
                      difficulty: _difficulty.name,
                      difficultyTabs: [
                        for (final d in Difficulty.values)
                          (label: d.label, value: d.name),
                      ],
                    ),
                  ),
                ),
                icon: const Icon(Icons.emoji_events, color: Color(0xFFFFD700), size: 18),
                label: const Text(
                  'LEADERBOARD',
                  style: TextStyle(
                    color: Color(0xFFFFD700),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 2,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              _TeamPlayButton(
                registered: _interestRegistered,
                loading: _interestLoading,
                onTap: () async {
                  if (_interestRegistered || _interestLoading) return;
                  setState(() => _interestLoading = true);
                  await InterestService.register();
                  if (mounted) {
                    setState(() {
                      _interestRegistered = true;
                      _interestLoading = false;
                    });
                  }
                },
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _TeamPlayButton extends StatelessWidget {
  final bool registered;
  final bool loading;
  final VoidCallback onTap;

  const _TeamPlayButton({
    required this.registered,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: registered ? const Color(0xFF0F3460).withValues(alpha: 0.6) : const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: registered ? Colors.greenAccent.withValues(alpha: 0.6) : const Color(0xFF3A3A5E),
            width: registered ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (loading)
              const SizedBox(
                width: 16, height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54),
              )
            else
              Text(
                registered ? '✓' : '🏆',
                style: const TextStyle(fontSize: 16),
              ),
            const SizedBox(width: 10),
            Text(
              registered ? 'You\'re interested in Team Play!' : 'Team Play — coming soon, tap if interested',
              style: TextStyle(
                color: registered ? Colors.greenAccent.withValues(alpha: 0.8) : Colors.white38,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DifficultyPicker extends StatelessWidget {
  final Difficulty selected;
  final Map<Difficulty, int> bestScores;
  final ValueChanged<Difficulty> onSelect;

  const _DifficultyPicker({
    required this.selected,
    required this.bestScores,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: Difficulty.values.map((d) {
        final isSelected = d == selected;
        return Expanded(
          child: GestureDetector(
            onTap: () => onSelect(d),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF0F3460) : const Color(0xFF1A1A2E),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? Colors.amber : const Color(0xFF3A3A5E),
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Column(
                children: [
                  Text(
                    d.label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: isSelected ? Colors.amber : Colors.white54,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    d.description,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: isSelected ? Colors.amber.withValues(alpha: 0.65) : Colors.white30,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
