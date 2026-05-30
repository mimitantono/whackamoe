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

  // Loads mute preference and pre-decodes all audio so the first tap has no delay.
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _muted = prefs.getBool(_muteKey) ?? true;

    // Pre-load: decode into native buffer now; play() will seek+resume instantly.
    await Future.wait([
      _whackPlayer.setSource(AssetSource('sounds/whack.mp3')),
      _missPlayer.setSource(AssetSource('sounds/miss.mp3')),
      _hedgehogPlayer.setSource(AssetSource('sounds/hedgehog.mp3')),
    ]);
  }

  void toggleMute() {
    _muted = !_muted;
    SharedPreferences.getInstance().then((p) => p.setBool(_muteKey, _muted));
  }

  void playWhack()    => _play(_whackPlayer);
  void playMiss()     => _play(_missPlayer);
  void playHedgehog() => _play(_hedgehogPlayer);

  void _play(AudioPlayer player) {
    if (_muted) return;
    // Seek to start then resume — no re-decode needed, fires immediately.
    player.seek(Duration.zero).then((_) => player.resume());
  }

  void dispose() {
    _whackPlayer.dispose();
    _missPlayer.dispose();
    _hedgehogPlayer.dispose();
  }
}
