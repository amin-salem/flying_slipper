import 'dart:math';
import 'dart:ui';

/// Things that happen inside the game, so the screen can play sounds.
enum GameEvent {
  jump,
  land,
  coin,
  whoosh,
  windup,
  hit,
  bounce,
  nearMiss,
  powerup,
  shieldBreak,
  death,
  kick,
  crack, // belt crack
  parentSwap,
  tutorialDone,
  shout, // a parent says something (see [GameWorld.shoutKey] for the voice file)
}

/// Who is chasing right now.
enum Parent { mom, dad }

enum ObstacleKind { vase, ball, books, samovar, teaTray, cat, geranium }

/// Attacks.
/// Mom: low (JUMP), high (DON'T jump), bounce (jump late), twin (two low).
/// Dad: whipLow (belt at your feet: JUMP), whipHigh (belt at head: DON'T),
///      remote (throws the TV remote low: JUMP).
enum ThrowKind { low, high, bounce, twin, whipLow, whipHigh, remote }

/// Special power of a character (see characters.dart).
class Ability {
  const Ability({
    this.airJumps = 0,
    this.warnBonus = 1.0,
    this.kickCooldown = 0,
    this.speedMul = 1.0,
    this.coinMul = 1,
    this.glide = false,
    this.glideFall = 170,
    this.startShield = false,
    this.shieldRegen = 0,
    this.magnet = 60,
  });
  final int airJumps; // extra jumps in the air (1 = double jump)
  final double warnBonus; // longer warning before attacks
  final double kickCooldown; // seconds between automatic kicks (0 = none)
  final double speedMul; // game speed multiplier
  final int coinMul; // coins per coin
  final bool glide; // hold while falling to float
  final double glideFall; // max falling speed while gliding
  final bool startShield; // begins every run with a pillow shield
  final double shieldRegen; // seconds to get a new shield (0 = never)
  final double magnet; // how far coins are pulled in

  bool get isNone => this == const Ability() || (airJumps == 0 &&
      warnBonus == 1.0 && kickCooldown == 0 && speedMul == 1.0 &&
      coinMul == 1 && !glide && !startShield);
}

Size obstacleSize(ObstacleKind k) => switch (k) {
      ObstacleKind.vase => const Size(44, 62),
      ObstacleKind.ball => const Size(36, 36),
      ObstacleKind.books => const Size(56, 40),
      ObstacleKind.samovar => const Size(46, 72),
      ObstacleKind.teaTray => const Size(66, 26),
      ObstacleKind.cat => const Size(60, 36),
      ObstacleKind.geranium => const Size(42, 58),
    };

class Hazard {
  Hazard.obstacle(this.kind, this.x, this.y)
      : isSlipper = false,
        throwKind = null,
        vx = 0,
        vy = 0;
  Hazard.slipper(this.throwKind, this.x, this.y, this.vx, this.vy)
      : isSlipper = true,
        kind = null;

  final bool isSlipper; // any flying thing (slipper or TV remote)
  final ObstacleKind? kind;
  final ThrowKind? throwKind;
  double x; // center x
  double y; // obstacles: floor y under them; flying: center y
  double vx;
  double vy;
  double rot = 0;
  double age = 0;
  bool bounced = false;
  bool passed = false;
  bool kicked = false; // kicked away by the football kid

  bool get isRemote => throwKind == ThrowKind.remote;

  /// Ball obstacles hop up and down.
  double get hop =>
      kind == ObstacleKind.ball && !kicked ? (sin(age * 6.5).abs()) * 46 : 0;

  Rect get hitbox {
    if (isSlipper) {
      return Rect.fromCenter(center: Offset(x, y), width: 40, height: 18);
    }
    final s = obstacleSize(kind!);
    return Rect.fromLTWH(x - s.width / 2 + 6, y - hop - s.height + 6,
        s.width - 12, s.height - 6);
  }
}

class Particle {
  Particle(this.type, this.x, this.y, this.vx, this.vy, this.life, this.size,
      this.color,
      {this.gravity = 0, this.spin = 0})
      : maxLife = life;
  final int type; // 0 dust, 1 sparkle, 2 star, 3 trail, 4 shard
  double x, y, vx, vy;
  double life;
  final double maxLife;
  final double size;
  final Color color;
  final double gravity;
  final double spin;
  double rot = 0;
}

class FloatText {
  FloatText(this.text, this.x, this.y, this.color, {this.size = 22});
  final String text;
  double x, y;
  double life = 1.1;
  final Color color;
  final double size;
}

class CoinItem {
  CoinItem(this.x, this.y);
  double x;
  double y;
}

const momLines = [
  'بیا اینجا ببینم!',
  'وایسا!',
  'مگه دستم بهت نرسه!',
  'کجا در میری؟!',
  'یک... دو... سه!',
  'دمپایی اومد!',
  'صد بار گفتم!',
];

const dadLines = [
  'صبر کن ببینم!',
  'کمربندم کو؟!',
  'به مامانت چی گفتی؟',
  'امروز حسابت رسیدس!',
  'فکر کردی من حواسم نیست؟',
  'بیا اینجا بچه!',
];

/// All game rules live here. The screen draws this and forwards input.
class GameWorld {
  final Random rng = Random();

  /// Size of the visible world in game units (not pixels).
  Size size = Size.zero;

  /// Pixels per game unit. Portrait shows ~520 units across, landscape
  /// shows ~440 units tall, so you always see far enough ahead.
  double zoom = 1;
  bool landscape = false;
  final List<GameEvent> events = [];

  /// The selected character's special power. Set before [reset].
  Ability ability = const Ability();

  /// Extra coin multiplier from events (weekend double coins).
  int eventCoinMul = 1;
  int get coinValue => ability.coinMul * eventCoinMul;

  double get floorY => size.height * (landscape ? 0.8 : 0.70);
  double get kidX => size.width * (landscape ? 0.3 : 0.36);

  /// Call with the real screen size (pixels). Handles rotation mid-game.
  void setViewport(Size screen) {
    if (screen.isEmpty) return;
    final land = screen.width > screen.height;
    final z = (land ? screen.height / 440 : screen.width / 520).clamp(0.5, 2.0);
    final newSize = Size(screen.width / z, screen.height / z);
    if (newSize == size && land == landscape) return;
    final oldFloor = floorY, oldKid = kidX;
    final hadSize = size != Size.zero;
    zoom = z;
    landscape = land;
    size = newSize;
    if (!hadSize) return;
    // keep everything in the same place relative to the kid and the floor
    final dx = kidX - oldKid, dy = floorY - oldFloor;
    for (final h in hazards) {
      h.x += dx;
      h.y += dy;
    }
    for (final c in coins) {
      c.x += dx;
      c.y += dy;
    }
    for (final p in particles) {
      p.x += dx;
      p.y += dy;
    }
    for (final t in texts) {
      t.x += dx;
      t.y += dy;
    }
  }

  static const double kidScale = 1.0;

  // ---- Jump tuning ----
  static const double jumpSpeed = 780;
  static const double gravityUp = 2300;
  static const double gravityHold = 1350; // while holding: higher jump
  static const double gravityDown = 3000; // snappy fall
  static const double maxHold = 0.22;
  static const double bufferTime = 0.14;

  // Kid
  double kidY = 0; // height above floor
  double kidVy = 0;
  bool holding = false;
  double _holdTime = 0;
  double _buffer = 0;
  int _airJumpsUsed = 0;
  double _shieldTimer = 0;
  bool gliding = false;
  double flip = 0; // 1..0 somersault after a double jump
  bool get onGround => kidY <= 0.01 && kidVy <= 0;
  double runPhase = 0;
  double squashX = 1, squashY = 1;
  double tilt = 0;
  double blinkTimer = 2;
  double kickCd = 0; // football kid: seconds until next kick is ready

  /// 0..1 how charged the kick is (1 = ready). For the HUD.
  double get kickReady => ability.kickCooldown <= 0
      ? 0
      : (1 - kickCd / ability.kickCooldown).clamp(0.0, 1.0);

  // Progress
  double traveled = 0;
  double speed = 270;
  double anger = 0.15; // 0..1 difficulty
  double time = 0;
  int coinsThisRun = 0;
  int nearMisses = 0;
  int jumps = 0;
  int slippersDodged = 0; // slippers and remotes that flew past
  int beltsDodged = 0;
  int get meters => traveled ~/ 40;
  int _lastRoom = 0;
  static const _roomNames = ['اتاق نشیمن', 'آشپزخونه', 'حیاط'];

  // States
  bool shield = false;
  double invincible = 0;
  double grandmaFlash = 0;
  double calm = 0; // parents calmed down by grandma
  double dying = 0;
  bool dead = false;
  bool usedContinue = false;
  double shake = 0;
  double _slowmo = 0;

  // ---- Parents ----
  Parent chaser = Parent.mom;
  Parent _outgoing = Parent.mom;
  double swapTimer = 0; // > 0 while one parent leaves and the other arrives
  double _nextSwap = 0;
  static const double swapDur = 1.6;

  /// The parent currently drawn (during a swap, first the old one leaves).
  Parent get shownParent => swapTimer > swapDur / 2 ? _outgoing : chaser;

  /// Extra x offset of the shown parent while walking off/on screen.
  double get parentSlide {
    if (swapTimer <= 0) return 0;
    const half = swapDur / 2;
    return swapTimer > half
        ? -(swapDur - swapTimer) / half * 260
        : -(swapTimer / half) * 260;
  }

  double windup = 0; // 0..1 while preparing an attack
  double _windupDur = 0.7;
  double release = 0; // 1..0 after throwing / whipping
  ThrowKind _nextThrow = ThrowKind.low;
  ThrowKind? get warning => windup > 0 ? _nextThrow : null;
  String shout = '';
  double shoutTimer = 0;

  /// Name of the voice file for the current shout, e.g. 'mom_3'
  /// (assets/voice/mom_3.ogg). Played only if that file exists.
  String shoutKey = '';

  void _say(String text, String key, double seconds) {
    shout = text;
    shoutKey = key;
    shoutTimer = seconds;
    events.add(GameEvent.shout);
  }

  String get _who => chaser == Parent.mom ? 'mom' : 'dad';
  double get parentX =>
      kidX - 150 + anger * 30 + sin(time * 1.3) * 8 + parentSlide;

  /// Angle of the twirling slipper / belt above the parent's head.
  double twirl = 0;

  // Dad's belt whip
  double whipT = 0; // 0 = idle, then 0..1 during a crack
  bool whipHigh = false;
  bool _whipHit = false;
  static const double whipDur = 0.5;
  double get whipY => floorY - (whipHigh ? 112 : 34);
  double get whipStartX => parentX + 44;
  double get whipTipX {
    if (whipT <= 0) return whipStartX;
    final full = kidX + 80;
    final double e;
    if (whipT < 0.25) {
      e = Curves2.easeOut(whipT / 0.25);
    } else if (whipT < 0.55) {
      e = 1;
    } else {
      e = 1 - (whipT - 0.55) / 0.45;
    }
    return whipStartX + (full - whipStartX) * e;
  }

  Rect get whipBox => Rect.fromLTRB(
      whipStartX, whipY - 9, max(whipStartX + 1, whipTipX), whipY + 9);

  // ---- Tutorial (first run only) ----
  /// Set to true before [reset] for a guided first run.
  bool tutorial = false;
  int tutStep = 0;
  double _tutTimer = 0;
  bool tutFreeze = false; // the world is paused to explain something
  bool tutWantTap = false; // paused until the player taps
  String tutText = '';
  Hazard? _tutTarget;
  Hazard? _lastThrown;

  // Spawning
  final List<Hazard> hazards = [];
  final List<CoinItem> coins = [];
  final List<Particle> particles = [];
  final List<FloatText> texts = [];
  double _obstacleTimer = 1.6;
  double _throwTimer = 3.2;
  double _coinTimer = 0.8;
  double _secondThrow = 0;
  double _trailTimer = 0;

  Rect get kidHitbox => Rect.fromLTWH(kidX - 12, floorY - kidY - 92, 26, 88);

  void reset() {
    kidY = 0;
    kidVy = 0;
    holding = false;
    _holdTime = 0;
    _buffer = 0;
    _airJumpsUsed = 0;
    _shieldTimer = 0;
    gliding = false;
    flip = 0;
    squashX = squashY = 1;
    tilt = 0;
    kickCd = 0;
    traveled = 0;
    _lastRoom = 0;
    speed = 270;
    anger = 0.15;
    time = 0;
    coinsThisRun = 0;
    nearMisses = 0;
    jumps = 0;
    slippersDodged = 0;
    beltsDodged = 0;
    shield = ability.startShield;
    invincible = 0;
    grandmaFlash = 0;
    calm = 0;
    dying = 0;
    dead = false;
    usedContinue = false;
    shake = 0;
    _slowmo = 0;
    chaser = Parent.mom;
    _outgoing = Parent.mom;
    swapTimer = 0;
    _nextSwap = tutorial ? 9999 : 20; // Dad shows up after ~20 seconds
    tutStep = 0;
    _tutTimer = 1.2;
    tutFreeze = false;
    tutWantTap = false;
    tutText = tutorial ? 'یه کم صبر کن... بابا و مامان دنبالت هستن!' : '';
    _tutTarget = null;
    _lastThrown = null;
    windup = 0;
    release = 0;
    whipT = 0;
    shout = '';
    shoutTimer = 0;
    hazards.clear();
    coins.clear();
    particles.clear();
    texts.clear();
    _obstacleTimer = 1.6;
    _throwTimer = 3.2;
    _coinTimer = 0.8;
    _secondThrow = 0;
    events.clear();
  }

  // ---------------- Input ----------------

  void press() {
    holding = true;
    if (dead || dying > 0) return;
    if (tutorial && tutFreeze) {
      if (tutWantTap) {
        tutFreeze = false;
        tutWantTap = false;
        tutText = '';
        _doJump();
      }
      return; // taps are ignored while we explain "don't jump"
    }
    if (onGround) {
      _doJump();
    } else if (_airJumpsUsed < ability.airJumps) {
      _airJumpsUsed++;
      _doJump(air: true);
    } else {
      _buffer = bufferTime; // jump as soon as we land
    }
  }

  void releasePress() {
    holding = false;
  }

  void _doJump({bool air = false}) {
    kidVy = air ? jumpSpeed * 0.9 : jumpSpeed;
    kidY = max(kidY, 0.02);
    _holdTime = air ? maxHold : 0;
    _buffer = 0;
    squashX = 0.78;
    squashY = 1.25;
    events.add(GameEvent.jump);
    jumps++;
    if (air) {
      flip = 1;
      _burst(kidX, floorY - kidY - 20, 8, const Color(0xFFFF6FA8), 1);
    } else {
      _dust(kidX, floorY, 6, -1);
    }
  }

  // ---------------- Power-ups ----------------

  void grandma() {
    for (final h in hazards) {
      _burst(h.x, h.isSlipper ? h.y : h.y - 30, 6, const Color(0xFFFFFFFF), 1);
    }
    hazards.clear();
    windup = 0;
    whipT = 0;
    calm = 2.6;
    _throwTimer = 3.2;
    _obstacleTimer = max(_obstacleTimer, 1.4);
    grandmaFlash = 1.0;
    _say(chaser == Parent.mom ? 'باشه مادر جون...' : 'چشم مادر...', '${_who}_calm', 1.6);
    texts.add(FloatText('مادربزرگ نجاتت داد!', size.width / 2, floorY - 220,
        const Color(0xFF26C6BE), size: 24));
    events.add(GameEvent.powerup);
  }

  void activateShield() {
    shield = true;
    _burst(kidX, floorY - kidY - 50, 10, const Color(0xFF26C6BE), 1);
    events.add(GameEvent.powerup);
  }

  void revive() {
    dead = false;
    dying = 0;
    usedContinue = true;
    hazards.clear();
    windup = 0;
    whipT = 0;
    kidY = 0;
    kidVy = 0;
    tilt = 0;
    flip = 0;
    invincible = 2.2;
    calm = 1.5;
    _obstacleTimer = 1.4;
    _throwTimer = 2.6;
  }

  // ---------------- Update ----------------

  double _lerp(double a, double b, double t) => a + (b - a) * t;

  void update(double realDt) {
    if (dead || size == Size.zero) return;
    if (tutorial && tutFreeze) {
      if (!tutWantTap) {
        _tutTimer -= realDt;
        if (_tutTimer <= 0) {
          tutFreeze = false;
          tutText = '';
        }
      }
      return;
    }
    // Slow motion (near miss / death)
    if (_slowmo > 0) _slowmo -= realDt;
    final dt = realDt * (dying > 0 ? 0.35 : (_slowmo > 0 ? 0.5 : 1.0));
    time += dt;
    if (shake > 0) shake = max(0, shake - realDt * 3);
    twirl += dt * (windup > 0 ? 17 : 8);

    _updateParticles(dt);

    if (dying > 0) {
      // kid tumbles away
      kidVy -= gravityDown * dt;
      kidY = max(0, kidY + kidVy * dt);
      tilt -= dt * 9;
      dying -= realDt;
      if (shoutTimer > 0) shoutTimer -= dt;
      if (dying <= 0) {
        dead = true;
        events.add(GameEvent.death);
      }
      return;
    }

    anger = (0.15 + meters / 1400).clamp(0.0, 1.0);
    speed = _lerp(270, 560, anger) * ability.speedMul;
    traveled += speed * dt;
    runPhase += dt * speed / 19;
    // announce a new room (same 450 m rooms as the painter)
    final room = (meters / 450).floor() % 3;
    if (room != _lastRoom) {
      _lastRoom = room;
      texts.add(FloatText('به ${_roomNames[room]} رسیدی!', size.width / 2,
          floorY - 260, const Color(0xFF1C8C9E), size: 24));
    }
    if (kickCd > 0) kickCd = max(0, kickCd - dt);
    if (ability.shieldRegen > 0 && !shield) {
      _shieldTimer += dt;
      if (_shieldTimer >= ability.shieldRegen) {
        _shieldTimer = 0;
        activateShield();
        texts.add(FloatText('سپر برگشت!', kidX, floorY - kidY - 140,
            const Color(0xFF26C6BE), size: 18));
      }
    }

    _updateKid(dt);
    _updateParents(dt);
    if (tutorial) {
      _tutorialScript(dt);
    } else {
      _spawn(dt);
    }
    _move(dt);
    _collide();
  }

  void _updateKid(double dt) {
    if (_buffer > 0) _buffer -= dt;
    final wasAir = !onGround;

    gliding = false;
    if (kidVy > 0 && holding && _holdTime < maxHold) {
      _holdTime += dt;
      kidVy -= gravityHold * dt;
    } else if (kidVy > 0) {
      kidVy -= gravityUp * dt;
    } else if (ability.glide && holding && kidY > 20) {
      // hero: float down slowly with the cape
      gliding = true;
      kidVy = max(kidVy - 700 * dt, -ability.glideFall);
    } else {
      kidVy -= gravityDown * dt;
    }
    kidY += kidVy * dt;
    if (kidY <= 0) {
      kidY = 0;
      if (wasAir) {
        kidVy = 0;
        _airJumpsUsed = 0;
        flip = 0;
        squashX = 1.28;
        squashY = 0.76;
        events.add(GameEvent.land);
        _dust(kidX, floorY, 8, 0);
        if (_buffer > 0) _doJump();
      }
      kidVy = max(0, kidVy);
    }
    if (flip > 0) flip = max(0, flip - dt * 2.6);

    // springy squash & stretch back to normal
    final k = min(1.0, dt * 14);
    double tx = 1, ty = 1;
    if (!onGround && !gliding) {
      final st = (kidVy.abs() / 2600).clamp(0.0, 0.18);
      tx = 1 - st;
      ty = 1 + st;
    }
    squashX += (tx - squashX) * k;
    squashY += (ty - squashY) * k;

    final targetTilt = onGround
        ? 0.07
        : (gliding ? 0.25 : (-kidVy / 5200).clamp(-0.2, 0.25) + 0.05);
    tilt += (targetTilt - tilt) * min(1.0, dt * 12);

    blinkTimer -= dt;
    if (blinkTimer < -0.12) blinkTimer = 1.5 + rng.nextDouble() * 2.5;

    if (invincible > 0) invincible -= dt;
    if (grandmaFlash > 0) grandmaFlash -= dt;
  }

  bool get blinking => blinkTimer < 0;

  void _updateParents(double dt) {
    if (shoutTimer > 0) shoutTimer -= dt;
    if (release > 0) release = max(0, release - dt * 4);

    // Belt crack in progress
    if (whipT > 0) {
      whipT += dt / whipDur;
      if (whipT >= 1) {
        whipT = 0;
        if (!_whipHit) {
          beltsDodged++;
          _checkWhipNearMiss();
        }
      }
    }

    // Mom and Dad take turns chasing
    if (swapTimer > 0) {
      swapTimer -= dt;
      if (swapTimer <= swapDur / 2 && swapTimer + dt > swapDur / 2) {
        // the new parent starts walking in
        final dad = chaser == Parent.dad;
        texts.add(FloatText(dad ? 'بابا اومد!' : 'مامان برگشت!',
            size.width / 2, floorY - 240, const Color(0xFFFF5A4E), size: 30));
        if (dad) {
          final i = rng.nextInt(dadLines.length);
          _say(dadLines[i], 'dad_$i', 1.6);
        } else {
          _say(momLines[0], 'mom_0', 1.6);
        }
        events.add(GameEvent.parentSwap);
      }
      return;
    }
    _nextSwap -= dt;
    if (!tutorial && _nextSwap <= 0 && windup <= 0 && whipT <= 0) {
      _outgoing = chaser;
      chaser = chaser == Parent.mom ? Parent.dad : Parent.mom;
      swapTimer = swapDur;
      _secondThrow = 0;
      _throwTimer = 1.4;
      _nextSwap = 22 + rng.nextDouble() * 10;
      return;
    }

    if (calm > 0) {
      calm -= dt;
      return;
    }
    if (windup > 0) {
      windup += dt / _windupDur;
      if (windup >= 1) {
        windup = 0;
        _attack(_nextThrow);
        if (_nextThrow == ThrowKind.twin) _secondThrow = 0.8;
      }
      return;
    }
    if (_secondThrow > 0) {
      _secondThrow -= dt;
      if (_secondThrow <= 0) _attack(ThrowKind.low);
    }
    if (tutorial) return; // the tutorial script decides the attacks
    _throwTimer -= dt;
    if (_throwTimer <= 0) _startWindup();
  }

  void _startWindup() {
    // Which attack? Harder kinds unlock as the parents get angrier.
    final List<ThrowKind> options;
    if (chaser == Parent.mom) {
      options = [ThrowKind.low, ThrowKind.low, ThrowKind.high];
      if (anger > 0.3) options.add(ThrowKind.bounce);
      if (anger > 0.5) options.add(ThrowKind.twin);
    } else {
      options = [ThrowKind.whipLow, ThrowKind.whipLow, ThrowKind.whipHigh];
      if (anger > 0.3) options.add(ThrowKind.remote);
    }
    var kind = options[rng.nextInt(options.length)];

    _windupDur = _lerp(0.85, 0.55, anger) * ability.warnBonus;
    final arrive = _windupDur + 0.4;
    // A high attack (stay down) must not meet an obstacle that needs a jump.
    final conflict = hazards.any((h) =>
        !h.isSlipper && ((h.x - kidX) / speed - arrive).abs() < 0.9);
    if (conflict) {
      if (kind == ThrowKind.high) kind = ThrowKind.low;
      if (kind == ThrowKind.whipHigh) kind = ThrowKind.whipLow;
    }
    if (kind == ThrowKind.high ||
        kind == ThrowKind.twin ||
        kind == ThrowKind.whipHigh) {
      _obstacleTimer = max(_obstacleTimer, arrive + 0.6);
    }
    _nextThrow = kind;
    windup = 0.001;
    final lines = chaser == Parent.mom ? momLines : dadLines;
    final li = rng.nextInt(lines.length);
    _say(lines[li], '${_who}_$li', _windupDur + 0.6);
    events.add(GameEvent.windup);
    _throwTimer = _lerp(4.2, 1.9, anger) + rng.nextDouble() * 1.4;
  }

  void _attack(ThrowKind kind) {
    release = 1;
    final x0 = parentX + 50;
    final v = _lerp(400, 540, anger);
    switch (kind) {
      case ThrowKind.low:
      case ThrowKind.twin:
        events.add(GameEvent.whoosh);
        _lastThrown = Hazard.slipper(ThrowKind.low, x0, floorY - 42, v, 0);
        hazards.add(_lastThrown!);
        break;
      case ThrowKind.high:
        events.add(GameEvent.whoosh);
        _lastThrown = Hazard.slipper(ThrowKind.high, x0, floorY - 116, v, 0);
        hazards.add(_lastThrown!);
        break;
      case ThrowKind.bounce:
        events.add(GameEvent.whoosh);
        // lob that lands before the kid and bounces into him
        final y0 = floorY - 150;
        final landX = kidX - 70;
        const t = 0.5;
        final vx = (landX - x0) / t;
        final vy = (floorY - 12 - y0 - 0.5 * 1500 * t * t) / t;
        hazards.add(Hazard.slipper(ThrowKind.bounce, x0, y0, vx, vy));
        break;
      case ThrowKind.remote:
        events.add(GameEvent.whoosh);
        hazards.add(Hazard.slipper(ThrowKind.remote, x0, floorY - 40, v * 1.1, 0));
        break;
      case ThrowKind.whipLow:
      case ThrowKind.whipHigh:
        events.add(GameEvent.crack);
        whipHigh = kind == ThrowKind.whipHigh;
        whipT = 0.001;
        _whipHit = false;
        break;
    }
  }

  void _forceAttack(ThrowKind kind, double windupSeconds) {
    _nextThrow = kind;
    _windupDur = windupSeconds;
    windup = 0.001;
    final li = rng.nextInt(momLines.length);
    _say(momLines[li], 'mom_$li', windupSeconds + 0.6);
    events.add(GameEvent.windup);
  }

  void _freeze({required bool tap, required String text, double seconds = 0}) {
    tutFreeze = true;
    tutWantTap = tap;
    tutText = text;
    _tutTimer = seconds;
  }

  /// The guided first run: obstacle -> low slipper -> high slipper -> coins.
  void _tutorialScript(double dt) {
    switch (tutStep) {
      case 0: // a moment to look around, then an obstacle
        _tutTimer -= dt;
        if (_tutTimer <= 0) {
          _tutTarget = Hazard.obstacle(ObstacleKind.books, size.width + 50, floorY);
          hazards.add(_tutTarget!);
          tutText = 'یه مانع جلوته! وقتی رسید، بپر';
          tutStep = 1;
        }
      case 1:
        if (_tutTarget!.x - kidX < 125) {
          _freeze(tap: true, text: 'حالا بزن تا بپری!');
          tutStep = 2;
        }
      case 2:
        if (_tutTarget!.x < kidX - 70 && onGround) {
          tutText = 'آفرین!';
          _tutTimer = 0.9;
          tutStep = 3;
        }
      case 3:
        _tutTimer -= dt;
        if (_tutTimer <= 0) {
          _forceAttack(ThrowKind.low, 1.5);
          tutText = 'مامان دمپایی پرت می‌کنه!\nعلامت قرمز «بپر!» یعنی باید بپری';
          tutStep = 4;
        }
      case 4:
        final s4 = _lastThrown;
        if (s4 != null && windup <= 0 && kidX - s4.x < 115) {
          _freeze(tap: true, text: 'حالا بپر!');
          tutStep = 5;
        }
      case 5:
        final s5 = _lastThrown;
        if ((s5 == null || s5.x > kidX + 60) && onGround) {
          tutText = 'عالی بود!';
          _tutTimer = 0.9;
          tutStep = 6;
        }
      case 6:
        _tutTimer -= dt;
        if (_tutTimer <= 0) {
          _lastThrown = null;
          _forceAttack(ThrowKind.high, 1.5);
          tutText = 'علامت فیروزه‌ای «نپر!» یعنی\nدمپایی از بالای سرت رد میشه';
          tutStep = 7;
        }
      case 7:
        final s7 = _lastThrown;
        if (s7 != null && windup <= 0 && kidX - s7.x < 115) {
          _freeze(tap: false, text: 'دست نزن! فقط نگاه کن...', seconds: 1.4);
          tutStep = 8;
        }
      case 8:
        final s8 = _lastThrown;
        if (s8 == null || s8.x > kidX + 60) {
          final x0 = size.width + 30;
          for (int i = 0; i < 6; i++) {
            coins.add(CoinItem(x0 + i * 36, floorY - 38));
          }
          tutText = 'سکه‌ها رو جمع کن!\nباهاشون شخصیت جدید بخر';
          _tutTimer = 3.2;
          tutStep = 9;
        }
      case 9:
        _tutTimer -= dt;
        if (_tutTimer <= 0) {
          tutText = 'آفرین! حالا بازی واقعی شروع میشه\nمواظب بابا هم باش!';
          _tutTimer = 2.4;
          tutStep = 10;
        }
      case 10:
        _tutTimer -= dt;
        if (_tutTimer <= 0) {
          tutorial = false;
          tutText = '';
          _throwTimer = 2.5;
          _obstacleTimer = 1.0;
          _nextSwap = 20;
          events.add(GameEvent.tutorialDone);
        }
    }
  }

  void _checkWhipNearMiss() {
    final kid = kidHitbox;
    final box = Rect.fromLTRB(whipStartX, whipY - 9, kidX + 80, whipY + 9);
    final gap = box.top > kid.bottom
        ? box.top - kid.bottom
        : (kid.top > box.bottom ? kid.top - box.bottom : 99.0);
    if (gap < 30) _nearMiss(kidX, whipY);
  }

  void _spawn(double dt) {
    // Obstacles from the right
    _obstacleTimer -= dt;
    if (_obstacleTimer <= 0) {
      final kinds = ObstacleKind.values;
      final k = kinds[rng.nextInt(kinds.length)];
      final x = size.width + 50;
      hazards.add(Hazard.obstacle(k, x, floorY));
      // Remove low coins that would sit inside this obstacle...
      final before = coins.length;
      coins.removeWhere((c) => (c.x - x).abs() < 80 && c.y > floorY - 110);
      // ...and often put a coin arc over it instead (you collect it by jumping).
      if (coins.length < before || rng.nextDouble() < 0.45) {
        for (int i = 0; i < 5; i++) {
          final f = i / 4;
          coins.add(CoinItem(x - 80 + f * 160, floorY - 95 - sin(f * pi) * 80));
        }
        _coinTimer = max(_coinTimer, 1.0);
      }
      _obstacleTimer = _lerp(1.9, 0.95, anger) + rng.nextDouble() * 1.0;
    }

    // Coin rows
    _coinTimer -= dt;
    if (_coinTimer <= 0) {
      final n = 3 + rng.nextInt(4);
      final x0 = size.width + 30, x1 = x0 + (n - 1) * 36;
      // A ground row must not overlap an obstacle: use an air row instead.
      final blocked =
          hazards.any((h) => !h.isSlipper && h.x > x0 - 90 && h.x < x1 + 90);
      final air = blocked || rng.nextDouble() < 0.35;
      final y = air ? floorY - 150 : floorY - 38;
      for (int i = 0; i < n; i++) {
        coins.add(CoinItem(x0 + i * 36, y));
      }
      _coinTimer = 1.4 + rng.nextDouble() * 1.6;
    }
  }

  void _move(double dt) {
    _trailTimer -= dt;
    final addTrail = _trailTimer <= 0;
    if (addTrail) _trailTimer = 0.025;

    for (final h in hazards) {
      h.age += dt;
      if (h.isSlipper) {
        h.x += h.vx * dt;
        h.rot += dt * (h.isRemote ? 22 : 16);
        if (h.throwKind == ThrowKind.bounce) {
          h.vy += 1500 * dt;
          h.y += h.vy * dt;
          if (h.vy > 0 && h.y >= floorY - 12) {
            h.y = floorY - 12;
            h.vy = h.bounced ? -h.vy * 0.45 : -440;
            h.bounced = true;
            h.vx = max(h.vx, 260);
            events.add(GameEvent.bounce);
            _dust(h.x, floorY, 6, 0);
          }
        } else {
          h.y += sin(h.age * 12) * 0.5;
        }
        if (addTrail) {
          particles.add(Particle(3, h.x - 14, h.y, -40, 0, 0.22, 12,
              h.isRemote ? const Color(0xFFB0B0C0) : const Color(0xFF8FB8FF)));
        }
      } else if (h.kicked) {
        // flying away after a kick
        h.x += 520 * dt;
        h.vy += 1500 * dt;
        h.y += h.vy * dt;
        h.rot += dt * 12;
      } else {
        h.x -= speed * dt;
        h.rot -= dt * speed / 18;
      }
    }
    hazards.removeWhere((h) =>
        h.x < -120 || h.x > size.width + 220 || h.y > size.height + 60);

    for (final c in coins) {
      c.x -= speed * dt;
      // small magnet when close
      final dx = kidX - c.x, dy = (floorY - kidY - 50) - c.y;
      if (dx.abs() < ability.magnet && dy.abs() < ability.magnet + 10) {
        c.x += dx * min(1.0, dt * 6);
        c.y += dy * min(1.0, dt * 6);
      }
    }
    coins.removeWhere((c) => c.x < -40);

    for (final t in texts) {
      t.life -= dt;
      t.y -= dt * 60;
    }
    texts.removeWhere((t) => t.life <= 0);
  }

  bool _useShield() {
    if (!shield) return false;
    shield = false;
    invincible = 1.0;
    shake = 0.5;
    events.add(GameEvent.shieldBreak);
    _burst(kidX, floorY - kidY - 50, 14, const Color(0xFF26C6BE), 4);
    texts.add(FloatText('بالش نجاتت داد!', kidX, floorY - kidY - 130,
        const Color(0xFF26C6BE)));
    return true;
  }

  void _collide() {
    final kid = kidHitbox;
    coins.removeWhere((c) {
      if (kid.inflate(10).contains(Offset(c.x, c.y))) {
        coinsThisRun += coinValue;
        events.add(GameEvent.coin);
        _burst(c.x, c.y, 5, const Color(0xFFFFD34D), 1);
        return true;
      }
      return false;
    });

    // Dad's belt
    if (whipT > 0 && whipT < 0.6 && !_whipHit && invincible <= 0) {
      if (whipBox.overlaps(kid)) {
        _whipHit = true;
        if (!_useShield()) {
          _die(null);
          return;
        }
      }
    }

    for (final h in List<Hazard>.from(hazards)) {
      if (h.kicked) continue;
      final box = h.hitbox;
      if (invincible <= 0 && box.overlaps(kid)) {
        // football kid kicks obstacles away
        if (!h.isSlipper && ability.kickCooldown > 0 && kickCd <= 0) {
          h.kicked = true;
          h.vy = -620;
          kickCd = ability.kickCooldown;
          events.add(GameEvent.kick);
          shake = 0.3;
          _burst(h.x, h.y - 30, 10, const Color(0xFFFFFFFF), 1);
          texts.add(FloatText('شوت!', kidX + 40, floorY - kidY - 120,
              const Color(0xFF26C6BE), size: 26));
          continue;
        }
        if (tutorial) {
          if (!h.passed) {
            h.passed = true;
            texts.add(FloatText('آخ! اشکال نداره، تمرینه', kidX, floorY - kidY - 130,
                const Color(0xFFFF5A4E), size: 18));
          }
          continue;
        }
        if (_useShield()) {
          hazards.remove(h);
          continue;
        }
        _die(h);
        return;
      }
      // near miss: something flew past very close
      if (h.isSlipper && !h.passed && h.x > kidX + 24) {
        h.passed = true;
        if (!tutorial) slippersDodged++;
        final gap = box.top > kid.bottom
            ? box.top - kid.bottom
            : (kid.top > box.bottom ? kid.top - box.bottom : 0.0);
        if (gap < 30) _nearMiss(h.x, h.y);
      }
    }
  }

  void _nearMiss(double x, double y) {
    nearMisses++;
    final bonus = 3 * coinValue;
    coinsThisRun += bonus;
    _slowmo = 0.22;
    events.add(GameEvent.nearMiss);
    texts.add(FloatText(bonus == 3 ? 'جاخالی! +۳' : (bonus == 6 ? 'جاخالی! +۶' : 'جاخالی! +${bonus}'), kidX + 30,
        floorY - kidY - 120, const Color(0xFFFF5A4E)));
    _burst(x, y, 8, const Color(0xFFFFFFFF), 1);
  }

  void _die(Hazard? h) {
    dying = 0.9;
    shake = 1;
    kidVy = 520;
    kidY = max(kidY, 1);
    flip = 0;
    events.add(GameEvent.hit);
    _burst(kidX, floorY - kidY - 70, 12, const Color(0xFFFFD34D), 2);
    if (h != null && h.isSlipper) {
      h.vx = -180;
      h.vy = -300;
    }
    _say(chaser == Parent.mom ? 'گرفتمت!' : 'حالا شد!', '${_who}_caught', 2);
  }

  // ---------------- Particles ----------------

  void _dust(double x, double y, int n, double dir) {
    for (int i = 0; i < n; i++) {
      final a = pi + rng.nextDouble() * pi; // upward half
      final sp = 40 + rng.nextDouble() * 90;
      particles.add(Particle(0, x + (rng.nextDouble() - 0.5) * 24, y - 2,
          cos(a) * sp - 60, sin(a) * sp * 0.5, 0.35 + rng.nextDouble() * 0.25,
          5 + rng.nextDouble() * 6, const Color(0xFFF6DDB8)));
    }
  }

  void _burst(double x, double y, int n, Color color, int type) {
    for (int i = 0; i < n; i++) {
      final a = rng.nextDouble() * 2 * pi;
      final sp = 80 + rng.nextDouble() * 180;
      particles.add(Particle(type, x, y, cos(a) * sp, sin(a) * sp,
          0.45 + rng.nextDouble() * 0.35, 4 + rng.nextDouble() * 5, color,
          gravity: type == 4 ? 900 : 200, spin: (rng.nextDouble() - 0.5) * 12));
    }
  }

  void _updateParticles(double dt) {
    for (final p in particles) {
      p.life -= dt;
      p.vy += p.gravity * dt;
      p.x += p.vx * dt;
      p.y += p.vy * dt;
      p.rot += p.spin * dt;
      if (p.type == 0 || p.type == 3) {
        p.vx *= 0.94;
        p.vy *= 0.94;
      }
    }
    particles.removeWhere((p) => p.life <= 0);
  }
}

/// Tiny easing helpers (no Flutter dependency in the game rules).
class Curves2 {
  static double easeOut(double t) => 1 - pow(1 - t, 3).toDouble();
}
