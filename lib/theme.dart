import 'dart:math';

import 'package:flutter/material.dart';

import 'services/audio.dart';

/// Game palette: warm Persian home, modern saturated accents.
class C {
  static const ink = Color(0xFF2B1B3A); // deep plum, used for outlines & text
  static const inkSoft = Color(0xFF6E5A7E);
  static const bgTop = Color(0xFFFFEFD6);
  static const bgBottom = Color(0xFFFFD2A8);
  static const cream = Color(0xFFFFF7EA);
  static const white = Color(0xFFFFFFFF);

  static const red = Color(0xFFFF5A4E);
  static const redDark = Color(0xFFD9342B);
  static const redEdge = Color(0xFFA82219);

  static const teal = Color(0xFF26C6BE);
  static const tealDark = Color(0xFF119A93);
  static const tealEdge = Color(0xFF0B6F6A);

  static const gold = Color(0xFFFFD34D);
  static const goldDark = Color(0xFFF5A623);
  static const goldEdge = Color(0xFFC07A0E);

  static const green = Color(0xFF4CD27A);
  static const greenDark = Color(0xFF22A955);
  static const greenEdge = Color(0xFF17783B);

  static const purple = Color(0xFFA77BFF);
  static const purpleDark = Color(0xFF7646E8);
  static const purpleEdge = Color(0xFF5229B8);

  static const blue = Color(0xFF5AA8FF);
  static const blueDark = Color(0xFF2F7BE0);

  // In-game scene
  static const wall = Color(0xFFFBE7C8);
  static const wallShade = Color(0xFFF2D3A6);
  static const rug = Color(0xFFB8322B);
  static const rugDark = Color(0xFF7E1D1A);
  static const rugGold = Color(0xFFF2B33D);
  static const rugNavy = Color(0xFF1F3A6E);
  static const skin = Color(0xFFF7CDA4);
  static const skinShade = Color(0xFFE8AE84);

  static const shade = Color(0xB32B1B3A);
  static const shadow = Color(0x332B1B3A);
}

/// A colour set for one button style.
class Tone {
  const Tone(this.top, this.bottom, this.edge, this.text);
  final Color top, bottom, edge, text;

  static const red = Tone(C.red, C.redDark, C.redEdge, C.white);
  static const teal = Tone(C.teal, C.tealDark, C.tealEdge, C.white);
  static const gold = Tone(C.gold, C.goldDark, C.goldEdge, C.ink);
  static const green = Tone(C.green, C.greenDark, C.greenEdge, C.white);
  static const purple = Tone(C.purple, C.purpleDark, C.purpleEdge, C.white);
  static const white =
      Tone(C.white, Color(0xFFF3EAF7), Color(0xFFD5C6DE), C.ink);
  static const dark = Tone(Color(0xFF4A3560), C.ink, Color(0xFF160C20), C.white);
}

/// Formats a number with Persian digits and thousands separators: 1250 -> ۱٬۲۵۰
String fa(num n) {
  final s = n.round().abs().toString();
  final buf = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write('٬');
    buf.write(s[i]);
  }
  const digits = '۰۱۲۳۴۵۶۷۸۹';
  final out = buf
      .toString()
      .split('')
      .map((ch) {
        final k = int.tryParse(ch);
        return k == null ? ch : digits[k];
      })
      .join();
  return n < 0 ? '-$out' : out;
}

const List<BoxShadow> kSoftShadow = [
  BoxShadow(color: C.shadow, blurRadius: 24, offset: Offset(0, 10)),
];

/// Glossy 3D game button with a coloured edge, press animation and click sound.
class GameButton extends StatefulWidget {
  const GameButton({
    super.key,
    required this.child,
    required this.onTap,
    this.tone = Tone.red,
    this.height = 58,
    this.radius = 20,
    this.depth = 6,
    this.padding = const EdgeInsets.symmetric(horizontal: 18),
    this.sound = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final Tone tone;
  final double height;
  final double radius;
  final double depth;
  final EdgeInsets padding;
  final bool sound;

  @override
  State<GameButton> createState() => _GameButtonState();
}

class _GameButtonState extends State<GameButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final press = _down ? widget.depth * 0.75 : 0.0;
    final r = BorderRadius.circular(widget.radius);
    return Semantics(
      button: true,
      enabled: enabled,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => setState(() => _down = true) : null,
        onTapCancel: () => setState(() => _down = false),
        onTapUp: enabled
            ? (_) {
                setState(() => _down = false);
                if (widget.sound) Audio.i.play(Sfx.click);
                widget.onTap!();
              }
            : null,
        child: Opacity(
          opacity: enabled ? 1.0 : 0.5,
          child: Stack(children: [
            // Edge (the "3D" side) – fills the area under the face
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: widget.height,
              child: Container(
                decoration: BoxDecoration(
                  color: widget.tone.edge,
                  borderRadius: r,
                  boxShadow: kSoftShadow,
                ),
              ),
            ),
            // Face – its size decides the button size
            AnimatedPadding(
              duration: const Duration(milliseconds: 60),
              padding: EdgeInsets.only(top: press, bottom: widget.depth - press),
              child: Container(
                height: widget.height,
                padding: widget.padding,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: r,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color.lerp(widget.tone.top, C.white, 0.28)!,
                      widget.tone.top,
                      widget.tone.bottom,
                    ],
                    stops: const [0, 0.42, 1],
                  ),
                ),
                child: DefaultTextStyle.merge(
                  style: TextStyle(
                    color: widget.tone.text,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'Vazirmatn',
                  ),
                  child: IconTheme.merge(
                    data: IconThemeData(color: widget.tone.text),
                    child: widget.child,
                  ),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Round icon button (pause, settings, back).
class RoundButton extends StatelessWidget {
  const RoundButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.tone = Tone.white,
    this.size = 48,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Tone tone;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      child: Tooltip(
        message: label,
        child: GameButton(
          tone: tone,
          height: size,
          radius: size / 2,
          depth: 4,
          padding: EdgeInsets.zero,
          onTap: onTap,
          child: Icon(icon, size: size * 0.5),
        ),
      ),
    );
  }
}

/// White rounded card with a soft shadow.
class Panel extends StatelessWidget {
  const Panel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.color = C.white,
    this.radius = 24,
    this.gradient,
    this.border,
  });
  final Widget child;
  final EdgeInsets padding;
  final Color color;
  final double radius;
  final Gradient? gradient;
  final BoxBorder? border;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: gradient == null ? color : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: kSoftShadow,
        border: border,
      ),
      child: child,
    );
  }
}

/// Big cartoon title text with a thick outline and drop shadow.
class OutlinedTitle extends StatelessWidget {
  const OutlinedTitle(
    this.text, {
    super.key,
    this.size = 48,
    this.fill = C.white,
    this.stroke = C.ink,
    this.strokeWidth,
  });
  final String text;
  final double size;
  final Color fill;
  final Color stroke;
  final double? strokeWidth;

  @override
  Widget build(BuildContext context) {
    final sw = strokeWidth ?? size * 0.16;
    final base = TextStyle(
      fontFamily: 'Vazirmatn',
      fontSize: size,
      fontWeight: FontWeight.w900,
      height: 1.15,
    );
    return Stack(children: [
      Transform.translate(
        offset: Offset(0, size * 0.08),
        child: Text(text,
            style: base.copyWith(
                foreground: Paint()
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = sw
                  ..strokeJoin = StrokeJoin.round
                  ..color = stroke)),
      ),
      Text(text,
          style: base.copyWith(
              foreground: Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = sw
                ..strokeJoin = StrokeJoin.round
                ..color = stroke)),
      Text(text, style: base.copyWith(color: fill)),
    ]);
  }
}

/// Golden coin icon with a shine.
class CoinIcon extends StatelessWidget {
  const CoinIcon({super.key, this.size = 22});
  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: Size.square(size), painter: _CoinPainter());
  }
}

class _CoinPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    paintCoin(canvas, size.center(Offset.zero), size.width / 2, 1);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Shared coin drawing (also used inside the game).
void paintCoin(Canvas c, Offset center, double r, double squash) {
  final rect = Rect.fromCenter(center: center, width: r * 2 * squash, height: r * 2);
  // coin thickness: the edge shows more as the coin turns sideways
  final edge = r * 0.28 * (1 - squash) + r * 0.06;
  c.drawOval(rect.shift(Offset(edge, r * 0.1)), Paint()..color = const Color(0xFFA8650A));
  for (double e = edge * 0.7; e > 0; e -= max(0.8, edge / 4)) {
    c.drawOval(rect.shift(Offset(e, r * 0.08)), Paint()..color = C.goldEdge);
  }
  c.drawOval(
      rect,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.3, -0.4),
          colors: [Color(0xFFFFF0A8), C.gold, C.goldDark],
          stops: [0, 0.45, 1],
        ).createShader(rect));
  final inner = Rect.fromCenter(
      center: center, width: max(1.0, rect.width * 0.55), height: r * 1.1);
  c.drawOval(
      inner,
      Paint()
        ..color = C.goldEdge
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(1.0, r * 0.14));
  c.drawCircle(center + Offset(-r * 0.35 * squash, -r * 0.4), r * 0.16,
      Paint()..color = const Color(0xCCFFFFFF));
}

/// Pill showing the player's coins.
class CoinPill extends StatelessWidget {
  const CoinPill({super.key, required this.amount, this.onTap});
  final int amount;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 42,
        padding: const EdgeInsetsDirectional.fromSTEB(6, 0, 6, 0),
        decoration: BoxDecoration(
          color: const Color(0xEEFFFFFF),
          borderRadius: BorderRadius.circular(999),
          boxShadow: kSoftShadow,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CoinIcon(size: 30),
            const SizedBox(width: 8),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: amount.toDouble(), end: amount.toDouble()),
              duration: const Duration(milliseconds: 400),
              builder: (context, v, _) => Text(fa(v),
                  style: const TextStyle(
                      fontWeight: FontWeight.w900, fontSize: 17, color: C.ink)),
            ),
            const SizedBox(width: 8),
            if (onTap != null)
              Container(
                width: 28,
                height: 28,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [C.green, C.greenDark]),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.add_rounded, size: 20, color: C.white),
              )
            else
              const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }
}

/// Warm background with a faint Persian tile pattern.
class WarmBackground extends StatelessWidget {
  const WarmBackground({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [C.bgTop, C.bgBottom],
        ),
      ),
      child: CustomPaint(painter: TilePatternPainter(), child: child),
    );
  }
}

/// Eight-pointed Persian star pattern.
class TilePatternPainter extends CustomPainter {
  TilePatternPainter({this.color = const Color(0x14B8322B), this.step = 64});
  final Color color;
  final double step;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = color;
    for (double y = 0; y < size.height + step; y += step) {
      final row = (y / step).round();
      for (double x = (row.isOdd ? step / 2 : 0); x < size.width + step; x += step) {
        canvas.drawPath(starPath(Offset(x, y), step * 0.22), p);
      }
    }
  }

  @override
  bool shouldRepaint(covariant TilePatternPainter old) => false;
}

/// 8-pointed star (two overlapping squares), a classic Persian tile motif.
Path starPath(Offset c, double r) {
  final path = Path();
  for (int k = 0; k < 16; k++) {
    final a = k * pi / 8 - pi / 2;
    final rr = k.isEven ? r : r * 0.62;
    final pt = c + Offset(cos(a) * rr, sin(a) * rr);
    if (k == 0) {
      path.moveTo(pt.dx, pt.dy);
    } else {
      path.lineTo(pt.dx, pt.dy);
    }
  }
  return path..close();
}

const TextStyle kBody =
    TextStyle(fontWeight: FontWeight.w700, color: C.ink, fontSize: 15);
const TextStyle kSmall =
    TextStyle(fontWeight: FontWeight.w600, color: C.inkSoft, fontSize: 12);
