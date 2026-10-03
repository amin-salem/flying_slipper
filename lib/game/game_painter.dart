import 'dart:math';

import 'package:flutter/material.dart';

import '../theme.dart';
import 'characters.dart';
import 'house_decor.dart';
import 'room_decor.dart';
import 'world.dart';
import '../services/missions.dart' show HuntToken;

/// Draws one frame of the game.
class GamePainter extends CustomPainter {
  GamePainter(this.w, this.ch, this.frame, {this.token = HuntToken.pistachio});
  final HuntToken token;

  final GameWorld w;
  final Character ch;
  final int frame; // changes every tick so Flutter repaints

  static final Random _shakeRng = Random();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    if (w.shake > 0) {
      final m = w.shake * 9;
      canvas.translate((_shakeRng.nextDouble() - 0.5) * m,
          (_shakeRng.nextDouble() - 0.5) * m);
    }
    // The world is laid out in "game units"; zoom fits it to this screen.
    canvas.scale(w.zoom);
    final vs = w.size;
    _background(canvas, vs);
    _coins(canvas);
    _pickups(canvas);
    _giftBoxes(canvas);
    _letters(canvas);
    _tokens(canvas);
    _obstacles(canvas);
    _parent(canvas);
    _warning(canvas);
    _kid(canvas);
    _slippers(canvas);
    _particles(canvas);
    _texts(canvas);
    _speech(canvas, vs);
    canvas.restore();

    // vignette
    final rect = Offset.zero & size;
    canvas.drawRect(
        rect,
        Paint()
          ..shader = const RadialGradient(
            radius: 0.95,
            colors: [Color(0x00000000), Color(0x00000000), Color(0x40250F2E)],
            stops: [0, 0.6, 1],
          ).createShader(rect));

    if (w.grandmaFlash > 0) {
      final a = (w.grandmaFlash).clamp(0.0, 1.0);
      canvas.drawRect(rect, Paint()..color = Color.fromARGB((a * 150).round(), 255, 255, 255));
    }
  }

  // ---------------------------------------------------------------- scene

  /// Which room the wall/floor at world-distance [units] belongs to.
  Room _room(double units) => units < 0 ? Room.living : roomForMeters(units / 40);

  /// How far in front of the wall the characters run (2.5D depth).
  static const double backDepth = 42;

  /// Floor perspective: the near (bottom) edge is this much wider.
  static const double floorSpread = 1.5;

  void _background(Canvas c, Size size) {
    final floorY = w.floorY;
    final wallBase = floorY - backDepth;
    final winTop = max(wallBase * 0.2, wallBase - 430);
    final winH = min(300.0, wallBase - 110 - winTop);
    final friezeY = max(14.0, winTop - 56);

    // ---- Wall: each slot belongs to a room (scrolls at half speed) ----
    const slotW = 230.0;
    final scroll = w.traveled * 0.5;
    final first = (scroll / slotW).floor();
    final slotH = wallBase - 60 - winTop;
    Room? prev;
    for (int k = first - 1; k * slotW - scroll < size.width + slotW; k++) {
      final x = k * slotW - scroll;
      // the wall moves at half speed: this slot is above the kid when
      // traveled == 2 * (k * slotW - kidX)
      final room = _room((k * slotW - w.kidX) * 2);
      drawWallBase(c, room, Rect.fromLTWH(x, 0, slotW + 0.5, wallBase), friezeY);
      if (room == Room.living) {
        final item = WallItem.values[k.abs() % WallItem.values.length];
        if (item == WallItem.orosi) {
          _orosi(c, Rect.fromLTWH(x + 40, winTop, 150, winH));
        } else {
          drawWallItem(c, item, Rect.fromLTWH(x, winTop, slotW, slotH), w.time);
        }
      } else {
        drawRoomItem(c, room, k.abs(), Rect.fromLTWH(x, winTop, slotW, slotH), w.time);
      }
      if (prev != null && prev != room) {
        drawDoorway(c, x, max(friezeY + 44, wallBase - 260), wallBase);
      }
      prev = room;
    }

    // seasonal garland (Yalda / Nowruz)
    drawSeasonGarland(c, currentSeason(), scroll, size.width, friezeY + 40, w.time);

    // wall lighting: soft light from the upper left, darker near the ceiling
    final wallRect = Rect.fromLTWH(0, 0, size.width, wallBase);
    c.drawRect(
        wallRect,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0x38251530), Color(0x00251530), Color(0x00251530), Color(0x1A251530)],
            stops: [0, 0.3, 0.75, 1],
          ).createShader(wallRect));
    c.drawRect(
        wallRect,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [Color(0x22FFF4D6), Color(0x00FFF4D6), Color(0x14251530)],
          ).createShader(wallRect));

    // skirting board along the bottom of the wall (gives the wall a "foot")
    c.drawRect(Rect.fromLTWH(0, wallBase - 9, size.width, 9),
        Paint()..color = const Color(0xFF8A5634));
    c.drawRect(Rect.fromLTWH(0, wallBase - 9, size.width, 2.5),
        Paint()..color = const Color(0xFFB27A4E));

    // ---- Along the wall: cushions / counters / flower beds ----
    const segW = 600.0;
    final ms = w.traveled * 0.6;
    final firstSeg = (ms / segW).floor();
    for (int k = firstSeg; k * segW - ms < size.width + segW; k++) {
      final x = k * segW - ms;
      drawMidSegment(c, _room((k * segW - w.kidX) / 0.6), x, wallBase, w.time);
    }

    // ---- Floor: a real perspective plane (moves at full speed) ----
    final vp = size.width * 0.5; // vanishing point x
    final hs = size.height - wallBase + 2; // floor height on screen
    final hFlat = hs / floorSpread;
    final k = (1 - 1 / floorSpread) / hFlat;
    // depth (flat units) of the row the characters run on
    final runY = backDepth / (1 + k * backDepth);
    final wc = 1 - k * runY; // perspective factor at the running row
    const tileW = 90.0;
    final fScroll = w.traveled * wc;
    c.save();
    c.translate(vp, wallBase);
    c.transform((Matrix4.identity()..setEntry(3, 1, -k)).storage);
    c.translate(-vp, -wallBase);
    final firstTile = (fScroll / tileW).floor() - 1;
    for (int j = firstTile; j * tileW - fScroll < size.width + tileW; j++) {
      final x = j * tileW - fScroll;
      // the floor under the kid changes exactly when the distance counter
      // reaches the next room
      final units = (j * tileW - vp) / wc + vp - w.kidX;
      drawFloorTile(c, _room(units), x, wallBase, wallBase + hFlat + 4);
    }
    c.restore();

    // floor lighting: dark at the back (near the wall), bright in the
    // middle where the light falls, slightly dark near the camera
    final floorRect = Rect.fromLTWH(0, wallBase, size.width, hs);
    c.drawRect(
        floorRect,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0x55251530), Color(0x00251530), Color(0x00FFF4D6), Color(0x30251530)],
            stops: [0, 0.22, 0.5, 1],
          ).createShader(floorRect));
    c.drawRect(
        floorRect,
        Paint()
          ..shader = RadialGradient(
            center: Alignment((w.kidX / size.width) * 2 - 1, -0.55),
            radius: 0.9,
            colors: const [Color(0x22FFF6DC), Color(0x00FFF6DC)],
          ).createShader(floorRect));

    // contact shadow where the wall meets the floor
    final ao = Rect.fromLTWH(0, wallBase, size.width, 26);
    c.drawRect(
        ao,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0x50000000), Color(0x00000000)],
          ).createShader(ao));
  }

  // ---------------------------------------------------------------- 2.5D helpers

  static final Paint _softShadow = Paint()
    ..color = const Color(0x40000000)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
  static final Paint _contactShadow = Paint()
    ..color = const Color(0x55000000)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);

  /// A soft ground shadow: a wide blurry one plus a tight dark one.
  /// [lift] is how high the thing is above the floor (shadow fades).
  void _groundShadow(Canvas c, double x, double width, {double lift = 0}) {
    final f = (1 - lift / 280).clamp(0.25, 1.0);
    final y = w.floorY + 3;
    c.drawOval(
        Rect.fromCenter(center: Offset(x + 8 * f, y), width: width * 1.15 * f, height: 16 * f),
        _softShadow..color = Color.fromARGB((70 * f).round(), 0, 0, 0));
    if (lift < 30) {
      c.drawOval(Rect.fromCenter(center: Offset(x, y), width: width * 0.7, height: 6),
          _contactShadow);
    }
  }

  /// Draws [paint] then lights it like a 3D object: a highlight from the
  /// upper left and shade on the lower right, only where something was drawn.
  void _lit(Canvas c, Rect layer, Rect body, void Function() paint,
      {double strength = 1}) {
    c.saveLayer(layer, Paint());
    paint();
    final a = (strength * 255).round().clamp(0, 255);
    c.drawRect(
        layer,
        Paint()
          ..blendMode = BlendMode.srcATop
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.fromARGB((0x50 * a) ~/ 255, 255, 250, 235),
              const Color(0x00FFFFFF),
              const Color(0x00000000),
              Color.fromARGB((0x60 * a) ~/ 255, 40, 20, 60),
            ],
            stops: const [0, 0.38, 0.55, 1],
          ).createShader(body));
    // rim light on the right edge (light bouncing off the wall)
    c.drawRect(
        layer,
        Paint()
          ..blendMode = BlendMode.srcATop
          ..shader = LinearGradient(
            begin: Alignment.centerRight,
            end: Alignment.centerLeft,
            colors: [Color.fromARGB((0x30 * a) ~/ 255, 255, 230, 200), const Color(0x00FFFFFF)],
            stops: const [0, 0.18],
          ).createShader(body));
    c.restore();
  }

  void _orosi(Canvas c, Rect r) {
    final arch = RRect.fromRectAndCorners(r,
        topLeft: Radius.circular(r.width / 2),
        topRight: Radius.circular(r.width / 2));
    c.drawRRect(arch.inflate(8), Paint()..color = const Color(0xFF8A5634));
    c.save();
    c.clipRRect(arch);
    const colors = [
      Color(0xFFE53935),
      Color(0xFF2F6BFF),
      Color(0xFFFFC23D),
      Color(0xFF1FA463),
      Color(0xFFBFEFFF),
    ];
    const cell = 25.0;
    int k = 0;
    for (double y = r.top; y < r.bottom; y += cell) {
      for (double x = r.left; x < r.right; x += cell) {
        c.drawRect(Rect.fromLTWH(x, y, cell, cell),
            Paint()..color = colors[(k * 7 + (y ~/ cell)) % colors.length].withAlpha(200));
        k++;
      }
    }
    final lead = Paint()
      ..color = const Color(0xFF5E3820)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    for (double y = r.top; y < r.bottom; y += cell) {
      c.drawLine(Offset(r.left, y), Offset(r.right, y), lead);
    }
    for (double x = r.left; x < r.right; x += cell) {
      c.drawLine(Offset(x, r.top), Offset(x, r.bottom), lead);
    }
    // light glare
    c.drawRect(
        r,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0x55FFFFFF), Color(0x00FFFFFF)],
          ).createShader(r));
    c.restore();
    c.drawRRect(
        arch,
        Paint()
          ..color = const Color(0xFF5E3820)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5);
  }

  // ---------------------------------------------------------------- items

  void _coins(Canvas c) {
    for (final coin in w.coins) {
      final lift = w.floorY - coin.y;
      if (lift < 220) {
        final f = 1 - lift / 220;
        c.drawOval(Rect.fromCenter(center: Offset(coin.x + 4, w.floorY + 3), width: 18 * f + 4, height: 5 * f + 1),
            Paint()..color = Color.fromARGB((60 * f).round(), 0, 0, 0));
      }
      final sq = 0.35 + 0.65 * cos(w.time * 5 + coin.x / 60).abs();
      paintCoin(c, Offset(coin.x, coin.y), 12, sq);
    }
  }

  void _tokens(Canvas c) {
    for (final t in w.tokens) {
      drawHuntToken(c, token, Offset(t.x, t.y + sin(w.time * 4 + t.x / 50) * 4), 13);
    }
  }

  void _letters(Canvas c) {
    for (final l in w.letters) {
      final p = Offset(l.x, l.y + sin(l.age * 3.5) * 6);
      final glow = 0.5 + 0.5 * sin(l.age * 6);
      c.drawCircle(p, 32 + glow * 4,
          Paint()..color = Color.fromARGB((50 + glow * 60).round(), 38, 198, 190));
      final tile = RRect.fromRectAndRadius(Rect.fromCenter(center: p, width: 46, height: 50), const Radius.circular(12));
      c.drawRRect(tile.shift(const Offset(0, 4)), Paint()..color = C.tealEdge);
      c.drawRRect(tile, Paint()..color = C.white);
      c.drawRRect(tile, Paint()
        ..color = C.teal
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3);
      _outlinedText(c, l.letter, p + const Offset(0, -2), 30, C.tealDark, stroke: false);
    }
  }

  void _giftBoxes(Canvas c) {
    for (final b in w.giftBoxes) {
      final p = Offset(b.x, b.y + sin(b.age * 3) * 6);
      drawGiftBox(c, p, 22, b.age);
    }
  }

  void _pickups(Canvas c) {
    for (final pk in w.pickups) {
      final p = Offset(pk.x, pk.y + sin(pk.age * 4) * 8);
      final glow = 0.5 + 0.5 * sin(pk.age * 6);
      c.drawCircle(p, 30 + glow * 4, Paint()..color = Color.fromARGB((60 + glow * 50).round(), 167, 123, 255));
      c.drawCircle(p, 24, Paint()..color = const Color(0xEEFFFFFF));
      c.drawCircle(p, 24, Paint()
        ..color = C.purpleDark
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3);
      drawPowerIcon(c, pk.kind, p, 15);
    }
  }

  void _obstacles(Canvas c) {
    for (final h in w.hazards) {
      if (h.isSlipper) continue;
      final s = obstacleSize(h.kind!);
      if (h.kicked) {
        c.save();
        c.translate(h.x, h.y - s.height / 2);
        c.rotate(h.rot);
        c.translate(-h.x, -(h.y - s.height / 2));
        _obstacle(c, h.kind!, Offset(h.x, h.y), 0);
        c.restore();
        continue;
      }
      _groundShadow(c, h.x, s.width, lift: h.hop * 2);
      final base = Offset(h.x, h.y - h.hop);
      final body = Rect.fromLTWH(base.dx - s.width / 2, base.dy - s.height, s.width, s.height);
      _lit(c, body.inflate(36), body, () => _obstacle(c, h.kind!, base, h.rot));
    }
  }

  void _parent(Canvas c) {
    final feet = Offset(w.parentX, w.floorY + 4);
    const scale = 0.95;
    _groundShadow(c, feet.dx, 90);
    // Dad's arm can reach far toward the kid while whipping
    final reachR = w.whipT > 0 ? max(feet.dx + 60, w.whipStartX + 40) : feet.dx + 60;
    final body = Rect.fromLTRB(feet.dx - 60, feet.dy - 215, reachR, feet.dy);
    final layer = Rect.fromLTRB(feet.dx - 170, feet.dy - 340, max(feet.dx + 190, reachR + 120), feet.dy + 16);
    if (w.shownParent == Parent.mom) {
      _lit(c, layer, body, () => _drawMom(c, feet, scale), strength: 0.9);
      return;
    }
    Offset? reach;
    if (w.whipT > 0) {
      reach = Offset((w.whipStartX - feet.dx) / scale, (w.whipY - feet.dy) / scale);
    }
    _lit(c, layer, body, () => drawDad(c, feet, scale,
        time: w.time,
        windup: w.windup,
        twirl: w.twirl,
        anger: w.anger,
        shouting: w.shoutTimer > 0,
        calm: w.calm > 0,
        reach: reach), strength: 0.9);
    if (w.whipT > 0) {
      _groundShadow(c, (w.whipStartX + w.whipTipX) / 2, (w.whipTipX - w.whipStartX).abs() * 0.8,
          lift: w.floorY - w.whipY);
      drawBeltWhip(c, Offset(w.whipStartX, w.whipY), Offset(w.whipTipX, w.whipY), w.time);
    }
  }

  void _drawMom(Canvas c, Offset feet, double scale) {
    drawMom(c, feet, scale,
        time: w.time,
        windup: w.windup,
        release: w.release,
        anger: w.anger,
        shouting: w.shoutTimer > 0,
        calm: w.calm > 0,
        twirl: w.twirl);
  }

  void _warning(Canvas c) {
    final kind = w.warning;
    if (kind == null) return;
    final stayDown = kind == ThrowKind.high || kind == ThrowKind.whipHigh;
    final y = switch (kind) {
      ThrowKind.high => w.floorY - 116,
      ThrowKind.whipHigh => w.floorY - 112,
      ThrowKind.whipLow => w.floorY - 34,
      ThrowKind.bounce => w.floorY - 20,
      _ => w.floorY - 42,
    };
    final color = stayDown ? C.teal : (kind == ThrowKind.bounce ? C.goldDark : C.red);
    final label = switch (kind) {
      ThrowKind.high => 'نپر!',
      ThrowKind.whipHigh => 'نپر!',
      ThrowKind.bounce => 'صبر کن...',
      ThrowKind.twin => 'دوتا!',
      ThrowKind.low => 'بپر!',
      ThrowKind.whipLow => 'بپر!',
      ThrowKind.remote => 'بپر!',
    };
    final x = w.kidX - 70;
    final pulse = 1 + 0.18 * sin(w.time * 22);
    // dotted path from Mom to the kid
    final dash = Paint()
      ..color = color.withAlpha(150)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    for (double dx = w.parentX + 90; dx < w.kidX - 20; dx += 14) {
      c.drawLine(Offset(dx, y), Offset(dx + 5, y), dash);
    }
    final p = Offset(x, y - 42);
    c.drawCircle(p, 19 * pulse, Paint()..color = const Color(0x55FFFFFF));
    c.drawCircle(p, 15 * pulse, Paint()..color = color);
    c.drawCircle(p, 15 * pulse, Paint()
      ..color = C.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3);
    _outlinedText(c, stayDown ? '↓' : '!', p, 20, C.white, stroke: false);
    _outlinedText(c, label, p + const Offset(0, 30), 15, color);
  }

  void _kid(Canvas c) {
    final feet = Offset(w.kidX, w.floorY - w.kidY);
    // ground shadow shrinks and fades while airborne
    _groundShadow(c, w.kidX, 52, lift: w.kidY);

    if (w.magnetT > 0) {
      final pulse = (w.time * 2) % 1.0;
      c.drawCircle(feet + const Offset(0, -50), 50 + pulse * 40,
          Paint()
            ..color = Color.fromARGB((120 * (1 - pulse)).round(), 255, 90, 78)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3);
    }
    if (w.ballooning) {
      // big red balloon on a string
      final hand = feet + const Offset(10, -60);
      final b = feet + Offset(18 + sin(w.time * 3) * 4, -150);
      c.drawLine(hand, b + const Offset(0, 34), Paint()
        ..color = C.ink
        ..strokeWidth = 2);
      c.drawOval(Rect.fromCenter(center: b, width: 58, height: 68), Paint()..color = const Color(0xFFE53935));
      c.drawOval(Rect.fromCenter(center: b + const Offset(-12, -14), width: 14, height: 20),
          Paint()..color = const Color(0x66FFFFFF));
      c.drawOval(Rect.fromCenter(center: b, width: 58, height: 68), Paint()
        ..color = C.ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5);
    }
    final flicker = w.invincible > 0 && !w.ballooning && (w.time * 14).floor().isEven;
    if (w.skating && w.onGround && !flicker) {
      // skateboard under the feet
      final deck = RRect.fromRectAndRadius(
          Rect.fromCenter(center: feet + const Offset(2, 2), width: 64, height: 9),
          const Radius.circular(5));
      c.drawRRect(deck, Paint()..color = const Color(0xFFFFB531));
      c.drawRRect(deck, Paint()
        ..color = C.ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2);
      for (final dx in [-20.0, 22.0]) {
        c.drawCircle(feet + Offset(dx, 10), 5, Paint()..color = const Color(0xFF3A3A44));
        c.drawCircle(feet + Offset(dx, 10), 2, Paint()..color = C.white);
      }
    }
    if (!flicker) {
      final kf = feet + (w.skating && w.onGround ? const Offset(0, -10) : Offset.zero);
      _lit(c, Rect.fromLTWH(kf.dx - 110, kf.dy - 220, 220, 240),
          Rect.fromLTWH(kf.dx - 40, kf.dy - 140, 80, 140), () => drawCharacter(c, ch, kf,
          GameWorld.kidScale,
          phase: w.skating && w.onGround ? 0.25 : w.runPhase,
          airborne: !w.onGround || w.ballooning,
          squashX: w.squashX,
          squashY: w.squashY,
          tilt: w.tilt,
          mood: w.dying > 0 ? Mood.hurt : null,
          time: w.time,
          blink: w.blinking,
          gliding: w.gliding,
          spin: w.flip > 0 ? -(1 - w.flip) * 2 * pi : 0.0));
    }
    if (w.ability.kickCooldown > 0 && w.kickReady >= 1 && w.dying <= 0) {
      // football ready: a little glowing ball at the kid's feet
      final bp = feet + const Offset(20, -9);
      c.drawCircle(bp, 13, Paint()..color = Color.fromARGB((90 + 60 * sin(w.time * 8)).round(), 255, 255, 255));
      c.drawCircle(bp, 8, Paint()..color = C.white);
      c.drawCircle(bp, 8, Paint()
        ..color = C.ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2);
      c.drawCircle(bp, 3, Paint()..color = C.ink);
    }
    if (w.shield) {
      final center = feet + const Offset(2, -52);
      final r = Rect.fromCircle(center: center, radius: 62);
      c.drawCircle(
          center,
          62,
          Paint()
            ..shader = const RadialGradient(
              colors: [Color(0x0026C6BE), Color(0x3326C6BE), Color(0x9926C6BE)],
              stops: [0, 0.7, 1],
            ).createShader(r));
      c.drawCircle(center, 62, Paint()
        ..color = const Color(0xCCFFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5);
      c.drawArc(Rect.fromCircle(center: center, radius: 50), pi * 1.15, 0.6, false,
          Paint()
            ..color = const Color(0xAAFFFFFF)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 5
            ..strokeCap = StrokeCap.round);
    }
  }

  void _slippers(Canvas c) {
    for (final h in w.hazards) {
      if (!h.isSlipper) continue;
      final lift = w.floorY - h.y;
      if (lift < 260) {
        final f = 1 - lift / 260;
        c.drawOval(Rect.fromCenter(center: Offset(h.x + 6, w.floorY + 3), width: 44 * f + 6, height: 8 * f + 2),
            Paint()..color = Color.fromARGB((70 * f).round(), 0, 0, 0));
      }
      if (h.isRemote) {
        drawRemote(c, Offset(h.x, h.y), 46, h.rot);
      } else {
        drawSlipper(c, Offset(h.x, h.y), 50, h.rot);
      }
    }
  }

  void _particles(Canvas c) {
    for (final p in w.particles) {
      final t = (p.life / p.maxLife).clamp(0.0, 1.0);
      final a = (255 * t).round();
      switch (p.type) {
        case 0: // dust
          c.drawCircle(Offset(p.x, p.y), p.size * (1.6 - t * 0.6),
              Paint()..color = p.color.withAlpha((a * 0.8).round()));
          break;
        case 1: // sparkle
          _sparkle(c, Offset(p.x, p.y), p.size * (0.6 + t), p.color.withAlpha(a));
          break;
        case 2: // star
          c.save();
          c.translate(p.x, p.y);
          c.rotate(p.rot);
          final star = _star5(p.size * 1.6);
          c.drawPath(star, Paint()..color = p.color.withAlpha(a));
          c.drawPath(star, Paint()
            ..color = C.ink.withAlpha(a)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5);
          c.restore();
          break;
        case 3: // slipper trail
          c.drawOval(
              Rect.fromCenter(center: Offset(p.x, p.y), width: p.size * 2.4 * t + 4, height: p.size * t + 2),
              Paint()..color = p.color.withAlpha((a * 0.5).round()));
          break;
        default: // shard
          c.save();
          c.translate(p.x, p.y);
          c.rotate(p.rot);
          c.drawRect(Rect.fromCenter(center: Offset.zero, width: p.size * 1.6, height: p.size * 0.8),
              Paint()..color = p.color.withAlpha(a));
          c.restore();
      }
    }
  }

  void _texts(Canvas c) {
    for (final t in w.texts) {
      final pop = t.life > 0.95 ? 1 + (t.life - 0.95) * 4 : 1.0;
      _outlinedText(c, t.text, Offset(t.x, t.y), t.size * pop, t.color,
          alpha: (t.life.clamp(0.0, 0.4) / 0.4));
    }
  }

  void _speech(Canvas c, Size size) {
    if (w.shoutTimer <= 0 || w.shout.isEmpty) return;
    final tp = TextPainter(
      text: TextSpan(
          text: w.shout,
          style: const TextStyle(
              fontFamily: 'Vazirmatn', fontSize: 15, fontWeight: FontWeight.w900, color: C.ink)),
      textDirection: TextDirection.rtl,
      maxLines: 1,
    )..layout(maxWidth: size.width * 0.6);
    final anchor = Offset(max(8.0, w.parentX + 40),
        w.floorY - (w.shownParent == Parent.dad ? 225 : 190));
    final r = Rect.fromLTWH(anchor.dx, anchor.dy - tp.height - 16, tp.width + 26, tp.height + 16);
    final pop = (w.shoutTimer > 1.4) ? 0.9 : 1.0;
    c.save();
    c.translate(r.left, r.bottom);
    c.scale(pop);
    c.translate(-r.left, -r.bottom);
    final bubble = RRect.fromRectAndRadius(r, const Radius.circular(16));
    final tail = Path()
      ..moveTo(r.left + 14, r.bottom - 2)
      ..lineTo(r.left + 6, r.bottom + 14)
      ..lineTo(r.left + 28, r.bottom - 2)
      ..close();
    c.drawRRect(bubble.shift(const Offset(0, 4)), Paint()..color = const Color(0x33000000));
    c.drawRRect(bubble, Paint()..color = C.white);
    c.drawPath(tail, Paint()..color = C.white);
    c.drawRRect(bubble, Paint()
      ..color = C.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5);
    tp.paint(c, Offset(r.left + 13, r.top + 8));
    c.restore();
  }

  // ---------------------------------------------------------------- helpers

  void _outlinedText(Canvas c, String text, Offset center, double size, Color fill,
      {bool stroke = true, double alpha = 1}) {
    final a = (alpha * 255).round();
    final base = TextStyle(fontFamily: 'Vazirmatn', fontSize: size, fontWeight: FontWeight.w900);
    if (stroke) {
      final s = TextPainter(
        text: TextSpan(
            text: text,
            style: base.copyWith(
                foreground: Paint()
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = size * 0.22
                  ..strokeJoin = StrokeJoin.round
                  ..color = C.white.withAlpha(a))),
        textDirection: TextDirection.rtl,
      )..layout();
      s.paint(c, center - Offset(s.width / 2, s.height / 2));
    }
    final f = TextPainter(
      text: TextSpan(text: text, style: base.copyWith(color: fill.withAlpha(a))),
      textDirection: TextDirection.rtl,
    )..layout();
    f.paint(c, center - Offset(f.width / 2, f.height / 2));
  }

  void _sparkle(Canvas c, Offset p, double r, Color color) {
    final path = Path()
      ..moveTo(p.dx, p.dy - r)
      ..quadraticBezierTo(p.dx, p.dy, p.dx + r, p.dy)
      ..quadraticBezierTo(p.dx, p.dy, p.dx, p.dy + r)
      ..quadraticBezierTo(p.dx, p.dy, p.dx - r, p.dy)
      ..quadraticBezierTo(p.dx, p.dy, p.dx, p.dy - r)
      ..close();
    c.drawPath(path, Paint()..color = color);
  }

  Path _star5(double r) {
    final path = Path();
    for (int k = 0; k < 10; k++) {
      final a = -pi / 2 + k * pi / 5;
      final rr = k.isEven ? r : r * 0.45;
      final pt = Offset(cos(a) * rr, sin(a) * rr);
      if (k == 0) {
        path.moveTo(pt.dx, pt.dy);
      } else {
        path.lineTo(pt.dx, pt.dy);
      }
    }
    return path..close();
  }

  void _obstacle(Canvas c, ObstacleKind k, Offset base, double spin) {
    final s = obstacleSize(k);
    final r = Rect.fromLTWH(base.dx - s.width / 2, base.dy - s.height, s.width, s.height);
    final outline = Paint()
      ..color = C.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeJoin = StrokeJoin.round;
    switch (k) {
      case ObstacleKind.vase:
        final p = Path()
          ..moveTo(r.left + 13, r.top)
          ..lineTo(r.right - 13, r.top)
          ..lineTo(r.right - 14, r.top + 8)
          ..quadraticBezierTo(r.right + 6, r.top + 26, r.right - 4, r.bottom - 8)
          ..quadraticBezierTo(r.center.dx, r.bottom + 4, r.left + 4, r.bottom - 8)
          ..quadraticBezierTo(r.left - 6, r.top + 26, r.left + 14, r.top + 8)
          ..close();
        c.drawPath(p, Paint()..color = const Color(0xFF2F6BFF));
        c.save();
        c.clipPath(p);
        c.drawRect(Rect.fromLTWH(r.left - 6, r.top + 24, r.width + 12, 14), Paint()..color = C.white);
        for (double x = r.left; x < r.right; x += 10) {
          c.drawCircle(Offset(x + 5, r.top + 31), 3, Paint()..color = const Color(0xFF2F6BFF));
        }
        c.drawRect(Rect.fromLTWH(r.left, r.top, 10, r.height), Paint()..color = const Color(0x33FFFFFF));
        c.restore();
        c.drawPath(p, outline);
        // flowers sticking out
        for (int i = -1; i <= 1; i++) {
          c.drawLine(Offset(r.center.dx + i * 4, r.top), Offset(r.center.dx + i * 10, r.top - 14),
              Paint()
                ..color = const Color(0xFF2E9B4E)
                ..strokeWidth = 2.5);
          c.drawCircle(Offset(r.center.dx + i * 10, r.top - 16), 5,
              Paint()..color = i == 0 ? C.red : C.gold);
        }
        break;
      case ObstacleKind.ball:
        final center = r.center;
        final rad = s.width / 2;
        c.save();
        c.translate(center.dx, center.dy);
        c.rotate(spin);
        const cols = [Color(0xFFFF5A4E), Color(0xFFFFFFFF), Color(0xFF2F6BFF), Color(0xFFFFD34D)];
        for (int i = 0; i < 4; i++) {
          c.drawArc(Rect.fromCircle(center: Offset.zero, radius: rad), i * pi / 2, pi / 2, true,
              Paint()..color = cols[i]);
        }
        c.restore();
        c.drawCircle(center + Offset(-rad * 0.35, -rad * 0.35), rad * 0.25, Paint()..color = const Color(0x88FFFFFF));
        c.drawCircle(center, rad, outline);
        break;
      case ObstacleKind.books:
        const cols = [Color(0xFFE53935), Color(0xFFFFC23D), Color(0xFF1FA463)];
        for (int i = 0; i < 3; i++) {
          final br = RRect.fromRectAndRadius(
              Rect.fromLTWH(r.left + (i == 1 ? 6 : (i == 2 ? 2 : 0)), r.top + i * 13.3, s.width - 6, 13.3),
              const Radius.circular(2));
          c.drawRRect(br, Paint()..color = cols[2 - i]);
          c.drawRect(Rect.fromLTWH(br.left + br.width - 10, br.top + 3, 8, br.height - 6),
              Paint()..color = const Color(0xFFFFF7EA));
          c.drawRRect(br, outline);
        }
        break;
      case ObstacleKind.samovar:
        // brass samovar with a teapot on top
        final body = Path()
          ..moveTo(r.left + 6, r.bottom - 8)
          ..lineTo(r.left + 2, r.top + 30)
          ..quadraticBezierTo(r.center.dx, r.top + 18, r.right - 2, r.top + 30)
          ..lineTo(r.right - 6, r.bottom - 8)
          ..close();
        final brass = Paint()
          ..shader = const LinearGradient(colors: [Color(0xFFFFE08A), Color(0xFFE0A531), Color(0xFFB57412)])
              .createShader(r);
        c.drawPath(body, brass);
        c.drawPath(body, outline);
        final foot = Rect.fromLTWH(r.left + 8, r.bottom - 10, s.width - 16, 10);
        c.drawRect(foot, brass);
        c.drawRect(foot, outline);
        // tap
        c.drawLine(Offset(r.right - 4, r.bottom - 26), Offset(r.right + 6, r.bottom - 22),
            Paint()
              ..color = C.ink
              ..strokeWidth = 4
              ..strokeCap = StrokeCap.round);
        // teapot
        final pot = Rect.fromCenter(center: Offset(r.center.dx, r.top + 14), width: 26, height: 18);
        c.drawOval(pot, Paint()..color = C.white);
        c.drawOval(pot.deflate(5), Paint()..color = const Color(0xFF2F6BFF));
        c.drawOval(pot, outline);
        // steam
        for (int i = 0; i < 2; i++) {
          final tt = (w.time * 1.2 + i * 0.5) % 1.0;
          c.drawCircle(Offset(r.center.dx + i * 6 - 3, r.top - tt * 22), 3 + tt * 4,
              Paint()..color = Color.fromARGB((160 * (1 - tt)).round(), 255, 255, 255));
        }
        break;
      case ObstacleKind.teaTray:
        // silver tray with tulip tea glasses and sugar cubes
        final tray = Rect.fromLTWH(r.left, r.bottom - 8, r.width, 8);
        c.drawOval(tray, Paint()..color = const Color(0xFFD9DDE6));
        c.drawOval(tray, outline);
        for (int i = 0; i < 3; i++) {
          final x = r.left + 14 + i * 19.0;
          final glass = Path()
            ..moveTo(x - 6, r.top)
            ..quadraticBezierTo(x - 2, r.top + 10, x - 5, r.bottom - 6)
            ..lineTo(x + 5, r.bottom - 6)
            ..quadraticBezierTo(x + 2, r.top + 10, x + 6, r.top)
            ..close();
          c.drawPath(glass, Paint()..color = const Color(0xDDB84A1E));
          c.drawPath(glass, Paint()
            ..color = C.ink
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6);
          c.drawLine(Offset(x - 6, r.top + 2), Offset(x + 6, r.top + 2),
              Paint()
                ..color = C.gold
                ..strokeWidth = 2);
        }
        c.drawRect(Rect.fromLTWH(r.right - 12, r.bottom - 15, 7, 7), Paint()..color = C.white);
        break;
      case ObstacleKind.cat:
        // sleeping cat curled up on the rug; ears twitch
        final catBody = Rect.fromLTWH(r.left + 4, r.top + 8, r.width - 8, r.height - 8);
        c.drawOval(catBody, Paint()..color = const Color(0xFFF2A65A));
        // stripes
        for (int i = 0; i < 3; i++) {
          c.drawArc(Rect.fromCenter(center: catBody.center + Offset(-8.0 + i * 9, 0), width: 10, height: catBody.height * 0.8),
              pi * 1.2, pi * 0.6, false,
              Paint()
                ..color = const Color(0xFFC8742A)
                ..style = PaintingStyle.stroke
                ..strokeWidth = 3);
        }
        c.drawOval(catBody, outline);
        // tail
        c.drawArc(Rect.fromCenter(center: Offset(catBody.left + 6, catBody.bottom - 6), width: 26, height: 16),
            pi * 0.5, pi, false,
            Paint()
              ..color = const Color(0xFFF2A65A)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 6
              ..strokeCap = StrokeCap.round);
        // head
        final catHead = Offset(catBody.right - 10, catBody.top + 10);
        final twitch = sin(w.time * 3).abs() > 0.95 ? -3.0 : 0.0;
        for (final dx in [-8.0, 6.0]) {
          final ear = Path()
            ..moveTo(catHead.dx + dx - 4, catHead.dy - 8)
            ..lineTo(catHead.dx + dx + 1, catHead.dy - 20 + twitch)
            ..lineTo(catHead.dx + dx + 6, catHead.dy - 8)
            ..close();
          c.drawPath(ear, Paint()..color = const Color(0xFFF2A65A));
          c.drawPath(ear, outline);
        }
        c.drawCircle(catHead, 12, Paint()..color = const Color(0xFFF2A65A));
        c.drawCircle(catHead, 12, outline);
        final eye = Paint()
          ..color = C.ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8;
        c.drawArc(Rect.fromCenter(center: catHead + const Offset(-5, 0), width: 6, height: 4), 0, pi, false, eye);
        c.drawArc(Rect.fromCenter(center: catHead + const Offset(5, 0), width: 6, height: 4), 0, pi, false, eye);
        c.drawCircle(catHead + const Offset(0, 4), 1.6, Paint()..color = const Color(0xFFFF7A9A));
        // zzz
        final zt = (w.time * 0.7) % 1.0;
        _outlinedText(c, 'z', catHead + Offset(10 + zt * 8, -22 - zt * 14), 12, C.inkSoft,
            alpha: 1 - zt);
        break;
      case ObstacleKind.geranium:
        // Mom's precious geranium pot (شمعدونی)
        final flowerPot = Path()
          ..moveTo(r.left + 6, r.bottom - 26)
          ..lineTo(r.right - 6, r.bottom - 26)
          ..lineTo(r.right - 10, r.bottom)
          ..lineTo(r.left + 10, r.bottom)
          ..close();
        c.drawPath(flowerPot, Paint()..color = const Color(0xFFC8693A));
        c.drawPath(flowerPot, outline);
        c.drawRect(Rect.fromLTWH(r.left + 3, r.bottom - 30, r.width - 6, 6),
            Paint()..color = const Color(0xFFA9532B));
        final leaf = Paint()..color = const Color(0xFF3FAE4A);
        for (int i = 0; i < 4; i++) {
          c.drawCircle(Offset(r.left + 10 + i * 8.0, r.bottom - 34 - (i.isOdd ? 4 : 0)), 7, leaf);
        }
        for (final f in [Offset(r.left + 12, r.top + 12), Offset(r.right - 12, r.top + 8), Offset(r.center.dx, r.top + 2)]) {
          for (int k = 0; k < 5; k++) {
            final a = k * 2 * pi / 5;
            c.drawCircle(f + Offset(cos(a) * 4, sin(a) * 4), 3.6, Paint()..color = const Color(0xFFE53935));
          }
          c.drawCircle(f, 2, Paint()..color = C.gold);
        }
        break;
    }
  }

  @override
  bool shouldRepaint(covariant GamePainter old) => true;
}


/// Icon for an in-run power-up (used in the game and the HUD/shop).
void drawPowerIcon(Canvas c, PowerKind k, Offset p, double r) {
  final ink = Paint()
    ..color = C.ink
    ..style = PaintingStyle.stroke
    ..strokeWidth = r * 0.14
    ..strokeCap = StrokeCap.round;
  switch (k) {
    case PowerKind.magnet:
      final u = Path()
        ..moveTo(p.dx - r * 0.6, p.dy - r * 0.7)
        ..lineTo(p.dx - r * 0.6, p.dy + r * 0.1)
        ..arcToPoint(Offset(p.dx + r * 0.6, p.dy + r * 0.1), radius: Radius.circular(r * 0.6), clockwise: false)
        ..lineTo(p.dx + r * 0.6, p.dy - r * 0.7);
      c.drawPath(u, Paint()
        ..color = const Color(0xFFE53935)
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.42);
      for (final dx in [-0.6, 0.6]) {
        c.drawRect(Rect.fromCenter(center: Offset(p.dx + dx * r, p.dy - r * 0.62), width: r * 0.44, height: r * 0.3),
            Paint()..color = const Color(0xFFD5D9E2));
      }
    case PowerKind.doubleCoins:
      paintCoin(c, p, r * 0.85, 1);
      final tp = TextPainter(
        text: TextSpan(
            text: '×۲',
            style: TextStyle(
                fontFamily: 'Vazirmatn', fontSize: r * 0.9, fontWeight: FontWeight.w900, color: C.redDark)),
        textDirection: TextDirection.rtl,
      )..layout();
      tp.paint(c, p - Offset(tp.width / 2, tp.height / 2));
    case PowerKind.skate:
      final deck = RRect.fromRectAndRadius(
          Rect.fromCenter(center: p + Offset(0, -r * 0.1), width: r * 1.9, height: r * 0.36), Radius.circular(r * 0.2));
      c.drawRRect(deck, Paint()..color = const Color(0xFFFFB531));
      c.drawRRect(deck, ink);
      for (final dx in [-0.55, 0.55]) {
        c.drawCircle(p + Offset(dx * r, r * 0.35), r * 0.22, Paint()..color = const Color(0xFF3A3A44));
      }
    case PowerKind.balloon:
      final b = p + Offset(0, -r * 0.2);
      c.drawLine(b + Offset(0, r * 0.6), p + Offset(r * 0.1, r), ink);
      c.drawOval(Rect.fromCenter(center: b, width: r * 1.2, height: r * 1.4), Paint()..color = const Color(0xFFE53935));
      c.drawOval(Rect.fromCenter(center: b + Offset(-r * 0.2, -r * 0.25), width: r * 0.3, height: r * 0.4),
          Paint()..color = const Color(0x66FFFFFF));
  }
}


/// Mystery gift box with a "?" (game, game-over card, home).
void drawGiftBox(Canvas c, Offset p, double r, double time) {
  final wobble = sin(time * 5) * 0.08;
  c.save();
  c.translate(p.dx, p.dy);
  c.rotate(wobble);
  final glow = 0.5 + 0.5 * sin(time * 6);
  c.drawCircle(Offset.zero, r * 1.5, Paint()..color = Color.fromARGB((50 + glow * 60).round(), 255, 211, 77));
  final box = Rect.fromCenter(center: Offset(0, r * 0.15), width: r * 1.8, height: r * 1.5);
  c.drawRect(box, Paint()..color = const Color(0xFF8E5BD6));
  final lid = Rect.fromCenter(center: Offset(0, -r * 0.6), width: r * 2.0, height: r * 0.45);
  c.drawRect(lid, Paint()..color = const Color(0xFFA77BFF));
  final ribbon = Paint()..color = C.gold;
  c.drawRect(Rect.fromCenter(center: Offset(0, r * 0.05), width: r * 0.35, height: r * 1.8), ribbon);
  c.drawOval(Rect.fromCenter(center: Offset(-r * 0.35, -r * 0.95), width: r * 0.7, height: r * 0.45), ribbon);
  c.drawOval(Rect.fromCenter(center: Offset(r * 0.35, -r * 0.95), width: r * 0.7, height: r * 0.45), ribbon);
  final o = Paint()
    ..color = C.ink
    ..style = PaintingStyle.stroke
    ..strokeWidth = r * 0.1;
  c.drawRect(box, o);
  c.drawRect(lid, o);
  final tp = TextPainter(
    text: TextSpan(
        text: '؟',
        style: TextStyle(fontFamily: 'Vazirmatn', fontSize: r * 1.0, fontWeight: FontWeight.w900, color: C.white)),
    textDirection: TextDirection.rtl,
  )..layout();
  tp.paint(c, Offset(-tp.width / 2 - r * 0.45, r * 0.15 - tp.height / 2));
  c.restore();
}


/// The weekly hunt item: pistachio, saffron flower or nabat (rock candy).
void drawHuntToken(Canvas c, HuntToken t, Offset p, double r) {
  final ink = Paint()
    ..color = C.ink
    ..style = PaintingStyle.stroke
    ..strokeWidth = r * 0.12;
  switch (t) {
    case HuntToken.pistachio:
      final shell = Rect.fromCenter(center: p, width: r * 1.7, height: r * 1.3);
      c.drawOval(shell, Paint()..color = const Color(0xFFE9D5A8));
      c.drawOval(Rect.fromCenter(center: p + Offset(0, -r * 0.05), width: r * 0.9, height: r * 0.8),
          Paint()..color = const Color(0xFF8BC34A));
      c.drawOval(shell, ink);
    case HuntToken.saffron:
      for (int k = 0; k < 6; k++) {
        final a = k * pi / 3;
        c.drawOval(
            Rect.fromCenter(center: p + Offset(cos(a), sin(a)) * r * 0.55, width: r * 0.9, height: r * 0.6),
            Paint()..color = const Color(0xFF9C6ADE));
      }
      for (int k = -1; k <= 1; k++) {
        c.drawLine(p, p + Offset(k * r * 0.35, -r * 0.8), Paint()
          ..color = const Color(0xFFE53935)
          ..strokeWidth = r * 0.16
          ..strokeCap = StrokeCap.round);
      }
      c.drawCircle(p, r * 0.22, Paint()..color = C.gold);
    case HuntToken.nabat:
      final crystal = Path()
        ..moveTo(p.dx, p.dy - r)
        ..lineTo(p.dx + r * 0.75, p.dy - r * 0.2)
        ..lineTo(p.dx + r * 0.45, p.dy + r * 0.9)
        ..lineTo(p.dx - r * 0.45, p.dy + r * 0.9)
        ..lineTo(p.dx - r * 0.75, p.dy - r * 0.2)
        ..close();
      c.drawPath(crystal, Paint()..color = const Color(0xFFFFC93C));
      c.drawLine(p + Offset(-r * 0.2, -r * 0.5), p + Offset(r * 0.1, r * 0.4),
          Paint()
            ..color = const Color(0x99FFFFFF)
            ..strokeWidth = r * 0.18);
      c.drawPath(crystal, ink);
  }
}
