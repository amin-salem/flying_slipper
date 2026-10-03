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

  /// Master levels: kept low so sounds stay gentle on phone speakers.
  static const double sfxVolume = 0.8;
  static const double musicVolume = 0.32;

  /// The same sound is not restarted faster than this (stops harsh
  /// machine-gun repeats, e.g. many coins or fast button taps).
  static const _minGapMs = {
    Sfx.coin: 45,
    Sfx.click: 70,
    Sfx.jump: 60,
    Sfx.land: 60,
    Sfx.whoosh: 80,
    Sfx.bounce: 80,
  };
  final Map<Sfx, int> _lastPlayed = {};

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
        await v.setVolume(0.9);
        v.play().catchError((_) {});
      } catch (_) {}
    }();
  }

  void play(Sfx s, {double volume = 1.0}) {
    if (!soundOn) return;
    final pool = _pools[s];
    if (pool == null || pool.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final last = _lastPlayed[s] ?? 0;
    if (now - last < (_minGapMs[s] ?? 40)) return;
    _lastPlayed[s] = now;
    final idx = _next[s]! % pool.length;
    _next[s] = idx + 1;
    final p = pool[idx];
    () async {
      try {
        await p.setVolume((volume * sfxVolume).clamp(0.0, 1.0));
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
        await _music!.setVolume(musicVolume);
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
