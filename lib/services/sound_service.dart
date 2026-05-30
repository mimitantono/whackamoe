import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SoundService {
  static const _muteKey = 'whackamoe_muted';

  // Two players per sound so rapid re-triggers never block on each other.
  final _whackPool    = [AudioPlayer(), AudioPlayer()];
  final _missPool     = [AudioPlayer(), AudioPlayer()];
  final _hedgehogPool = [AudioPlayer(), AudioPlayer()];
  int _wi = 0, _mi = 0, _hi = 0;

  bool _muted = true;
  bool get muted => _muted;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _muted = prefs.getBool(_muteKey) ?? true;

    for (final p in [..._whackPool, ..._missPool, ..._hedgehogPool]) {
      p.setReleaseMode(ReleaseMode.stop);
    }
    await Future.wait([
      ..._whackPool.map((p)    => p.setSource(AssetSource('sounds/whack.ogg'))),
      ..._missPool.map((p)     => p.setSource(AssetSource('sounds/miss.ogg'))),
      ..._hedgehogPool.map((p) => p.setSource(AssetSource('sounds/hedgehog.ogg'))),
    ]);
  }

  // Call inside the PLAY button gesture to unlock the Web Audio AudioContext
  // and exercise every player so none are cold on first real use.
  Future<void> warmUp() async {
    if (_muted) return;
    try {
      for (final p in [..._whackPool, ..._missPool, ..._hedgehogPool]) {
        await p.setVolume(0);
        await p.resume();
        await p.stop();
        await p.setVolume(1);
      }
    } catch (_) {}
  }

  void toggleMute() {
    _muted = !_muted;
    SharedPreferences.getInstance().then((p) => p.setBool(_muteKey, _muted));
  }

  void playWhack() {
    if (_muted) return;
    _wi = (_wi + 1) % _whackPool.length;
    _whackPool[_wi].play(AssetSource('sounds/whack.ogg'));
  }

  void playMiss() {
    if (_muted) return;
    _mi = (_mi + 1) % _missPool.length;
    _missPool[_mi].play(AssetSource('sounds/miss.ogg'));
  }

  void playHedgehog() {
    if (_muted) return;
    _hi = (_hi + 1) % _hedgehogPool.length;
    _hedgehogPool[_hi].play(AssetSource('sounds/hedgehog.ogg'));
  }

  void dispose() {
    for (final p in [..._whackPool, ..._missPool, ..._hedgehogPool]) {
      p.dispose();
    }
  }
}
