import 'dart:math';

import 'package:flutter/material.dart';

import '../game/characters.dart';
import '../game/room_decor.dart';
import '../game/game_painter.dart' show drawHuntToken;
import '../services/audio.dart';
import '../services/missions.dart';
import '../services/save_data.dart';
import '../theme.dart';
import 'game_screen.dart';
import 'house_screen.dart';
import 'rewards.dart';
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

  static bool _calendarShown = false;

  @override
  void initState() {
    super.initState();
    // Open the login calendar automatically once per app start.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final s = SaveData.i;
      if (!_calendarShown && s.canClaimDaily && s.tutorialDone && mounted) {
        _calendarShown = true;
        _claimDaily();
      }
    });
  }

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
    await showDialog<void>(
      context: context,
      builder: (ctx) => const Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.all(16),
        child: _LoginCalendar(),
      ),
    );
  }

  void _openMissions() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => const _MissionsSheet(),
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
                    if (s.mysteryBoxes > 0) ...[
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => showOpenBoxes(context),
                        child: Container(
                          height: 42,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [C.purple, C.purpleDark]),
                            borderRadius: BorderRadius.circular(999),
                            boxShadow: kSoftShadow,
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.card_giftcard_rounded, color: C.white, size: 22),
                            const SizedBox(width: 4),
                            Text(fa(s.mysteryBoxes),
                                style: const TextStyle(color: C.white, fontWeight: FontWeight.w900)),
                          ]),
                        ),
                      ),
                    ],
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
                    Stack(clipBehavior: Clip.none, children: [
                      RoundButton(
                        icon: Icons.home_repair_service_rounded,
                        label: 'تعمیر خونه',
                        tone: Tone.green,
                        onTap: () => Navigator.of(context)
                            .push(MaterialPageRoute(builder: (_) => const HouseScreen())),
                      ),
                      if (s.repairs.length < kRepairs.length &&
                          s.coins >= kRepairs[s.repairs.length].cost)
                        Positioned(
                          top: -4,
                          left: -4,
                          child: Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              color: C.red,
                              shape: BoxShape.circle,
                              border: Border.all(color: C.white, width: 2),
                            ),
                          ),
                        ),
                    ]),
                    const SizedBox(width: 10),
                    RoundButton(
                        icon: Icons.settings_rounded,
                        label: 'تنظیمات',
                        onTap: _settings),
                  ]),
                  const SizedBox(height: 6),
                  _Title(anim: _anim),
                  if (currentSeason() != Season.none)
                    Center(
                      child: Container(
                        margin: const EdgeInsets.only(top: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                        decoration: BoxDecoration(
                          color: currentSeason() == Season.yalda
                              ? const Color(0xFFC62828)
                              : const Color(0xFF2E9B4E),
                          borderRadius: BorderRadius.circular(999),
                          boxShadow: kSoftShadow,
                        ),
                        child: Text(
                            currentSeason() == Season.yalda
                                ? 'شب یلدا مبارک! خونه تزئین شده'
                                : 'نوروز مبارک! خونه تزئین شده',
                            style: const TextStyle(
                                fontWeight: FontWeight.w900, color: C.white)),
                      ),
                    ),
                  if (s.weekendEvent)
                    Center(
                      child: Container(
                        margin: const EdgeInsets.only(top: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [C.gold, C.goldDark]),
                          borderRadius: BorderRadius.circular(999),
                          boxShadow: kSoftShadow,
                        ),
                        child: const Text('آخر هفته‌ست! همه سکه‌ها دوبرابر',
                            style: TextStyle(fontWeight: FontWeight.w900, color: C.ink)),
                      ),
                    ),
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
                        label: 'ماموریت‌ها',
                        icon: Icons.flag_rounded,
                        tone: Tone.red,
                        badge: s.missionsToClaim > 0,
                        onTap: _openMissions),
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


/// 7-day login calendar: come back every day for bigger prizes.
class _LoginCalendar extends StatefulWidget {
  const _LoginCalendar();

  @override
  State<_LoginCalendar> createState() => _LoginCalendarState();
}

class _LoginCalendarState extends State<_LoginCalendar> {
  DailyReward? _got;

  void _claim() {
    final r = SaveData.i.claimDaily();
    if (r == null) return;
    Audio.i.play(Sfx.reward);
    setState(() => _got = r);
  }

  @override
  Widget build(BuildContext context) {
    final s = SaveData.i;
    final today = s.calendarToday;
    final can = s.canClaimDaily;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Panel(
        radius: 28,
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [C.cream, Color(0xFFFFE6C6)],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const OutlinedTitle('جایزه هر روز', size: 30, fill: C.gold),
          const SizedBox(height: 4),
          Text(
              s.streakBroken
                  ? 'یه روز نیومدی، از روز اول شروع شد!'
                  : 'هر روز بیا، جایزه‌ها بزرگ‌تر میشن',
              style: kSmall.copyWith(fontSize: 13)),
          const SizedBox(height: 14),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 0.95,
            children: [for (int i = 0; i < 6; i++) _tile(i, today, can)],
          ),
          const SizedBox(height: 8),
          SizedBox(height: 92, child: _tile(6, today, can)),
          const SizedBox(height: 16),
          if (_got != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text('+${fa(_got!.coins)} سکه گرفتی!',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w900, color: C.greenDark)),
            ),
          GameButton(
            tone: can ? Tone.green : Tone.white,
            onTap: can ? _claim : () => Navigator.of(context).pop(),
            child: Text(can ? 'بگیرش!' : 'فردا برگرد',
                style: const TextStyle(fontSize: 18)),
          ),
        ]),
      ),
    );
  }

  Widget _tile(int i, int today, bool can) {
    final r = SaveData.calendar[i];
    final claimed = i < today || (i == today && !can);
    final isToday = i == today && can;
    final big = i == 6;
    final extras = [
      if (r.pillows > 0) '${fa(r.pillows)} بالش',
      if (r.grandmas > 0) '${fa(r.grandmas)} مادربزرگ',
    ].join(' + ');
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        gradient: isToday
            ? const LinearGradient(colors: [C.gold, C.goldDark])
            : (big
                ? const LinearGradient(colors: [Color(0xFFEDE2FF), Color(0xFFD2BCFF)])
                : null),
        color: isToday || big ? null : (claimed ? const Color(0xFFE8F6EC) : C.white),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: isToday ? C.redDark : const Color(0x22000000), width: isToday ? 3 : 1),
        boxShadow: isToday ? kSoftShadow : null,
      ),
      child: Stack(children: [
        Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('روز ${fa(i + 1)}',
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w800, color: C.inkSoft)),
            const SizedBox(height: 2),
            Row(mainAxisSize: MainAxisSize.min, children: [
              CoinIcon(size: big ? 30 : 22),
              const SizedBox(width: 4),
              Text(fa(r.coins),
                  style: TextStyle(
                      fontSize: big ? 22 : 16, fontWeight: FontWeight.w900, color: C.ink)),
            ]),
            if (extras.isNotEmpty)
              Text('+ $extras',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 10, fontWeight: FontWeight.w800, color: C.purpleDark)),
          ]),
        ),
        if (claimed)
          const Positioned(
            top: 0,
            left: 0,
            child: Icon(Icons.check_circle_rounded, color: C.greenDark, size: 22),
          ),
      ]),
    );
  }
}


/// Today's 3 missions with progress bars and a claim button.
class _MissionsSheet extends StatelessWidget {
  const _MissionsSheet();

  String _timeLeft() {
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day + 1);
    final d = midnight.difference(now);
    return '${fa(d.inHours)} ساعت و ${fa(d.inMinutes % 60)} دقیقه';
  }

  @override
  Widget build(BuildContext context) {
    final s = SaveData.i;
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) {
        final missions = s.missions;
        return Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 20),
          decoration: BoxDecoration(
            color: C.cream,
            borderRadius: BorderRadius.circular(28),
            boxShadow: kSoftShadow,
          ),
          child: SafeArea(
            top: false,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const OutlinedTitle('ماموریت‌های امروز', size: 28, fill: C.red),
              const SizedBox(height: 4),
              Text('ماموریت‌های جدید تا ${_timeLeft()} دیگه',
                  style: kSmall.copyWith(fontSize: 12)),
              const SizedBox(height: 14),
              for (int i = 0; i < missions.length; i++) ...[
                _row(context, missions[i], i),
                const SizedBox(height: 10),
              ],
              _wordCard(),
              const SizedBox(height: 10),
              _huntCard(),
            ]),
          ),
        );
      },
    );
  }

  Widget _huntCard() {
    final s = SaveData.i;
    final got = s.weekTokens;
    final maxT = kHuntTrack.last[0];
    final next = kHuntTrack.where((r) => r[0] > got).toList();
    final now = DateTime.now();
    final dayOfHunt = DateTime.utc(now.year, now.month, now.day)
            .difference(DateTime.utc(2024, 1, 6))
            .inDays %
        7;
    final daysLeft = 7 - dayOfHunt;
    return Panel(
      radius: 20,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      gradient: const LinearGradient(colors: [Color(0xFFF3ECFF), Color(0xFFE2D3FF)]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          SizedBox(width: 26, height: 26, child: CustomPaint(painter: _HuntIconPainter(s.huntToken))),
          const SizedBox(width: 8),
          Expanded(
            child: Text('شکار هفته: ${huntTokenNames[s.huntToken]} جمع کن',
                style: const TextStyle(fontWeight: FontWeight.w900, color: C.purpleEdge)),
          ),
          Text('${fa(daysLeft.clamp(1, 7))} روز مونده', style: kSmall.copyWith(fontSize: 11)),
        ]),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: (got / maxT).clamp(0.0, 1.0),
            minHeight: 12,
            backgroundColor: const Color(0x55FFFFFF),
            color: C.purpleDark,
          ),
        ),
        const SizedBox(height: 6),
        Text(
            next.isEmpty
                ? 'همه جایزه‌های این هفته رو گرفتی!'
                : '${fa(got)} از ${fa(next.first[0])} · جایزه بعدی: ${huntRewardText(next.first)}',
            style: kSmall.copyWith(fontSize: 12, color: C.ink)),
      ]),
    );
  }

  Widget _wordCard() {
    final s = SaveData.i;
    final letters = lettersOf(s.todayWord);
    final got = s.todayWordProgress;
    return Panel(
      radius: 20,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      gradient: const LinearGradient(colors: [Color(0xFFDFF7F5), Color(0xFFBDEDE9)]),
      child: Column(children: [
        Text(s.wordDone ? 'کلمه امروز رو کامل کردی!' : 'کلمه امروز: حرف‌ها رو توی بازی جمع کن',
            style: const TextStyle(fontWeight: FontWeight.w900, color: C.tealEdge)),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          for (int i = 0; i < letters.length; i++)
            Container(
              width: 30,
              height: 34,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: i < got ? C.teal : C.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(i < got ? letters[i] : '؟',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: i < got ? C.white : const Color(0x552B1B3A))),
            ),
        ]),
        const SizedBox(height: 6),
        Text('جایزه: ${fa(kWordReward)} سکه + یه جعبه شانس', style: kSmall.copyWith(fontSize: 12)),
      ]),
    );
  }

  Widget _row(BuildContext context, Mission m, int i) {
    final s = SaveData.i;
    final progress = s.missionProgress[i].clamp(0, m.target);
    final done = progress >= m.target;
    final claimed = s.missionClaimed[i];
    return Panel(
      radius: 20,
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(m.title,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w900, color: C.ink)),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progress / m.target,
                minHeight: 10,
                backgroundColor: const Color(0xFFF1E4F5),
                color: done ? C.green : C.goldDark,
              ),
            ),
            const SizedBox(height: 4),
            Text('${fa(progress)} از ${fa(m.target)}', style: kSmall.copyWith(fontSize: 11)),
          ]),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 96,
          child: claimed
              ? const Column(children: [
                  Icon(Icons.check_circle_rounded, color: C.greenDark, size: 30),
                  Text('گرفتی', style: TextStyle(fontWeight: FontWeight.w800, color: C.greenDark)),
                ])
              : GameButton(
                  tone: done ? Tone.green : Tone.white,
                  height: 44,
                  radius: 14,
                  depth: 4,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  onTap: done
                      ? () {
                          if (s.claimMission(i)) Audio.i.play(Sfx.reward);
                        }
                      : null,
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const CoinIcon(size: 18),
                    const SizedBox(width: 4),
                    Text(fa(m.reward), style: const TextStyle(fontSize: 15)),
                  ]),
                ),
        ),
      ]),
    );
  }
}


class _HuntIconPainter extends CustomPainter {
  _HuntIconPainter(this.t);
  final HuntToken t;

  @override
  void paint(Canvas canvas, Size size) => drawHuntToken(canvas, t, size.center(Offset.zero), size.width * 0.42);

  @override
  bool shouldRepaint(covariant _HuntIconPainter old) => old.t != t;
}
