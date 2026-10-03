import 'dart:math';

import 'package:flutter/material.dart';

import '../services/audio.dart';
import '../services/save_data.dart';
import '../theme.dart';

/// "Fix the house": the kid broke things at home. Repairing them with coins
/// gives permanent bonuses, and Mom & Dad slowly calm down.
class Repair {
  const Repair(this.id, this.name, this.story, this.effect, this.cost);
  final String id;
  final String name;
  final String story;
  final String effect;
  final int cost;
}

const List<Repair> kRepairs = [
  Repair('vase', 'گلدون مامان', 'با توپ زدی شکستیش!', '۵٪ سکه بیشتر در هر بازی', 800),
  Repair('window', 'شیشه پنجره', 'شوت محکم... صاف خورد به شیشه!', 'مامان ۸٪ دیرتر دمپایی پرت می‌کنه', 2000),
  Repair('tv', 'تلویزیون بابا', 'کنترل رو انداختی تو حوض!', 'بابا ۱۰ ثانیه دیرتر میاد', 3500),
  Repair('carpet', 'فرش دستباف', 'آب‌میوه ریختی روش!', '۱۰٪ سکه بیشتر در هر بازی', 5000),
  Repair('shelf', 'قفسه کتاب', 'ازش بالا رفتی و افتاد!', 'هر بازی با یه بالش شروع میشه', 7500),
  Repair('wedding', 'عکس عروسی', 'قاب عکس عروسی بابا و مامان رو شکوندی!', 'عصبانیت مامان و بابا ۱۵٪ آروم‌تر بالا میره', 10000),
];

/// Bonuses from all the repairs done so far.
class HouseBonus {
  const HouseBonus({
    this.coinBonus = 0,
    this.throwDelayMul = 1,
    this.dadDelay = 0,
    this.startShield = false,
    this.angerMul = 1,
  });
  final double coinBonus; // extra share of the run's coins (0.15 = +15%)
  final double throwDelayMul; // > 1 = attacks come less often
  final double dadDelay; // seconds before Dad first arrives
  final bool startShield;
  final double angerMul; // < 1 = anger grows slower

  static HouseBonus of(Set<String> done) => HouseBonus(
        coinBonus: (done.contains('vase') ? 0.05 : 0.0) + (done.contains('carpet') ? 0.10 : 0.0),
        throwDelayMul: done.contains('window') ? 1.08 : 1.0,
        dadDelay: done.contains('tv') ? 10.0 : 0.0,
        startShield: done.contains('shelf'),
        angerMul: done.contains('wedding') ? 0.85 : 1.0,
      );
}

class HouseScreen extends StatelessWidget {
  const HouseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = SaveData.i;
    return Scaffold(
      body: WarmBackground(
        child: SafeArea(
          child: ListenableBuilder(
            listenable: s,
            builder: (context, _) {
              final done = s.repairs;
              final all = done.length >= kRepairs.length;
              return Column(children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                  child: Row(children: [
                    RoundButton(
                      icon: Icons.arrow_back_rounded,
                      label: 'بازگشت',
                      onTap: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(child: OutlinedTitle('تعمیر خونه', size: 30)),
                    CoinPill(amount: s.coins),
                  ]),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Panel(
                    radius: 22,
                    padding: const EdgeInsets.all(14),
                    child: Column(children: [
                      Text(
                          all
                              ? 'همه چی درست شد! مامان و بابا بخشیدنت.'
                              : 'کلی خرابکاری کردی! با سکه‌هات خونه رو تعمیر کن تا مامان و بابا آروم‌تر بشن.',
                          textAlign: TextAlign.center,
                          style: kBody.copyWith(height: 1.5)),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: done.length / kRepairs.length,
                          minHeight: 12,
                          backgroundColor: const Color(0xFFF1E4F5),
                          color: C.green,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text('${fa(done.length)} از ${fa(kRepairs.length)} تعمیر',
                          style: kSmall.copyWith(fontSize: 12)),
                    ]),
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                    children: [
                      for (int i = 0; i < kRepairs.length; i++) ...[
                        _RepairCard(
                          r: kRepairs[i],
                          fixed: done.contains(kRepairs[i].id),
                          // repairs unlock in order
                          locked: i > 0 && !done.contains(kRepairs[i - 1].id),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ],
                  ),
                ),
              ]);
            },
          ),
        ),
      ),
    );
  }
}

class _RepairCard extends StatelessWidget {
  const _RepairCard({required this.r, required this.fixed, required this.locked});
  final Repair r;
  final bool fixed;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final s = SaveData.i;
    return Opacity(
      opacity: locked ? 0.55 : 1.0,
      child: Panel(
        radius: 22,
        padding: const EdgeInsets.all(12),
        border: fixed ? Border.all(color: C.green, width: 2.5) : null,
        child: Row(children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              color: fixed ? const Color(0xFFE8F6EC) : const Color(0xFFFFEDEA),
              borderRadius: BorderRadius.circular(18),
            ),
            child: CustomPaint(painter: _RepairPainter(r.id, fixed)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(r.name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: C.ink)),
              Text(fixed ? 'درست شد!' : r.story, style: kSmall.copyWith(fontSize: 12)),
              const SizedBox(height: 4),
              Row(children: [
                Icon(fixed ? Icons.check_circle_rounded : Icons.auto_awesome_rounded,
                    size: 16, color: fixed ? C.greenDark : C.purpleDark),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(r.effect,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: fixed ? C.greenDark : C.purpleDark)),
                ),
              ]),
            ]),
          ),
          const SizedBox(width: 8),
          if (!fixed)
            locked
                ? const Icon(Icons.lock_rounded, color: C.inkSoft)
                : GameButton(
                    tone: Tone.green,
                    height: 44,
                    radius: 14,
                    depth: 4,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    onTap: () {
                      if (s.doRepair(r.id, r.cost)) {
                        Audio.i.play(Sfx.reward);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                            content: Text('سکه کافی نداری!', style: TextStyle(fontFamily: 'Vazirmatn'))));
                      }
                    },
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const Text('تعمیر', style: TextStyle(fontSize: 13)),
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        const CoinIcon(size: 14),
                        const SizedBox(width: 3),
                        Text(fa(r.cost), style: const TextStyle(fontSize: 12)),
                      ]),
                    ]),
                  ),
        ]),
      ),
    );
  }
}

/// Small before/after drawings for each repair.
class _RepairPainter extends CustomPainter {
  _RepairPainter(this.id, this.fixed);
  final String id;
  final bool fixed;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final o = Paint()
      ..color = C.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeJoin = StrokeJoin.round;
    final crack = Paint()
      ..color = C.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    void cracks(Offset p, double s) {
      if (fixed) return;
      canvas.drawPath(
          Path()
            ..moveTo(p.dx - s, p.dy - s)
            ..lineTo(p.dx - s * 0.2, p.dy - s * 0.1)
            ..lineTo(p.dx - s * 0.5, p.dy + s * 0.4)
            ..lineTo(p.dx + s * 0.3, p.dy + s),
          crack);
    }

    void sparkle(Offset p) {
      if (!fixed) return;
      canvas.drawPath(starPath(p, 7), Paint()..color = C.gold);
    }

    switch (id) {
      case 'vase':
        final v = Path()
          ..moveTo(c.dx - 10, c.dy - 26)
          ..lineTo(c.dx + 10, c.dy - 26)
          ..quadraticBezierTo(c.dx + 26, c.dy, c.dx + 12, c.dy + 26)
          ..lineTo(c.dx - 12, c.dy + 26)
          ..quadraticBezierTo(c.dx - 26, c.dy, c.dx - 10, c.dy - 26)
          ..close();
        canvas.drawPath(v, Paint()..color = const Color(0xFF2F6BFF));
        canvas.drawPath(v, o);
        cracks(c, 14);
        sparkle(c + const Offset(24, -24));
      case 'window':
        final r = Rect.fromCenter(center: c, width: 56, height: 56);
        canvas.drawRect(r, Paint()..color = const Color(0xFFBFEFFF));
        canvas.drawRect(r, o);
        canvas.drawLine(Offset(c.dx, r.top), Offset(c.dx, r.bottom), o);
        canvas.drawLine(Offset(r.left, c.dy), Offset(r.right, c.dy), o);
        cracks(c + const Offset(10, -8), 16);
        if (!fixed) canvas.drawCircle(c + const Offset(14, -12), 6, Paint()..color = C.red);
        sparkle(c + const Offset(26, -26));
      case 'tv':
        final r = Rect.fromCenter(center: c, width: 60, height: 44);
        canvas.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(6)), Paint()..color = const Color(0xFF3A3A44));
        final screen = r.deflate(6);
        canvas.drawRect(screen, Paint()..color = fixed ? const Color(0xFF5AA8FF) : const Color(0xFFB0B0C0));
        if (!fixed) {
          final rng = Random(4);
          for (int i = 0; i < 40; i++) {
            canvas.drawCircle(
                Offset(screen.left + rng.nextDouble() * screen.width, screen.top + rng.nextDouble() * screen.height),
                1.2,
                Paint()..color = C.white);
          }
        } else {
          canvas.drawCircle(screen.center, 8, Paint()..color = C.gold);
        }
        canvas.drawLine(Offset(c.dx - 10, r.bottom), Offset(c.dx - 16, r.bottom + 10), o);
        canvas.drawLine(Offset(c.dx + 10, r.bottom), Offset(c.dx + 16, r.bottom + 10), o);
        sparkle(c + const Offset(26, -24));
      case 'carpet':
        final r = Rect.fromCenter(center: c, width: 64, height: 48);
        canvas.drawRect(r, Paint()..color = C.rug);
        canvas.drawRect(r.deflate(6), Paint()
          ..color = C.rugGold
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2);
        canvas.drawPath(starPath(c, 10), Paint()..color = C.rugGold);
        if (!fixed) {
          canvas.drawOval(Rect.fromCenter(center: c + const Offset(10, 6), width: 30, height: 18),
              Paint()..color = const Color(0xCC7CB342));
        }
        sparkle(c + const Offset(28, -24));
      case 'shelf':
        final tilt = fixed ? 0.0 : 0.35;
        canvas.save();
        canvas.translate(c.dx, c.dy);
        canvas.rotate(tilt);
        final r = Rect.fromCenter(center: Offset.zero, width: 44, height: 60);
        canvas.drawRect(r, Paint()..color = const Color(0xFF8A5634));
        for (int i = 0; i < 3; i++) {
          final y = r.top + 8 + i * 18.0;
          for (int k = 0; k < 4; k++) {
            canvas.drawRect(Rect.fromLTWH(r.left + 5 + k * 9.0, y, 7, 12),
                Paint()..color = [C.red, C.teal, C.gold, C.purple][k]);
          }
        }
        canvas.drawRect(r, o);
        canvas.restore();
        sparkle(c + const Offset(26, -26));
      default: // wedding photo
        final tilt = fixed ? 0.0 : -0.3;
        canvas.save();
        canvas.translate(c.dx, c.dy);
        canvas.rotate(tilt);
        final r = Rect.fromCenter(center: Offset.zero, width: 50, height: 60);
        canvas.drawRect(r, Paint()..color = C.goldDark);
        canvas.drawRect(r.deflate(6), Paint()..color = const Color(0xFFFFE3EC));
        canvas.drawCircle(const Offset(-8, -2), 7, Paint()..color = C.skin);
        canvas.drawCircle(const Offset(8, -2), 7, Paint()..color = C.skin);
        canvas.drawRect(const Rect.fromLTWH(-15, 6, 14, 16), Paint()..color = const Color(0xFF26222E));
        canvas.drawRect(const Rect.fromLTWH(1, 6, 14, 16), Paint()..color = C.white);
        canvas.drawRect(r, o);
        canvas.restore();
        cracks(c, 18);
        if (fixed) {
          final h = Path()
            ..moveTo(c.dx + 26, c.dy - 18)
            ..cubicTo(c.dx + 18, c.dy - 30, c.dx + 10, c.dy - 20, c.dx + 26, c.dy - 6)
            ..cubicTo(c.dx + 42, c.dy - 20, c.dx + 34, c.dy - 30, c.dx + 26, c.dy - 18);
          canvas.drawPath(h, Paint()..color = const Color(0xFFFF5C8A));
        }
    }
  }

  @override
  bool shouldRepaint(covariant _RepairPainter old) => old.fixed != fixed || old.id != id;
}
