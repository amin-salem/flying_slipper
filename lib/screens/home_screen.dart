import 'dart:math';

import 'package:flutter/material.dart';

import '../game/characters.dart';
import '../services/audio.dart';
import '../services/save_data.dart';
import '../theme.dart';
import 'game_screen.dart';
import 'shop_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim =
      AnimationController(vsync: this, duration: const Duration(seconds: 6))
        ..repeat();

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  void _openShop(int tab) {
    Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ShopScreen(initialTab: tab)));
  }

  void _play() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const GameScreen()));
  }

  Future<void> _claimDaily() async {
    final s = SaveData.i;
    final got = s.claimDaily();
    if (got > 0) Audio.i.play(Sfx.reward);
    await showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Panel(
          radius: 28,
          padding: const EdgeInsets.all(22),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            OutlinedTitle(got > 0 ? 'جایزه امروز!' : 'فردا بیا!',
                size: 32, fill: C.gold),
            const SizedBox(height: 14),
            if (got > 0)
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const CoinIcon(size: 44),
                const SizedBox(width: 10),
                Text('+${fa(got)}',
                    style: const TextStyle(
                        fontSize: 36, fontWeight: FontWeight.w900)),
              ])
            else
              const Text('جایزه امروز رو گرفتی. فردا دوباره سر بزن.',
                  textAlign: TextAlign.center, style: kBody),
            const SizedBox(height: 18),
            GameButton(
              tone: Tone.green,
              onTap: () => Navigator.pop(ctx),
              child: const Text('عالیه!', style: TextStyle(fontSize: 18)),
            ),
          ]),
        ),
      ),
    );
  }

  void _settings() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const _SettingsSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = SaveData.i;
    return Scaffold(
      body: WarmBackground(
        child: SafeArea(
          child: ListenableBuilder(
            listenable: s,
            builder: (context, _) => Padding(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    CoinPill(amount: s.coins, onTap: () => _openShop(0)),
                    const Spacer(),
                    if (s.vip)
                      Container(
                        margin: const EdgeInsetsDirectional.only(end: 10),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                            gradient: const LinearGradient(
                                colors: [C.gold, C.goldDark]),
                            borderRadius: BorderRadius.circular(999)),
                        child: const Text('VIP',
                            style: TextStyle(
                                color: C.ink, fontWeight: FontWeight.w900)),
                      ),
                    RoundButton(
                        icon: Icons.settings_rounded,
                        label: 'تنظیمات',
                        onTap: _settings),
                  ]),
                  const SizedBox(height: 6),
                  _Title(anim: _anim),
                  const SizedBox(height: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _openShop(1),
                      child: _HeroCard(anim: _anim, ch: s.character),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.emoji_events_rounded,
                          color: C.goldDark, size: 22),
                      const SizedBox(width: 6),
                      const Text('رکورد تو:',
                          style: TextStyle(
                              color: C.inkSoft, fontWeight: FontWeight.w700)),
                      const SizedBox(width: 6),
                      Text('${fa(s.best)} متر',
                          style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                              color: C.ink)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  AnimatedBuilder(
                    animation: _anim,
                    builder: (context, child) => Transform.scale(
                      scale: 1 + 0.03 * sin(_anim.value * 2 * pi * 3),
                      child: child,
                    ),
                    child: GameButton(
                      tone: Tone.red,
                      height: 74,
                      radius: 30,
                      depth: 8,
                      onTap: _play,
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.play_arrow_rounded, size: 40),
                          SizedBox(width: 6),
                          Text('بزن بریم!', style: TextStyle(fontSize: 28)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(children: [
                    _NavCard(
                        label: 'فروشگاه',
                        icon: Icons.shopping_bag_rounded,
                        tone: Tone.gold,
                        onTap: () => _openShop(0)),
                    const SizedBox(width: 10),
                    _NavCard(
                        label: 'شخصیت‌ها',
                        icon: Icons.face_retouching_natural,
                        tone: Tone.purple,
                        onTap: () => _openShop(1)),
                    const SizedBox(width: 10),
                    _NavCard(
                        label: 'جایزه روزانه',
                        icon: Icons.card_giftcard_rounded,
                        tone: Tone.teal,
                        badge: s.canClaimDaily,
                        onTap: _claimDaily),
                  ]),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Title extends StatelessWidget {
  const _Title({required this.anim});
  final Animation<double> anim;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: anim,
      builder: (context, _) {
        final wob = sin(anim.value * 2 * pi * 2);
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const OutlinedTitle('دمپایی', size: 46),
            const SizedBox(width: 10),
            Transform.rotate(
              angle: -0.08 + wob * 0.04,
              child: Transform.translate(
                offset: Offset(0, -6 + wob * 3),
                child: const OutlinedTitle('پرنده!', size: 52, fill: C.gold),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.anim, required this.ch});
  final Animation<double> anim;
  final Character ch;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        boxShadow: kSoftShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(children: [
        Positioned.fill(
          child: AnimatedBuilder(
            animation: anim,
            builder: (context, _) =>
                CustomPaint(painter: _HeroPainter(anim.value, ch)),
          ),
        ),
        PositionedDirectional(
          bottom: 12,
          start: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xE6FFFFFF),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                    color: ch.rarity.color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Text(ch.name,
                  style: const TextStyle(
                      fontWeight: FontWeight.w900, fontSize: 13, color: C.ink)),
              if (ch.abilityName != 'بدون قدرت ویژه') ...[
                const SizedBox(width: 6),
                Icon(ch.abilityIcon, size: 14, color: ch.rarity.color),
                const SizedBox(width: 2),
                Text(ch.abilityName,
                    style: TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 12, color: ch.rarity.color)),
              ],
            ]),
          ),
        ),
      ]),
    );
  }
}

/// Little animated preview of the chase on the home screen.
class _HeroPainter extends CustomPainter {
  _HeroPainter(this.t, this.ch);
  final double t; // 0..1 looping
  final Character ch;

  @override
  void paint(Canvas canvas, Size size) {
    final time = t * 6; // seconds
    final floorY = size.height * 0.8;

    // wall
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, floorY),
        Paint()..color = const Color(0xFF1C8C9E));
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width, floorY));
    TilePatternPainter(color: const Color(0x2EFFFFFF), step: 46)
        .paint(canvas, Size(size.width + 46, floorY));
    canvas.restore();
    // sunbeam
    final beam = Path()
      ..moveTo(size.width * 0.55, 0)
      ..lineTo(size.width * 0.85, 0)
      ..lineTo(size.width * 0.65, floorY)
      ..lineTo(size.width * 0.2, floorY)
      ..close();
    canvas.drawPath(beam, Paint()..color = const Color(0x18FFFFFF));

    // rug
    canvas.drawRect(Rect.fromLTWH(0, floorY, size.width, size.height - floorY),
        Paint()..color = C.rug);
    canvas.drawRect(Rect.fromLTWH(0, floorY, size.width, 8),
        Paint()..color = C.rugNavy);
    canvas.drawRect(Rect.fromLTWH(0, floorY + 8, size.width, 4),
        Paint()..color = C.rugGold);
    final rs = (time * 200) % 70;
    for (double x = -rs; x < size.width + 70; x += 70) {
      canvas.drawPath(starPath(Offset(x, floorY + 30), 10),
          Paint()..color = C.rugGold);
    }

    final scale = (size.height / 230).clamp(0.7, 1.4);
    final kidX = size.width * 0.66;
    // kid hops every 1.5 s
    final hopT = (time % 1.5) / 1.5;
    final hop = (hopT > 0.3 && hopT < 0.56)
        ? sin((hopT - 0.3) / 0.26 * pi) * 50 * scale
        : 0.0;
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(kidX, floorY + 2),
            width: 44 * scale * (1 - hop / 200),
            height: 9 * scale),
        Paint()..color = const Color(0x44000000));
    drawCharacter(canvas, ch, Offset(kidX, floorY - hop), scale,
        phase: time * 14, airborne: hop > 2, time: time);

    // Mom chasing
    final windup = hopT < 0.15 ? hopT / 0.15 : 0.0;
    drawMom(canvas, Offset(size.width * 0.15, floorY + 4), scale * 0.85,
        time: time, windup: windup, anger: 0.8, shouting: true, twirl: time * 9);

    // slipper flying across under the hop
    final st = ((time % 1.5) / 1.5 - 0.15) / 0.5;
    if (st > 0 && st < 1) {
      final sx = size.width * 0.28 + st * size.width * 0.8;
      drawSlipper(canvas, Offset(sx, floorY - 30 * scale), 46 * scale, time * 16);
      for (int k = 1; k <= 4; k++) {
        canvas.drawOval(
            Rect.fromCenter(
                center: Offset(sx - k * 14, floorY - 30 * scale),
                width: 18 - k * 2.0,
                height: 6),
            Paint()..color = Color.fromARGB(120 - k * 25, 160, 200, 255));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _HeroPainter old) => old.t != t || old.ch != ch;
}

class _NavCard extends StatelessWidget {
  const _NavCard({
    required this.label,
    required this.icon,
    required this.tone,
    required this.onTap,
    this.badge = false,
  });
  final String label;
  final IconData icon;
  final Tone tone;
  final VoidCallback onTap;
  final bool badge;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Stack(clipBehavior: Clip.none, children: [
        GameButton(
          tone: tone,
          height: 76,
          radius: 22,
          depth: 5,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          onTap: onTap,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 30),
              const SizedBox(height: 2),
              FittedBox(
                  child: Text(label, style: const TextStyle(fontSize: 13))),
            ],
          ),
        ),
        if (badge)
          Positioned(
            top: -6,
            left: -4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
              decoration: BoxDecoration(
                color: C.red,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: C.white, width: 2),
              ),
              child: const Text('!',
                  style: TextStyle(
                      color: C.white, fontWeight: FontWeight.w900)),
            ),
          ),
      ]),
    );
  }
}

class _SettingsSheet extends StatelessWidget {
  const _SettingsSheet();

  @override
  Widget build(BuildContext context) {
    final s = SaveData.i;
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) => Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
        decoration: BoxDecoration(
          color: C.cream,
          borderRadius: BorderRadius.circular(28),
          boxShadow: kSoftShadow,
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const OutlinedTitle('تنظیمات', size: 30),
          const SizedBox(height: 12),
          _switchRow(Icons.volume_up_rounded, 'صداها', s.soundOn, (v) {
            s.setSound(v);
            Audio.i.setSound(v);
            if (v) Audio.i.play(Sfx.click);
          }),
          _switchRow(Icons.music_note_rounded, 'موسیقی', s.musicOn, (v) async {
            s.setMusic(v);
            await Audio.i.setMusic(v);
            if (v) await Audio.i.startMusic();
          }),
          const SizedBox(height: 8),
          GameButton(
            tone: Tone.white,
            height: 46,
            onTap: () {
              s.setTutorialDone(false);
              final messenger = ScaffoldMessenger.of(context);
              Navigator.of(context).pop();
              messenger.showSnackBar(const SnackBar(
                  content: Text('بازی بعدی با آموزش شروع میشه',
                      style: TextStyle(fontFamily: 'Vazirmatn'))));
            },
            child: const Text('آموزش رو دوباره ببینم', style: TextStyle(fontSize: 15)),
          ),
          const SizedBox(height: 8),
          const Text('دمپایی پرنده · نسخه ۱٫۴', style: kSmall),
        ]),
      ),
    );
  }

  Widget _switchRow(
      IconData icon, String label, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Panel(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        radius: 18,
        child: Row(children: [
          Icon(icon, color: C.ink),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: kBody)),
          Switch(
            value: value,
            activeColor: C.white,
            activeTrackColor: C.green,
            onChanged: onChanged,
          ),
        ]),
      ),
    );
  }
}
