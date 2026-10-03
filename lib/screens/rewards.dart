import 'dart:math';

import 'package:flutter/material.dart';

import '../game/game_painter.dart' show drawGiftBox;
import '../services/ad_service.dart';
import '../services/audio.dart';
import '../services/save_data.dart';
import '../theme.dart';

/// Lucky wheel (after a run) and mystery gift boxes.

final _rng = Random();

/// Lucky wheel slices (all the same size on screen, but not equally likely).
const List<Prize> kWheel = [
  Prize(PrizeKind.coins, 50),
  Prize(PrizeKind.pillow, 1),
  Prize(PrizeKind.coins, 100),
  Prize(PrizeKind.box, 1),
  Prize(PrizeKind.coins, 200),
  Prize(PrizeKind.grandma, 1),
  Prize(PrizeKind.coins, 500),
  Prize(PrizeKind.coins, 1000),
];
const List<int> _wheelWeights = [22, 13, 20, 8, 15, 8, 10, 4];

/// What can come out of a mystery box.
const List<Prize> _boxPrizes = [
  Prize(PrizeKind.coins, 150),
  Prize(PrizeKind.coins, 300),
  Prize(PrizeKind.pillow, 2),
  Prize(PrizeKind.grandma, 1),
  Prize(PrizeKind.coins, 800),
  Prize(PrizeKind.coins, 3000), // jackpot!
];
const List<int> _boxWeights = [35, 25, 13, 13, 12, 2];

int _pick(List<int> weights) {
  final total = weights.reduce((a, b) => a + b);
  var r = _rng.nextInt(total);
  for (int i = 0; i < weights.length; i++) {
    r -= weights[i];
    if (r < 0) return i;
  }
  return 0;
}

Prize rollBox() => _boxPrizes[_pick(_boxWeights)];

String prizeText(Prize p) => switch (p.kind) {
      PrizeKind.coins => '${fa(p.amount)} سکه',
      PrizeKind.pillow => '${fa(p.amount)} بالش',
      PrizeKind.grandma => '${fa(p.amount)} مادربزرگ',
      PrizeKind.box => 'جعبه شانس',
    };

IconData prizeIcon(PrizeKind k) => switch (k) {
      PrizeKind.coins => Icons.monetization_on_rounded,
      PrizeKind.pillow => Icons.bed_rounded,
      PrizeKind.grandma => Icons.elderly_rounded,
      PrizeKind.box => Icons.card_giftcard_rounded,
    };

// ---------------------------------------------------------------- wheel

/// Shows the lucky wheel. One free spin; one more by watching an ad.
Future<void> showLuckyWheel(BuildContext context) => showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.all(16),
        child: _WheelDialog(),
      ),
    );

class _WheelDialog extends StatefulWidget {
  const _WheelDialog();

  @override
  State<_WheelDialog> createState() => _WheelDialogState();
}

class _WheelDialogState extends State<_WheelDialog> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 3600));
  double _from = 0, _to = 0;
  bool _spinning = false;
  bool _usedAdSpin = false;
  int _spins = 0;
  Prize? _won;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _spin() async {
    if (_spinning) return;
    final i = _pick(_wheelWeights);
    const seg = 2 * pi / 8;
    // slice i is centred at angle i*seg (0 = top); rotate it under the pointer
    final current = _to % (2 * pi);
    final target = (2 * pi - i * seg) % (2 * pi);
    final extra = (target - current + 2 * pi) % (2 * pi);
    setState(() {
      _spinning = true;
      _won = null;
      _from = _to;
      _to = _to + 6 * pi + extra + (_rng.nextDouble() - 0.5) * seg * 0.6;
    });
    Audio.i.play(Sfx.windup);
    await _c.forward(from: 0);
    final prize = kWheel[i];
    SaveData.i.applyPrize(prize);
    Audio.i.play(Sfx.reward);
    if (mounted) {
      setState(() {
        _spinning = false;
        _won = prize;
        _spins++;
      });
    }
  }

  Future<void> _adSpin() async {
    final ok = await AdService.showRewarded(context);
    if (!ok || !mounted) return;
    setState(() => _usedAdSpin = true);
    _spin();
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 400),
      child: Panel(
        radius: 30,
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [C.cream, Color(0xFFFFE6C6)],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const OutlinedTitle('گردونه شانس', size: 32, fill: C.gold),
          const SizedBox(height: 12),
          SizedBox(
            width: 280,
            height: 296,
            child: Stack(alignment: Alignment.topCenter, children: [
              Positioned(
                top: 16,
                child: AnimatedBuilder(
                  animation: _c,
                  builder: (context, _) {
                    final t = Curves.easeOutQuart.transform(_c.value);
                    final a = _from + (_to - _from) * t;
                    return Transform.rotate(
                      angle: a,
                      child: CustomPaint(size: const Size(280, 280), painter: _WheelPainter()),
                    );
                  },
                ),
              ),
              // pointer
              CustomPaint(size: const Size(34, 40), painter: _PointerPainter()),
            ]),
          ),
          const SizedBox(height: 12),
          if (_won != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(prizeIcon(_won!.kind), color: C.goldDark, size: 28),
                const SizedBox(width: 8),
                Text('بردی: ${prizeText(_won!)}',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: C.ink)),
              ]),
            ),
          if (_spins == 0)
            GameButton(
              tone: Tone.gold,
              onTap: _spinning ? null : _spin,
              child: const Text('بچرخون!', style: TextStyle(fontSize: 20)),
            )
          else ...[
            if (!_usedAdSpin)
              GameButton(
                tone: Tone.purple,
                onTap: _spinning ? null : _adSpin,
                child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.ondemand_video_rounded),
                  SizedBox(width: 8),
                  Text('یه دور دیگه با تبلیغ', style: TextStyle(fontSize: 16)),
                ]),
              ),
            const SizedBox(height: 8),
            GameButton(
              tone: Tone.white,
              height: 48,
              onTap: _spinning ? null : () => Navigator.of(context).pop(),
              child: const Text('باشه', style: TextStyle(fontSize: 16)),
            ),
          ],
        ]),
      ),
    );
  }
}

class _WheelPainter extends CustomPainter {
  static const _colors = [C.red, C.gold, C.teal, C.purple, C.green, C.blue, Color(0xFFFF8FB1), C.goldDark];

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    canvas.drawCircle(c + const Offset(0, 6), r, Paint()..color = const Color(0x33000000));
    canvas.drawCircle(c, r, Paint()..color = C.ink);
    const seg = 2 * pi / 8;
    for (int i = 0; i < 8; i++) {
      // slice i is centred at the top when the wheel is not rotated
      final start = -pi / 2 + i * seg - seg / 2;
      canvas.drawArc(Rect.fromCircle(center: c, radius: r - 6), start, seg, true,
          Paint()..color = _colors[i]);
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(i * seg);
      final p = kWheel[i];
      final tp = TextPainter(
        text: TextSpan(
          text: p.kind == PrizeKind.coins ? fa(p.amount) : prizeText(p),
          style: TextStyle(
              fontFamily: 'Vazirmatn',
              fontSize: p.kind == PrizeKind.coins ? 20 : 12,
              fontWeight: FontWeight.w900,
              color: C.white,
              shadows: const [Shadow(color: Color(0x88000000), blurRadius: 3)]),
        ),
        textDirection: TextDirection.rtl,
      )..layout(maxWidth: 70);
      tp.paint(canvas, Offset(-tp.width / 2, -r * 0.78));
      final icon = prizeIcon(p.kind);
      final ip = TextPainter(
        text: TextSpan(
            text: String.fromCharCode(icon.codePoint),
            style: TextStyle(fontFamily: icon.fontFamily, package: icon.fontPackage, fontSize: 22, color: C.white)),
        textDirection: TextDirection.ltr,
      )..layout();
      ip.paint(canvas, Offset(-ip.width / 2, -r * 0.5));
      canvas.restore();
    }
    canvas.drawCircle(c, 26, Paint()..color = C.white);
    canvas.drawCircle(c, 26, Paint()
      ..color = C.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4);
    canvas.drawPath(starPath(c, 14), Paint()..color = C.gold);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PointerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Path()
      ..moveTo(size.width / 2, size.height)
      ..lineTo(0, 0)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(p, Paint()..color = C.red);
    canvas.drawPath(p, Paint()
      ..color = C.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeJoin = StrokeJoin.round);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ---------------------------------------------------------------- boxes

/// Opens the player's saved mystery boxes one by one.
Future<void> showOpenBoxes(BuildContext context) => showDialog<void>(
      context: context,
      builder: (_) => const Dialog(
        backgroundColor: Colors.transparent,
        child: _BoxDialog(),
      ),
    );

class _BoxDialog extends StatefulWidget {
  const _BoxDialog();

  @override
  State<_BoxDialog> createState() => _BoxDialogState();
}

class _BoxDialogState extends State<_BoxDialog> with SingleTickerProviderStateMixin {
  late final AnimationController _shake =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));
  Prize? _prize;
  bool _opening = false;

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  Future<void> _open() async {
    if (_opening || !SaveData.i.useBox()) return;
    setState(() {
      _opening = true;
      _prize = null;
    });
    Audio.i.play(Sfx.windup);
    await _shake.forward(from: 0);
    final p = rollBox();
    SaveData.i.applyPrize(p);
    Audio.i.play(p.amount >= 3000 ? Sfx.nearmiss : Sfx.reward);
    if (mounted) {
      setState(() {
        _opening = false;
        _prize = p;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final left = SaveData.i.mysteryBoxes;
    final jackpot = _prize != null && _prize!.kind == PrizeKind.coins && _prize!.amount >= 3000;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 380),
      child: Panel(
        radius: 30,
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          OutlinedTitle(jackpot ? 'جک‌پات!' : 'جعبه شانس', size: 30, fill: jackpot ? C.red : C.purple),
          const SizedBox(height: 12),
          SizedBox(
            height: 130,
            child: AnimatedBuilder(
              animation: _shake,
              builder: (context, _) => CustomPaint(
                size: const Size(160, 130),
                painter: _BoxPainter(_shake.value, _prize != null),
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (_prize != null)
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(prizeIcon(_prize!.kind), color: C.goldDark, size: 28),
              const SizedBox(width: 8),
              Text(prizeText(_prize!),
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: C.ink)),
            ])
          else
            Text('${fa(left)} جعبه داری', style: kBody),
          const SizedBox(height: 14),
          if (left > 0)
            GameButton(
              tone: Tone.purple,
              onTap: _opening ? null : _open,
              child: Text(_prize == null ? 'بازش کن!' : 'یکی دیگه (${fa(left)})',
                  style: const TextStyle(fontSize: 18)),
            ),
          const SizedBox(height: 8),
          GameButton(
            tone: Tone.white,
            height: 46,
            onTap: _opening ? null : () => Navigator.of(context).pop(),
            child: const Text('بستن', style: TextStyle(fontSize: 15)),
          ),
        ]),
      ),
    );
  }
}

class _BoxPainter extends CustomPainter {
  _BoxPainter(this.t, this.opened);
  final double t;
  final bool opened;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    if (opened) {
      // burst of rays
      for (int k = 0; k < 12; k++) {
        final a = k * pi / 6;
        canvas.drawLine(c + Offset(cos(a), sin(a)) * 34, c + Offset(cos(a), sin(a)) * 62,
            Paint()
              ..color = C.gold
              ..strokeWidth = 5
              ..strokeCap = StrokeCap.round);
      }
      paintCoin(canvas, c, 26, 1);
      return;
    }
    final shake = sin(t * pi * 14) * 8 * t;
    drawGiftBox(canvas, c + Offset(shake, 0), 40, t * 3);
  }

  @override
  bool shouldRepaint(covariant _BoxPainter old) => old.t != t || old.opened != opened;
}
