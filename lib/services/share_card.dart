import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../game/characters.dart';
import '../theme.dart';

/// Draws a 1080×1350 "my run" picture and opens the phone's share menu
/// (Instagram, Telegram, WhatsApp, ...).
class ShareCard {
  static const _w = 1080.0;
  static const _h = 1350.0;

  static Future<void> shareRun({
    required Character ch,
    required int meters,
    required int coins,
    required int best,
    required bool record,
  }) async {
    final bytes = await _render(ch: ch, meters: meters, coins: coins, best: best, record: record);
    if (bytes == null) return;
    final text = 'تو «دمپایی پرنده» ${fa(meters)} متر از دست مامان و بابا فرار کردم! '
        'تو می‌تونی رکوردم رو بزنی؟ 🩴';
    await SharePlus.instance.share(ShareParams(
      text: text,
      files: [XFile.fromData(bytes, mimeType: 'image/png', name: 'flying_slipper.png')],
      fileNameOverrides: ['flying_slipper.png'],
    ));
  }

  static Future<Uint8List?> _render({
    required Character ch,
    required int meters,
    required int coins,
    required int best,
    required bool record,
  }) async {
    final rec = ui.PictureRecorder();
    final c = Canvas(rec, const Rect.fromLTWH(0, 0, _w, _h));
    const full = Rect.fromLTWH(0, 0, _w, _h);

    // warm sunburst background with Persian stars
    c.drawRect(
        full,
        Paint()
          ..shader = const RadialGradient(
            center: Alignment(0, -0.2),
            radius: 0.9,
            colors: [Color(0xFFFFF1A6), Color(0xFFFFC93C), Color(0xFFFF8A2E), Color(0xFFF0562B)],
            stops: [0, 0.35, 0.75, 1],
          ).createShader(full));
    final center = const Offset(_w / 2, _h * 0.45);
    for (int k = 0; k < 18; k++) {
      final a0 = k * 2 * pi / 18;
      final p = Path()
        ..moveTo(center.dx, center.dy)
        ..lineTo(center.dx + cos(a0) * 1600, center.dy + sin(a0) * 1600)
        ..lineTo(center.dx + cos(a0 + pi / 18) * 1600, center.dy + sin(a0 + pi / 18) * 1600)
        ..close();
      c.drawPath(p, Paint()..color = const Color(0x22FFFFFF));
    }
    TilePatternPainter(color: const Color(0x18B8322B), step: 110).paint(c, full.size);

    // title
    _text(c, 'دمپایی پرنده', const Offset(_w / 2, 120), 96, C.white, stroke: C.ink);

    // the kid running from a flying slipper
    c.drawOval(Rect.fromCenter(center: Offset(_w / 2 + 60, 790), width: 300, height: 50),
        Paint()..color = const Color(0x44000000));
    drawCharacter(c, ch, const Offset(_w / 2 + 60, 780), 4.4,
        phase: 1.0, mood: Mood.scared, time: 0.5);
    drawSlipper(c, const Offset(_w / 2 - 260, 420), 240, 0.5);
    for (int k = 0; k < 3; k++) {
      c.drawLine(Offset(_w / 2 - 470 - k * 10, 360 + k * 50), Offset(_w / 2 - 380, 360 + k * 50),
          Paint()
            ..color = C.white
            ..strokeWidth = 18
            ..strokeCap = StrokeCap.round);
    }

    // the result
    final card = RRect.fromRectAndRadius(
        Rect.fromCenter(center: const Offset(_w / 2, 1010), width: 900, height: 290),
        const Radius.circular(60));
    c.drawRRect(card.shift(const Offset(0, 14)), Paint()..color = const Color(0x40000000));
    c.drawRRect(card, Paint()..color = C.white);
    if (record) {
      final badge = RRect.fromRectAndRadius(
          Rect.fromCenter(center: const Offset(_w / 2, 870), width: 340, height: 70),
          const Radius.circular(35));
      c.drawRRect(badge, Paint()..color = C.red);
      _text(c, 'رکورد جدید!', const Offset(_w / 2, 870), 44, C.white);
    }
    _text(c, '${fa(meters)} متر', const Offset(_w / 2, 975), 120, C.ink);
    _text(c, 'از دست مامان و بابا فرار کردم!', const Offset(_w / 2, 1080), 52, C.inkSoft);

    // challenge line
    _text(c, 'تو می‌تونی رکوردم رو بزنی؟', const Offset(_w / 2, 1220), 58, C.white, stroke: C.ink);
    _text(c, 'دانلود از کافه‌بازار', const Offset(_w / 2, 1300), 40, C.ink);

    final img = await rec.endRecording().toImage(_w.toInt(), _h.toInt());
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    return data?.buffer.asUint8List();
  }

  static void _text(Canvas c, String text, Offset center, double size, Color fill, {Color? stroke}) {
    final style = TextStyle(fontFamily: 'Vazirmatn', fontSize: size, fontWeight: FontWeight.w900);
    if (stroke != null) {
      final s = TextPainter(
        text: TextSpan(
            text: text,
            style: style.copyWith(
                foreground: Paint()
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = size * 0.18
                  ..strokeJoin = StrokeJoin.round
                  ..color = stroke)),
        textDirection: TextDirection.rtl,
      )..layout();
      s.paint(c, center - Offset(s.width / 2, s.height / 2));
    }
    final f = TextPainter(
      text: TextSpan(text: text, style: style.copyWith(color: fill)),
      textDirection: TextDirection.rtl,
    )..layout();
    f.paint(c, center - Offset(f.width / 2, f.height / 2));
  }
}
