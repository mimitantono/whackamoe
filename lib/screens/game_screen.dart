import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../leaderboard/leaderboard_service.dart';
import '../leaderboard/new_high_score_dialog.dart';
import '../models/difficulty.dart';
import '../models/game_state.dart';
import '../services/segmentation_service.dart';
import '../services/sound_service.dart';
import '../widgets/hole_widget.dart';

// ── Floating popup (score or broken heart) ────────────────────────────────────

class _Popup {
  final String label;
  final Color color;
  final Offset origin; // center point in Stack's coordinate space
  final AnimationController ctrl;
  late final Animation<double> opacity;
  late final Animation<double> slideY;

  _Popup({
    required this.label,
    required this.color,
    required this.origin,
    required this.ctrl,
  }) {
    opacity = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 15),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 55),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 30),
    ]).animate(ctrl);
    slideY = Tween(begin: 0.0, end: -72.0).animate(
      CurvedAnimation(parent: ctrl, curve: Curves.easeOut),
    );
  }
}

// ── Screen ────────────────────────────────────────────────────────────────────

class GameScreen extends StatefulWidget {
  final Difficulty difficulty;

  const GameScreen({super.key, required this.difficulty});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  late GameState _state;
  final _rng = Random();
  Timer? _spawnTimer;
  late List<Timer?> _holeTimers;
  late List<DateTime?> _holeAppearTimes;
  List<bool> _holeCoolingDown = [];
  List<Timer?> _holeCooldownTimers = [];
  Uint8List? _customImageBytes;
  bool _customImageIsSegmented = false;
  bool _isSegmenting = false;
  bool _started = false;
  int _highScore = 0;

  late final SoundService _sounds;
  final List<_Popup> _popups = [];

  // GlobalKey per hole so we can look up each hole's screen position.
  late List<GlobalKey> _holeKeys;
  final GlobalKey _stackKey = GlobalKey();

  late List<AnimationController> _shakeControllers;
  late List<Animation<double>> _shakeAnims;

  @override
  void initState() {
    super.initState();
    _sounds = SoundService();
    _sounds.init().then((_) { if (mounted) setState(() {}); });
    _resetHoleState();
    _loadHighScore();
  }

  void _resetHoleState() {
    for (final t in _holeCooldownTimers) { t?.cancel(); }
    final count = widget.difficulty.holeCount;
    _state = GameState.initial(widget.difficulty);
    _holeTimers = List.filled(count, null);
    _holeAppearTimes = List.filled(count, null);
    _holeCoolingDown = List.filled(count, false);
    _holeCooldownTimers = List.filled(count, null);
    _holeKeys = List.generate(count, (_) => GlobalKey());
    _shakeControllers = List.generate(
      count,
      (_) => AnimationController(vsync: this, duration: const Duration(milliseconds: 400)),
    );
    _shakeAnims = _shakeControllers.map((ctrl) {
      return Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: ctrl, curve: Curves.elasticOut),
      );
    }).toList();
  }

  Future<void> _loadHighScore() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _highScore = prefs.getInt(widget.difficulty.bestScoreKey) ?? 0);
  }

  Future<void> _saveHighScore(int score) async {
    if (score <= _highScore) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(widget.difficulty.bestScoreKey, score);
    setState(() => _highScore = score);
  }

  void _startGame() {
    for (final c in _shakeControllers) { c.dispose(); }
    _resetHoleState();
    setState(() => _started = true);
    _scheduleSpawn();
  }

  void _scheduleSpawn() {
    _spawnTimer?.cancel();
    if (_state.isGameOver) return;
    _spawnTimer = Timer(Duration(milliseconds: _state.spawnIntervalMs), () {
      _spawn();
      _scheduleSpawn();
    });
  }

  void _spawn() {
    if (!mounted || _state.isGameOver) return;

    final emptyIndices = [
      for (int i = 0; i < _state.holes.length; i++)
        if (_state.holes[i] == HoleContent.empty && !_holeCoolingDown[i]) i,
    ];
    if (emptyIndices.isEmpty) return;

    final index = emptyIndices[_rng.nextInt(emptyIndices.length)];
    final content = _rng.nextDouble() < 0.72 ? HoleContent.mole : HoleContent.danger;

    final newHoles = List<HoleContent>.from(_state.holes);
    newHoles[index] = content;
    _holeAppearTimes[index] = DateTime.now();
    setState(() => _state = _state.copyWith(holes: newHoles));

    _holeTimers[index]?.cancel();
    _holeTimers[index] = Timer(Duration(milliseconds: _state.visibilityMs), () {
      if (!mounted) return;
      _clearHole(index);
    });
  }

  void _clearHole(int index) {
    final content = _state.holes[index];
    if (content == HoleContent.empty) return;
    final newHoles = List<HoleContent>.from(_state.holes);
    newHoles[index] = HoleContent.empty;
    _holeAppearTimes[index] = null;
    _holeTimers[index]?.cancel();
    _holeTimers[index] = null;

    if (content == HoleContent.mole) {
      final newHp = (_state.hp - 1).clamp(0, GameState.maxHp);
      final gameOver = newHp <= 0;
      setState(() => _state = _state.copyWith(holes: newHoles, hp: newHp, isGameOver: gameOver));
      if (gameOver) {
        _spawnTimer?.cancel();
        for (final t in _holeTimers) { t?.cancel(); }
        _saveHighScore(_state.score);
        WidgetsBinding.instance.addPostFrameCallback((_) => _handleGameOver());
      } else {
        // Mole escaped — block this hole for a moment and signal the miss.
        _holeCoolingDown[index] = true;
        _holeCooldownTimers[index]?.cancel();
        _holeCooldownTimers[index] = Timer(const Duration(milliseconds: 750), () {
          _holeCoolingDown[index] = false;
        });
        _sounds.playMiss();
        _showPopup(index: index, label: '💨', color: Colors.white60);
      }
    } else {
      setState(() => _state = _state.copyWith(holes: newHoles));
    }
  }

  // Fast = +3, medium = +2, late = +1.
  int _calcPoints(int index) {
    final appeared = _holeAppearTimes[index];
    if (appeared == null) return 1;
    final ratio = DateTime.now().difference(appeared).inMilliseconds / _state.visibilityMs;
    if (ratio < 0.45) return 3;
    if (ratio < 0.75) return 2;
    return 1;
  }

  // Returns the center of the mole's head area in Stack-local coordinates.
  Offset? _holeCenterInStack(int index) {
    final holeBox = _holeKeys[index].currentContext?.findRenderObject() as RenderBox?;
    final stackBox = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    if (holeBox == null || stackBox == null) return null;
    final topLeft = stackBox.globalToLocal(holeBox.localToGlobal(Offset.zero));
    // Target the upper portion of the hole widget — where the character's head is.
    return topLeft + Offset(holeBox.size.width / 2, holeBox.size.height * 0.30);
  }

  void _showPopup({required int index, required String label, required Color color}) {
    final origin = _holeCenterInStack(index) ?? Offset.zero;
    final ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 750));
    final popup = _Popup(label: label, color: color, origin: origin, ctrl: ctrl);
    setState(() => _popups.add(popup));
    ctrl.forward().then((_) {
      if (mounted) setState(() => _popups.remove(popup));
      ctrl.dispose();
    });
  }

  void _onHoleTap(int index, HoleContent content) {
    _holeTimers[index]?.cancel();
    _holeTimers[index] = null;

    final newHoles = List<HoleContent>.from(_state.holes);
    newHoles[index] = HoleContent.empty;

    if (content == HoleContent.mole) {
      final points = _calcPoints(index);
      _holeAppearTimes[index] = null;
      final newScore = _state.score + points;
      setState(() => _state = _state.copyWith(holes: newHoles, score: newScore));
      _sounds.playWhack();
      _showPopup(
        index: index,
        label: '+$points',
        color: switch (points) { 3 => const Color(0xFF00E676), 2 => Colors.amber, _ => Colors.white },
      );
      _saveHighScore(newScore);
      _scheduleSpawn();
    } else {
      _holeAppearTimes[index] = null;
      final newHp = (_state.hp - 2).clamp(0, GameState.maxHp);
      final gameOver = newHp <= 0;
      setState(() => _state = _state.copyWith(holes: newHoles, hp: newHp, isGameOver: gameOver));
      _sounds.playHedgehog();
      _showPopup(index: index, label: '💔', color: Colors.red);
      _shakeControllers[index].forward(from: 0);
      if (gameOver) {
        _spawnTimer?.cancel();
        for (final t in _holeTimers) { t?.cancel(); }
        _saveHighScore(_state.score);
        WidgetsBinding.instance.addPostFrameCallback((_) => _handleGameOver());
      }
    }
  }

  static const _nameKey = 'leaderboard_player_name';
  static const _countryKey = 'leaderboard_country_code';

  Future<void> _handleGameOver() async {
    final score = _state.score;
    final difficulty = widget.difficulty.name;
    bool qualifies = false;
    try {
      qualifies = await LeaderboardService.qualifies(
        gameId: 'whackamoe',
        difficulty: difficulty,
        score: score,
      );
    } catch (_) {}
    if (!mounted) return;

    if (qualifies) {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      await showNewHighScoreDialog(
        context,
        gameId: 'whackamoe',
        difficulty: difficulty,
        score: score,
        rememberedName: prefs.getString(_nameKey),
        rememberedCountryCode: prefs.getString(_countryKey),
        onNameRemembered: (n) => prefs.setString(_nameKey, n),
        onCountryRemembered: (c) => prefs.setString(_countryKey, c),
      );
      if (!mounted) return;
    }
    _showGameOver();
  }

  void _showGameOver() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Game Over',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 24),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Score: ${_state.score}',
                style: const TextStyle(color: Colors.amber, fontSize: 32, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('Best: $_highScore',
                style: const TextStyle(color: Colors.white54, fontSize: 16)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () { Navigator.pop(context); Navigator.pop(context); },
            child: const Text('Menu', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F3460)),
            onPressed: () { Navigator.pop(context); _startGame(); },
            child: const Text('Play Again',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, maxWidth: 512, maxHeight: 512);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() => _isSegmenting = true);
    final result = await SegmentationService.removeBackground(bytes);
    if (mounted) {
      setState(() {
        _customImageBytes = result.bytes;
        _customImageIsSegmented = result.hasTransparency;
        _isSegmenting = false;
      });
    }
  }

  @override
  void dispose() {
    _spawnTimer?.cancel();
    for (final t in _holeTimers) { t?.cancel(); }
    for (final t in _holeCooldownTimers) { t?.cancel(); }
    for (final c in _shakeControllers) { c.dispose(); }
    _sounds.dispose();
    super.dispose();
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
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          children: [
            const Text('Whack-a-Moe',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20, letterSpacing: 1.5)),
            Text(widget.difficulty.label,
                style: const TextStyle(color: Colors.white38, fontSize: 11, letterSpacing: 1)),
          ],
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  _TopBar(score: _state.score, highScore: _highScore, hp: _state.hp),
                  const SizedBox(height: 24),
                  Expanded(
                    child: Stack(
                      key: _stackKey,
                      clipBehavior: Clip.none,
                      children: [
                        _started
                            ? _HoleGrid(
                                difficulty: widget.difficulty,
                                holes: _state.holes,
                                customImageBytes: _customImageBytes,
                                customImageIsSegmented: _customImageIsSegmented,
                                shakeAnims: _shakeAnims,
                                holeKeys: _holeKeys,
                                onTap: _onHoleTap,
                              )
                            : _StartPrompt(
                                onStart: _startGame,
                                hasCustomImage: _customImageBytes != null,
                                isSegmented: _customImageIsSegmented,
                                isSegmenting: _isSegmenting,
                                onPickImage: _pickImage,
                                muted: _sounds.muted,
                                onToggleMute: () { _sounds.toggleMute(); setState(() {}); },
                              ),
                        // Floating popups anchored to their hole.
                        for (final popup in _popups)
                          AnimatedBuilder(
                            animation: popup.ctrl,
                            builder: (context, _) => Positioned(
                              left: popup.origin.dx,
                              top: popup.origin.dy + popup.slideY.value,
                              child: FractionalTranslation(
                                translation: const Offset(-0.5, -0.5),
                                child: Opacity(
                                  opacity: popup.opacity.value,
                                  child: Text(
                                    popup.label,
                                    style: TextStyle(
                                      color: popup.color,
                                      fontSize: 36,
                                      fontWeight: FontWeight.bold,
                                      shadows: const [Shadow(color: Colors.black54, blurRadius: 6)],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Top bar ───────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final int score;
  final int highScore;
  final int hp;

  const _TopBar({required this.score, required this.highScore, required this.hp});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('SCORE', style: TextStyle(color: Colors.white38, fontSize: 11, letterSpacing: 1.5)),
            Text('$score', style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
          ],
        ),
        Row(
          children: List.generate(5, (i) {
            final fullThreshold = (i + 1) * 2;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: _HalfHeart(full: hp >= fullThreshold, half: hp == fullThreshold - 1),
            );
          }),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Text('BEST', style: TextStyle(color: Colors.white38, fontSize: 11, letterSpacing: 1.5)),
            Text('$highScore', style: const TextStyle(color: Colors.amber, fontSize: 28, fontWeight: FontWeight.bold)),
          ],
        ),
      ],
    );
  }
}

class _HalfHeart extends StatelessWidget {
  final bool full;
  final bool half;
  const _HalfHeart({required this.full, required this.half});

  @override
  Widget build(BuildContext context) {
    const size = 28.0;
    if (full) return const Icon(Icons.favorite, color: Colors.red, size: size);
    if (half) {
      return SizedBox(
        width: size, height: size,
        child: Stack(children: [
          const Icon(Icons.favorite_border, color: Colors.red, size: size),
          ClipRect(
            clipper: _LeftHalfClipper(),
            child: const Icon(Icons.favorite, color: Colors.red, size: size),
          ),
        ]),
      );
    }
    return const Icon(Icons.favorite_border, color: Colors.red, size: size);
  }
}

class _LeftHalfClipper extends CustomClipper<Rect> {
  @override
  Rect getClip(Size size) => Rect.fromLTWH(0, 0, size.width / 2, size.height);
  @override
  bool shouldReclip(covariant CustomClipper<Rect> _) => false;
}

// ── Hole grid ─────────────────────────────────────────────────────────────────

class _HoleGrid extends StatelessWidget {
  final Difficulty difficulty;
  final List<HoleContent> holes;
  final Uint8List? customImageBytes;
  final bool customImageIsSegmented;
  final List<Animation<double>> shakeAnims;
  final List<GlobalKey> holeKeys;
  final void Function(int, HoleContent) onTap;

  const _HoleGrid({
    required this.difficulty,
    required this.holes,
    required this.customImageBytes,
    required this.customImageIsSegmented,
    required this.shakeAnims,
    required this.holeKeys,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final rows = _buildRows();
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: rows.map((rowIndices) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: rowIndices.map(_buildHole).toList(),
        );
      }).toList(),
    );
  }

  List<List<int>> _buildRows() {
    switch (difficulty) {
      case Difficulty.easy:   return [[0, 1], [2, 3]];
      case Difficulty.medium: return [[0, 1, 2], [3, 4, 5]];
      case Difficulty.hard:   return [[0, 1, 2], [3, 4, 5], [6, 7, 8]];
    }
  }

  Widget _buildHole(int index) {
    return Flexible(
      child: AspectRatio(
        aspectRatio: 0.65,
        child: Padding(
          key: holeKeys[index],
          padding: const EdgeInsets.all(8),
          child: AnimatedBuilder(
            animation: shakeAnims[index],
            builder: (context, child) {
              final shake = shakeAnims[index].value;
              final offset = sin(shake * pi * 6) * 6 * (1 - shake);
              return Transform.translate(offset: Offset(offset, 0), child: child);
            },
            child: HoleWidget(
              key: ValueKey(index),
              content: holes[index],
              customImageBytes: customImageBytes,
              customImageIsSegmented: customImageIsSegmented,
              onTap: (content) => onTap(index, content),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Start prompt ──────────────────────────────────────────────────────────────

class _StartPrompt extends StatelessWidget {
  final VoidCallback onStart;
  final bool hasCustomImage;
  final bool isSegmented;
  final bool isSegmenting;
  final VoidCallback onPickImage;
  final bool muted;
  final VoidCallback onToggleMute;

  const _StartPrompt({
    required this.onStart,
    required this.hasCustomImage,
    required this.isSegmented,
    required this.isSegmenting,
    required this.onPickImage,
    required this.muted,
    required this.onToggleMute,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('🦔', style: TextStyle(fontSize: 72)),
        const SizedBox(height: 20),
        const Text(
          'Whack the moe!\nDon\'t hit the hedgehog!',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white70, fontSize: 18, height: 1.5),
        ),
        const SizedBox(height: 8),
        const Text(
          'Hit fast for +3  •  slow for +1',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white38, fontSize: 13),
        ),
        const SizedBox(height: 24),
        _UploadButton(
          hasCustom: hasCustomImage,
          isSegmented: isSegmented,
          isSegmenting: isSegmenting,
          onTap: onPickImage,
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: onToggleMute,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A2E),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF3A3A5E)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  muted ? Icons.volume_off : Icons.volume_up,
                  color: Colors.white54,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  muted ? 'Sound off' : 'Sound on',
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 28),
        SizedBox(
          width: 200, height: 54,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F3460),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: onStart,
            child: const Text('PLAY',
                style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 3)),
          ),
        ),
      ],
    );
  }
}

// ── Upload button ─────────────────────────────────────────────────────────────

class _UploadButton extends StatelessWidget {
  final bool hasCustom;
  final bool isSegmented;
  final bool isSegmenting;
  final VoidCallback onTap;
  const _UploadButton({
    required this.hasCustom,
    required this.isSegmented,
    required this.isSegmenting,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color borderColor;
    final Color contentColor;
    final Widget leading;
    final String label;

    if (isSegmenting) {
      borderColor = const Color(0xFF3A3A5E);
      contentColor = Colors.white54;
      leading = const SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54),
      );
      label = 'Removing background…';
    } else if (hasCustom && isSegmented) {
      borderColor = Colors.greenAccent;
      contentColor = Colors.greenAccent;
      leading = const Icon(Icons.auto_awesome, color: Colors.greenAccent, size: 18);
      label = 'Custom nemesis (smart crop)';
    } else if (hasCustom) {
      borderColor = Colors.amber;
      contentColor = Colors.amber;
      leading = const Icon(Icons.check_circle, color: Colors.amber, size: 18);
      label = 'Custom nemesis set!';
    } else {
      borderColor = const Color(0xFF3A3A5E);
      contentColor = Colors.white54;
      leading = const Icon(Icons.upload_rounded, color: Colors.white54, size: 18);
      label = 'Upload your nemesis';
    }

    return GestureDetector(
      onTap: isSegmenting ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: hasCustom ? 2 : 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            leading,
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(color: contentColor, fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
