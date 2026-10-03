import 'dart:math';

import 'package:flutter/material.dart';

import '../theme.dart';

/// Things hanging on the family's living-room wall. Each one tells a little
/// story: Mom & Dad's wedding, the day the kid was born, the bad report card...
enum WallItem {
  orosi,
  wedding,
  clockGrandpa,
  baby,
  vanyakad,
  hangingRug,
  haftSin,
  reportCard,
  shelf,
}

const _ink = C.ink;

Paint _p(Color c) => Paint()..color = c;

Paint _st(Color c, double w) => Paint()
  ..color = c
  ..style = PaintingStyle.stroke
  ..strokeWidth = w
  ..strokeCap = StrokeCap.round
  ..strokeJoin = StrokeJoin.round;

final Map<String, TextPainter> _textCache = {};

void _txt(Canvas c, String text, Offset center, double size, Color color,
    {FontWeight weight = FontWeight.w900}) {
  final key = '$text|$size|${color.toARGB32()}|${weight.index}';
  final tp = _textCache.putIfAbsent(
      key,
      () => TextPainter(
            text: TextSpan(
                text: text,
                style: TextStyle(
                    fontFamily: 'Vazirmatn',
                    fontSize: size,
                    fontWeight: weight,
                    color: color,
                    height: 1.1)),
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.center,
          )..layout());
  tp.paint(c, center - Offset(tp.width / 2, tp.height / 2));
}

/// Picture frame with a nail and wire; returns the photo area.
Rect _frame(Canvas c, Rect r,
    {Color outer = const Color(0xFFD9A441),
    Color edge = const Color(0xFF9C6A1C),
    double border = 9,
    bool wire = true}) {
  if (wire) {
    final nail = Offset(r.center.dx, r.top - 22);
    c.drawLine(nail, r.topLeft + const Offset(14, 4), _st(const Color(0xFF6B5A4A), 1.6));
    c.drawLine(nail, r.topRight + const Offset(-14, 4), _st(const Color(0xFF6B5A4A), 1.6));
    c.drawCircle(nail, 3, _p(const Color(0xFF6B5A4A)));
  }
  c.drawRRect(RRect.fromRectAndRadius(r.shift(const Offset(4, 7)), const Radius.circular(4)),
      _p(const Color(0x30000000)));
  c.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(4)), _p(edge));
  c.drawRRect(RRect.fromRectAndRadius(r.deflate(2), const Radius.circular(3)),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color.lerp(outer, Colors.white, 0.35)!, outer, edge],
        ).createShader(r));
  final photo = r.deflate(border);
  c.drawRect(photo, _p(const Color(0xFFFFFBF2)));
  return photo;
}

void _glare(Canvas c, Rect photo) {
  final g = Path()
    ..moveTo(photo.left, photo.top)
    ..lineTo(photo.left + photo.width * 0.35, photo.top)
    ..lineTo(photo.left, photo.top + photo.height * 0.45)
    ..close();
  c.drawPath(g, _p(const Color(0x22FFFFFF)));
}

void _plaque(Canvas c, Offset center, String text, {double w = 92}) {
  final r = Rect.fromCenter(center: center, width: w, height: 18);
  c.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(4)), _p(const Color(0xFF3B2A1E)));
  c.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(4)), _st(C.gold, 1.5));
  _txt(c, text, center, 10, C.gold);
}

/// Simple smiling head used in the family photos.
void _face(Canvas c, Offset p, double r,
    {Color hair = const Color(0xFF2A1A12), bool mustache = false, bool closedEyes = false}) {
  c.drawCircle(p, r, _p(C.skin));
  c.drawCircle(p, r, _st(_ink, 1.6));
  // hair cap
  c.drawArc(Rect.fromCircle(center: p, radius: r), pi * 1.05, pi * 0.9, true, _p(hair));
  final e = r * 0.32;
  if (closedEyes) {
    c.drawArc(Rect.fromCenter(center: p + Offset(-e, 1), width: r * 0.4, height: r * 0.3), 0, pi,
        false, _st(_ink, 1.4));
    c.drawArc(Rect.fromCenter(center: p + Offset(e, 1), width: r * 0.4, height: r * 0.3), 0, pi,
        false, _st(_ink, 1.4));
  } else {
    c.drawCircle(p + Offset(-e, 1), r * 0.1, _p(_ink));
    c.drawCircle(p + Offset(e, 1), r * 0.1, _p(_ink));
  }
  if (mustache) {
    c.drawOval(Rect.fromCenter(center: p + Offset(0, r * 0.42), width: r * 0.9, height: r * 0.22),
        _p(const Color(0xFF1E1A18)));
  }
  c.drawArc(Rect.fromCenter(center: p + Offset(0, r * 0.5), width: r * 0.6, height: r * 0.35), 0,
      pi, false, _st(_ink, 1.4));
  c.drawCircle(p + Offset(-r * 0.55, r * 0.35), r * 0.14, _p(const Color(0x55FF6F8A)));
  c.drawCircle(p + Offset(r * 0.55, r * 0.35), r * 0.14, _p(const Color(0x55FF6F8A)));
}

/// Draws [item] centred in [slot]. [time] animates the clock etc.
void drawWallItem(Canvas c, WallItem item, Rect slot, double time) {
  final cx = slot.center.dx;
  final cy = slot.top + slot.height * 0.42;
  switch (item) {
    case WallItem.orosi:
      break; // drawn by the painter (it needs the full window height)
    case WallItem.wedding:
      _wedding(c, Rect.fromCenter(center: Offset(cx, cy), width: 124, height: 150));
      break;
    case WallItem.baby:
      _baby(c, Rect.fromCenter(center: Offset(cx, cy + 6), width: 112, height: 124));
      break;
    case WallItem.vanyakad:
      _vanyakad(c, Rect.fromCenter(center: Offset(cx, cy - 10), width: 176, height: 84));
      break;
    case WallItem.clockGrandpa:
      _clock(c, Offset(cx - 40, cy - 30), 34, time);
      _grandpa(c, Rect.fromCenter(center: Offset(cx + 42, cy + 34), width: 78, height: 96));
      break;
    case WallItem.hangingRug:
      _hangingRug(c, Rect.fromCenter(center: Offset(cx, cy + 4), width: 118, height: 156));
      break;
    case WallItem.haftSin:
      _haftSin(c, Rect.fromCenter(center: Offset(cx, cy), width: 150, height: 116));
      break;
    case WallItem.reportCard:
      _reportCard(c, Rect.fromCenter(center: Offset(cx, cy), width: 104, height: 136));
      break;
    case WallItem.shelf:
      _shelf(c, Offset(cx, cy + 40));
      break;
  }
}

// ---------------------------------------------------------------- items

void _wedding(Canvas c, Rect r) {
  final photo = _frame(c, r);
  c.save();
  c.clipRect(photo);
  c.drawRect(
      photo,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFE3EC), Color(0xFFFFC9D9)],
        ).createShader(photo));
  final groom = Offset(photo.center.dx - 22, photo.bottom - 10);
  final bride = Offset(photo.center.dx + 22, photo.bottom - 10);
  // groom: black suit, white shirt, bow tie, young Dad with a mustache
  final suit = Path()
    ..moveTo(groom.dx - 22, groom.dy + 12)
    ..lineTo(groom.dx - 16, groom.dy - 52)
    ..quadraticBezierTo(groom.dx, groom.dy - 60, groom.dx + 16, groom.dy - 52)
    ..lineTo(groom.dx + 22, groom.dy + 12)
    ..close();
  c.drawPath(suit, _p(const Color(0xFF26222E)));
  c.drawPath(
      Path()
        ..moveTo(groom.dx - 7, groom.dy - 56)
        ..lineTo(groom.dx, groom.dy - 36)
        ..lineTo(groom.dx + 7, groom.dy - 56)
        ..close(),
      _p(Colors.white));
  c.drawPath(
      Path()
        ..moveTo(groom.dx - 5, groom.dy - 54)
        ..lineTo(groom.dx + 5, groom.dy - 50)
        ..lineTo(groom.dx + 5, groom.dy - 54)
        ..lineTo(groom.dx - 5, groom.dy - 50)
        ..close(),
      _p(const Color(0xFFE53935)));
  _face(c, Offset(groom.dx, groom.dy - 72), 15, mustache: true);
  // bride: white dress, veil and a bouquet
  final veil = Path()
    ..moveTo(bride.dx - 18, bride.dy - 88)
    ..quadraticBezierTo(bride.dx - 34, bride.dy - 30, bride.dx - 30, bride.dy + 4)
    ..lineTo(bride.dx + 30, bride.dy + 4)
    ..quadraticBezierTo(bride.dx + 34, bride.dy - 30, bride.dx + 18, bride.dy - 88)
    ..close();
  c.drawPath(veil, _p(const Color(0xAAFFFFFF)));
  final dress = Path()
    ..moveTo(bride.dx - 30, bride.dy + 12)
    ..lineTo(bride.dx - 12, bride.dy - 52)
    ..quadraticBezierTo(bride.dx, bride.dy - 58, bride.dx + 12, bride.dy - 52)
    ..lineTo(bride.dx + 30, bride.dy + 12)
    ..close();
  c.drawPath(dress, _p(Colors.white));
  c.drawPath(dress, _st(const Color(0xFFE0D0D8), 1.5));
  _face(c, Offset(bride.dx, bride.dy - 70), 14, hair: const Color(0xFF3A2416));
  // tiara
  c.drawArc(Rect.fromCircle(center: Offset(bride.dx, bride.dy - 72), radius: 15), pi * 1.2,
      pi * 0.6, false, _st(C.gold, 2.5));
  for (int i = 0; i < 4; i++) {
    c.drawCircle(Offset(bride.dx - 6 + i * 4.0, bride.dy - 34), 3.6,
        _p(i.isEven ? const Color(0xFFE53935) : const Color(0xFFFF7A9A)));
  }
  // floating hearts
  for (int i = 0; i < 3; i++) {
    final hp = Offset(photo.left + 18 + i * 34.0, photo.top + 16 + (i.isOdd ? 6 : 0));
    _heart(c, hp, 6, const Color(0xFFFF5C8A));
  }
  c.restore();
  _glare(c, photo);
  _plaque(c, Offset(r.center.dx, r.bottom + 14), 'عروسی بابا و مامان', w: 108);
}

void _heart(Canvas c, Offset p, double s, Color color) {
  final h = Path()
    ..moveTo(p.dx, p.dy + s)
    ..cubicTo(p.dx - s * 1.6, p.dy - s * 0.2, p.dx - s * 0.6, p.dy - s * 1.4, p.dx, p.dy - s * 0.4)
    ..cubicTo(p.dx + s * 0.6, p.dy - s * 1.4, p.dx + s * 1.6, p.dy - s * 0.2, p.dx, p.dy + s)
    ..close();
  c.drawPath(h, _p(color));
}

void _baby(Canvas c, Rect r) {
  final photo = _frame(c, r,
      outer: const Color(0xFF8EC5FF), edge: const Color(0xFF3F7FD6), border: 8);
  c.save();
  c.clipRect(photo);
  c.drawRect(photo, _p(const Color(0xFFFFF4C9)));
  // little stars on the wall of the hospital room
  for (int i = 0; i < 5; i++) {
    c.drawPath(starPath(Offset(photo.left + 12 + i * 20.0, photo.top + 12 + (i % 2) * 8), 4),
        _p(const Color(0xFFFFC93C)));
  }
  // swaddled newborn
  final center = Offset(photo.center.dx, photo.center.dy + 10);
  c.drawOval(Rect.fromCenter(center: center + const Offset(0, 14), width: 70, height: 44),
      _p(const Color(0xFF8EC5FF)));
  c.drawOval(Rect.fromCenter(center: center + const Offset(0, 14), width: 70, height: 44),
      _st(const Color(0xFF3F7FD6), 1.6));
  c.drawLine(center + const Offset(-24, 8), center + const Offset(24, 22),
      _st(const Color(0xFF3F7FD6), 1.4));
  _face(c, center + const Offset(0, -10), 16, closedEyes: true, hair: const Color(0xFF5A3A22));
  // one curl of hair
  c.drawArc(Rect.fromCircle(center: center + const Offset(0, -28), radius: 4), 0, pi * 1.5,
      false, _st(const Color(0xFF5A3A22), 2));
  // "zzz"
  _txt(c, 'z', center + const Offset(24, -26), 10, const Color(0xFF6E5A7E));
  c.restore();
  _glare(c, photo);
  _plaque(c, Offset(r.center.dx, r.bottom + 14), 'روزی که به دنیا اومدم', w: 112);
}

void _vanyakad(Canvas c, Rect r) {
  final photo = _frame(c, r, border: 7);
  c.drawRect(
      photo,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF0E5E3A), Color(0xFF1A8050), Color(0xFF0E5E3A)],
        ).createShader(photo));
  final inner = photo.deflate(5);
  c.drawRect(inner, _st(C.gold, 1.4));
  // corner ornaments
  for (final corner in [inner.topLeft, inner.topRight, inner.bottomLeft, inner.bottomRight]) {
    c.drawPath(starPath(corner, 5), _p(C.gold));
  }
  _txt(c, 'وَ اِن یَکاد', photo.center + const Offset(0, -2), 26, const Color(0xFFFFD86B));
  // little swirls under the calligraphy
  c.drawArc(Rect.fromCenter(center: photo.center + const Offset(-30, 20), width: 30, height: 10),
      0, pi, false, _st(C.gold, 1.4));
  c.drawArc(Rect.fromCenter(center: photo.center + const Offset(30, 20), width: 30, height: 10),
      0, pi, false, _st(C.gold, 1.4));
}

void _clock(Canvas c, Offset p, double r, double time) {
  c.drawCircle(p + const Offset(3, 5), r + 4, _p(const Color(0x30000000)));
  c.drawCircle(p, r + 5, _p(const Color(0xFF8A5634)));
  c.drawCircle(p, r, _p(const Color(0xFFFFFBF2)));
  c.drawCircle(p, r, _st(_ink, 1.6));
  for (int i = 0; i < 12; i++) {
    final a = i * pi / 6;
    final o = Offset(cos(a), sin(a));
    c.drawLine(p + o * (r - 3), p + o * (r - (i % 3 == 0 ? 9 : 6)), _st(_ink, i % 3 == 0 ? 2.4 : 1.4));
  }
  final m = time * 0.6; // fast cartoon clock
  final h = m / 12;
  c.drawLine(p, p + Offset(cos(h - pi / 2), sin(h - pi / 2)) * (r * 0.5), _st(_ink, 3));
  c.drawLine(p, p + Offset(cos(m - pi / 2), sin(m - pi / 2)) * (r * 0.78), _st(_ink, 2));
  c.drawCircle(p, 2.6, _p(const Color(0xFFE53935)));
}

void _grandpa(Canvas c, Rect r) {
  // oval sepia portrait of Grandpa
  c.drawOval(r.shift(const Offset(3, 6)), _p(const Color(0x30000000)));
  c.drawOval(r, _p(const Color(0xFF8A5634)));
  final photo = r.deflate(7);
  c.drawOval(photo, _p(const Color(0xFFE8D2A8)));
  c.save();
  c.clipPath(Path()..addOval(photo));
  final p = Offset(photo.center.dx, photo.center.dy + 2);
  // shoulders
  c.drawOval(Rect.fromCenter(center: p + const Offset(0, 40), width: 60, height: 40),
      _p(const Color(0xFF6B5440)));
  c.drawCircle(p, 18, _p(const Color(0xFFD9B88A)));
  c.drawCircle(p, 18, _st(const Color(0xFF4A3828), 1.4));
  // white side hair, big white mustache, round glasses
  c.drawOval(Rect.fromCenter(center: p + const Offset(-16, -2), width: 8, height: 14),
      _p(const Color(0xFFF5EFE6)));
  c.drawOval(Rect.fromCenter(center: p + const Offset(16, -2), width: 8, height: 14),
      _p(const Color(0xFFF5EFE6)));
  c.drawOval(Rect.fromCenter(center: p + const Offset(0, 8), width: 20, height: 6),
      _p(const Color(0xFFF5EFE6)));
  c.drawCircle(p + const Offset(-6, -3), 4.5, _st(const Color(0xFF4A3828), 1.4));
  c.drawCircle(p + const Offset(6, -3), 4.5, _st(const Color(0xFF4A3828), 1.4));
  c.restore();
}

void _hangingRug(Canvas c, Rect r) {
  // rod
  c.drawLine(Offset(r.left - 10, r.top), Offset(r.right + 10, r.top), _st(const Color(0xFF6B3E1E), 5));
  c.drawCircle(Offset(r.left - 12, r.top), 4, _p(C.gold));
  c.drawCircle(Offset(r.right + 12, r.top), 4, _p(C.gold));
  c.drawRect(r.shift(const Offset(3, 6)), _p(const Color(0x30000000)));
  c.drawRect(r, _p(C.rugNavy));
  final field = r.deflate(10);
  c.drawRect(field, _p(C.rug));
  c.drawRect(field, _st(C.rugGold, 2));
  // border dots
  for (double x = r.left + 6; x < r.right; x += 10) {
    c.drawCircle(Offset(x, r.top + 5), 2, _p(C.rugGold));
    c.drawCircle(Offset(x, r.bottom - 5), 2, _p(C.rugGold));
  }
  // central medallion
  final m = field.center;
  final d = Path()
    ..moveTo(m.dx, m.dy - 46)
    ..lineTo(m.dx + 34, m.dy)
    ..lineTo(m.dx, m.dy + 46)
    ..lineTo(m.dx - 34, m.dy)
    ..close();
  c.drawPath(d, _p(C.rugNavy));
  c.drawPath(starPath(m, 18), _p(C.rugGold));
  c.drawPath(starPath(m, 9), _p(C.rugDark));
  // corner pieces
  for (final k in [field.topLeft, field.topRight, field.bottomLeft, field.bottomRight]) {
    c.drawCircle(k, 12, _p(C.rugNavy));
  }
  // fringes
  for (double x = r.left + 3; x < r.right; x += 6) {
    c.drawLine(Offset(x, r.bottom), Offset(x, r.bottom + 9), _st(const Color(0xFFF7E3C0), 1.6));
  }
}

void _haftSin(Canvas c, Rect r) {
  final photo = _frame(c, r, outer: const Color(0xFFB57A4A), edge: const Color(0xFF6B3E1E));
  c.save();
  c.clipRect(photo);
  c.drawRect(photo, _p(const Color(0xFFFFF2DC)));
  // table cloth (termeh)
  final table = Rect.fromLTWH(photo.left, photo.bottom - 30, photo.width, 30);
  c.drawRect(table, _p(const Color(0xFFB8322B)));
  for (double x = table.left; x < table.right; x += 14) {
    c.drawPath(starPath(Offset(x + 7, table.top + 15), 4), _p(C.rugGold));
  }
  final base = table.top;
  // sabzeh (sprouts) with a red ribbon
  final sb = Offset(photo.left + 24, base);
  c.drawOval(Rect.fromCenter(center: sb + const Offset(0, -4), width: 30, height: 12), _p(const Color(0xFFDCC7A0)));
  for (int i = 0; i < 9; i++) {
    c.drawLine(sb + Offset(-12.0 + i * 3, -6), sb + Offset(-14.0 + i * 3.5, -30 - (i % 3) * 4),
        _st(const Color(0xFF3FAE4A), 2));
  }
  c.drawLine(sb + const Offset(-13, -12), sb + const Offset(13, -12), _st(const Color(0xFFE53935), 3));
  // goldfish bowl
  final bowl = Offset(photo.center.dx, base - 18);
  c.drawCircle(bowl, 18, _p(const Color(0x8899DDFF)));
  c.drawCircle(bowl, 18, _st(const Color(0xFF6FA8C8), 1.4));
  c.drawOval(Rect.fromCenter(center: bowl + const Offset(-2, 2), width: 12, height: 7),
      _p(const Color(0xFFFF6A1F)));
  c.drawPath(
      Path()
        ..moveTo(bowl.dx + 4, bowl.dy + 2)
        ..lineTo(bowl.dx + 9, bowl.dy - 2)
        ..lineTo(bowl.dx + 9, bowl.dy + 6)
        ..close(),
      _p(const Color(0xFFFF6A1F)));
  // red apples, a coin, painted eggs
  c.drawCircle(Offset(photo.right - 28, base - 8), 8, _p(const Color(0xFFE53935)));
  c.drawCircle(Offset(photo.right - 14, base - 7), 7, _p(const Color(0xFFD32F2F)));
  c.drawOval(Rect.fromCenter(center: Offset(photo.center.dx + 32, base - 7), width: 9, height: 12),
      _p(const Color(0xFF8E5BD6)));
  c.drawOval(Rect.fromCenter(center: Offset(photo.center.dx + 42, base - 6), width: 9, height: 12),
      _p(const Color(0xFF26C6BE)));
  // candles
  for (final x in [photo.left + 48, photo.right - 46]) {
    c.drawRect(Rect.fromLTWH(x - 3, base - 26, 6, 22), _p(Colors.white));
    c.drawOval(Rect.fromCenter(center: Offset(x, base - 31), width: 6, height: 10), _p(const Color(0xFFFFB531)));
  }
  c.restore();
  _glare(c, photo);
  _plaque(c, Offset(r.center.dx, r.bottom + 14), 'نوروز', w: 60);
}

void _reportCard(Canvas c, Rect r) {
  final photo = _frame(c, r, outer: const Color(0xFF3A3A44), edge: const Color(0xFF1E1E24), border: 6);
  c.drawRect(photo, _p(Colors.white));
  _txt(c, 'کارنامه', Offset(photo.center.dx, photo.top + 13), 12, _ink);
  c.drawLine(Offset(photo.left + 8, photo.top + 24), Offset(photo.right - 8, photo.top + 24),
      _st(const Color(0xFFCCCCD6), 1));
  final rows = [
    ['ریاضی', '۲۰', const Color(0xFF1FA463)],
    ['علوم', '۱۹', const Color(0xFF1FA463)],
    ['ورزش', '۲۰', const Color(0xFF1FA463)],
    ['انضباط', '۱۲', const Color(0xFFE53935)],
  ];
  for (int i = 0; i < rows.length; i++) {
    final y = photo.top + 38 + i * 19.0;
    _txt(c, rows[i][0] as String, Offset(photo.right - 26, y), 10, _ink, weight: FontWeight.w700);
    _txt(c, rows[i][1] as String, Offset(photo.left + 22, y), 12, rows[i][2] as Color);
  }
  // the bad grade is circled in red
  c.drawOval(
      Rect.fromCenter(center: Offset(photo.left + 22, photo.top + 38 + 3 * 19.0), width: 26, height: 18),
      _st(const Color(0xFFE53935), 1.6));
}

void _shelf(Canvas c, Offset p) {
  // wooden shelf with tea glasses (estekan), Hafez and a small vase
  final plank = Rect.fromCenter(center: p, width: 170, height: 10);
  c.drawRect(plank.shift(const Offset(2, 5)), _p(const Color(0x30000000)));
  c.drawRect(plank, _p(const Color(0xFF8A5634)));
  c.drawRect(Rect.fromLTWH(plank.left + 16, plank.bottom, 6, 14), _p(const Color(0xFF6B3E1E)));
  c.drawRect(Rect.fromLTWH(plank.right - 22, plank.bottom, 6, 14), _p(const Color(0xFF6B3E1E)));
  final top = plank.top;
  // three tulip-shaped tea glasses on saucers
  for (int i = 0; i < 3; i++) {
    final x = plank.left + 22 + i * 22.0;
    c.drawOval(Rect.fromCenter(center: Offset(x, top - 2), width: 18, height: 5), _p(Colors.white));
    final glass = Path()
      ..moveTo(x - 6, top - 26)
      ..quadraticBezierTo(x - 2, top - 14, x - 5, top - 4)
      ..lineTo(x + 5, top - 4)
      ..quadraticBezierTo(x + 2, top - 14, x + 6, top - 26)
      ..close();
    c.drawPath(glass, _p(const Color(0xCCB84A1E)));
    c.drawPath(glass, _st(const Color(0x88FFFFFF), 1.2));
    c.drawLine(Offset(x - 6, top - 24), Offset(x + 6, top - 24), _st(const Color(0xFFD9A441), 1.6));
  }
  // Divan of Hafez standing up
  final book = Rect.fromLTWH(plank.left + 92, top - 40, 22, 40);
  c.drawRect(book, _p(const Color(0xFF1C6FA8)));
  c.drawRect(book, _st(_ink, 1.2));
  c.drawRect(Rect.fromLTWH(book.left + 3, book.top + 4, book.width - 6, book.height - 8),
      _st(C.gold, 1.2));
  c.save();
  c.translate(book.center.dx, book.center.dy);
  c.rotate(-pi / 2);
  _txt(c, 'حافظ', Offset.zero, 9, C.gold);
  c.restore();
  // small vase with a flower
  final v = Offset(plank.right - 26, top);
  c.drawOval(Rect.fromCenter(center: v + const Offset(0, -12), width: 20, height: 24),
      _p(const Color(0xFF26C6BE)));
  c.drawLine(v + const Offset(0, -22), v + const Offset(2, -42), _st(const Color(0xFF2E9B4E), 2));
  c.drawCircle(v + const Offset(2, -44), 6, _p(const Color(0xFFFF5C8A)));
  c.drawCircle(v + const Offset(2, -44), 2.5, _p(C.gold));
}
