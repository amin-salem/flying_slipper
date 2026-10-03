import 'dart:math';

import 'package:flutter/material.dart';

import '../theme.dart';
import 'world.dart' show Ability;
import 'cosmetics.dart';

enum Rarity { common, rare, epic, legendary }

extension RarityInfo on Rarity {
  String get label => const ['عادی', 'کمیاب', 'حماسی', 'افسانه‌ای'][index];
  Color get color =>
      const [Color(0xFF8C7D99), C.blueDark, C.purpleDark, C.goldEdge][index];
  List<Color> get bg => const [
        [Color(0xFFF4ECF7), Color(0xFFE6DAEE)],
        [Color(0xFFDDEEFF), Color(0xFFB9D9FF)],
        [Color(0xFFEDE2FF), Color(0xFFD2BCFF)],
        [Color(0xFFFFF1C4), Color(0xFFFFD877)],
      ][index];
}

enum Hair { spiky, pigtails, neat, headband, curly, nightcap, hero }

enum Extra { none, backpack, glasses, goldfish, cape }

enum Mood { scared, happy, hurt, cool, sleepy }

class Character {
  const Character({
    required this.id,
    required this.name,
    required this.desc,
    required this.rarity,
    required this.price,
    required this.shirt,
    required this.pants,
    required this.shoes,
    required this.hair,
    required this.hairColor,
    this.extras = const [],
    this.vest,
    this.stripes,
    this.number,
    this.runMood = Mood.scared,
    this.ability = const Ability(),
    this.abilityName = 'بدون قدرت ویژه',
    this.abilityDesc = 'شیطون، ولی معمولی!',
    this.abilityIcon = Icons.sentiment_satisfied_alt_rounded,
  });

  final String id;
  final String name;
  final String desc;
  final Rarity rarity;
  final int price; // coins
  final Color shirt;
  final Color pants;
  final Color shoes;
  final Hair hair;
  final Color hairColor;
  final List<Extra> extras;
  final Color? vest;
  final Color? stripes;
  final String? number;
  final Mood runMood;

  /// What makes this kid special in the game (shown in the shop).
  final Ability ability;
  final String abilityName;
  final String abilityDesc;
  final IconData abilityIcon;
}

const List<Character> kCharacters = [
  Character(
    id: 'ali',
    name: 'علی شیطون',
    desc: 'همیشه یه خرابکاری کرده!',
    rarity: Rarity.common,
    price: 0,
    shirt: Color(0xFFFF8A3D),
    pants: Color(0xFF2E3A73),
    shoes: Color(0xFFFF4D4D),
    hair: Hair.spiky,
    hairColor: Color(0xFF3A2416),
  ),
  Character(
    id: 'sara',
    name: 'سارا',
    desc: 'سریع‌ترین دختر کوچه',
    rarity: Rarity.common,
    price: 1200,
    shirt: Color(0xFFFF6FA8),
    pants: Color(0xFF6C3FB5),
    shoes: Color(0xFFFFFFFF),
    hair: Hair.pigtails,
    hairColor: Color(0xFF2A1A12),
    ability: Ability(airJumps: 1),
    abilityName: 'پرش دوبل',
    abilityDesc: 'وسط هوا یه بار دیگه بپر!',
    abilityIcon: Icons.keyboard_double_arrow_up_rounded,
  ),
  Character(
    id: 'omid',
    name: 'امید درس‌خون',
    desc: 'فقط عینکش نیفته!',
    rarity: Rarity.rare,
    price: 1500,
    shirt: Color(0xFF7D93B5),
    pants: Color(0xFF2C3550),
    shoes: Color(0xFF3A2A20),
    hair: Hair.neat,
    hairColor: Color(0xFF241812),
    extras: [Extra.glasses, Extra.backpack],
    ability: Ability(warnBonus: 1.45),
    abilityName: 'آینده‌نگر',
    abilityDesc: 'حمله‌ها رو خیلی زودتر می‌بینه',
    abilityIcon: Icons.visibility_rounded,
  ),
  Character(
    id: 'pajama',
    name: 'خواب‌آلو',
    desc: 'هنوز از خواب بیدار نشده',
    rarity: Rarity.rare,
    price: 2500,
    shirt: Color(0xFF8EC5FF),
    pants: Color(0xFF8EC5FF),
    shoes: Color(0xFF9B6B4A),
    hair: Hair.nightcap,
    hairColor: Color(0xFF5A3A22),
    stripes: Color(0xFF3F7FD6),
    runMood: Mood.sleepy,
    ability: Ability(speedMul: 0.85),
    abilityName: 'دنیای آهسته',
    abilityDesc: 'همه چی ۱۵٪ آروم‌تره',
    abilityIcon: Icons.bedtime_rounded,
  ),
  Character(
    id: 'football',
    name: 'گل‌زن محله',
    desc: 'توپ رو شکوند به شیشه!',
    rarity: Rarity.rare,
    price: 3000,
    shirt: Color(0xFFE53935),
    pants: Color(0xFFFFFFFF),
    shoes: Color(0xFF26C6BE),
    hair: Hair.headband,
    hairColor: Color(0xFF3A2416),
    number: '۱۰',
    runMood: Mood.happy,
    ability: Ability(kickCooldown: 10),
    abilityName: 'شوت',
    abilityDesc: 'هر ۱۰ ثانیه یه مانع رو شوت می‌کنه',
    abilityIcon: Icons.sports_soccer_rounded,
  ),
  Character(
    id: 'nowruz',
    name: 'بچه عید',
    desc: 'لباس نو، ماهی قرمز، فرار!',
    rarity: Rarity.epic,
    price: 6000,
    shirt: Color(0xFFFFFFFF),
    pants: Color(0xFF3A3A4A),
    shoes: Color(0xFF1E1E28),
    hair: Hair.curly,
    hairColor: Color(0xFF2A1A12),
    vest: Color(0xFF1FA463),
    extras: [Extra.goldfish],
    runMood: Mood.happy,
    ability: Ability(coinMul: 2),
    abilityName: 'عیدی',
    abilityDesc: 'هر سکه دوتا حساب میشه!',
    abilityIcon: Icons.redeem_rounded,
  ),
  Character(
    id: 'hero',
    name: 'ابرپسر',
    desc: 'حتی ابرقهرمان‌ها هم از دمپایی می‌ترسن',
    rarity: Rarity.legendary,
    price: 10000,
    shirt: Color(0xFF2F6BFF),
    pants: Color(0xFF2F6BFF),
    shoes: Color(0xFFE53935),
    hair: Hair.hero,
    hairColor: Color(0xFF1C1410),
    extras: [Extra.cape],
    runMood: Mood.cool,
    ability: Ability(glide: true, startShield: true),
    abilityName: 'پرواز',
    abilityDesc: 'نگه دار تا پرواز کنی + سپر اول هر بازی',
    abilityIcon: Icons.flight_rounded,
  ),
];

/// Power levels: every kid's power can be upgraded twice with coins.
const List<int> kUpgradeCost = [0, 2000, 5000]; // cost to reach level 1, 2, 3

extension CharacterPower on Character {
  bool get upgradable => !ability.isNone;

  /// The power at [level] (1..3).
  Ability abilityAt(int level) {
    final l = level < 1 ? 1 : (level > 3 ? 3 : level);
    switch (id) {
      case 'sara':
        return [
          const Ability(airJumps: 1),
          const Ability(airJumps: 2),
          const Ability(airJumps: 2, startShield: true),
        ][l - 1];
      case 'omid':
        return [
          const Ability(warnBonus: 1.45),
          const Ability(warnBonus: 1.75),
          const Ability(warnBonus: 2.1),
        ][l - 1];
      case 'pajama':
        return [
          const Ability(speedMul: 0.85),
          const Ability(speedMul: 0.8),
          const Ability(speedMul: 0.75),
        ][l - 1];
      case 'football':
        return [
          const Ability(kickCooldown: 10),
          const Ability(kickCooldown: 7),
          const Ability(kickCooldown: 5),
        ][l - 1];
      case 'nowruz':
        return [
          const Ability(coinMul: 2),
          const Ability(coinMul: 2, magnet: 120),
          const Ability(coinMul: 3, magnet: 120),
        ][l - 1];
      case 'hero':
        return [
          const Ability(glide: true, startShield: true),
          const Ability(glide: true, glideFall: 110, startShield: true),
          const Ability(glide: true, glideFall: 110, startShield: true, shieldRegen: 25),
        ][l - 1];
      default:
        return ability;
    }
  }

  /// What the power does at [level] (1..3), in Persian.
  String descAt(int level) {
    final l = level < 1 ? 1 : (level > 3 ? 3 : level);
    switch (id) {
      case 'sara':
        return ['وسط هوا یه بار دیگه بپر', 'پرش سه‌تایی!', 'پرش سه‌تایی + سپر اول بازی'][l - 1];
      case 'omid':
        return ['حمله‌ها رو ۴۵٪ زودتر می‌بینه', '۷۵٪ زودتر', 'دوبرابر زودتر!'][l - 1];
      case 'pajama':
        return ['همه چی ۱۵٪ آروم‌تره', '۲۰٪ آروم‌تر', '۲۵٪ آروم‌تر'][l - 1];
      case 'football':
        return ['هر ۱۰ ثانیه یه شوت', 'هر ۷ ثانیه یه شوت', 'هر ۵ ثانیه یه شوت!'][l - 1];
      case 'nowruz':
        return ['هر سکه دوتا حساب میشه', 'سکه دوبرابر + آهنربای سکه', 'سکه سه‌برابر + آهنربا!'][l - 1];
      case 'hero':
        return ['پرواز + سپر اول بازی', 'پرواز آروم‌تر + سپر', 'پرواز + سپر هر ۲۵ ثانیه برمی‌گرده'][l - 1];
      default:
        return abilityDesc;
    }
  }
}

Character characterById(String id) =>
    kCharacters.firstWhere((c) => c.id == id, orElse: () => kCharacters.first);

// ---------------------------------------------------------------------------
// Drawing helpers
// ---------------------------------------------------------------------------

const double _ow = 2.6; // outline width (in character units)

Paint _f(Color c) => Paint()
  ..color = c
  ..isAntiAlias = true;

Paint _s(Color c, double w) => Paint()
  ..color = c
  ..style = PaintingStyle.stroke
  ..strokeWidth = w
  ..strokeCap = StrokeCap.round
  ..strokeJoin = StrokeJoin.round;

final Paint _outline = _s(C.ink, _ow);

void _fillOutline(Canvas c, Path p, Color color) {
  c.drawPath(p, _f(color));
  c.drawPath(p, _outline);
}

/// A limb drawn as an outlined thick line through [pts].
void _limb(Canvas c, List<Offset> pts, Color color, double w) {
  final path = Path()..moveTo(pts.first.dx, pts.first.dy);
  for (final p in pts.skip(1)) {
    path.lineTo(p.dx, p.dy);
  }
  c.drawPath(path, _s(C.ink, w + _ow * 2));
  c.drawPath(path, _s(color, w));
}

Offset _polar(double len, double angle) =>
    Offset(sin(angle) * len, cos(angle) * len);

/// Draws a character. [feet] = point on the floor under the feet.
/// The character is ~105 units tall at scale 1 and faces right.
void drawCharacter(
  Canvas canvas,
  Character ch,
  Offset feet,
  double scale, {
  double phase = 0,
  bool airborne = false,
  double squashX = 1,
  double squashY = 1,
  double tilt = 0,
  Mood? mood,
  double time = 0,
  bool blink = false,
  bool gliding = false,
  double spin = 0,
}) {
  final m = mood ?? ch.runMood;
  canvas.save();
  canvas.translate(feet.dx, feet.dy);
  canvas.scale(scale * squashX, scale * squashY);
  canvas.rotate(tilt);
  if (spin != 0) {
    // somersault around the middle of the body
    canvas.translate(0, -50);
    canvas.rotate(spin);
    canvas.translate(0, 50);
  }

  // ---- Running cycle ----
  double legA, legB, kneeA, kneeB, armA, armB;
  if (gliding) {
    legA = -0.5; // legs trail behind like a flying hero
    kneeA = -0.2;
    legB = -0.8;
    kneeB = -0.2;
    armA = 1.9; // fist forward
    armB = -1.4;
  } else if (airborne) {
    legA = 0.9; // front leg tucked
    kneeA = -1.4;
    legB = -0.6; // back leg stretched
    kneeB = -0.3;
    armA = -2.4; // arms up (panic!)
    armB = 2.2;
  } else {
    final s = sin(phase);
    legA = s * 0.85;
    legB = -s * 0.85;
    kneeA = -0.9 * (0.5 - 0.5 * cos(phase));
    kneeB = -0.9 * (0.5 + 0.5 * cos(phase));
    armA = -s * 1.0;
    armB = s * 1.0;
  }

  const hipA = Offset(4, -32);
  const hipB = Offset(-3, -32);
  const shoulderA = Offset(8, -51);
  const shoulderB = Offset(-6, -51);

  void leg(Offset hip, double a, double knee) {
    final k = hip + _polar(14, a);
    final f = k + _polar(14, a + knee);
    _limb(canvas, [hip, k, f], ch.pants, 9);
    // shoe
    canvas.save();
    canvas.translate(f.dx, f.dy);
    canvas.rotate(-(a + knee) * 0.6);
    final shoe = RRect.fromRectAndRadius(
        const Rect.fromLTWH(-5, -3, 15, 8), const Radius.circular(4));
    canvas.drawRRect(shoe, _f(ch.shoes));
    canvas.drawRRect(shoe, _outline);
    canvas.drawLine(const Offset(-3, 3.5), const Offset(9, 3.5),
        _s(const Color(0x55FFFFFF), 2));
    canvas.restore();
  }

  void arm(Offset sh, double a, {bool front = false}) {
    final e = sh + _polar(11, a);
    final h = e + _polar(10, a + (airborne ? 0.3 : 1.2));
    _limb(canvas, [sh, e], ch.shirt, 8);
    _limb(canvas, [e, h], C.skin, 7);
    canvas.drawCircle(h, 4.6, _f(C.skin));
    canvas.drawCircle(h, 4.6, _outline);
    if (front && ch.extras.contains(Extra.goldfish)) _goldfish(canvas, h, time);
  }

  // ---- Cape (behind everything) ----
  if (ch.extras.contains(Extra.cape) && gliding) {
    final wave = sin(time * 14) * 5;
    final cape = Path()
      ..moveTo(-8, -54)
      ..quadraticBezierTo(-40, -70 + wave, -76, -52 - wave)
      ..quadraticBezierTo(-56, -36 + wave, -64, -20)
      ..quadraticBezierTo(-30, -30, 6, -50)
      ..close();
    _fillOutline(canvas, cape, const Color(0xFFE53935));
  } else if (ch.extras.contains(Extra.cape)) {
    final wave = sin(time * 9) * 4;
    final cape = Path()
      ..moveTo(-8, -54)
      ..quadraticBezierTo(-30, -40 + wave, -44, -18 - wave)
      ..quadraticBezierTo(-30, -14 + wave, -20, -12)
      ..quadraticBezierTo(-12, -30, 6, -54)
      ..close();
    _fillOutline(canvas, cape, const Color(0xFFE53935));
  }

  // ---- Back limbs ----
  arm(shoulderB, armB);
  leg(hipB, legB, kneeB);

  // ---- Backpack ----
  if (ch.extras.contains(Extra.backpack)) {
    final bp = RRect.fromRectAndRadius(
        const Rect.fromLTWH(-24, -55, 14, 24), const Radius.circular(6));
    canvas.drawRRect(bp, _f(const Color(0xFFFFB531)));
    canvas.drawRRect(bp, _outline);
    canvas.drawLine(const Offset(-22, -44), const Offset(-12, -44),
        _s(const Color(0xFFC07A0E), 2.5));
  }

  // ---- Body ----
  final torso = RRect.fromRectAndRadius(
      const Rect.fromLTWH(-12, -57, 25, 30), const Radius.circular(10));
  canvas.drawRRect(torso, _f(ch.shirt));
  if (ch.stripes != null) {
    canvas.save();
    canvas.clipRRect(torso);
    for (double y = -54; y < -26; y += 6) {
      canvas.drawLine(Offset(-14, y), Offset(15, y), _s(ch.stripes!, 2.5));
    }
    canvas.restore();
  }
  if (ch.vest != null) {
    canvas.save();
    canvas.clipRRect(torso);
    final v1 = Path()
      ..moveTo(-12, -57)
      ..lineTo(2, -57)
      ..lineTo(-2, -27)
      ..lineTo(-12, -27)
      ..close();
    final v2 = Path()
      ..moveTo(13, -57)
      ..lineTo(8, -57)
      ..lineTo(11, -27)
      ..lineTo(13, -27)
      ..close();
    canvas.drawPath(v1, _f(ch.vest!));
    canvas.drawPath(v2, _f(ch.vest!));
    canvas.drawLine(const Offset(2, -57), const Offset(-2, -27), _s(C.gold, 2));
    canvas.drawLine(const Offset(8, -57), const Offset(11, -27), _s(C.gold, 2));
    canvas.restore();
  }
  // belt line / pants top
  canvas.save();
  canvas.clipRRect(torso);
  canvas.drawRect(const Rect.fromLTWH(-13, -32, 27, 6), _f(ch.pants));
  canvas.restore();
  canvas.drawRRect(torso, _outline);
  if (ch.number != null) {
    final tp = TextPainter(
      text: TextSpan(
          text: ch.number,
          style: const TextStyle(
              fontFamily: 'Vazirmatn',
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: C.white)),
      textDirection: TextDirection.rtl,
    )..layout();
    tp.paint(canvas, Offset(0.5 - tp.width / 2, -52));
  }
  if (ch.extras.contains(Extra.backpack)) {
    canvas.drawLine(const Offset(-10, -55), const Offset(-4, -32),
        _s(const Color(0xFFC07A0E), 3));
  }

  // ---- Head ----
  const hc = Offset(3, -75);
  const r = 22.0;

  // hair behind the head
  if (ch.hair == Hair.pigtails) {
    for (final o in const [Offset(-21, -70), Offset(-15, -60)]) {
      final tail = Path()..addOval(Rect.fromCircle(center: o, radius: 8.5));
      _fillOutline(canvas, tail, ch.hairColor);
    }
    final bow = Path()
      ..moveTo(-16, -78)
      ..lineTo(-24, -84)
      ..lineTo(-24, -72)
      ..close()
      ..moveTo(-16, -78)
      ..lineTo(-8, -84)
      ..lineTo(-8, -72)
      ..close();
    _fillOutline(canvas, bow, const Color(0xFFFF4D8D));
  }

  // neck
  canvas.drawRect(const Rect.fromLTWH(-1, -58, 7, 6), _f(C.skinShade));
  // head
  final head = Path()..addOval(Rect.fromCircle(center: hc, radius: r));
  _fillOutline(canvas, head, C.skin);
  // ear
  final ear = Path()..addOval(Rect.fromCircle(center: hc + const Offset(-7, 3), radius: 5));
  _fillOutline(canvas, ear, C.skin);

  // hero mask (under the eyes)
  if (ch.hair == Hair.hero) {
    final mask = RRect.fromRectAndRadius(
        Rect.fromLTWH(hc.dx - 1, hc.dy - 7, 25, 11), const Radius.circular(5));
    canvas.drawRRect(mask, _f(const Color(0xFFE53935)));
    canvas.drawRRect(mask, _outline);
    canvas.drawLine(Offset(hc.dx - 1, hc.dy - 2), Offset(hc.dx - 18, hc.dy + 2),
        _s(const Color(0xFFE53935), 3));
  }

  _face(canvas, hc, m, blink: blink);

  // hair on top
  _hair(canvas, ch, hc, r, time);

  if (ch.extras.contains(Extra.glasses)) {
    final g = _s(C.ink, 2.2);
    canvas.drawCircle(hc + const Offset(7, 0), 6, g);
    canvas.drawCircle(hc + const Offset(18, 0), 5.5, g);
    canvas.drawLine(hc + const Offset(12.5, -1), hc + const Offset(13, -1), g);
    canvas.drawLine(hc + const Offset(1, -1), hc + const Offset(-8, -3), g);
    canvas.drawCircle(hc + const Offset(5, -2), 1.6, _f(const Color(0xAAFFFFFF)));
  }

  // ---- Front limbs ----
  leg(hipA, legA, kneeA);
  arm(shoulderA, armA, front: true);

  // sweat drop when scared
  if (m == Mood.scared) {
    final d = Path()
      ..moveTo(-16, -100)
      ..quadraticBezierTo(-11, -91, -16, -88)
      ..quadraticBezierTo(-21, -91, -16, -100)
      ..close();
    canvas.drawPath(d, _f(const Color(0xFFA8E6FF)));
    canvas.drawPath(d, _s(C.ink, 1.6));
  }
  if (m == Mood.sleepy) {
    _zzz(canvas, hc + const Offset(-12, -34), time);
  }

  canvas.restore();
}

void _face(Canvas c, Offset hc, Mood m, {bool blink = false}) {
  final e1 = hc + const Offset(7, 0);
  final e2 = hc + const Offset(18, 0);

  // blush
  c.drawOval(Rect.fromCenter(center: hc + const Offset(4, 9), width: 8, height: 5),
      _f(const Color(0x66FF6F8A)));
  c.drawOval(Rect.fromCenter(center: hc + const Offset(20, 9), width: 6, height: 5),
      _f(const Color(0x66FF6F8A)));

  if (m == Mood.hurt) {
    final x = _s(C.ink, 2.4);
    for (final e in [e1, e2]) {
      c.drawLine(e + const Offset(-3.5, -3.5), e + const Offset(3.5, 3.5), x);
      c.drawLine(e + const Offset(-3.5, 3.5), e + const Offset(3.5, -3.5), x);
    }
    final w = Path()
      ..moveTo(hc.dx + 6, hc.dy + 12)
      ..quadraticBezierTo(hc.dx + 9, hc.dy + 9, hc.dx + 12, hc.dy + 12)
      ..quadraticBezierTo(hc.dx + 15, hc.dy + 15, hc.dx + 18, hc.dy + 12);
    c.drawPath(w, _s(C.ink, 2.2));
    return;
  }

  if (m == Mood.happy) {
    final a = _s(C.ink, 2.6);
    for (final e in [e1, e2]) {
      c.drawArc(Rect.fromCenter(center: e + const Offset(0, 1.5), width: 8, height: 7),
          pi, pi, false, a);
    }
    final mouth = Path()
      ..moveTo(hc.dx + 6, hc.dy + 9)
      ..quadraticBezierTo(hc.dx + 13, hc.dy + 19, hc.dx + 20, hc.dy + 9)
      ..close();
    c.drawPath(mouth, _f(const Color(0xFF8A2A2A)));
    c.drawPath(mouth, _s(C.ink, 2));
    return;
  }

  // eyes (scared / cool / sleepy)
  final lid = m == Mood.cool ? 0.45 : (m == Mood.sleepy ? 0.6 : 0.0);
  for (final e in [e1, e2]) {
    final size = e == e1 ? const Size(9, 11) : const Size(8, 10);
    final rect = Rect.fromCenter(center: e, width: size.width, height: size.height);
    if (blink) {
      c.drawLine(e + const Offset(-4, 0), e + const Offset(4, 0), _s(C.ink, 2.4));
      continue;
    }
    c.drawOval(rect, _f(C.white));
    c.drawOval(rect, _s(C.ink, 2));
    c.drawCircle(e + const Offset(1.4, 0.6), 2.8, _f(C.ink));
    c.drawCircle(e + const Offset(0.4, -1.3), 1.1, _f(C.white));
    if (lid > 0) {
      c.save();
      c.clipRect(Rect.fromLTWH(rect.left - 1, rect.top - 1, rect.width + 2,
          rect.height * lid + 1));
      c.drawOval(rect, _f(C.skin));
      c.restore();
      c.drawLine(Offset(rect.left, rect.top + rect.height * lid),
          Offset(rect.right, rect.top + rect.height * lid), _s(C.ink, 2.2));
    }
  }

  if (m == Mood.scared) {
    // worried brows
    c.drawLine(e1 + const Offset(-4, -8), e1 + const Offset(3, -10), _s(C.ink, 2.4));
    c.drawLine(e2 + const Offset(4, -8), e2 + const Offset(-3, -10), _s(C.ink, 2.4));
    final mouth = Rect.fromCenter(
        center: hc + const Offset(13, 12), width: 8, height: 10);
    c.drawOval(mouth, _f(const Color(0xFF8A2A2A)));
    c.drawOval(
        Rect.fromCenter(center: hc + const Offset(13, 15), width: 5, height: 4),
        _f(const Color(0xFFFF8A8A)));
    c.drawOval(mouth, _s(C.ink, 2));
  } else if (m == Mood.cool) {
    c.drawLine(e1 + const Offset(-4, -8), e1 + const Offset(4, -7), _s(C.ink, 2.6));
    c.drawLine(e2 + const Offset(-3, -7), e2 + const Offset(4, -8), _s(C.ink, 2.6));
    final smirk = Path()
      ..moveTo(hc.dx + 8, hc.dy + 12)
      ..quadraticBezierTo(hc.dx + 15, hc.dy + 15, hc.dx + 20, hc.dy + 9);
    c.drawPath(smirk, _s(C.ink, 2.4));
  } else {
    // sleepy
    c.drawOval(
        Rect.fromCenter(center: hc + const Offset(13, 12), width: 6, height: 4),
        _f(const Color(0xFF8A2A2A)));
  }
}

void _hair(Canvas c, Character ch, Offset hc, double r, double time) {
  final color = ch.hairColor;
  Path cap({double fringeY = -6}) {
    final p = Path()
      ..moveTo(hc.dx + cos(pi * 0.92) * (r + 2), hc.dy + sin(pi * 0.92) * (r + 2))
      ..arcTo(Rect.fromCircle(center: hc, radius: r + 2), pi * 0.92, pi * 1.0,
          false)
      ..quadraticBezierTo(hc.dx + 12, hc.dy + fringeY - 4, hc.dx + 2, hc.dy + fringeY)
      ..quadraticBezierTo(hc.dx - 8, hc.dy + fringeY + 2, hc.dx - 12, hc.dy + 4)
      ..close();
    return p;
  }

  switch (ch.hair) {
    case Hair.spiky:
      final p = Path();
      const n = 7;
      const a0 = pi * 0.95;
      const a1 = pi * 1.98;
      for (int k = 0; k <= n * 2; k++) {
        final a = a0 + (a1 - a0) * k / (n * 2);
        final rr = k.isOdd ? r + 9 : r + 1;
        final pt = hc + Offset(cos(a) * rr, sin(a) * rr);
        if (k == 0) {
          p.moveTo(pt.dx, pt.dy);
        } else {
          p.lineTo(pt.dx, pt.dy);
        }
      }
      p
        ..quadraticBezierTo(hc.dx + 10, hc.dy - 12, hc.dx, hc.dy - 8)
        ..quadraticBezierTo(hc.dx - 10, hc.dy - 4, hc.dx - 14, hc.dy + 4)
        ..close();
      _fillOutline(c, p, color);
      break;
    case Hair.pigtails:
    case Hair.neat:
    case Hair.hero:
      _fillOutline(c, cap(), color);
      // shine
      c.drawArc(Rect.fromCircle(center: hc, radius: r - 4), pi * 1.25, pi * 0.3,
          false, _s(const Color(0x40FFFFFF), 3));
      break;
    case Hair.headband:
      _fillOutline(c, cap(fringeY: -8), color);
      final band = _s(C.white, 6);
      c.drawArc(Rect.fromCircle(center: hc, radius: r - 2), pi * 1.08, pi * 0.86,
          false, _s(C.ink, 6 + _ow * 2));
      c.drawArc(Rect.fromCircle(center: hc, radius: r - 2), pi * 1.08, pi * 0.86,
          false, band);
      final flutter = sin(time * 14) * 3;
      c.drawLine(hc + Offset(-r + 1, -4), hc + Offset(-r - 12, 2 + flutter),
          _s(C.white, 4));
      c.drawLine(hc + Offset(-r + 1, -2), hc + Offset(-r - 9, 8 - flutter),
          _s(C.white, 4));
      break;
    case Hair.curly:
      for (int k = 0; k < 8; k++) {
        final a = pi * 0.95 + k * pi * 1.0 / 7;
        final o = hc + Offset(cos(a) * (r - 1), sin(a) * (r - 1));
        final curl = Path()..addOval(Rect.fromCircle(center: o, radius: 7.5));
        _fillOutline(c, curl, color);
      }
      final top = Path()..addOval(Rect.fromCircle(center: hc + const Offset(-2, -10), radius: 15));
      c.drawPath(top, _f(color));
      break;
    case Hair.nightcap:
      _fillOutline(c, cap(), color);
      final droop = sin(time * 6) * 3;
      final hat = Path()
        ..moveTo(hc.dx - r - 2, hc.dy - 4)
        ..quadraticBezierTo(hc.dx - 4, hc.dy - r - 14, hc.dx + r - 2, hc.dy - 8)
        ..quadraticBezierTo(hc.dx - 6, hc.dy - r - 6, hc.dx - r - 16, hc.dy + 6 + droop)
        ..close();
      _fillOutline(c, hat, const Color(0xFF3F7FD6));
      final pom = Path()
        ..addOval(Rect.fromCircle(
            center: Offset(hc.dx - r - 16, hc.dy + 8 + droop), radius: 5.5));
      _fillOutline(c, pom, C.white);
      break;
  }
}

void _goldfish(Canvas c, Offset hand, double time) {
  final swing = sin(time * 8) * 0.25;
  c.save();
  c.translate(hand.dx, hand.dy);
  c.rotate(swing);
  c.drawLine(Offset.zero, const Offset(0, 6), _s(C.ink, 1.6));
  final bag = Path()
    ..moveTo(-3, 6)
    ..quadraticBezierTo(-12, 16, -6, 24)
    ..quadraticBezierTo(0, 28, 6, 24)
    ..quadraticBezierTo(12, 16, 3, 6)
    ..close();
  c.drawPath(bag, _f(const Color(0x88BFEFFF)));
  c.drawPath(bag, _s(C.ink, 1.6));
  final fish = Path()
    ..addOval(Rect.fromCenter(center: const Offset(0, 18), width: 8, height: 5));
  c.drawPath(fish, _f(const Color(0xFFFF6A1F)));
  final tail = Path()
    ..moveTo(-4, 18)
    ..lineTo(-8, 15)
    ..lineTo(-8, 21)
    ..close();
  c.drawPath(tail, _f(const Color(0xFFFF6A1F)));
  c.restore();
}

void _zzz(Canvas c, Offset at, double time) {
  for (int k = 0; k < 2; k++) {
    final tt = (time * 0.8 + k * 0.5) % 1.0;
    final tp = TextPainter(
      text: TextSpan(
          text: 'z',
          style: TextStyle(
              fontSize: 9 + tt * 7,
              fontWeight: FontWeight.w900,
              color: C.inkSoft.withAlpha((255 * (1 - tt)).round()))),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, at + Offset(-tt * 10, -tt * 16));
  }
}

// ---------------------------------------------------------------------------
// Mom
// ---------------------------------------------------------------------------

/// Mom, chasing from the left. [feet] is under her feet. ~160 units tall.
/// [windup] 0..1 raises the slipper; [release] 1..0 swings the arm forward.
void drawMom(
  Canvas c,
  Offset feet,
  double scale, {
  double time = 0,
  double windup = 0,
  double release = 0,
  double anger = 0.3,
  bool shouting = false,
  bool calm = false,
  double twirl = 0,
}) {
  c.save();
  final bob = -(sin(time * 11).abs()) * 4;
  c.translate(feet.dx, feet.dy + bob * scale);
  c.scale(scale);

  // feet: one slipper on, one bare (the other one is flying!)
  final step = sin(time * 11) * 6;
  final f1 = RRect.fromRectAndRadius(
      Rect.fromLTWH(-14 + step, -6, 18, 7), const Radius.circular(4));
  c.drawRRect(f1, _f(const Color(0xFF3F70C8)));
  c.drawRRect(f1, _outline);
  final f2 = RRect.fromRectAndRadius(
      Rect.fromLTWH(6 - step, -6, 14, 7), const Radius.circular(4));
  c.drawRRect(f2, _f(C.skin));
  c.drawRRect(f2, _outline);

  // back arm on hip
  _limb(c, const [Offset(-16, -92), Offset(-30, -70), Offset(-18, -58)],
      const Color(0xFF8E5BD6), 9);

  // long house dress with flowers
  final dress = Path()
    ..moveTo(-20, -98)
    ..quadraticBezierTo(0, -106, 20, -98)
    ..lineTo(30, -6)
    ..quadraticBezierTo(0, 0, -30, -6)
    ..close();
  _fillOutline(c, dress, const Color(0xFF8E5BD6));
  c.save();
  c.clipPath(dress);
  final flower = _f(const Color(0xFFFFC2E2));
  for (int i = 0; i < 12; i++) {
    final x = -26.0 + (i % 4) * 17 + (i ~/ 4).isOdd.toInt() * 8;
    final y = -88.0 + (i ~/ 4) * 28;
    for (int k = 0; k < 5; k++) {
      final a = k * 2 * pi / 5;
      c.drawCircle(Offset(x + cos(a) * 3, y + sin(a) * 3), 2.2, flower);
    }
    c.drawCircle(Offset(x, y), 1.6, _f(C.gold));
  }
  c.restore();
  // apron
  final apron = Path()
    ..moveTo(-2, -78)
    ..lineTo(22, -78)
    ..lineTo(26, -24)
    ..quadraticBezierTo(12, -18, 0, -24)
    ..close();
  _fillOutline(c, apron, const Color(0xFFFFF7EA));

  // head + headscarf (rosari)
  const hc = Offset(4, -124);
  final scarf = Path()
    ..addOval(Rect.fromCircle(center: hc + const Offset(-2, -2), radius: 31))
    ..moveTo(hc.dx - 6, hc.dy + 26)
    ..lineTo(hc.dx + 4, hc.dy + 44)
    ..lineTo(hc.dx + 14, hc.dy + 24)
    ..close();
  _fillOutline(c, scarf, const Color(0xFFFF5C8A));
  c.save();
  c.clipPath(scarf);
  for (int i = 0; i < 14; i++) {
    final a = i * 0.9;
    c.drawCircle(hc + Offset(cos(a) * (12 + (i % 3) * 7), sin(a) * (12 + (i % 3) * 7) - 4),
        2.4, _f(const Color(0xFFFFE3EC)));
  }
  c.restore();
  final face = Path()
    ..addOval(Rect.fromCenter(center: hc + const Offset(8, 4), width: 38, height: 42));
  _fillOutline(c, face, const Color(0xFFF2C29A));

  final e1 = hc + const Offset(3, 1);
  final e2 = hc + const Offset(16, 1);
  if (calm) {
    c.drawArc(Rect.fromCenter(center: e1, width: 7, height: 6), pi, pi, false, _s(C.ink, 2.4));
    c.drawArc(Rect.fromCenter(center: e2, width: 7, height: 6), pi, pi, false, _s(C.ink, 2.4));
    c.drawArc(Rect.fromCenter(center: hc + const Offset(10, 14), width: 10, height: 6),
        0, pi, false, _s(C.ink, 2.4));
  } else {
    for (final e in [e1, e2]) {
      c.drawOval(Rect.fromCenter(center: e, width: 7, height: 8), _f(C.white));
      c.drawOval(Rect.fromCenter(center: e, width: 7, height: 8), _s(C.ink, 1.8));
      c.drawCircle(e + const Offset(1.2, 0.8), 2.2, _f(C.ink));
    }
    // angry brows
    c.drawLine(e1 + const Offset(-5, -9), e1 + const Offset(4, -5), _s(C.ink, 3.4));
    c.drawLine(e2 + const Offset(5, -9), e2 + const Offset(-4, -5), _s(C.ink, 3.4));
    if (shouting) {
      final mouth = Rect.fromCenter(center: hc + const Offset(10, 16), width: 12, height: 10);
      c.drawOval(mouth, _f(const Color(0xFF7A1F1F)));
      c.drawRect(Rect.fromLTWH(mouth.left + 2, mouth.top + 1, mouth.width - 4, 2.5),
          _f(C.white));
      c.drawOval(mouth, _s(C.ink, 2));
    } else {
      c.drawArc(Rect.fromCenter(center: hc + const Offset(10, 19), width: 12, height: 7),
          pi, pi, false, _s(C.ink, 2.6));
    }
  }
  // angry cheeks
  c.drawCircle(hc + const Offset(-4, 10), 4,
      _f(Color.fromARGB((60 + anger * 120).round(), 255, 80, 80)));
  c.drawCircle(hc + const Offset(22, 10), 3.4,
      _f(Color.fromARGB((60 + anger * 120).round(), 255, 80, 80)));

  // steam when very angry
  if (anger > 0.55 && !calm) {
    for (int k = 0; k < 3; k++) {
      final tt = (time * 1.4 + k / 3) % 1.0;
      final side = k.isEven ? -1 : 1;
      final p = hc + Offset(side * (20 + tt * 10), -30 - tt * 26);
      c.drawCircle(p, 4 + tt * 7,
          _f(Color.fromARGB((200 * (1 - tt)).round(), 255, 255, 255)));
    }
  }

  // throwing arm: twirls a slipper above her head, swings forward to throw
  const shoulder = Offset(14, -94);
  final throwing = release > 0.15;
  Offset elbow, hand;
  if (calm) {
    elbow = shoulder + const Offset(6, 18);
    hand = elbow + const Offset(10, 12);
  } else if (throwing) {
    final a = 0.5 + release * 2.4 - (1 - release) * 0.6;
    elbow = shoulder + Offset(sin(a) * 18, cos(a) * 18);
    hand = elbow + Offset(sin(a + 0.3) * 16, cos(a + 0.3) * 16);
  } else {
    final r = 6 + windup * 6;
    elbow = shoulder + const Offset(22, -34);
    hand = shoulder + Offset(8 + cos(twirl) * r, -76 + sin(twirl) * r * 0.5);
  }
  _limb(c, [shoulder, elbow, hand], const Color(0xFF8E5BD6), 9);
  c.drawCircle(hand, 5.5, _f(const Color(0xFFF2C29A)));
  c.drawCircle(hand, 5.5, _outline);
  c.restore();

  if (!calm && !throwing) {
    // the slipper spins around her hand (world space, same size as thrown ones)
    final orbit = Offset(cos(twirl) * 14, sin(twirl) * 7);
    final handWorld = feet + Offset(hand.dx * scale, (hand.dy + bob) * scale);
    drawSlipper(c, handWorld + orbit * scale + Offset(0, -10 * scale),
        52 * scale, twirl * 1.0);
  }
}

/// Dad: white tank top, striped pajama pants, big mustache, bald head,
/// twirling his belt like a lasso. ~175 units tall, faces right.
/// [reach] (local units) is where his hand goes while cracking the belt.
void drawDad(
  Canvas c,
  Offset feet,
  double scale, {
  double time = 0,
  double windup = 0,
  double twirl = 0,
  double anger = 0.3,
  bool shouting = false,
  bool calm = false,
  Offset? reach,
}) {
  c.save();
  final bob = -(sin(time * 10).abs()) * 5;
  c.translate(feet.dx, feet.dy + bob * scale);
  c.scale(scale);
  const skin = Color(0xFFE9B58C);
  const pants = Color(0xFF7D8AA6);

  // legs in striped pajama pants
  final step = sin(time * 10) * 7;
  for (final dx in [-12.0 + step, 10.0 - step]) {
    final leg = RRect.fromRectAndRadius(
        Rect.fromLTWH(dx - 8, -64, 17, 58), const Radius.circular(7));
    c.drawRRect(leg, _f(pants));
    c.save();
    c.clipRRect(leg);
    for (double y = -62; y < -6; y += 8) {
      c.drawLine(Offset(dx - 9, y), Offset(dx + 10, y), _s(const Color(0xFF5A6788), 2));
    }
    c.restore();
    c.drawRRect(leg, _outline);
    final shoe = RRect.fromRectAndRadius(
        Rect.fromLTWH(dx - 8, -8, 22, 8), const Radius.circular(4));
    c.drawRRect(shoe, _f(const Color(0xFF3F70C8)));
    c.drawRRect(shoe, _outline);
  }

  // back arm on hip
  _limb(c, const [Offset(-20, -112), Offset(-36, -88), Offset(-22, -74)], skin, 10);

  // big belly in a white tank top (rekabi)
  final belly = Path()
    ..moveTo(-22, -124)
    ..quadraticBezierTo(0, -130, 22, -124)
    ..quadraticBezierTo(40, -96, 30, -64)
    ..quadraticBezierTo(0, -54, -28, -64)
    ..quadraticBezierTo(-34, -96, -22, -124)
    ..close();
  _fillOutline(c, belly, const Color(0xFFF7F5F0));
  // arm holes & a little chest hair
  c.drawArc(Rect.fromCenter(center: const Offset(-18, -116), width: 14, height: 18),
      -pi / 2, pi, false, _s(C.ink, 2));
  for (int i = 0; i < 5; i++) {
    c.drawLine(Offset(-6.0 + i * 3, -124), Offset(-7.0 + i * 3, -119), _s(C.ink, 1.6));
  }
  // belt loops (no belt: it's in his hand!)
  c.drawLine(const Offset(-26, -66), const Offset(30, -66), _s(const Color(0xFF5A6788), 3));

  // head
  const hc = Offset(6, -148);
  final head = Path()..addOval(Rect.fromCircle(center: hc, radius: 26));
  _fillOutline(c, head, skin);
  // side hair (bald on top)
  for (final side in [-1.0, 1.0]) {
    final hair = Path()
      ..addOval(Rect.fromCenter(
          center: hc + Offset(side * 22, 2), width: 12, height: 22));
    c.drawPath(hair, _f(const Color(0xFF3B3B3B)));
  }
  // shiny bald spot
  c.drawOval(Rect.fromCenter(center: hc + const Offset(-6, -16), width: 14, height: 7),
      _f(const Color(0x88FFFFFF)));
  // red angry face
  c.drawOval(Rect.fromCircle(center: hc, radius: 24),
      _f(Color.fromARGB((anger * 70).round(), 255, 60, 60)));

  final e1 = hc + const Offset(2, -2);
  final e2 = hc + const Offset(17, -2);
  if (calm) {
    c.drawArc(Rect.fromCenter(center: e1, width: 8, height: 6), pi, pi, false, _s(C.ink, 2.6));
    c.drawArc(Rect.fromCenter(center: e2, width: 8, height: 6), pi, pi, false, _s(C.ink, 2.6));
  } else {
    for (final e in [e1, e2]) {
      c.drawOval(Rect.fromCenter(center: e, width: 8, height: 8), _f(C.white));
      c.drawOval(Rect.fromCenter(center: e, width: 8, height: 8), _s(C.ink, 1.8));
      c.drawCircle(e + const Offset(1.4, 0.6), 2.4, _f(C.ink));
    }
    // one thick angry unibrow
    final brow = Path()
      ..moveTo(e1.dx - 7, e1.dy - 10)
      ..lineTo(e1.dx + 6, e1.dy - 5)
      ..lineTo(e2.dx - 6, e2.dy - 5)
      ..lineTo(e2.dx + 7, e2.dy - 10);
    c.drawPath(brow, _s(C.ink, 4.2));
  }
  // nose
  c.drawOval(Rect.fromCenter(center: hc + const Offset(12, 6), width: 12, height: 10),
      _f(const Color(0xFFDDA27A)));
  // mouth (under the mustache)
  if (shouting && !calm) {
    final mouth = Rect.fromCenter(center: hc + const Offset(11, 19), width: 14, height: 10);
    c.drawOval(mouth, _f(const Color(0xFF7A1F1F)));
    c.drawOval(mouth, _s(C.ink, 2));
  }
  // the famous Iranian dad mustache
  final stache = Path()
    ..moveTo(hc.dx - 6, hc.dy + 14)
    ..quadraticBezierTo(hc.dx + 2, hc.dy + 6, hc.dx + 11, hc.dy + 11)
    ..quadraticBezierTo(hc.dx + 20, hc.dy + 6, hc.dx + 28, hc.dy + 14)
    ..quadraticBezierTo(hc.dx + 20, hc.dy + 18, hc.dx + 11, hc.dy + 14)
    ..quadraticBezierTo(hc.dx + 2, hc.dy + 18, hc.dx - 6, hc.dy + 14)
    ..close();
  c.drawPath(stache, _f(const Color(0xFF1E1A18)));
  // ear
  final ear = Path()..addOval(Rect.fromCircle(center: hc + const Offset(-14, 2), radius: 6));
  _fillOutline(c, ear, skin);

  // steam when very angry
  if (anger > 0.55 && !calm) {
    for (int k = 0; k < 3; k++) {
      final tt = (time * 1.4 + k / 3) % 1.0;
      final side = k.isEven ? -1 : 1;
      final p = hc + Offset(side * (18 + tt * 10), -32 - tt * 26);
      c.drawCircle(p, 4 + tt * 7,
          _f(Color.fromARGB((200 * (1 - tt)).round(), 255, 255, 255)));
    }
  }

  // belt arm
  const shoulder = Offset(18, -116);
  final belt = _s(currentBelt.color, 7);
  final beltEdge = _s(C.ink, 7 + _ow * 2);
  if (reach != null) {
    // cracking the belt: arm stretched towards the kid (belt drawn by painter)
    final elbow = Offset.lerp(shoulder, reach, 0.5)! + const Offset(0, -6);
    _limb(c, [shoulder, elbow, reach], skin, 10);
    c.drawCircle(reach, 6, _f(skin));
    c.drawCircle(reach, 6, _outline);
  } else if (calm) {
    _limb(c, const [Offset(18, -116), Offset(26, -94), Offset(34, -82)], skin, 10);
    // belt hanging down
    c.drawPath(Path()..moveTo(34, -82)..quadraticBezierTo(40, -60, 36, -40), beltEdge);
    c.drawPath(Path()..moveTo(34, -82)..quadraticBezierTo(40, -60, 36, -40), belt);
  } else {
    // twirling the belt above his head like a lasso
    final r = 7 + windup * 5;
    final hand = shoulder + Offset(10 + cos(twirl) * r, -72 + sin(twirl) * r * 0.5);
    _limb(c, [shoulder, shoulder + const Offset(26, -34), hand], skin, 10);
    final loop = Rect.fromCenter(center: hand + const Offset(0, -12), width: 78, height: 30);
    c.drawArc(loop, twirl, 4.6, false, beltEdge);
    c.drawArc(loop, twirl, 4.6, false, belt);
    // buckle at the end of the belt
    final end = twirl + 4.6;
    final bp = loop.center + Offset(cos(end) * loop.width / 2, sin(end) * loop.height / 2);
    final buckle = Rect.fromCenter(center: bp, width: 12, height: 10);
    c.drawRect(buckle, _f(currentBelt.buckle));
    c.drawRect(buckle, _s(C.ink, 2));
    c.drawCircle(hand, 6, _f(skin));
    c.drawCircle(hand, 6, _outline);
    // motion lines
    for (int k = 0; k < 2; k++) {
      final aa = twirl - 0.6 - k * 0.5;
      final p1 = loop.center + Offset(cos(aa) * 46, sin(aa) * 20);
      final p2 = loop.center + Offset(cos(aa - 0.4) * 46, sin(aa - 0.4) * 20);
      c.drawLine(p1, p2, _s(const Color(0x882B1B3A), 2.5));
    }
  }
  c.restore();
}

/// Dad's belt stretched out while cracking, in world space.
void drawBeltWhip(Canvas c, Offset from, Offset tip, double time) {
  final len = (tip - from).distance;
  if (len < 4) return;
  final path = Path()..moveTo(from.dx, from.dy);
  const n = 10;
  for (int i = 1; i <= n; i++) {
    final t = i / n;
    final wave = sin(t * pi * 3 - time * 40) * 6 * (1 - t) * min(1.0, len / 120);
    path.lineTo(from.dx + (tip.dx - from.dx) * t, from.dy + (tip.dy - from.dy) * t + wave);
  }
  c.drawPath(path, _s(C.ink, 7 + _ow * 2));
  c.drawPath(path, _s(currentBelt.color, 7));
  final buckle = Rect.fromCenter(center: tip, width: 14, height: 12);
  c.drawRect(buckle, _f(currentBelt.buckle));
  c.drawRect(buckle, _s(C.ink, 2));
  // crack sparks at the tip
  for (int k = 0; k < 4; k++) {
    final a = k * pi / 2 + time * 8;
    c.drawLine(tip + Offset(cos(a) * 10, sin(a) * 10), tip + Offset(cos(a) * 18, sin(a) * 18),
        _s(C.ink, 2.4));
  }
}

/// TV remote control (Dad throws it), drawn top-down.
void drawRemote(Canvas c, Offset center, double width, double rotation) {
  c.save();
  c.translate(center.dx, center.dy);
  c.rotate(rotation);
  c.scale(width / 50);
  final body = RRect.fromRectAndRadius(
      const Rect.fromLTWH(-25, -9, 50, 18), const Radius.circular(6));
  c.drawRRect(body, _f(const Color(0xFF2E2E36)));
  c.drawRRect(body, _s(C.ink, 2));
  c.drawCircle(const Offset(-16, 0), 3.5, _f(const Color(0xFFE53935)));
  for (int i = 0; i < 3; i++) {
    for (int j = 0; j < 2; j++) {
      c.drawCircle(Offset(-4.0 + i * 8, -3.5 + j * 7), 2, _f(const Color(0xFFB8B8C8)));
    }
  }
  c.restore();
}

/// The famous plastic slipper (top-down-ish view). Colours come from the
/// equipped skin unless given.
void drawSlipper(Canvas c, Offset center, double width, double rotation,
    {Color? sole, Color? strap, SlipperSkin? skin}) {
  final k = skin ?? currentSlipper;
  final soleColor = sole ?? k.sole;
  final strapColor = strap ?? k.strap;
  c.save();
  c.translate(center.dx, center.dy);
  c.rotate(rotation);
  final s = width / 60;
  c.scale(s);
  // shadow-ish thickness
  final soleRect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(-30, -9, 60, 20), const Radius.circular(10));
  c.drawRRect(soleRect.shift(const Offset(0, 3)), _f(k.edge));
  c.drawRRect(soleRect, _f(soleColor));
  // patterns
  if (k.pattern != 0) {
    c.save();
    c.clipRRect(soleRect);
    if (k.pattern == 1) {
      for (int i = 0; i < 5; i++) {
        c.drawPath(starPath(Offset(-22 + i * 11.0, 1), 3.4), _f(strapColor.withAlpha(200)));
      }
    } else if (k.pattern == 2) {
      for (double x = -30; x < 30; x += 7) {
        c.drawRect(Rect.fromLTWH(x, -9, 3.5, 20), _f(const Color(0xFF2B1B3A)));
      }
    } else {
      for (int i = 0; i < 6; i++) {
        c.drawCircle(Offset(-24 + i * 9.5, (i.isEven ? -3 : 4)), 1.6, _f(const Color(0xCCFFFFFF)));
      }
    }
    c.restore();
  } else {
    // little grip dots
    for (int i = 0; i < 5; i++) {
      c.drawCircle(Offset(-20 + i * 9.0, 2), 1.4, _f(const Color(0x553A2A6E)));
    }
  }
  c.drawRRect(soleRect.shift(const Offset(0, 3)), _s(C.ink, 2.2));
  c.drawRRect(soleRect, _s(C.ink, 2.2));
  // strap
  final strapP = Path()
    ..moveTo(-8, -8)
    ..quadraticBezierTo(4, -22, 16, -8);
  c.drawPath(strapP, _s(C.ink, 9 + 4));
  c.drawPath(strapP, _s(strapColor, 9));
  c.drawPath(
      Path()
        ..moveTo(-4, -12)
        ..quadraticBezierTo(4, -19, 10, -13),
      _s(const Color(0x66FFFFFF), 2));
  c.restore();
}

/// A short piece of belt for shop previews.
void drawBeltSample(Canvas c, Offset center, double width, BeltSkin b) {
  final p = Path()
    ..moveTo(center.dx - width / 2, center.dy + 6)
    ..quadraticBezierTo(center.dx, center.dy - 14, center.dx + width / 2 - 14, center.dy + 4);
  c.drawPath(p, _s(C.ink, 9 + _ow * 2));
  c.drawPath(p, _s(b.color, 9));
  if (b.pattern == 1) {
    for (int i = 0; i < 6; i++) {
      final t = i / 6;
      c.drawCircle(Offset(center.dx - width / 2 + t * (width - 14), center.dy + 4 - 12 * (1 - (2 * t - 1) * (2 * t - 1))),
          1.6, _f(const Color(0x88FFFFFF)));
    }
  }
  final buckle = Rect.fromCenter(center: Offset(center.dx + width / 2 - 8, center.dy + 4), width: 16, height: 14);
  c.drawRect(buckle, _f(b.buckle));
  c.drawRect(buckle, _s(C.ink, 2));
}

extension on bool {
  int toInt() => this ? 1 : 0;
}
