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
}

enum ObstacleKind { vase, ball, books, samovar }

/// How Mom throws.
/// low: straight at your legs -> JUMP.  high: at head height -> DON'T jump.
/// bounce: hits the rug and bounces at you -> jump late.  twin: two low ones.
enum ThrowKind { low, high, bounce, twin }

Size obstacleSize(ObstacleKind k) => switch (k) {
      ObstacleKind.vase => const Size(44, 62),
      ObstacleKind.ball => const Size(36, 36),
      ObstacleKind.books => const Size(56, 40),
      ObstacleKind.samovar => const Size(46, 72),
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

  final bool isSlipper;
  final ObstacleKind? kind;
  final ThrowKind? throwKind;
  double x; // center x
  double y; // obstacles: floor y under them; slippers: center y
  double vx;
  double vy;
  double rot = 0;
  double age = 0;
  bool bounced = false;
  bool passed = false;

  /// Ball obstacles hop up and down.
  double get hop =>
      kind == ObstacleKind.ball ? (sin(age * 6.5).abs()) * 46 : 0;

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
  bool get onGround => kidY <= 0.01 && kidVy <= 0;
  double runPhase = 0;
  double squashX = 1, squashY = 1;
  double tilt = 0;
  double blinkTimer = 2;

  // Progress
  double traveled = 0;
  double speed = 270;
  double anger = 0.15; // 0..1 difficulty
  double time = 0;
  int coinsThisRun = 0;
  int nearMisses = 0;
  int get meters => traveled ~/ 40;

  // States
  bool shield = false;
  double invincible = 0;
  double grandmaFlash = 0;
  double calm = 0; // Mom calmed down by grandma
  double dying = 0;
  bool dead = false;
  bool usedContinue = false;
  double shake = 0;
  double _slowmo = 0;

  // Mom
  double windup = 0; // 0..1 while preparing a throw
  double _windupDur = 0.7;
  double release = 0; // 1..0 after throwing
  ThrowKind _nextThrow = ThrowKind.low;
  ThrowKind? get warning => windup > 0 ? _nextThrow : null;
  String shout = '';
  double shoutTimer = 0;
  double get momX => kidX - 150 + anger * 30 + sin(time * 1.3) * 8;

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

  Rect get kidHitbox => Rect.fromLTWH(
      kidX - 12, floorY - kidY - 92, 26, 88);

  void reset() {
    kidY = 0;
    kidVy = 0;
    holding = false;
    _holdTime = 0;
    _buffer = 0;
    squashX = squashY = 1;
    tilt = 0;
    traveled = 0;
    speed = 270;
    anger = 0.15;
    time = 0;
    coinsThisRun = 0;
    nearMisses = 0;
    shield = false;
    invincible = 0;
    grandmaFlash = 0;
    calm = 0;
    dying = 0;
    dead = false;
    usedContinue = false;
    shake = 0;
    _slowmo = 0;
    windup = 0;
    release = 0;
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
    if (onGround) {
      _doJump();
    } else {
      _buffer = bufferTime; // jump as soon as we land
    }
  }

  void releasePress() {
    holding = false;
  }

  void _doJump() {
    kidVy = jumpSpeed;
    kidY = 0.02;
    _holdTime = 0;
    _buffer = 0;
    squashX = 0.78;
    squashY = 1.25;
    events.add(GameEvent.jump);
    _dust(kidX, floorY, 6, -1);
  }

  // ---------------- Power-ups ----------------

  void grandma() {
    for (final h in hazards) {
      _burst(h.x, h.isSlipper ? h.y : h.y - 30, 6, const Color(0xFFFFFFFF), 1);
    }
    hazards.clear();
    windup = 0;
    calm = 2.6;
    _throwTimer = 3.2;
    _obstacleTimer = max(_obstacleTimer, 1.4);
    grandmaFlash = 1.0;
    shout = 'باشه مادر جون...';
    shoutTimer = 1.6;
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
    kidY = 0;
    kidVy = 0;
    tilt = 0;
    invincible = 2.2;
    calm = 1.5;
    _obstacleTimer = 1.4;
    _throwTimer = 2.6;
  }

  // ---------------- Update ----------------

  double _lerp(double a, double b, double t) => a + (b - a) * t;

  void update(double realDt) {
    if (dead || size == Size.zero) return;
    // Slow motion (near miss / death)
    if (_slowmo > 0) _slowmo -= realDt;
    final dt = realDt * (dying > 0 ? 0.35 : (_slowmo > 0 ? 0.5 : 1.0));
    time += dt;
    if (shake > 0) shake = max(0, shake - realDt * 3);

    _updateParticles(dt);

    if (dying > 0) {
      // kid tumbles away
      kidVy -= gravityDown * dt;
      kidY = max(0, kidY + kidVy * dt);
      tilt -= dt * 9;
      dying -= realDt;
      if (dying <= 0) {
        dead = true;
        events.add(GameEvent.death);
      }
      return;
    }

    anger = (0.15 + meters / 1400).clamp(0.0, 1.0);
    speed = _lerp(270, 560, anger);
    traveled += speed * dt;
    runPhase += dt * speed / 19;

    _updateKid(dt);
    _updateMom(dt);
    _spawn(dt);
    _move(dt);
    _collide();
  }

  void _updateKid(double dt) {
    if (_buffer > 0) _buffer -= dt;
    final wasAir = !onGround;

    if (kidVy > 0 && holding && _holdTime < maxHold) {
      _holdTime += dt;
      kidVy -= gravityHold * dt;
    } else if (kidVy > 0) {
      kidVy -= gravityUp * dt;
    } else {
      kidVy -= gravityDown * dt;
    }
    kidY += kidVy * dt;
    if (kidY <= 0) {
      kidY = 0;
      if (wasAir) {
        kidVy = 0;
        squashX = 1.28;
        squashY = 0.76;
        events.add(GameEvent.land);
        _dust(kidX, floorY, 8, 0);
        if (_buffer > 0) _doJump();
      }
      kidVy = max(0, kidVy);
    }

    // springy squash & stretch back to normal
    final k = min(1.0, dt * 14);
    double tx = 1, ty = 1;
    if (!onGround) {
      final st = (kidVy.abs() / 2600).clamp(0.0, 0.18);
      tx = 1 - st;
      ty = 1 + st;
    }
    squashX += (tx - squashX) * k;
    squashY += (ty - squashY) * k;

    final targetTilt =
        onGround ? 0.07 : (-kidVy / 5200).clamp(-0.2, 0.25) + 0.05;
    tilt += (targetTilt - tilt) * min(1.0, dt * 12);

    blinkTimer -= dt;
    if (blinkTimer < -0.12) blinkTimer = 1.5 + rng.nextDouble() * 2.5;

    if (invincible > 0) invincible -= dt;
    if (grandmaFlash > 0) grandmaFlash -= dt;
  }

  bool get blinking => blinkTimer < 0;

  void _updateMom(double dt) {
    if (shoutTimer > 0) shoutTimer -= dt;
    if (release > 0) release = max(0, release - dt * 4);
    if (calm > 0) {
      calm -= dt;
      return;
    }
    if (windup > 0) {
      windup += dt / _windupDur;
      if (windup >= 1) {
        windup = 0;
        _throw(_nextThrow);
        if (_nextThrow == ThrowKind.twin) _secondThrow = 0.8;
      }
      return;
    }
    if (_secondThrow > 0) {
      _secondThrow -= dt;
      if (_secondThrow <= 0) _throw(ThrowKind.low);
    }
    _throwTimer -= dt;
    if (_throwTimer <= 0) _startWindup();
  }

  void _startWindup() {
    // Which throw? Harder kinds unlock as Mom gets angrier.
    final options = <ThrowKind>[ThrowKind.low, ThrowKind.low, ThrowKind.high];
    if (anger > 0.3) options.add(ThrowKind.bounce);
    if (anger > 0.5) options.add(ThrowKind.twin);
    var kind = options[rng.nextInt(options.length)];

    _windupDur = _lerp(0.85, 0.55, anger);
    final arrive = _windupDur + 0.4;
    // A high slipper (stay down) must not meet an obstacle that needs a jump.
    final conflict = hazards.any((h) =>
        !h.isSlipper && ((h.x - kidX) / speed - arrive).abs() < 0.9);
    if (kind == ThrowKind.high && conflict) kind = ThrowKind.low;
    if (kind == ThrowKind.high || kind == ThrowKind.twin) {
      _obstacleTimer = max(_obstacleTimer, arrive + 0.6);
    }
    _nextThrow = kind;
    windup = 0.001;
    shout = momLines[rng.nextInt(momLines.length)];
    shoutTimer = _windupDur + 0.6;
    events.add(GameEvent.windup);
    _throwTimer = _lerp(4.2, 1.9, anger) + rng.nextDouble() * 1.4;
  }

  void _throw(ThrowKind kind) {
    release = 1;
    events.add(GameEvent.whoosh);
    final x0 = momX + 50;
    final v = _lerp(400, 540, anger);
    switch (kind) {
      case ThrowKind.low:
      case ThrowKind.twin:
        hazards.add(Hazard.slipper(ThrowKind.low, x0, floorY - 42, v, 0));
        break;
      case ThrowKind.high:
        hazards.add(Hazard.slipper(ThrowKind.high, x0, floorY - 116, v, 0));
        break;
      case ThrowKind.bounce:
        // lob that lands before the kid and bounces into him
        final y0 = floorY - 150;
        final landX = kidX - 70;
        const t = 0.5;
        final vx = (landX - x0) / t;
        final vy = (floorY - 12 - y0 - 0.5 * 1500 * t * t) / t;
        hazards.add(Hazard.slipper(ThrowKind.bounce, x0, y0, vx, vy));
        break;
    }
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
          coins.add(CoinItem(
              x - 80 + f * 160, floorY - 95 - sin(f * pi) * 80));
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
      final blocked = hazards.any(
          (h) => !h.isSlipper && h.x > x0 - 90 && h.x < x1 + 90);
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
        h.rot += dt * 16;
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
              const Color(0xFF8FB8FF)));
        }
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
      if (dx.abs() < 60 && dy.abs() < 70) {
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

  void _collide() {
    final kid = kidHitbox;
    coins.removeWhere((c) {
      if (kid.inflate(10).contains(Offset(c.x, c.y))) {
        coinsThisRun++;
        events.add(GameEvent.coin);
        _burst(c.x, c.y, 5, const Color(0xFFFFD34D), 1);
        return true;
      }
      return false;
    });

    for (final h in List<Hazard>.from(hazards)) {
      final box = h.hitbox;
      if (invincible <= 0 && box.overlaps(kid)) {
        if (shield) {
          shield = false;
          invincible = 1.0;
          hazards.remove(h);
          shake = 0.5;
          events.add(GameEvent.shieldBreak);
          _burst(kidX, floorY - kidY - 50, 14, const Color(0xFF26C6BE), 4);
          texts.add(FloatText('بالش نجاتت داد!', kidX, floorY - kidY - 130,
              const Color(0xFF26C6BE)));
          continue;
        }
        _die(h);
        return;
      }
      // near miss: a slipper just flew past very close
      if (h.isSlipper && !h.passed && h.x > kidX + 24) {
        h.passed = true;
        final gap = box.top > kid.bottom
            ? box.top - kid.bottom
            : (kid.top > box.bottom ? kid.top - box.bottom : 0.0);
        if (gap < 30) {
          nearMisses++;
          coinsThisRun += 3;
          _slowmo = 0.22;
          events.add(GameEvent.nearMiss);
          texts.add(FloatText('جاخالی! +۳', kidX + 30, floorY - kidY - 120,
              const Color(0xFFFF5A4E)));
          _burst(h.x, h.y, 8, const Color(0xFFFFFFFF), 1);
        }
      }
    }
  }

  void _die(Hazard h) {
    dying = 0.9;
    shake = 1;
    kidVy = 520;
    kidY = max(kidY, 1);
    events.add(GameEvent.hit);
    _burst(kidX, floorY - kidY - 70, 12, const Color(0xFFFFD34D), 2);
    if (h.isSlipper) {
      h.vx = -180;
      h.vy = -300;
    }
    shout = 'گرفتمت!';
    shoutTimer = 2;
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
