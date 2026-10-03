import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../game/characters.dart';
import '../game/game_painter.dart';
import '../game/world.dart';
import '../services/ad_service.dart';
import '../services/audio.dart';
import '../services/missions.dart';
import '../services/save_data.dart';
import '../services/share_card.dart';
import '../services/store_service.dart';
import 'house_screen.dart' show HouseBonus;
import 'rewards.dart';
import '../theme.dart';

const _gameOverLines = [
  'صبر کن بابات بیاد خونه!',
  'مگه دستم بهت نرسه!',
  'صد بار گفتم تو خونه توپ‌بازی نکن!',
  'فکر کردی می‌تونی در بری؟',
  'برو تو اتاقت!',
  'امشب از شام خبری نیست!',
];

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin {
  final GameWorld _w = GameWorld();
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  int _frame = 0;
  bool _paused = false;
  double _hintTime = 3.5;
  bool _doubled = false;
  bool _record = false;
  int _committedCoins = 0;
  // what was already sent to the daily missions (a run can continue after an ad)
  int _recNear = 0, _recSlip = 0, _recBelt = 0, _recJumps = 0, _recCoins = 0;
  bool _recGame = false;
  final List<Mission> _missionsDone = [];
  int _piggyAdded = 0;
  int _recBoxes = 0;
  int _recTokens = 0;
  final List<List<int>> _huntRewards = [];
  int _houseBonusCoins = 0;

  void _applyHouse() {
    final b = HouseBonus.of(s.repairs);
    _w.attackDelayMul = b.throwDelayMul;
    _w.dadDelay = b.dadDelay;
    _w.angerMul = b.angerMul;
    _w.houseShield = b.startShield;
  }
  bool _spun = false;
  bool _bestScore = false;
  String _momLine = _gameOverLines.first;

  SaveData get s => SaveData.i;

  @override
  void initState() {
    super.initState();
    // The run can be played in portrait or, for a wider view, sideways.
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _w.ability = s.ability;
    _w.powerDurations = s.boostDurations;
    _w.scoreMul = s.scoreMultiplier;
    _applyHouse();
    _w.wordLetters = lettersOf(s.todayWord);
    _w.wordIndex = s.todayWordProgress;
    _w.eventCoinMul = s.weekendEvent ? 2 : 1;
    _w.tutorial = !s.tutorialDone;
    if (_w.tutorial) _hintTime = 0;
    _w.reset();
    _ticker = createTicker(_tick)..start();
    Audio.i.setMusicVolume(Audio.musicVolume);
  }

  @override
  void dispose() {
    _ticker.dispose();
    Audio.i.setMusicVolume(Audio.musicVolume);
    // Menus are portrait only.
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  void _tick(Duration now) {
    final dt = min((now - _last).inMicroseconds / 1e6, 1 / 30);
    _last = now;
    if (_paused || _w.dead) return;
    _w.update(dt);
    if (_hintTime > 0) _hintTime -= dt;
    _handleEvents();
    setState(() => _frame++);
  }

  void _handleEvents() {
    for (final e in _w.events) {
      switch (e) {
        case GameEvent.jump:
          Audio.i.play(Sfx.jump, volume: 0.7);
          HapticFeedback.selectionClick();
          break;
        case GameEvent.land:
          Audio.i.play(Sfx.land, volume: 0.5);
          break;
        case GameEvent.coin:
          Audio.i.play(Sfx.coin, volume: 0.6);
          break;
        case GameEvent.whoosh:
          Audio.i.play(Sfx.whoosh, volume: 0.8);
          break;
        case GameEvent.windup:
          Audio.i.play(Sfx.windup, volume: 0.6);
          break;
        case GameEvent.hit:
          Audio.i.play(Sfx.hit);
          HapticFeedback.heavyImpact();
          break;
        case GameEvent.bounce:
          Audio.i.play(Sfx.bounce, volume: 0.7);
          break;
        case GameEvent.nearMiss:
          Audio.i.play(Sfx.nearmiss, volume: 0.7);
          HapticFeedback.lightImpact();
          break;
        case GameEvent.powerup:
          Audio.i.play(Sfx.powerup);
          break;
        case GameEvent.shieldBreak:
          Audio.i.play(Sfx.shield);
          HapticFeedback.mediumImpact();
          break;
        case GameEvent.kick:
          Audio.i.play(Sfx.kick);
          HapticFeedback.mediumImpact();
          break;
        case GameEvent.crack:
          Audio.i.play(Sfx.crack, volume: 0.9);
          break;
        case GameEvent.letter:
          Audio.i.play(Sfx.coin);
          if (s.setWordProgress(_w.wordIndex)) {
            Audio.i.play(Sfx.reward);
            _w.texts.add(FloatText('+${fa(kWordReward)} سکه و یه جعبه شانس!',
                _w.size.width / 2, _w.floorY - 300, C.goldDark, size: 22));
          }
          break;
        case GameEvent.shout:
          Audio.i.playVoice(_w.shoutKey);
          break;
        case GameEvent.tutorialDone:
          s.setTutorialDone(true);
          Audio.i.play(Sfx.reward);
          break;
        case GameEvent.parentSwap:
          Audio.i.play(Sfx.dad, volume: 0.8);
          break;
        case GameEvent.death:
          _onDeath();
          break;
      }
    }
    _w.events.clear();
  }

  void _onDeath() {
    Audio.i.play(Sfx.gameover, volume: 0.8);
    Audio.i.setMusicVolume(0.15);
    // Save coins collected so far and the best score immediately.
    s.addCoins(_w.coinsThisRun - _committedCoins);
    _committedCoins = _w.coinsThisRun;
    _record = s.submitScore(_w.meters) || _record;
    _bestScore = s.submitBestScore(_w.score) || _bestScore;
    _momLine = _gameOverLines[Random().nextInt(_gameOverLines.length)];
    // daily missions
    final done = s.recordRun(RunStats(
      meters: _w.meters,
      coins: _w.coinsThisRun - _recCoins,
      nearMisses: _w.nearMisses - _recNear,
      slippersDodged: _w.slippersDodged - _recSlip,
      beltsDodged: _w.beltsDodged - _recBelt,
      jumps: _w.jumps - _recJumps,
      games: _recGame ? 0 : 1,
    ));
    final houseExtra =
        ((_w.coinsThisRun - _recCoins) * HouseBonus.of(s.repairs).coinBonus).round();
    if (houseExtra > 0) {
      s.addCoins(houseExtra);
      _houseBonusCoins += houseExtra;
    }
    _piggyAdded += s.addToPiggy(_w.coinsThisRun - _recCoins);
    s.addBoxes(_w.boxesThisRun - _recBoxes);
    _huntRewards.addAll(s.addHuntTokens(_w.tokensThisRun - _recTokens));
    _recTokens = _w.tokensThisRun;
    _recBoxes = _w.boxesThisRun;
    _recCoins = _w.coinsThisRun;
    _recNear = _w.nearMisses;
    _recSlip = _w.slippersDodged;
    _recBelt = _w.beltsDodged;
    _recJumps = _w.jumps;
    _recGame = true;
    _missionsDone.addAll(done);
    // After the 3rd game, show the one-time starter offer (24 hours).
    if (s.shouldShowStarterOffer) {
      s.startStarterOffer();
      Future.delayed(const Duration(milliseconds: 1200), () {
        if (mounted) _showStarterOffer();
      });
    }
  }

  Future<void> _showStarterOffer() async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Panel(
          radius: 28,
          padding: const EdgeInsets.all(20),
          gradient: const LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [C.teal, Color(0xFF1C6FA8)],
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
              decoration: BoxDecoration(
                  color: C.red, borderRadius: BorderRadius.circular(999)),
              child: const Text('پیشنهاد ویژه · فقط ۲۴ ساعت',
                  style: TextStyle(color: C.white, fontWeight: FontWeight.w900)),
            ),
            const SizedBox(height: 10),
            const OutlinedTitle('بسته شروع', size: 34, fill: C.gold),
            const SizedBox(height: 10),
            for (final line in const [
              'حذف همیشگی تبلیغات',
              '۵٬۰۰۰ سکه',
              'شخصیت «گل‌زن محله» با قدرت شوت',
            ])
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.check_circle_rounded, color: C.gold, size: 20),
                  const SizedBox(width: 6),
                  Text(line,
                      style: const TextStyle(
                          color: C.white, fontWeight: FontWeight.w800, fontSize: 15)),
                ]),
              ),
            const SizedBox(height: 14),
            GameButton(
              tone: Tone.gold,
              onTap: () async {
                Navigator.pop(ctx);
                await StoreService.buy(context, Products.starter);
              },
              child: Text(Products.starter.priceLabel, style: const TextStyle(fontSize: 18)),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('بعداً',
                  style: TextStyle(color: C.white, fontWeight: FontWeight.w700)),
            ),
          ]),
        ),
      ),
    );
  }

  void _useGrandma() {
    if (_w.dead || _w.dying > 0 || _paused) return;
    if (s.useGrandma()) _w.grandma();
  }

  void _usePillow() {
    if (_w.dead || _w.dying > 0 || _paused || _w.shield) return;
    if (s.usePillow()) _w.activateShield();
  }

  Future<void> _continue() async {
    final ok = s.vip ? true : await AdService.showRewarded(context);
    if (!ok || !mounted) return;
    Audio.i.play(Sfx.powerup);
    Audio.i.setMusicVolume(Audio.musicVolume);
    setState(() => _w.revive());
  }

  Future<void> _doubleCoins() async {
    final ok = await AdService.showRewarded(context);
    if (!ok || !mounted) return;
    s.addCoins(_w.coinsThisRun);
    Audio.i.play(Sfx.reward);
    setState(() => _doubled = true);
  }

  Future<void> _retry() async {
    await AdService.maybeShowInterstitial(context);
    if (!mounted) return;
    Audio.i.setMusicVolume(Audio.musicVolume);
    setState(() {
      _w.ability = s.ability;
      _w.wordLetters = lettersOf(s.todayWord);
      _w.wordIndex = s.todayWordProgress;
      _w.reset();
      _doubled = false;
      _record = false;
      _committedCoins = 0;
      _recNear = _recSlip = _recBelt = _recJumps = _recCoins = 0;
      _recGame = false;
      _missionsDone.clear();
      _piggyAdded = 0;
      _recBoxes = 0;
      _recTokens = 0;
      _bestScore = false;
      _huntRewards.clear();
      _spun = false;
      _houseBonusCoins = 0;
      _hintTime = 0;
    });
  }

  Future<void> _home() async {
    await AdService.maybeShowInterstitial(context);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: C.wall,
        body: LayoutBuilder(builder: (context, box) {
          _w.setViewport(Size(box.maxWidth, box.maxHeight));
          return Stack(
            children: [
              // The game itself: press anywhere to jump, hold to jump higher.
              Positioned.fill(
                child: Listener(
                  behavior: HitTestBehavior.opaque,
                  onPointerDown: (_) {
                    if (!_paused) _w.press();
                  },
                  onPointerUp: (_) => _w.releasePress(),
                  onPointerCancel: (_) => _w.releasePress(),
                  child: CustomPaint(
                    painter: GamePainter(_w, s.character, _frame, token: s.huntToken),
                  ),
                ),
              ),
              SafeArea(child: _hud()),
              if (_hintTime > 0 && !_w.dead) _hint(),
              if (_w.tutorial) _tutorialOverlay(),
              if (_paused) _pauseOverlay(),
              if (_w.dead) _gameOver(),
            ],
          );
        }),
    );
  }

  // ------------------------------------------------------------------ HUD

  Widget _hud() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 20),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CoinPill(amount: _w.coinsThisRun),
                  const SizedBox(height: 8),
                  _abilityBadge(),
                  for (final k in PowerKind.values)
                    if (_w.powerTime(k) > 0) ...[
                      const SizedBox(height: 6),
                      _powerTimer(k),
                    ],
                  if (_w.eventCoinMul > 1) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [C.gold, C.goldDark]),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text('آخر هفته: سکه ×۲',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: C.ink)),
                    ),
                  ],
                ],
              ),
              const Spacer(),
              Column(children: [
                OutlinedTitle(fa(_w.meters), size: 38),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
                  decoration: BoxDecoration(
                    color: const Color(0xCC2B1B3A),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text('امتیاز ${fa(_w.score)}  ×${fa(_w.scoreMul)}',
                      style: const TextStyle(color: C.gold, fontSize: 12, fontWeight: FontWeight.w900)),
                ),
                if (_w.wordLetters.isNotEmpty && !_w.tutorial) _wordStrip(),
                const Text('متر',
                    style: TextStyle(
                        color: C.ink,
                        fontWeight: FontWeight.w900,
                        fontSize: 13)),
              ]),
              const Spacer(),
              RoundButton(
                icon: Icons.pause_rounded,
                label: 'توقف',
                onTap: () => setState(() => _paused = true),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _angerBar(),
          const Spacer(),
          Row(
            children: [
              _powerButton('مادربزرگ', Icons.elderly, s.grandmas, Tone.purple,
                  _useGrandma),
              const SizedBox(width: 14),
              _powerButton('بالش', Icons.bed, s.pillows, Tone.teal, _usePillow,
                  active: _w.shield),
              const Spacer(),
            ],
          ),
        ],
      ),
    );
  }

  /// Today's word, collected letters filled in.
  Widget _wordStrip() {
    return Container(
      margin: const EdgeInsets.only(top: 2),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xE6FFFFFF),
        borderRadius: BorderRadius.circular(10),
        boxShadow: kSoftShadow,
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        for (int i = 0; i < _w.wordLetters.length; i++)
          Container(
            width: 20,
            height: 24,
            margin: const EdgeInsets.symmetric(horizontal: 1),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: i < _w.wordIndex ? C.teal : const Color(0xFFF1E4F5),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(_w.wordLetters[i],
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: i < _w.wordIndex ? C.white : const Color(0x552B1B3A))),
          ),
      ]),
    );
  }

  /// An active in-run power-up with a shrinking bar.
  Widget _powerTimer(PowerKind k) {
    return Container(
      height: 30,
      padding: const EdgeInsetsDirectional.fromSTEB(4, 0, 10, 0),
      decoration: BoxDecoration(
        color: const Color(0xE6FFFFFF),
        borderRadius: BorderRadius.circular(999),
        boxShadow: kSoftShadow,
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(
          width: 26,
          height: 26,
          child: CustomPaint(painter: _PowerIconPainter(k)),
        ),
        const SizedBox(width: 6),
        SizedBox(
          width: 54,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: _w.powerLeft(k),
              minHeight: 7,
              backgroundColor: const Color(0xFFF1E4F5),
              color: C.purple,
            ),
          ),
        ),
      ]),
    );
  }

  /// Small pill showing the character's power (and the kick charge).
  Widget _abilityBadge() {
    final ch = s.character;
    if (!ch.upgradable) return const SizedBox.shrink();
    final kick = _w.ability.kickCooldown > 0;
    final ready = _w.kickReady;
    return Container(
      height: 30,
      padding: const EdgeInsetsDirectional.fromSTEB(6, 0, 10, 0),
      decoration: BoxDecoration(
        color: const Color(0xE6FFFFFF),
        borderRadius: BorderRadius.circular(999),
        boxShadow: kSoftShadow,
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(
          width: 22,
          height: 22,
          child: Stack(alignment: Alignment.center, children: [
            if (kick)
              CircularProgressIndicator(
                value: ready,
                strokeWidth: 3,
                color: ready >= 1 ? C.green : C.goldDark,
                backgroundColor: const Color(0xFFF1E4F5),
              ),
            Icon(ch.abilityIcon, size: 15, color: ch.rarity.color),
          ]),
        ),
        const SizedBox(width: 6),
        Text(kick && ready < 1 ? '${ch.abilityName}...' : ch.abilityName,
            style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w900, color: C.ink)),
      ]),
    );
  }

  Widget _angerBar() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: _angerBarInner(),
      ),
    );
  }

  Widget _angerBarInner() {
    final level = _w.anger;
    final label = level < 0.35
        ? 'یه کم عصبانی'
        : level < 0.7
            ? 'عصبانی'
            : 'آتیشی!';
    return Container(
      height: 46,
      padding: const EdgeInsetsDirectional.fromSTEB(14, 0, 10, 0),
      decoration: BoxDecoration(
        color: const Color(0xE6FFFFFF),
        borderRadius: BorderRadius.circular(999),
        boxShadow: kSoftShadow,
      ),
      child: Row(children: [
        const Text('عصبانیت مامان',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            height: 14,
            decoration: BoxDecoration(
              color: const Color(0xFFF1E4F5),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: FractionallySizedBox(
                widthFactor: max(0.06, level),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    gradient: const LinearGradient(
                        colors: [C.gold, C.red, Color(0xFFB0124A)]),
                    boxShadow: level > 0.7
                        ? const [BoxShadow(color: Color(0x88FF5A4E), blurRadius: 10)]
                        : null,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(label,
            style: const TextStyle(
                fontWeight: FontWeight.w900, fontSize: 13, color: C.redDark)),
      ]),
    );
  }

  Widget _powerButton(String label, IconData icon, int count, Tone tone,
      VoidCallback onTap,
      {bool active = false}) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        SizedBox(
          width: 70,
          child: GameButton(
            tone: count > 0 || active ? tone : Tone.white,
            height: 64,
            radius: 22,
            depth: 5,
            padding: EdgeInsets.zero,
            onTap: count > 0 && !active ? onTap : null,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 28),
                Text(label, style: const TextStyle(fontSize: 11)),
              ],
            ),
          ),
        ),
        Positioned(
          top: -8,
          left: -8,
          child: Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: C.white,
              shape: BoxShape.circle,
              boxShadow: kSoftShadow,
              border: Border.all(color: tone.bottom, width: 2.5),
            ),
            child: Text(fa(count),
                style: const TextStyle(
                    color: C.ink, fontSize: 12, fontWeight: FontWeight.w900)),
          ),
        ),
      ],
    );
  }

  Widget _hint() {
    return Positioned(
      left: 24,
      right: 24,
      bottom: 120,
      child: IgnorePointer(
        child: AnimatedOpacity(
          opacity: _hintTime > 0.5 ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 400),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: BoxDecoration(
              color: C.shade,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Column(mainAxisSize: MainAxisSize.min, children: [
              Text('بزن تا بپری — نگه دار تا بلندتر بپری',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: C.white, fontWeight: FontWeight.w900, fontSize: 14)),
              SizedBox(height: 4),
              Text('قرمز «بپر!»  ·  فیروزه‌ای «نپر!»',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: C.gold, fontWeight: FontWeight.w700, fontSize: 13)),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _tutorialOverlay() {
    final frozen = _w.tutFreeze;
    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(children: [
          if (frozen) Container(color: const Color(0x552B1B3A)),
          if (_w.tutText.isNotEmpty)
            Positioned(
              left: 20,
              right: 20,
              top: MediaQuery.of(context).padding.top + 150,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Panel(
                    radius: 22,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    child: Text(_w.tutText,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            color: C.ink,
                            height: 1.5)),
                  ),
                ),
              ),
            ),
          if (frozen && _w.tutWantTap)
            Align(
              alignment: const Alignment(0, 0.35),
              child: TweenAnimationBuilder<double>(
                key: ValueKey(_w.tutStep),
                tween: Tween(begin: 0.85, end: 1.1),
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeInOut,
                builder: (context, v, child) =>
                    Transform.scale(scale: v, child: child),
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: C.white,
                    shape: BoxShape.circle,
                    boxShadow: kSoftShadow,
                    border: Border.all(color: C.red, width: 4),
                  ),
                  child: const Icon(Icons.touch_app_rounded, size: 56, color: C.red),
                ),
              ),
            ),
          // skip button area is not needed: the tutorial is short (~25 s)
        ]),
      ),
    );
  }

  Widget _pauseOverlay() {
    return Positioned.fill(
      child: Container(
        color: C.shade,
        padding: const EdgeInsets.all(36),
        alignment: Alignment.center,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(child: OutlinedTitle('استراحت', size: 46)),
            const SizedBox(height: 30),
            GameButton(
              tone: Tone.green,
              height: 64,
              onTap: () => setState(() => _paused = false),
              child: const Text('ادامه', style: TextStyle(fontSize: 22)),
            ),
            const SizedBox(height: 14),
            GameButton(
              tone: Tone.white,
              onTap: () => Navigator.of(context).pop(),
              child: const Text('خانه', style: TextStyle(fontSize: 18)),
            ),
          ],
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------ Game over

  Widget _gameOver() {
    return Positioned.fill(
      child: Container(
        color: C.shade,
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(18),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 450),
                curve: Curves.easeOutBack,
                builder: (context, t, child) => Transform.translate(
                  offset: Offset(0, (1 - t) * 240),
                  child: Opacity(opacity: t.clamp(0.0, 1.0), child: child),
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: _gameOverCard(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _gameOverCard() {
    final ch = s.character;
    return Panel(
      radius: 32,
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
      gradient: const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [C.cream, Color(0xFFFFE6C6)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 130,
            child: CustomPaint(painter: _DizzyPainter(ch)),
          ),
          const Center(child: OutlinedTitle('خوردی!', size: 50, fill: C.red)),
          const SizedBox(height: 8),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: C.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: kSoftShadow,
              ),
              child: Text('مامان: «$_momLine»',
                  textAlign: TextAlign.center,
                  style: kBody.copyWith(fontWeight: FontWeight.w900)),
            ),
          ),
          if (_w.tokensThisRun > 0) ...[
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              SizedBox(
                  width: 22,
                  height: 22,
                  child: CustomPaint(painter: _TokenPainter(s.huntToken))),
              const SizedBox(width: 6),
              Text('${fa(_w.tokensThisRun)} ${huntTokenNames[s.huntToken]} · این هفته ${fa(s.weekTokens)}',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: C.ink)),
            ]),
          ],
          for (final r in _huntRewards) ...[
            const SizedBox(height: 6),
            Center(
              child: Text('جایزه هفتگی: ${huntRewardText(r)}',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: C.goldEdge)),
            ),
          ],
          if (_houseBonusCoins > 0) ...[
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.home_repair_service_rounded, color: C.greenDark, size: 18),
              const SizedBox(width: 6),
              Text('+${fa(_houseBonusCoins)} سکه پاداش تعمیر خونه',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: C.greenDark)),
            ]),
          ],
          if (_piggyAdded > 0) ...[
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.savings_rounded, color: C.purpleDark, size: 18),
              const SizedBox(width: 6),
              Text('+${fa(_piggyAdded)} سکه رفت تو قلک',
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w800, color: C.purpleDark)),
            ]),
          ],
          for (final m in _missionsDone) ...[
            const SizedBox(height: 8),
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F6EC),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: C.greenDark, width: 1.5),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.task_alt_rounded, color: C.greenDark, size: 18),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text('ماموریت انجام شد: ${m.title}',
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w800, color: C.greenDark)),
                  ),
                ]),
              ),
            ),
          ],
          if (_record) ...[
            const SizedBox(height: 12),
            Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [C.gold, C.goldDark]),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text('رکورد جدید!',
                    style: TextStyle(
                        fontWeight: FontWeight.w900, fontSize: 15, color: C.ink)),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(children: [
            _stat('مسافت', fa(_w.meters), 'متر', Icons.directions_run),
            const SizedBox(width: 10),
            _stat('سکه', '+${fa(_w.coinsThisRun * (_doubled ? 2 : 1))}',
                _doubled ? 'دوبرابر!' : 'جمع شد', Icons.savings_outlined),
            const SizedBox(width: 10),
            _stat('جاخالی', fa(_w.nearMisses), 'بار', Icons.bolt),
          ]),
          const SizedBox(height: 12),
          Panel(
            radius: 18,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            color: C.ink,
            child: Row(children: [
              const Icon(Icons.star_rounded, color: C.gold),
              const SizedBox(width: 6),
              Text('امتیاز ${fa(_w.score)}',
                  style: const TextStyle(color: C.white, fontSize: 18, fontWeight: FontWeight.w900)),
              const Spacer(),
              Text(_bestScore ? 'بهترین امتیاز!' : 'بهترین: ${fa(s.bestScore)}',
                  style: TextStyle(
                      color: _bestScore ? C.gold : const Color(0xFFE5D8F0),
                      fontSize: 12,
                      fontWeight: FontWeight.w800)),
            ]),
          ),
          const SizedBox(height: 18),
          if (!_w.usedContinue) ...[
            GameButton(
              tone: Tone.green,
              height: 70,
              radius: 24,
              onTap: _continue,
              child: Row(children: [
                Icon(s.vip ? Icons.workspace_premium : Icons.play_circle_fill,
                    size: 36),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('ادامه بده!',
                          style: TextStyle(fontSize: 22, height: 1.2)),
                      Text(
                          s.vip
                              ? 'رایگان برای VIP'
                              : 'از همین‌جا، با دیدن یک تبلیغ',
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 10),
          ],
          if (!_doubled && _w.coinsThisRun > 0) ...[
            GameButton(
              tone: Tone.gold,
              height: 56,
              onTap: _doubleCoins,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.ondemand_video, size: 22),
                  const SizedBox(width: 8),
                  Text('سکه‌ها رو دوبرابر کن (${fa(_w.coinsThisRun * 2)})',
                      style: const TextStyle(fontSize: 16)),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
          if (!_spun && _w.meters >= 150) ...[
            GameButton(
              tone: Tone.gold,
              height: 54,
              onTap: () async {
                setState(() => _spun = true);
                await showLuckyWheel(context);
                if (mounted) setState(() {});
              },
              child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.casino_rounded),
                SizedBox(width: 8),
                Text('گردونه شانس رایگان!', style: TextStyle(fontSize: 17)),
              ]),
            ),
            const SizedBox(height: 10),
          ],
          if (s.mysteryBoxes > 0) ...[
            GameButton(
              tone: Tone.purple,
              height: 50,
              onTap: () async {
                await showOpenBoxes(context);
                if (mounted) setState(() {});
              },
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.card_giftcard_rounded),
                const SizedBox(width: 8),
                Text('${fa(s.mysteryBoxes)} جعبه شانس داری، بازش کن!',
                    style: const TextStyle(fontSize: 15)),
              ]),
            ),
            const SizedBox(height: 10),
          ],
          GameButton(
            tone: Tone.teal,
            height: 50,
            onTap: () => ShareCard.shareRun(
              ch: s.character,
              meters: _w.meters,
              coins: _w.coinsThisRun,
              best: s.best,
              record: _record,
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.share_rounded),
                SizedBox(width: 8),
                Text('رکوردم رو به دوستام نشون بده', style: TextStyle(fontSize: 15)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
              child: GameButton(
                tone: Tone.red,
                onTap: _retry,
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.replay_rounded),
                    SizedBox(width: 8),
                    Text('دوباره', style: TextStyle(fontSize: 18)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GameButton(
                tone: Tone.white,
                onTap: _home,
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.home_rounded),
                    SizedBox(width: 8),
                    Text('خانه', style: TextStyle(fontSize: 18)),
                  ],
                ),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _stat(String label, String value, String sub, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        decoration: BoxDecoration(
          color: C.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: kSoftShadow,
        ),
        child: Column(children: [
          Icon(icon, size: 20, color: C.inkSoft),
          Text(label, style: kSmall),
          FittedBox(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 22, fontWeight: FontWeight.w900, color: C.ink)),
          ),
          Text(sub, style: kSmall.copyWith(fontSize: 11)),
        ]),
      ),
    );
  }
}

class _DizzyPainter extends CustomPainter {
  _DizzyPainter(this.ch);
  final Character ch;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    drawCharacter(canvas, ch, Offset(cx, size.height - 2), 1.15,
        mood: Mood.hurt, phase: 0.3);
    drawSlipper(canvas, Offset(cx + 34, 16), 50, 0.6);
    // dizzy stars
    final p = Paint()..color = C.gold;
    for (int k = 0; k < 3; k++) {
      final a = k * 2 * pi / 3;
      canvas.drawPath(
          starPath(Offset(cx + cos(a) * 34, 26 + sin(a) * 8), 7), p);
    }
  }

  @override
  bool shouldRepaint(covariant _DizzyPainter old) => old.ch != ch;
}


class _PowerIconPainter extends CustomPainter {
  _PowerIconPainter(this.kind);
  final PowerKind kind;

  @override
  void paint(Canvas canvas, Size size) =>
      drawPowerIcon(canvas, kind, size.center(Offset.zero), size.width * 0.45);

  @override
  bool shouldRepaint(covariant _PowerIconPainter old) => old.kind != kind;
}


class _TokenPainter extends CustomPainter {
  _TokenPainter(this.t);
  final HuntToken t;

  @override
  void paint(Canvas canvas, Size size) => drawHuntToken(canvas, t, size.center(Offset.zero), size.width * 0.42);

  @override
  bool shouldRepaint(covariant _TokenPainter old) => old.t != t;
}
