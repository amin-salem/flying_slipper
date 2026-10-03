import 'dart:math';

import 'package:flutter/material.dart';

import '../theme.dart';
import 'characters.dart';
import 'world.dart';

/// Draws one frame of the game.
class GamePainter extends CustomPainter {
  GamePainter(this.w, this.ch, this.frame);

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
    _obstacles(canvas);
    _mom(canvas);
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

  void _background(Canvas c, Size size) {
    final floorY = w.floorY;
    final wallRect = Rect.fromLTWH(0, 0, size.width, floorY);
    c.drawRect(
        wallRect,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFF3DD), C.wall, C.wallShade],
            stops: [0, 0.6, 1],
          ).createShader(wallRect));

    // Tile frieze near the ceiling
    final winTop = max(floorY * 0.2, floorY - 430);
    final winH = min(300.0, floorY - 110 - winTop);
    final friezeY = max(14.0, winTop - 56);
    c.drawRect(Rect.fromLTWH(0, friezeY, size.width, 34), Paint()..color = const Color(0xFF1C8C9E));
    c.drawRect(Rect.fromLTWH(0, friezeY - 4, size.width, 4), Paint()..color = C.rugGold);
    c.drawRect(Rect.fromLTWH(0, friezeY + 34, size.width, 4), Paint()..color = C.rugGold);
    final fs = (w.traveled * 0.2) % 40;
    final star = Paint()..color = const Color(0xFFFFF3DD);
    final dot = Paint()..color = const Color(0xFF0E5F70);
    for (double x = -fs; x < size.width + 40; x += 40) {
      c.drawPath(starPath(Offset(x, friezeY + 17), 11), star);
      c.drawCircle(Offset(x, friezeY + 17), 3.5, dot);
      c.drawCircle(Offset(x + 20, friezeY + 17), 2.5, star);
    }

    // Orosi windows (colourful stained glass) – far layer
    final winScroll = (w.traveled * 0.35) % 520;
    for (double x = 40 - winScroll; x < size.width + 300; x += 520) {
      _orosi(c, Rect.fromLTWH(x, winTop, 150, winH));
      _frame(c, Offset(x + 300, winTop + 40));
    }

    // Cushions (poshti) along the wall – mid layer
    final cushionY = floorY - 46;
    c.drawRect(Rect.fromLTWH(0, floorY - 10, size.width, 10),
        Paint()..color = const Color(0xFFE2BE8C));
    final cs = (w.traveled * 0.6) % 600;
    for (double x = -cs; x < size.width + 600; x += 600) {
      for (int i = 0; i < 4; i++) {
        _cushion(c, Rect.fromLTWH(x + i * 62, cushionY, 58, 40),
            i.isEven ? C.rug : C.rugNavy);
      }
      _plant(c, Offset(x + 330, floorY - 10));
    }

    // Persian rug floor
    final rug = Rect.fromLTRB(0, floorY, size.width, size.height);
    c.drawRect(rug, Paint()..color = C.rug);
    c.drawRect(Rect.fromLTWH(0, floorY, size.width, 14), Paint()..color = C.rugNavy);
    c.drawRect(Rect.fromLTWH(0, floorY + 14, size.width, 5), Paint()..color = C.rugGold);
    final rs = w.traveled % 90;
    final gold = Paint()..color = C.rugGold;
    final navy = Paint()..color = C.rugNavy;
    final dark = Paint()..color = C.rugDark;
    final cream = Paint()..color = const Color(0xFFF7E3C0);
    for (double x = -rs; x < size.width + 90; x += 90) {
      // little triangles on the border
      c.drawPath(
          Path()
            ..moveTo(x, floorY + 14)
            ..lineTo(x + 8, floorY + 4)
            ..lineTo(x + 16, floorY + 14)
            ..close(),
          gold);
      // medallions
      final cy = floorY + (size.height - floorY) * 0.45;
      final d = Path()
        ..moveTo(x + 45, cy - 30)
        ..lineTo(x + 75, cy)
        ..lineTo(x + 45, cy + 30)
        ..lineTo(x + 15, cy)
        ..close();
      c.drawPath(d, navy);
      c.drawPath(starPath(Offset(x + 45, cy), 16), dark);
      c.drawPath(starPath(Offset(x + 45, cy), 8), gold);
      c.drawCircle(Offset(x, cy - 34), 4, cream);
      c.drawCircle(Offset(x, cy + 34), 4, cream);
    }
    // soft shadow where wall meets floor
    c.drawRect(
        Rect.fromLTWH(0, floorY, size.width, 30),
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0x40000000), Color(0x00000000)],
          ).createShader(Rect.fromLTWH(0, floorY, size.width, 30)));
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

  void _frame(Canvas c, Offset at) {
    final r = Rect.fromLTWH(at.dx, at.dy, 70, 86);
    c.drawRRect(RRect.fromRectAndRadius(r.inflate(6), const Radius.circular(6)),
        Paint()..color = C.goldDark);
    c.drawRect(r, Paint()..color = const Color(0xFFFFF7EA));
    // tiny family portrait: two smiling heads
    final skin = Paint()..color = C.skin;
    c.drawCircle(r.center + const Offset(-14, -4), 12, skin);
    c.drawCircle(r.center + const Offset(14, -2), 11, skin);
    c.drawCircle(r.center + const Offset(-14, -10), 12, Paint()..color = const Color(0xFFFF5C8A));
    c.drawCircle(r.center + const Offset(14, -9), 9, Paint()..color = C.ink);
    c.drawRect(Rect.fromLTWH(r.left + 6, r.bottom - 22, r.width - 12, 16),
        Paint()..color = const Color(0xFF8E5BD6));
  }

  void _cushion(Canvas c, Rect r, Color color) {
    final rr = RRect.fromRectAndRadius(r, const Radius.circular(12));
    c.drawRRect(rr.shift(const Offset(0, 4)), Paint()..color = const Color(0x33000000));
    c.drawRRect(rr, Paint()..color = color);
    c.drawRRect(rr.deflate(6), Paint()
      ..color = C.rugGold
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5);
    c.drawPath(starPath(r.center, 8), Paint()..color = C.rugGold);
  }

  void _plant(Canvas c, Offset base) {
    final leaf = Paint()..color = const Color(0xFF2E9B4E);
    for (int i = 0; i < 5; i++) {
      final a = -pi / 2 + (i - 2) * 0.45;
      c.drawOval(
          Rect.fromCenter(
              center: base + Offset(cos(a) * 26, -44 + sin(a) * 26),
              width: 16,
              height: 34),
          leaf);
    }
    final pot = Path()
      ..moveTo(base.dx - 18, base.dy - 40)
      ..lineTo(base.dx + 18, base.dy - 40)
      ..lineTo(base.dx + 13, base.dy)
      ..lineTo(base.dx - 13, base.dy)
      ..close();
    c.drawPath(pot, Paint()..color = const Color(0xFF1C8C9E));
    c.drawRect(Rect.fromLTWH(base.dx - 20, base.dy - 44, 40, 8),
        Paint()..color = const Color(0xFF0E5F70));
  }

  // ---------------------------------------------------------------- items

  void _coins(Canvas c) {
    for (final coin in w.coins) {
      final sq = 0.35 + 0.65 * cos(w.time * 5 + coin.x / 60).abs();
      paintCoin(c, Offset(coin.x, coin.y), 12, sq);
    }
  }

  void _obstacles(Canvas c) {
    for (final h in w.hazards) {
      if (h.isSlipper) continue;
      final s = obstacleSize(h.kind!);
      // shadow
      final shadowW = s.width * (1 - h.hop / 120);
      c.drawOval(
          Rect.fromCenter(center: Offset(h.x, h.y + 2), width: shadowW, height: 10),
          Paint()..color = const Color(0x44000000));
      _obstacle(c, h.kind!, Offset(h.x, h.y - h.hop), h.rot);
    }
  }

  void _mom(Canvas c) {
    drawMom(c, Offset(w.momX, w.floorY + 4), 0.95,
        time: w.time,
        windup: w.windup,
        release: w.release,
        anger: w.anger,
        shouting: w.shoutTimer > 0,
        calm: w.calm > 0);
  }

  void _warning(Canvas c) {
    final kind = w.warning;
    if (kind == null) return;
    final y = switch (kind) {
      ThrowKind.high => w.floorY - 116,
      ThrowKind.bounce => w.floorY - 20,
      _ => w.floorY - 42,
    };
    final color = kind == ThrowKind.high ? C.teal : (kind == ThrowKind.bounce ? C.goldDark : C.red);
    final label = switch (kind) {
      ThrowKind.high => 'نپر!',
      ThrowKind.bounce => 'صبر کن...',
      ThrowKind.twin => 'دوتا!',
      ThrowKind.low => 'بپر!',
    };
    final x = w.kidX - 70;
    final pulse = 1 + 0.18 * sin(w.time * 22);
    // dotted path from Mom to the kid
    final dash = Paint()
      ..color = color.withAlpha(150)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    for (double dx = w.momX + 90; dx < w.kidX - 20; dx += 14) {
      c.drawLine(Offset(dx, y), Offset(dx + 5, y), dash);
    }
    final p = Offset(x, y - 42);
    c.drawCircle(p, 19 * pulse, Paint()..color = const Color(0x55FFFFFF));
    c.drawCircle(p, 15 * pulse, Paint()..color = color);
    c.drawCircle(p, 15 * pulse, Paint()
      ..color = C.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3);
    _outlinedText(c, kind == ThrowKind.high ? '↓' : '!', p, 20, C.white, stroke: false);
    _outlinedText(c, label, p + const Offset(0, 30), 15, color);
  }

  void _kid(Canvas c) {
    final feet = Offset(w.kidX, w.floorY - w.kidY);
    // ground shadow shrinks while airborne
    final sh = (1 - w.kidY / 260).clamp(0.3, 1.0);
    c.drawOval(
        Rect.fromCenter(center: Offset(w.kidX, w.floorY + 3), width: 46 * sh, height: 10 * sh),
        Paint()..color = const Color(0x44000000));

    final flicker = w.invincible > 0 && (w.time * 14).floor().isEven;
    if (!flicker) {
      drawCharacter(c, ch, feet, GameWorld.kidScale,
          phase: w.runPhase,
          airborne: !w.onGround,
          squashX: w.squashX,
          squashY: w.squashY,
          tilt: w.tilt,
          mood: w.dying > 0 ? Mood.hurt : null,
          time: w.time,
          blink: w.blinking);
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
      drawSlipper(c, Offset(h.x, h.y), 50, h.rot);
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
    final anchor = Offset(max(8.0, w.momX + 40), w.floorY - 190);
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
    }
  }

  @override
  bool shouldRepaint(covariant GamePainter old) => true;
}
