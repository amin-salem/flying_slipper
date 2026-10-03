import 'dart:math';

import 'package:flutter/material.dart';

import '../theme.dart';

/// The house has three areas. You run from one into the next as the
/// distance grows, then back into the living room, and so on.
enum Room { living, kitchen, yard }

const double roomLength = 450; // meters per room

Room roomForMeters(double m) {
  final i = (m / roomLength).floor() % 3;
  return Room.values[i < 0 ? 0 : i];
}

String roomName(Room r) => switch (r) {
      Room.living => 'اتاق نشیمن',
      Room.kitchen => 'آشپزخونه',
      Room.yard => 'حیاط',
    };

/// Seasonal decorations by (Gregorian) date.
enum Season { none, yalda, nowruz }

Season currentSeason([DateTime? now]) {
  final d = now ?? DateTime.now();
  if (d.month == 12 && d.day >= 14 && d.day <= 23) return Season.yalda;
  if ((d.month == 3 && d.day >= 10) || (d.month == 4 && d.day <= 4)) {
    return Season.nowruz;
  }
  return Season.none;
}

Paint _p(Color c) => Paint()..color = c;

Paint _st(Color c, double w) => Paint()
  ..color = c
  ..style = PaintingStyle.stroke
  ..strokeWidth = w
  ..strokeCap = StrokeCap.round
  ..strokeJoin = StrokeJoin.round;

// ------------------------------------------------------------------ walls

/// Background of one wall slot (everything above the floor line).
void drawWallBase(Canvas c, Room room, Rect r, double friezeY) {
  switch (room) {
    case Room.living:
      c.drawRect(
          r,
          Paint()
            ..shader = const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFFFF3DD), C.wall, C.wallShade],
              stops: [0, 0.6, 1],
            ).createShader(r));
      _tileFrieze(c, r, friezeY, const Color(0xFF1C8C9E), const Color(0xFF0E5F70));
    case Room.kitchen:
      // light blue wall with white tile backsplash in the lower half
      c.drawRect(r, _p(const Color(0xFFE3F1F6)));
      final split = r.top + r.height * 0.55;
      final tiles = Rect.fromLTRB(r.left, split, r.right, r.bottom);
      c.drawRect(tiles, _p(const Color(0xFFFAFDFF)));
      final grout = _st(const Color(0xFFC9DDE6), 1.2);
      for (double y = split; y < r.bottom; y += 24) {
        c.drawLine(Offset(r.left, y), Offset(r.right, y), grout);
      }
      for (double x = r.left - (r.left % 24); x < r.right; x += 24) {
        c.drawLine(Offset(x, split), Offset(x, r.bottom), grout);
      }
      // a row of blue patterned tiles (kashi) between wall and backsplash
      c.drawRect(Rect.fromLTWH(r.left, split - 16, r.width, 16), _p(const Color(0xFF2F6BB0)));
      for (double x = r.left - (r.left % 16) + 8; x < r.right; x += 16) {
        c.drawPath(starPath(Offset(x, split - 8), 5.5), _p(const Color(0xFFFAFDFF)));
      }
      _tileFrieze(c, r, friezeY, const Color(0xFF2F6BB0), const Color(0xFF1C4A80));
    case Room.yard:
      // blue sky above a brick garden wall
      c.drawRect(
          r,
          Paint()
            ..shader = const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF7CC8F2), Color(0xFFBFE6FA)],
            ).createShader(r));
      final wallTop = r.bottom - r.height * 0.42;
      final bricks = Rect.fromLTRB(r.left, wallTop, r.right, r.bottom);
      c.drawRect(bricks, _p(const Color(0xFFD9925B)));
      final mortar = _st(const Color(0xFFF2D3B0), 2);
      int row = 0;
      for (double y = wallTop; y < r.bottom; y += 16, row++) {
        c.drawLine(Offset(r.left, y), Offset(r.right, y), mortar);
        final off = row.isOdd ? 18.0 : 0.0;
        for (double x = r.left - (r.left % 36) + off; x < r.right; x += 36) {
          c.drawLine(Offset(x, y), Offset(x, min(y + 16, r.bottom)), mortar);
        }
      }
      // wall cap
      c.drawRect(Rect.fromLTWH(r.left, wallTop - 8, r.width, 10), _p(const Color(0xFFB8733F)));
  }
}

void _tileFrieze(Canvas c, Rect r, double y, Color band, Color dot) {
  c.drawRect(Rect.fromLTWH(r.left, y, r.width, 34), _p(band));
  c.drawRect(Rect.fromLTWH(r.left, y - 4, r.width, 4), _p(C.rugGold));
  c.drawRect(Rect.fromLTWH(r.left, y + 34, r.width, 4), _p(C.rugGold));
  for (double x = r.left - (r.left % 40); x < r.right + 40; x += 40) {
    c.drawPath(starPath(Offset(x, y + 17), 11), _p(const Color(0xFFFFF3DD)));
    c.drawCircle(Offset(x, y + 17), 3.5, _p(dot));
  }
}

/// Wooden door frame where one room leads into the next.
void drawDoorway(Canvas c, double x, double top, double floorY) {
  final r = Rect.fromLTRB(x - 46, top, x + 46, floorY);
  final frame = RRect.fromRectAndCorners(r,
      topLeft: const Radius.circular(46), topRight: const Radius.circular(46));
  c.drawRRect(frame.inflate(10), _p(const Color(0xFF8A5634)));
  c.drawRRect(frame, _p(const Color(0xFF3B2A1E)));
  c.drawRRect(frame.inflate(10), _st(C.ink, 2));
  // bead curtain
  for (double bx = r.left + 8; bx < r.right - 4; bx += 10) {
    for (double by = r.top + 30; by < r.bottom - 20; by += 9) {
      c.drawCircle(Offset(bx, by), 2.4,
          _p(((bx + by) ~/ 9).isEven ? const Color(0xFFFF5A4E) : const Color(0xFFFFD34D)));
    }
  }
}

/// Item on a kitchen or yard wall slot. Slot = the area between the top
/// of the windows and the counter/flower line.
void drawRoomItem(Canvas c, Room room, int k, Rect slot, double time) {
  final cx = slot.center.dx;
  final cy = slot.top + slot.height * 0.42;
  if (room == Room.kitchen) {
    switch (k % 4) {
      case 0:
        _kitchenWindow(c, Rect.fromCenter(center: Offset(cx, cy), width: 130, height: 120), time);
      case 1:
        _spiceShelf(c, Offset(cx, cy + 20));
      case 2:
        _pans(c, Offset(cx, cy - 30));
      default:
        _calendar(c, Rect.fromCenter(center: Offset(cx, cy), width: 84, height: 100));
    }
  } else if (room == Room.yard) {
    switch (k % 3) {
      case 0:
        _tree(c, Offset(cx, slot.bottom + 40), slot.height, time);
      case 1:
        _clothesline(c, Rect.fromLTWH(slot.left + 10, cy - 30, slot.width - 20, 90), time);
      default:
        _houseWindow(c, Rect.fromCenter(center: Offset(cx, cy - 10), width: 100, height: 120));
    }
  }
}

// ------------------------------------------------------------- mid layer

/// Things standing along the wall: cushions (living room), counters
/// (kitchen) or a flower bed with a little pool (yard).
void drawMidSegment(Canvas c, Room room, double x, double floorY, double time) {
  switch (room) {
    case Room.living:
      for (int i = 0; i < 4; i++) {
        _cushion(c, Rect.fromLTWH(x + i * 62, floorY - 46, 58, 40), i.isEven ? C.rug : C.rugNavy);
      }
      _plant(c, Offset(x + 330, floorY - 10));
    case Room.kitchen:
      _counter(c, Rect.fromLTWH(x, floorY - 70, 300, 70), time);
      _fridge(c, Rect.fromLTWH(x + 360, floorY - 150, 80, 150));
    case Room.yard:
      _flowerBed(c, Rect.fromLTWH(x, floorY - 34, 220, 34));
      _pool(c, Rect.fromLTWH(x + 260, floorY - 30, 200, 30), time);
  }
}

void _cushion(Canvas c, Rect r, Color color) {
  final rr = RRect.fromRectAndRadius(r, const Radius.circular(12));
  c.drawRRect(rr.shift(const Offset(0, 4)), _p(const Color(0x33000000)));
  c.drawRRect(rr, _p(color));
  c.drawRRect(rr.deflate(6), _st(C.rugGold, 2.5));
  c.drawPath(starPath(r.center, 8), _p(C.rugGold));
}

void _plant(Canvas c, Offset base) {
  final leaf = _p(const Color(0xFF2E9B4E));
  for (int i = 0; i < 5; i++) {
    final a = -pi / 2 + (i - 2) * 0.45;
    c.drawOval(
        Rect.fromCenter(center: base + Offset(cos(a) * 26, -44 + sin(a) * 26), width: 16, height: 34),
        leaf);
  }
  final pot = Path()
    ..moveTo(base.dx - 18, base.dy - 40)
    ..lineTo(base.dx + 18, base.dy - 40)
    ..lineTo(base.dx + 13, base.dy)
    ..lineTo(base.dx - 13, base.dy)
    ..close();
  c.drawPath(pot, _p(const Color(0xFF1C8C9E)));
  c.drawRect(Rect.fromLTWH(base.dx - 20, base.dy - 44, 40, 8), _p(const Color(0xFF0E5F70)));
}

void _counter(Canvas c, Rect r, double time) {
  // wooden cabinets
  c.drawRect(r, _p(const Color(0xFFB57A4A)));
  for (double x = r.left; x < r.right; x += 75) {
    final door = Rect.fromLTWH(x + 6, r.top + 14, 63, r.height - 20);
    c.drawRect(door, _p(const Color(0xFFC88C58)));
    c.drawRect(door, _st(const Color(0xFF8A5634), 2));
    c.drawCircle(Offset(x + 60, r.top + 40), 3, _p(C.gold));
  }
  // countertop
  c.drawRect(Rect.fromLTWH(r.left - 6, r.top, r.width + 12, 10), _p(const Color(0xFFE9E4DC)));
  // stove with a pot of stew (ghormeh sabzi!) and steam
  final stove = Rect.fromLTWH(r.left + 160, r.top - 4, 90, 6);
  c.drawRect(stove, _p(const Color(0xFF3A3A44)));
  final pot = Rect.fromLTWH(r.left + 178, r.top - 34, 54, 30);
  c.drawRRect(RRect.fromRectAndRadius(pot, const Radius.circular(6)), _p(const Color(0xFF9AA3B2)));
  c.drawRect(Rect.fromLTWH(pot.left - 6, pot.top - 4, pot.width + 12, 6), _p(const Color(0xFF7D8696)));
  c.drawRRect(RRect.fromRectAndRadius(pot, const Radius.circular(6)), _st(C.ink, 1.6));
  for (int i = 0; i < 3; i++) {
    final tt = (time * 0.9 + i / 3) % 1.0;
    c.drawCircle(Offset(pot.center.dx - 12 + i * 12.0, pot.top - 8 - tt * 30), 4 + tt * 6,
        _p(Color.fromARGB((150 * (1 - tt)).round(), 255, 255, 255)));
  }
  // bread basket (sangak)
  final bread = Rect.fromLTWH(r.left + 30, r.top - 16, 80, 16);
  c.drawOval(bread, _p(const Color(0xFFE0B070)));
  for (int i = 0; i < 6; i++) {
    c.drawCircle(Offset(bread.left + 12 + i * 11.0, bread.center.dy), 2, _p(const Color(0xFF9C6A2E)));
  }
}

void _fridge(Canvas c, Rect r) {
  final rr = RRect.fromRectAndRadius(r, const Radius.circular(10));
  c.drawRRect(rr.shift(const Offset(3, 4)), _p(const Color(0x30000000)));
  c.drawRRect(rr, _p(const Color(0xFFF5F7FA)));
  c.drawRRect(rr, _st(C.ink, 2));
  c.drawLine(Offset(r.left, r.top + 50), Offset(r.right, r.top + 50), _st(C.ink, 2));
  c.drawLine(Offset(r.right - 12, r.top + 16), Offset(r.right - 12, r.top + 38), _st(const Color(0xFF9AA3B2), 4));
  c.drawLine(Offset(r.right - 12, r.top + 64), Offset(r.right - 12, r.top + 100), _st(const Color(0xFF9AA3B2), 4));
  // fridge magnets and the kid's drawing
  final paper = Rect.fromLTWH(r.left + 12, r.top + 62, 40, 48);
  c.drawRect(paper, _p(Colors.white));
  c.drawCircle(paper.center + const Offset(0, -6), 7, _p(const Color(0xFFFFD34D)));
  c.drawLine(paper.center + const Offset(-12, 14), paper.center + const Offset(12, 14), _st(const Color(0xFF2E9B4E), 3));
  c.drawCircle(Offset(paper.center.dx, paper.top), 4, _p(C.red));
  c.drawCircle(Offset(r.left + 20, r.top + 20), 5, _p(C.teal));
  c.drawCircle(Offset(r.left + 36, r.top + 30), 5, _p(C.gold));
}

void _flowerBed(Canvas c, Rect r) {
  c.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(8)), _p(const Color(0xFF8A5A3A)));
  for (double x = r.left + 12; x < r.right - 8; x += 22) {
    c.drawCircle(Offset(x, r.top), 12, _p(const Color(0xFF3FAE4A)));
    final color = (x ~/ 22).isEven ? const Color(0xFFE53935) : const Color(0xFFFFC93C);
    for (int k = 0; k < 5; k++) {
      final a = k * 2 * pi / 5;
      c.drawCircle(Offset(x + cos(a) * 4, r.top - 8 + sin(a) * 4), 3.4, _p(color));
    }
    c.drawCircle(Offset(x, r.top - 8), 2, _p(Colors.white));
  }
}

void _pool(Canvas c, Rect r, double time) {
  // the classic blue courtyard pool (hoz) with goldfish and a fountain
  final rr = RRect.fromRectAndRadius(r, const Radius.circular(6));
  c.drawRRect(rr.inflate(6), _p(const Color(0xFF2F6BB0)));
  c.drawRRect(rr, _p(const Color(0xFF56B9E8)));
  for (int i = 0; i < 2; i++) {
    final fx = r.left + 40 + ((time * 30 + i * 90) % (r.width - 60));
    c.drawOval(Rect.fromCenter(center: Offset(fx, r.center.dy + (i == 0 ? -4 : 5)), width: 14, height: 7),
        _p(const Color(0xFFFF6A1F)));
  }
  // fountain
  final f = Offset(r.center.dx, r.top);
  for (int k = 0; k < 6; k++) {
    final tt = (time * 1.5 + k / 6) % 1.0;
    final side = k.isEven ? -1 : 1;
    c.drawCircle(f + Offset(side * tt * 20, -40 * sin(tt * pi)), 2.6,
        _p(Color.fromARGB((220 * (1 - tt)).round(), 230, 248, 255)));
  }
}

// ---------------------------------------------------------- wall items

void _kitchenWindow(Canvas c, Rect r, double time) {
  c.drawRect(r.inflate(6), _p(const Color(0xFFFFFFFF)));
  c.drawRect(r, _p(const Color(0xFF9FD8F5)));
  c.drawCircle(Offset(r.right - 26, r.top + 26), 12, _p(const Color(0xFFFFE07A)));
  c.drawLine(Offset(r.center.dx, r.top), Offset(r.center.dx, r.bottom), _st(Colors.white, 5));
  c.drawLine(Offset(r.left, r.center.dy), Offset(r.right, r.center.dy), _st(Colors.white, 5));
  // checked curtains, gently moving
  final sway = sin(time * 2) * 3;
  for (final left in [true, false]) {
    final x0 = left ? r.left - 8 : r.right + 8;
    final x1 = left ? r.left + 34 + sway : r.right - 34 - sway;
    final p = Path()
      ..moveTo(x0, r.top - 10)
      ..lineTo(x1, r.top - 10)
      ..quadraticBezierTo(x1 + (left ? -10 : 10), r.center.dy, x0, r.bottom + 6)
      ..close();
    c.drawPath(p, _p(const Color(0xFFE85C5C)));
    c.save();
    c.clipPath(p);
    for (double y = r.top - 10; y < r.bottom + 10; y += 10) {
      c.drawLine(Offset(r.left - 20, y), Offset(r.right + 20, y), _st(const Color(0x66FFFFFF), 3));
    }
    c.restore();
  }
  c.drawLine(Offset(r.left - 14, r.top - 10), Offset(r.right + 14, r.top - 10), _st(const Color(0xFF8A5634), 4));
}

void _spiceShelf(Canvas c, Offset p) {
  final plank = Rect.fromCenter(center: p, width: 160, height: 9);
  c.drawRect(plank, _p(const Color(0xFF8A5634)));
  const jars = [
    Color(0xFFE53935), // zereshk (barberry)
    Color(0xFFFFB300), // zardchoobeh (turmeric)
    Color(0xFFD84315), // saffron
    Color(0xFF6D4C41), // cinnamon
    Color(0xFF7CB342), // dried herbs
  ];
  for (int i = 0; i < jars.length; i++) {
    final x = plank.left + 16 + i * 31.0;
    final jar = RRect.fromRectAndRadius(Rect.fromLTWH(x - 11, plank.top - 34, 22, 34), const Radius.circular(5));
    c.drawRRect(jar, _p(const Color(0x66FFFFFF)));
    c.drawRRect(Rect.fromLTWH(x - 9, plank.top - 22, 18, 20).toRRect(4), _p(jars[i]));
    c.drawRect(Rect.fromLTWH(x - 11, plank.top - 40, 22, 7), _p(const Color(0xFF3A3A44)));
    c.drawRRect(jar, _st(C.ink, 1.4));
  }
}

extension on Rect {
  RRect toRRect(double r) => RRect.fromRectAndRadius(this, Radius.circular(r));
}

void _pans(Canvas c, Offset p) {
  c.drawLine(p + const Offset(-70, 0), p + const Offset(70, 0), _st(const Color(0xFF6B5A4A), 4));
  for (int i = 0; i < 3; i++) {
    final x = p.dx - 50 + i * 50.0;
    c.drawLine(Offset(x, p.dy), Offset(x, p.dy + 14), _st(const Color(0xFF6B5A4A), 2));
    final size = 22.0 + i * 4;
    c.drawLine(Offset(x, p.dy + 14), Offset(x, p.dy + 34), _st(const Color(0xFF3A3A44), 6));
    c.drawCircle(Offset(x, p.dy + 34 + size), size, _p(const Color(0xFF3A3A44)));
    c.drawCircle(Offset(x, p.dy + 34 + size), size - 5, _p(const Color(0xFF55555F)));
    c.drawArc(Rect.fromCircle(center: Offset(x, p.dy + 34 + size), radius: size - 9), pi * 1.1,
        0.8, false, _st(const Color(0x55FFFFFF), 3));
  }
}

void _calendar(Canvas c, Rect r) {
  c.drawRect(r.shift(const Offset(3, 5)), _p(const Color(0x30000000)));
  c.drawRect(r, _p(Colors.white));
  c.drawRect(Rect.fromLTWH(r.left, r.top, r.width, 26), _p(const Color(0xFFE53935)));
  // grid of days, one circled (the day of the broken vase!)
  for (int row = 0; row < 4; row++) {
    for (int col = 0; col < 5; col++) {
      final o = Offset(r.left + 12 + col * 15.0, r.top + 38 + row * 15.0);
      c.drawRect(Rect.fromCenter(center: o, width: 8, height: 6), _p(const Color(0xFFD5CEDC)));
    }
  }
  c.drawCircle(Offset(r.left + 12 + 3 * 15.0, r.top + 38 + 2 * 15.0), 7, _st(const Color(0xFFE53935), 1.8));
  c.drawCircle(Offset(r.center.dx, r.top - 6), 3, _p(const Color(0xFF6B5A4A)));
}

void _tree(Canvas c, Offset base, double h, double time) {
  final trunkTop = base.dy - h * 0.8;
  c.drawRect(Rect.fromLTRB(base.dx - 12, trunkTop, base.dx + 12, base.dy), _p(const Color(0xFF8A5A3A)));
  final sway = sin(time * 1.6) * 4;
  final leaf = _p(const Color(0xFF3FAE4A));
  final dark = _p(const Color(0xFF2E8B3E));
  for (final o in const [Offset(-40, 0), Offset(40, 0), Offset(0, -34), Offset(-22, -20), Offset(22, -22)]) {
    c.drawCircle(Offset(base.dx + o.dx + sway, trunkTop + o.dy), 36, dark);
  }
  for (final o in const [Offset(-30, -6), Offset(30, -8), Offset(0, -38), Offset(0, 4)]) {
    c.drawCircle(Offset(base.dx + o.dx + sway, trunkTop + o.dy), 28, leaf);
  }
  // pomegranates
  for (final o in const [Offset(-30, 8), Offset(18, -20), Offset(36, 10), Offset(-8, -44)]) {
    final p = Offset(base.dx + o.dx + sway, trunkTop + o.dy);
    c.drawCircle(p, 7, _p(const Color(0xFFD32F2F)));
    c.drawCircle(p + const Offset(-2, -2), 2, _p(const Color(0x66FFFFFF)));
  }
}

void _clothesline(Canvas c, Rect r, double time) {
  c.drawLine(Offset(r.left, r.top + 10), Offset(r.left, r.bottom + 60), _st(const Color(0xFF6B5A4A), 4));
  c.drawLine(Offset(r.right, r.top + 10), Offset(r.right, r.bottom + 60), _st(const Color(0xFF6B5A4A), 4));
  final line = Path()
    ..moveTo(r.left, r.top + 12)
    ..quadraticBezierTo(r.center.dx, r.top + 30, r.right, r.top + 12);
  c.drawPath(line, _st(const Color(0xFF6B5A4A), 1.6));
  const clothes = [Color(0xFF2F6BFF), Color(0xFFFFFFFF), Color(0xFFE53935), Color(0xFF8E5BD6)];
  for (int i = 0; i < 4; i++) {
    final t = (i + 0.7) / 4.5;
    final x = r.left + r.width * t;
    final y = r.top + 12 + 18 * sin(t * pi) * 1.0;
    final sway = sin(time * 2.4 + i) * 3;
    final shirt = Path()
      ..moveTo(x - 14, y)
      ..lineTo(x + 14, y)
      ..lineTo(x + 12 + sway, y + 34)
      ..lineTo(x - 12 + sway, y + 34)
      ..close();
    c.drawPath(shirt, _p(clothes[i]));
    c.drawPath(shirt, _st(C.ink, 1.4));
    c.drawRect(Rect.fromCenter(center: Offset(x - 8, y), width: 4, height: 8), _p(const Color(0xFFFFD34D)));
    c.drawRect(Rect.fromCenter(center: Offset(x + 8, y), width: 4, height: 8), _p(const Color(0xFFFFD34D)));
  }
  // Dad's famous striped pajama pants, of course
  final px = r.left + r.width * 0.92;
  c.drawRect(Rect.fromLTWH(px - 8, r.top + 16, 10, 40), _p(const Color(0xFF7D8AA6)));
  c.drawRect(Rect.fromLTWH(px + 4, r.top + 16, 10, 40), _p(const Color(0xFF7D8AA6)));
}

void _houseWindow(Canvas c, Rect r) {
  final arch = RRect.fromRectAndCorners(r,
      topLeft: Radius.circular(r.width / 2), topRight: Radius.circular(r.width / 2));
  c.drawRRect(arch.inflate(8), _p(const Color(0xFFE9D7BC)));
  c.drawRRect(arch, _p(const Color(0xFF2F4A6E)));
  c.save();
  c.clipRRect(arch);
  c.drawRect(Rect.fromLTWH(r.left, r.top, r.width / 2, r.height), _p(const Color(0xFF3A5A82)));
  c.restore();
  c.drawLine(Offset(r.center.dx, r.top), Offset(r.center.dx, r.bottom), _st(const Color(0xFFE9D7BC), 5));
  // flower box under the window
  final box = Rect.fromLTWH(r.left - 6, r.bottom + 4, r.width + 12, 14);
  c.drawRect(box, _p(const Color(0xFF8A5634)));
  for (double x = box.left + 8; x < box.right; x += 14) {
    c.drawCircle(Offset(x, box.top - 4), 5, _p((x ~/ 14).isEven ? const Color(0xFFE53935) : const Color(0xFFFF8FB1)));
  }
}

// --------------------------------------------------------------- floors

/// One 90-unit-wide piece of floor, starting at [x].
void drawFloorTile(Canvas c, Room room, double x, double floorY, double bottom) {
  final h = bottom - floorY;
  switch (room) {
    case Room.living:
      c.drawRect(Rect.fromLTWH(x, floorY, 91, h), _p(C.rug));
      c.drawRect(Rect.fromLTWH(x, floorY, 91, 14), _p(C.rugNavy));
      c.drawRect(Rect.fromLTWH(x, floorY + 14, 91, 5), _p(C.rugGold));
      c.drawPath(
          Path()
            ..moveTo(x, floorY + 14)
            ..lineTo(x + 8, floorY + 4)
            ..lineTo(x + 16, floorY + 14)
            ..close(),
          _p(C.rugGold));
      final cy = floorY + h * 0.45;
      final d = Path()
        ..moveTo(x + 45, cy - 30)
        ..lineTo(x + 75, cy)
        ..lineTo(x + 45, cy + 30)
        ..lineTo(x + 15, cy)
        ..close();
      c.drawPath(d, _p(C.rugNavy));
      c.drawPath(starPath(Offset(x + 45, cy), 16), _p(C.rugDark));
      c.drawPath(starPath(Offset(x + 45, cy), 8), _p(C.rugGold));
      c.drawCircle(Offset(x, cy - 34), 4, _p(const Color(0xFFF7E3C0)));
      c.drawCircle(Offset(x, cy + 34), 4, _p(const Color(0xFFF7E3C0)));
    case Room.kitchen:
      const s = 45.0;
      for (double y = floorY; y < bottom; y += s) {
        for (int i = 0; i < 2; i++) {
          final even = (((y - floorY) / s).round() + i).isEven;
          c.drawRect(Rect.fromLTWH(x + i * s, y, s + 0.5, s + 0.5),
              _p(even ? const Color(0xFFF4E9D8) : const Color(0xFFC8693A)));
        }
      }
      c.drawRect(Rect.fromLTWH(x, floorY, 91, 6), _p(const Color(0xFFB57A4A)));
    case Room.yard:
      // grass strip then a brick path
      c.drawRect(Rect.fromLTWH(x, floorY, 91, h), _p(const Color(0xFFE2B886)));
      final mortar = _st(const Color(0xFFC79A66), 2);
      int row = 0;
      for (double y = floorY + 14; y < bottom; y += 22, row++) {
        c.drawLine(Offset(x, y), Offset(x + 91, y), mortar);
        final off = row.isOdd ? 22.5 : 0.0;
        for (double bx = x + off; bx < x + 91; bx += 45) {
          c.drawLine(Offset(bx, y), Offset(bx, y + 22), mortar);
        }
      }
      c.drawRect(Rect.fromLTWH(x, floorY, 91, 14), _p(const Color(0xFF5DBB4A)));
      for (double gx = x + 4; gx < x + 91; gx += 9) {
        c.drawLine(Offset(gx, floorY + 2), Offset(gx + 2, floorY - 6), _st(const Color(0xFF3FAE4A), 2.5));
      }
  }
}

// --------------------------------------------------------- seasonal

/// A garland of seasonal things hanging across the top of the wall.
void drawSeasonGarland(Canvas c, Season season, double scroll, double width, double y, double time) {
  if (season == Season.none) return;
  const gap = 64.0;
  final start = -(scroll % gap);
  final string = Path()..moveTo(start - gap, y);
  for (double x = start - gap; x < width + gap; x += gap) {
    string.quadraticBezierTo(x + gap / 2, y + 16, x + gap, y);
  }
  c.drawPath(string, _st(const Color(0xFF6B5A4A), 1.6));
  int i = ((scroll / gap).floor());
  for (double x = start; x < width + gap; x += gap, i++) {
    final p = Offset(x + gap / 2, y + 14 + sin(time * 2 + i) * 2);
    if (season == Season.yalda) {
      if (i.isEven) {
        // pomegranate
        c.drawCircle(p + const Offset(0, 12), 11, _p(const Color(0xFFC62828)));
        c.drawPath(starPath(p + const Offset(0, 1), 4), _p(const Color(0xFF8E1B1B)));
        c.drawCircle(p + const Offset(-4, 8), 3, _p(const Color(0x55FFFFFF)));
      } else {
        // watermelon slice
        final slice = Path()
          ..moveTo(p.dx - 13, p.dy + 4)
          ..arcToPoint(Offset(p.dx + 13, p.dy + 4), radius: const Radius.circular(13), clockwise: false)
          ..close();
        c.drawPath(slice, _p(const Color(0xFF2E9B4E)));
        final inner = Path()
          ..moveTo(p.dx - 10, p.dy + 4)
          ..arcToPoint(Offset(p.dx + 10, p.dy + 4), radius: const Radius.circular(10), clockwise: false)
          ..close();
        c.drawPath(inner, _p(const Color(0xFFFF4F5E)));
        for (int k = -1; k <= 1; k++) {
          c.drawCircle(Offset(p.dx + k * 5, p.dy + 10), 1.4, _p(C.ink));
        }
      }
    } else {
      // Nowruz: painted eggs and spring flowers
      if (i.isEven) {
        const eggColors = [Color(0xFF8E5BD6), Color(0xFF26C6BE), Color(0xFFFFB300), Color(0xFFFF5C8A)];
        final egg = Rect.fromCenter(center: p + const Offset(0, 12), width: 16, height: 21);
        c.drawOval(egg, _p(eggColors[(i ~/ 2) % eggColors.length]));
        c.drawLine(Offset(egg.left + 2, egg.center.dy), Offset(egg.right - 2, egg.center.dy), _st(Colors.white, 2));
      } else {
        for (int k = 0; k < 5; k++) {
          final a = k * 2 * pi / 5;
          c.drawCircle(p + Offset(cos(a) * 5, 10 + sin(a) * 5), 4, _p(const Color(0xFFFF8FB1)));
        }
        c.drawCircle(p + const Offset(0, 10), 3, _p(const Color(0xFFFFD34D)));
      }
    }
  }
}
