import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';

/// Every sound in the game. File names match assets/sfx/<name>.ogg
enum Sfx {
  jump,
  land,
  coin,
  whoosh,
  windup,
  hit,
  bounce,
  nearmiss,
  powerup,
  shield,
  gameover,
  click,
  reward,
  crack,
  kick,
  dad,
}

/// Plays sound effects and the background music (uses the just_audio plugin).
/// Every call is safe: if audio fails, the game simply stays silent.
class Audio {
  Audio._();
  static final Audio i = Audio._();

  // Sounds that can overlap get more than one player.
  static const _poolSizes = {
    Sfx.coin: 3,
    Sfx.jump: 2,
    Sfx.land: 2,
    Sfx.whoosh: 2,
    Sfx.click: 2,
  };

  final Map<Sfx, List<AudioPlayer>> _pools = {};
  final Map<Sfx, int> _next = {};
  AudioPlayer? _music;
  bool _musicLoaded = false;
  bool _musicPlaying = false;

  bool soundOn = true;
  bool musicOn = true;

  /// Optional recorded voices: assets/voice/<key>.ogg (or .mp3 / .m4a / .wav).
  final Map<String, String> _voiceFiles = {};
  AudioPlayer? _voice;

  Future<void> init({required bool sound, required bool music}) async {
    soundOn = sound;
    musicOn = music;
    for (final s in Sfx.values) {
      final players = <AudioPlayer>[];
      for (int k = 0; k < (_poolSizes[s] ?? 1); k++) {
        try {
          final p = AudioPlayer(handleInterruptions: false);
          await p.setAsset('assets/sfx/${s.name}.ogg');
          players.add(p);
        } catch (_) {
          // This sound couldn't load; skip it.
        }
      }
      _pools[s] = players;
      _next[s] = 0;
    }
    await _findVoices();
  }

  Future<void> _findVoices() async {
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      for (final path in manifest.listAssets()) {
        if (!path.startsWith('assets/voice/')) continue;
        final name = path.split('/').last;
        final dot = name.lastIndexOf('.');
        if (dot <= 0) continue;
        final ext = name.substring(dot + 1).toLowerCase();
        if (!['ogg', 'mp3', 'm4a', 'wav', 'aac'].contains(ext)) continue;
        _voiceFiles[name.substring(0, dot)] = path;
      }
      if (_voiceFiles.isNotEmpty) _voice = AudioPlayer(handleInterruptions: false);
    } catch (_) {}
  }

  /// Plays a recorded voice line if the file exists (e.g. key 'dad_2').
  void playVoice(String key) {
    if (!soundOn || key.isEmpty) return;
    final path = _voiceFiles[key];
    final v = _voice;
    if (path == null || v == null) return;
    () async {
      try {
        await v.stop();
        await v.setAsset(path);
        await v.setVolume(1.0);
        v.play().catchError((_) {});
      } catch (_) {}
    }();
  }

  void play(Sfx s, {double volume = 1.0}) {
    if (!soundOn) return;
    final pool = _pools[s];
    if (pool == null || pool.isEmpty) return;
    final idx = _next[s]! % pool.length;
    _next[s] = idx + 1;
    final p = pool[idx];
    () async {
      try {
        await p.setVolume(volume);
        await p.seek(Duration.zero);
        // play() finishes only when the sound ends, so don't wait for it.
        p.play().catchError((_) {});
      } catch (_) {}
    }();
  }

  Future<void> startMusic() async {
    if (!musicOn || _musicPlaying) return;
    try {
      _music ??= AudioPlayer();
      if (!_musicLoaded) {
        await _music!.setAsset('assets/music/chase.ogg');
        await _music!.setLoopMode(LoopMode.one);
        await _music!.setVolume(0.45);
        _musicLoaded = true;
      }
      _musicPlaying = true;
      _music!.play().catchError((_) {});
    } catch (_) {}
  }

  Future<void> stopMusic() async {
    _musicPlaying = false;
    try {
      await _music?.pause();
    } catch (_) {}
  }

  Future<void> pauseMusic() async {
    try {
      await _music?.pause();
    } catch (_) {}
  }

  Future<void> resumeMusic() async {
    if (!musicOn || !_musicPlaying) return;
    try {
      _music?.play().catchError((_) {});
    } catch (_) {}
  }

  Future<void> setMusicVolume(double v) async {
    try {
      await _music?.setVolume(v);
    } catch (_) {}
  }

  void setSound(bool on) => soundOn = on;

  Future<void> setMusic(bool on) async {
    musicOn = on;
    if (!on) await stopMusic();
  }
}
