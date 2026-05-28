import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SoundService {
  static const _muteKey = 'whackamoe_muted';

  final AudioPlayer _whackPlayer = AudioPlayer();
  final AudioPlayer _missPlayer = AudioPlayer();
  final AudioPlayer _hedgehogPlayer = AudioPlayer();

  bool _muted = true;
  bool get muted => _muted;

  SoundService() {
    for (final p in [_whackPlayer, _missPlayer, _hedgehogPlayer]) {
      p.setReleaseMode(ReleaseMode.stop);
    }
  }

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _muted = prefs.getBool(_muteKey) ?? true;
  }

  void toggleMute() {
    _muted = !_muted;
    SharedPreferences.getInstance().then((p) => p.setBool(_muteKey, _muted));
  }

  void playWhack()    { if (!_muted) _whackPlayer.play(AssetSource('sounds/whack.mp3')); }
  void playMiss()     { if (!_muted) _missPlayer.play(AssetSource('sounds/miss.mp3')); }
  void playHedgehog() { if (!_muted) _hedgehogPlayer.play(AssetSource('sounds/hedgehog.mp3')); }

  void dispose() {
    _whackPlayer.dispose();
    _missPlayer.dispose();
    _hedgehogPlayer.dispose();
  }
}
