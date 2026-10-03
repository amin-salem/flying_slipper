import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../game/characters.dart';
import '../game/cosmetics.dart';
import '../game/game_painter.dart' show drawPowerIcon;
import '../game/world.dart' show PowerKind, powerNames;
import '../services/ad_service.dart';
import '../services/audio.dart';
import '../services/save_data.dart';
import '../services/store_service.dart';
import '../theme.dart';

const int kPillowPrice = 300;
const int kGrandmaPrice = 500;

class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key, this.initialTab = 0});
  final int initialTab;

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  late int _tab = widget.initialTab;

  @override
  Widget build(BuildContext context) {
    final s = SaveData.i;
    return Scaffold(
      body: WarmBackground(
        child: SafeArea(
          child: ListenableBuilder(
            listenable: s,
            builder: (context, _) => Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                  child: Row(children: [
                    RoundButton(
                      icon: Icons.arrow_back_rounded,
                      label: 'بازگشت',
                      onTap: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(child: OutlinedTitle('فروشگاه', size: 32)),
                    CoinPill(amount: s.coins),
                  ]),
                ),
                _Tabs(
                  index: _tab,
                  labels: const ['سکه و بسته', 'شخصیت‌ها', 'پاورآپ', 'دمپایی‌ها'],
                  onChanged: (i) => setState(() => _tab = i),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: switch (_tab) {
                      0 => const _CoinsTab(key: ValueKey(0)),
                      1 => const _CharactersTab(key: ValueKey(1)),
                      2 => const _PowerTab(key: ValueKey(2)),
                      _ => const _SkinsTab(key: ValueKey(3)),
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Tabs extends StatelessWidget {
  const _Tabs(
      {required this.index, required this.labels, required this.onChanged});
  final int index;
  final List<String> labels;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: const Color(0xCCFFFFFF),
        borderRadius: BorderRadius.circular(20),
        boxShadow: kSoftShadow,
      ),
      child: Row(children: [
        for (int i = 0; i < labels.length; i++)
          Expanded(
            child: Semantics(
              selected: i == index,
              button: true,
              child: GestureDetector(
                onTap: () {
                  Audio.i.play(Sfx.click);
                  onChanged(i);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: i == index
                        ? const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0xFF4A3560), C.ink])
                        : null,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Text(labels[i],
                      style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                          color: i == index ? C.white : C.inkSoft)),
                ),
              ),
            ),
          ),
      ]),
    );
  }
}

void _toast(BuildContext context, String msg) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    behavior: SnackBarBehavior.floating,
    backgroundColor: C.ink,
    content: Text(msg,
        style: const TextStyle(
            fontFamily: 'Vazirmatn', fontWeight: FontWeight.w700)),
    duration: const Duration(seconds: 2),
  ));
}

// ---------------------------------------------------------------- Coins

class _CoinsTab extends StatelessWidget {
  const _CoinsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final s = SaveData.i;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      children: [
        if (!s.starterBought) ...[
          _StarterCard(
              onBuy: () => StoreService.buy(context, Products.starter)),
          const SizedBox(height: 18),
        ],
        _PiggyCard(amount: s.piggy),
        const SizedBox(height: 18),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 14,
          crossAxisSpacing: 12,
          childAspectRatio: 0.86,
          children: [
            const _CoinPack(Products.coinsSmall, amount: '۱٬۰۰۰', coins: 1),
            const _CoinPack(Products.coinsMedium,
                amount: '۵٬۰۰۰', coins: 3, tag: 'محبوب‌ترین', tagTone: Tone.red),
            const _CoinPack(Products.coinsLarge,
                amount: '۱۵٬۰۰۰', coins: 5, tag: 'بهترین ارزش', tagTone: Tone.purple),
            _FreeCoins(left: s.freeAdsLeft),
          ],
        ),
        const SizedBox(height: 16),
        if (!s.noAds) ...[
          const _RowOffer(product: Products.removeAds, icon: Icons.block_rounded),
          const SizedBox(height: 12),
        ],
        if (!s.vip)
          const _RowOffer(
              product: Products.vip,
              icon: Icons.workspace_premium_rounded,
              dark: true),
      ],
    );
  }
}

class _StarterCard extends StatelessWidget {
  const _StarterCard({required this.onBuy});
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    final football = characterById('football');
    return Panel(
      radius: 28,
      padding: EdgeInsets.zero,
      gradient: const LinearGradient(
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
        colors: [C.teal, Color(0xFF1C6FA8)],
      ),
      child: Stack(children: [
        Positioned.fill(
          child: CustomPaint(
              painter: TilePatternPainter(color: const Color(0x22FFFFFF), step: 40)),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                    decoration: BoxDecoration(
                        color: C.red, borderRadius: BorderRadius.circular(999)),
                    child: Text(
                        SaveData.i.starterOfferLeft != null
                            ? 'فقط ${fa(SaveData.i.starterOfferLeft!.inHours)} ساعت مونده!'
                            : 'فقط یک‌بار',
                        style: const TextStyle(
                            color: C.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 12)),
                  ),
                  const SizedBox(height: 6),
                  const OutlinedTitle('بسته شروع', size: 26),
                  const SizedBox(height: 6),
                  for (final line in const [
                    'حذف همیشگی تبلیغات',
                    '۵٬۰۰۰ سکه',
                    'شخصیت «گل‌زن محله»'
                  ])
                    Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Row(children: [
                        const Icon(Icons.check_circle_rounded,
                            color: C.gold, size: 18),
                        const SizedBox(width: 6),
                        Text(line,
                            style: const TextStyle(
                                color: C.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 14)),
                      ]),
                    ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: 150,
                    child: GameButton(
                      tone: Tone.gold,
                      height: 48,
                      radius: 16,
                      depth: 5,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      onTap: onBuy,
                      child: FittedBox(
                        child: Text(Products.starter.priceLabel,
                            style: const TextStyle(fontSize: 15)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 110,
              height: 150,
              child: CustomPaint(
                  painter: _CharPreview(football, mood: Mood.happy, scale: 1.25)),
            ),
          ]),
        ),
      ]),
    );
  }
}

/// Piggy bank: fills with 20% of every run's coins; break it to get them.
class _PiggyCard extends StatelessWidget {
  const _PiggyCard({required this.amount});
  final int amount;

  @override
  Widget build(BuildContext context) {
    final ready = amount >= SaveData.piggyMinToBreak;
    return Panel(
      radius: 24,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      gradient: const LinearGradient(colors: [Color(0xFFFFE3EC), Color(0xFFFFC9D9)]),
      child: Row(children: [
        Container(
          width: 56,
          height: 56,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(colors: [Color(0xFFFF8FB1), Color(0xFFE85C8A)]),
          ),
          child: const Icon(Icons.savings_rounded, color: C.white, size: 32),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('قلک', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: C.ink)),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: amount / SaveData.piggyMax,
                minHeight: 10,
                backgroundColor: const Color(0x55FFFFFF),
                color: const Color(0xFFE85C8A),
              ),
            ),
            const SizedBox(height: 3),
            Text(
                ready
                    ? '${fa(amount)} سکه منتظرته!'
                    : '${fa(amount)} از ${fa(SaveData.piggyMinToBreak)} · با بازی کردن پر میشه',
                style: kSmall.copyWith(fontSize: 11)),
          ]),
        ),
        const SizedBox(width: 10),
        GameButton(
          tone: Tone.purple,
          height: 44,
          radius: 14,
          depth: 4,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          onTap: ready ? () => StoreService.buy(context, Products.piggy) : null,
          child: FittedBox(
            child: Text(ready ? Products.piggy.priceLabel : 'قفله',
                style: const TextStyle(fontSize: 13)),
          ),
        ),
      ]),
    );
  }
}

class _CoinPack extends StatelessWidget {
  const _CoinPack(this.product,
      {required this.amount, required this.coins, this.tag, this.tagTone});
  final Product product;
  final String amount;
  final int coins; // how many coin icons to stack
  final String? tag;
  final Tone? tagTone;

  @override
  Widget build(BuildContext context) {
    return Stack(clipBehavior: Clip.none, children: [
      Positioned.fill(
        child: Panel(
          radius: 24,
          padding: const EdgeInsets.fromLTRB(10, 14, 10, 10),
          border: tagTone != null
              ? Border.all(color: tagTone!.bottom, width: 2.5)
              : null,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SizedBox(
                height: 48,
                child: Stack(alignment: Alignment.center, children: [
                  for (int i = 0; i < coins; i++)
                    Transform.translate(
                      offset: Offset((i - (coins - 1) / 2) * 13.0,
                          (i % 2 == 0 ? 0 : -6).toDouble()),
                      child: const CoinIcon(size: 38),
                    ),
                ]),
              ),
              Text(product.title, style: kSmall),
              Text(amount,
                  style: const TextStyle(
                      fontWeight: FontWeight.w900, fontSize: 22, color: C.ink)),
              GameButton(
                tone: Tone.green,
                height: 42,
                radius: 14,
                depth: 4,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                onTap: () => StoreService.buy(context, product),
                child: FittedBox(
                  child: Text(product.priceLabel,
                      style: const TextStyle(fontSize: 14)),
                ),
              ),
            ],
          ),
        ),
      ),
      if (tag != null)
        Positioned(
          top: -11,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: [tagTone!.top, tagTone!.bottom]),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(tag!,
                  style: const TextStyle(
                      color: C.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w900)),
            ),
          ),
        ),
    ]);
  }
}

class _FreeCoins extends StatelessWidget {
  const _FreeCoins({required this.left});
  final int left;

  @override
  Widget build(BuildContext context) {
    return Panel(
      radius: 24,
      color: const Color(0xFFFFF7EA),
      padding: const EdgeInsets.fromLTRB(10, 14, 10, 10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const SizedBox(
            height: 48,
            child: Icon(Icons.smart_display_rounded, size: 44, color: C.purpleDark),
          ),
          const Text('سکه رایگان', style: kSmall),
          const Text('۱۰۰',
              style: TextStyle(
                  fontWeight: FontWeight.w900, fontSize: 22, color: C.ink)),
          GameButton(
            tone: Tone.purple,
            height: 42,
            radius: 14,
            depth: 4,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            onTap: left > 0
                ? () async {
                    final ok = await AdService.showRewarded(context);
                    if (ok) {
                      SaveData.i.useFreeAd();
                      SaveData.i.addCoins(100);
                      Audio.i.play(Sfx.reward);
                    }
                  }
                : null,
            child: FittedBox(
              child: Text(left > 0 ? 'دیدن تبلیغ (${fa(left)})' : 'فردا دوباره',
                  style: const TextStyle(fontSize: 14)),
            ),
          ),
        ],
      ),
    );
  }
}

class _RowOffer extends StatelessWidget {
  const _RowOffer({required this.product, required this.icon, this.dark = false});
  final Product product;
  final IconData icon;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Panel(
      radius: 22,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      gradient: dark
          ? const LinearGradient(colors: [Color(0xFF4A3560), C.ink])
          : null,
      child: Row(children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: dark ? const [C.gold, C.goldDark] : const [C.red, C.redDark],
            ),
          ),
          child: Icon(icon, color: dark ? C.ink : C.white, size: 26),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(product.title,
                  style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      color: dark ? C.white : C.ink)),
              Text(product.subtitle,
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      color: dark ? const Color(0xFFE5D8F0) : C.inkSoft)),
            ],
          ),
        ),
        GameButton(
          tone: dark ? Tone.gold : Tone.green,
          height: 42,
          radius: 14,
          depth: 4,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          onTap: () => StoreService.buy(context, product),
          child: Text(product.priceLabel, style: const TextStyle(fontSize: 13)),
        ),
      ]),
    );
  }
}

// ---------------------------------------------------------------- Characters

class _CharactersTab extends StatelessWidget {
  const _CharactersTab({super.key});

  @override
  Widget build(BuildContext context) {
    final s = SaveData.i;
    return GridView.count(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
      crossAxisCount: 2,
      mainAxisSpacing: 14,
      crossAxisSpacing: 12,
      childAspectRatio: 0.56,
      children: [
        for (final ch in kCharacters)
          _CharacterCard(
            ch: ch,
            owned: s.owned.contains(ch.id),
            selected: s.skin == ch.id,
          ),
      ],
    );
  }
}

class _CharacterCard extends StatefulWidget {
  const _CharacterCard(
      {required this.ch, required this.owned, required this.selected});
  final Character ch;
  final bool owned;
  final bool selected;

  @override
  State<_CharacterCard> createState() => _CharacterCardState();
}

class _CharacterCardState extends State<_CharacterCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _a =
      AnimationController(vsync: this, duration: const Duration(seconds: 2))
        ..repeat();

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = SaveData.i;
    final ch = widget.ch;
    String label;
    Tone tone;
    VoidCallback? onTap;
    if (widget.selected) {
      label = 'انتخاب شده';
      tone = Tone.white;
      onTap = null;
    } else if (widget.owned) {
      label = 'انتخاب';
      tone = Tone.teal;
      onTap = () => s.selectCharacter(ch.id);
    } else {
      label = fa(ch.price);
      tone = Tone.green;
      onTap = () {
        if (s.buyCharacter(ch)) {
          Audio.i.play(Sfx.reward);
        } else {
          _toast(context, 'سکه کافی نداری! از تب «سکه و بسته» بگیر.');
        }
      };
    }

    return Panel(
      radius: 24,
      padding: const EdgeInsets.all(8),
      border: widget.selected ? Border.all(color: C.teal, width: 3) : null,
      child: Column(children: [
        Expanded(
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: ch.rarity.bg,
              ),
            ),
            child: Stack(children: [
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _a,
                  builder: (context, _) => CustomPaint(
                    painter: _CharPreview(ch,
                        time: _a.value * 2,
                        mood: widget.owned ? Mood.happy : ch.runMood,
                        locked: !widget.owned),
                  ),
                ),
              ),
              PositionedDirectional(
                top: 6,
                start: 6,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
                  decoration: BoxDecoration(
                    color: ch.rarity.color,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(ch.rarity.label,
                      style: const TextStyle(
                          color: C.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w900)),
                ),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 6),
        Text(ch.name,
            style: const TextStyle(
                fontWeight: FontWeight.w900, fontSize: 15, color: C.ink)),
        const SizedBox(height: 4),
        // the character's special power: the reason to buy them
        GestureDetector(
          onTap: ch.upgradable ? () => _showPower(context, ch, widget.owned) : null,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(6, 5, 6, 5),
            decoration: BoxDecoration(
              color: ch.rarity.bg.last.withAlpha(150),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(children: [
              Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(ch.abilityIcon, size: 16, color: ch.rarity.color),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(ch.abilityName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: ch.rarity.color)),
                ),
              ]),
              Text(ch.descAt(s.levelOf(ch.id)),
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: kSmall.copyWith(fontSize: 11, height: 1.25)),
              if (ch.upgradable) ...[
                const SizedBox(height: 3),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  for (int l = 1; l <= 3; l++)
                    Container(
                      width: 14,
                      height: 6,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: l <= s.levelOf(ch.id) ? ch.rarity.color : const Color(0x332B1B3A),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  if (widget.owned && s.levelOf(ch.id) < 3) ...[
                    const SizedBox(width: 4),
                    const Icon(Icons.upgrade_rounded, size: 16, color: C.greenDark),
                  ],
                ]),
              ],
            ]),
          ),
        ),
        const SizedBox(height: 6),
        GameButton(
          tone: tone,
          height: 40,
          radius: 14,
          depth: 4,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          onTap: onTap,
          sound: true,
          child: FittedBox(
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (!widget.owned) ...[
                const CoinIcon(size: 18),
                const SizedBox(width: 4),
              ],
              Text(label, style: const TextStyle(fontSize: 14)),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _CharPreview extends CustomPainter {
  _CharPreview(this.ch,
      {this.time = 0, this.mood = Mood.happy, this.locked = false, this.scale});
  final Character ch;
  final double time;
  final Mood mood;
  final bool locked;
  final double? scale;

  @override
  void paint(Canvas canvas, Size size) {
    final sc = scale ?? (size.height / 135).clamp(0.6, 1.4);
    final feet = Offset(size.width / 2 - 4, size.height - 10);
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(size.width / 2, size.height - 9),
            width: 50 * sc,
            height: 10 * sc),
        Paint()..color = const Color(0x33000000));
    if (locked) {
      canvas.saveLayer(Offset.zero & size, Paint()..color = const Color(0xFFFFFFFF));
    }
    drawCharacter(canvas, ch, feet, sc,
        phase: 0.6, mood: mood, time: time, airborne: false);
    if (locked) {
      // silhouette-ish tint for locked characters
      canvas.drawRect(
          Offset.zero & size,
          Paint()
            ..color = const Color(0x552B1B3A)
            ..blendMode = BlendMode.srcATop);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _CharPreview old) =>
      old.time != time || old.ch != ch || old.locked != locked || old.mood != mood;
}

/// Shows all 3 levels of a character's power, with an upgrade button.
void _showPower(BuildContext context, Character ch, bool owned) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (ctx) => ListenableBuilder(
      listenable: SaveData.i,
      builder: (ctx, _) {
        final s = SaveData.i;
        final lvl = s.levelOf(ch.id);
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
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(ch.abilityIcon, color: ch.rarity.color, size: 30),
                const SizedBox(width: 8),
                OutlinedTitle(ch.abilityName, size: 28, fill: ch.rarity.color),
              ]),
              Text(ch.name, style: kSmall.copyWith(fontSize: 13)),
              const SizedBox(height: 14),
              for (int l = 1; l <= 3; l++)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: l <= lvl ? ch.rarity.bg.last : C.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: l == lvl ? ch.rarity.color : const Color(0x22000000),
                        width: l == lvl ? 2.5 : 1),
                  ),
                  child: Row(children: [
                    Text('سطح ${fa(l)}',
                        style: TextStyle(
                            fontWeight: FontWeight.w900, color: ch.rarity.color)),
                    const SizedBox(width: 10),
                    Expanded(child: Text(ch.descAt(l), style: kBody.copyWith(fontSize: 14))),
                    if (l <= lvl)
                      const Icon(Icons.check_circle_rounded, color: C.greenDark, size: 22),
                  ]),
                ),
              const SizedBox(height: 8),
              if (!owned)
                Text('اول این شخصیت رو بخر', style: kSmall.copyWith(fontSize: 13))
              else if (lvl >= 3)
                const Text('حداکثر سطح!',
                    style: TextStyle(fontWeight: FontWeight.w900, color: C.greenDark))
              else
                GameButton(
                  tone: Tone.green,
                  onTap: () {
                    if (s.upgradePower(ch)) {
                      Audio.i.play(Sfx.powerup);
                    } else {
                      _toast(ctx, 'سکه کافی نداری!');
                    }
                  },
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text('ارتقا به سطح ${fa(lvl + 1)}', style: const TextStyle(fontSize: 17)),
                    const SizedBox(width: 10),
                    const CoinIcon(size: 22),
                    const SizedBox(width: 4),
                    Text(fa(kUpgradeCost[lvl]), style: const TextStyle(fontSize: 17)),
                  ]),
                ),
            ]),
          ),
        );
      },
    ),
  );
}

// ---------------------------------------------------------------- Power-ups

class _PowerTab extends StatelessWidget {
  const _PowerTab({super.key});

  @override
  Widget build(BuildContext context) {
    final s = SaveData.i;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text('توی بازی جمعشون کن · ارتقا = زمان بیشتر',
              style: kSmall.copyWith(fontSize: 13)),
        ),
        for (final k in PowerKind.values) ...[
          _BoostRow(kind: k),
          const SizedBox(height: 12),
        ],
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text('کمک‌های قبل از بازی', style: kSmall.copyWith(fontSize: 13)),
        ),
        _PowerRow(
          icon: Icons.bed_rounded,
          tone: Tone.teal,
          title: 'بالش',
          desc: 'یک بار جلوی ضربه رو می‌گیره',
          have: s.pillows,
          price: kPillowPrice,
          onBuy: () {
            if (s.spend(kPillowPrice)) {
              s.addPillows(1);
              Audio.i.play(Sfx.powerup);
            } else {
              _toast(context, 'سکه کافی نداری!');
            }
          },
        ),
        const SizedBox(height: 12),
        _PowerRow(
          icon: Icons.elderly_rounded,
          tone: Tone.purple,
          title: 'مادربزرگ',
          desc: 'میاد و همه چی رو جمع می‌کنه، مامان هم آروم میشه',
          have: s.grandmas,
          price: kGrandmaPrice,
          onBuy: () {
            if (s.spend(kGrandmaPrice)) {
              s.addGrandmas(1);
              Audio.i.play(Sfx.powerup);
            } else {
              _toast(context, 'سکه کافی نداری!');
            }
          },
        ),
      ],
    );
  }
}

/// Upgrade row for an in-run power-up (5 levels, longer each time).
class _BoostRow extends StatelessWidget {
  const _BoostRow({required this.kind});
  final PowerKind kind;

  @override
  Widget build(BuildContext context) {
    final s = SaveData.i;
    final lvl = s.boostLevel(kind);
    final maxed = lvl >= SaveData.boostMaxLevel;
    final secs = s.boostDuration(kind).round();
    return Panel(
      radius: 22,
      child: Row(children: [
        Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            color: const Color(0xFFF3ECFF),
            borderRadius: BorderRadius.circular(18),
          ),
          child: CustomPaint(painter: _BoostIconPainter(kind)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${powerNames[kind]}  ·  ${fa(secs)} ثانیه',
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: C.ink)),
            const SizedBox(height: 4),
            Row(children: [
              for (int l = 1; l <= SaveData.boostMaxLevel; l++)
                Container(
                  width: 18,
                  height: 7,
                  margin: const EdgeInsetsDirectional.only(end: 3),
                  decoration: BoxDecoration(
                    color: l <= lvl ? C.purpleDark : const Color(0x332B1B3A),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
            ]),
          ]),
        ),
        const SizedBox(width: 8),
        maxed
            ? const Text('حداکثر', style: TextStyle(fontWeight: FontWeight.w900, color: C.greenDark))
            : GameButton(
                tone: Tone.green,
                height: 42,
                radius: 14,
                depth: 4,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                onTap: () {
                  if (s.upgradeBoost(kind)) {
                    Audio.i.play(Sfx.powerup);
                  } else {
                    _toast(context, 'سکه کافی نداری!');
                  }
                },
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const CoinIcon(size: 18),
                  const SizedBox(width: 4),
                  Text(fa(SaveData.boostCosts[lvl]), style: const TextStyle(fontSize: 14)),
                ]),
              ),
      ]),
    );
  }
}

class _BoostIconPainter extends CustomPainter {
  _BoostIconPainter(this.kind);
  final PowerKind kind;

  @override
  void paint(Canvas canvas, Size size) =>
      drawPowerIcon(canvas, kind, size.center(Offset.zero), size.width * 0.32);

  @override
  bool shouldRepaint(covariant _BoostIconPainter old) => old.kind != kind;
}

class _PowerRow extends StatelessWidget {
  const _PowerRow({
    required this.icon,
    required this.tone,
    required this.title,
    required this.desc,
    required this.have,
    required this.price,
    required this.onBuy,
  });
  final IconData icon;
  final Tone tone;
  final String title;
  final String desc;
  final int have;
  final int price;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    return Panel(
      radius: 22,
      child: Row(children: [
        Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [tone.top, tone.bottom]),
          ),
          child: Icon(icon, size: 32, color: C.white),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$title  ·  داری: ${fa(have)}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w900, fontSize: 16, color: C.ink)),
              Text(desc, style: kSmall),
            ],
          ),
        ),
        const SizedBox(width: 8),
        GameButton(
          tone: Tone.green,
          height: 42,
          radius: 14,
          depth: 4,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          onTap: onBuy,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const CoinIcon(size: 18),
            const SizedBox(width: 4),
            Text(fa(price), style: const TextStyle(fontSize: 14)),
          ]),
        ),
      ]),
    );
  }
}


// ---------------------------------------------------------------- Skins

/// Is this id a slipper skin (otherwise a belt skin)?
bool _isSlipper(String id) => id.startsWith('slipper_');

String _skinName(String id) =>
    _isSlipper(id) ? slipperById(id).name : beltById(id).name;

int _skinRarity(String id) =>
    _isSlipper(id) ? slipperById(id).rarity : beltById(id).rarity;

class _SkinPreview extends CustomPainter {
  _SkinPreview(this.id, {this.t = 0});
  final String id;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    if (_isSlipper(id)) {
      drawSlipper(canvas, c, size.width * 0.62, -0.35 + math.sin(t * math.pi * 2) * 0.12,
          skin: slipperById(id));
    } else {
      drawBeltSample(canvas, c, size.width * 0.8, beltById(id));
    }
  }

  @override
  bool shouldRepaint(_SkinPreview old) => old.id != id || old.t != t;
}

class _SkinsTab extends StatelessWidget {
  const _SkinsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final s = SaveData.i;
    Widget grid(List<String> ids, String equipped) => GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 0.72,
          children: [
            for (final id in ids)
              _SkinCard(
                id: id,
                owned: s.ownedCosmetics.contains(id),
                equipped: equipped == id,
              ),
          ],
        );
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      children: [
        const _MachineCard(),
        const SizedBox(height: 18),
        const _SectionTitle('دمپایی مامان'),
        const SizedBox(height: 8),
        grid([for (final k in kSlippers) k.id], s.equippedSlipper),
        const SizedBox(height: 18),
        const _SectionTitle('کمربند بابا'),
        const SizedBox(height: 8),
        grid([for (final b in kBelts) b.id], s.equippedBelt),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(text,
          style: const TextStyle(
              fontWeight: FontWeight.w900, fontSize: 18, color: C.ink)),
    );
  }
}

class _MachineCard extends StatelessWidget {
  const _MachineCard();

  @override
  Widget build(BuildContext context) {
    final s = SaveData.i;
    final total = kSlippers.length + kBelts.length;
    final have = s.ownedCosmetics.length;
    return Panel(
      radius: 26,
      gradient: const LinearGradient(
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
        colors: [Color(0xFF7646E8), Color(0xFF3A2A6E)],
      ),
      child: Row(children: [
        const _MachineIcon(),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('دستگاه جایزه',
                style: TextStyle(
                    fontWeight: FontWeight.w900, fontSize: 20, color: C.white)),
            const SizedBox(height: 2),
            Text(
                'دمپایی و کمربند جدید ببر! تکراری بود ${fa(SaveData.machineRefund)} سکه پس می‌گیری.',
                style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: Color(0xFFE6DCFF))),
            const SizedBox(height: 4),
            Text('مجموعه: ${fa(have)} از ${fa(total)}',
                style: const TextStyle(
                    fontWeight: FontWeight.w900, fontSize: 12, color: C.gold)),
            const SizedBox(height: 8),
            GameButton(
              tone: Tone.gold,
              height: 46,
              onTap: () => _pull(context),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const CoinIcon(size: 20),
                const SizedBox(width: 6),
                Text(fa(SaveData.machineCost),
                    style: const TextStyle(
                        fontWeight: FontWeight.w900, fontSize: 17, color: C.ink)),
                const SizedBox(width: 8),
                const Text('بچرخون!',
                    style: TextStyle(
                        fontWeight: FontWeight.w900, fontSize: 15, color: C.ink)),
              ]),
            ),
          ]),
        ),
      ]),
    );
  }

  void _pull(BuildContext context) {
    final r = SaveData.i.pullMachine();
    if (r == null) {
      _toast(context, 'سکه کافی نداری! از تب «سکه و بسته» بگیر.');
      return;
    }
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _PullDialog(result: r),
    );
  }
}

class _MachineIcon extends StatelessWidget {
  const _MachineIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 84,
      height: 104,
      decoration: BoxDecoration(
        color: const Color(0xFFFF5A4E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: C.ink, width: 3),
      ),
      child: Column(children: [
        const SizedBox(height: 8),
        Container(
          width: 64,
          height: 56,
          decoration: BoxDecoration(
            color: const Color(0xFFDDF4FF),
            shape: BoxShape.circle,
            border: Border.all(color: C.ink, width: 3),
          ),
          child: CustomPaint(painter: _SkinPreview('slipper_gold')),
        ),
        const SizedBox(height: 8),
        Container(
          width: 30,
          height: 18,
          decoration: BoxDecoration(
            color: C.ink,
            borderRadius: BorderRadius.circular(6),
          ),
        ),
      ]),
    );
  }
}

class _PullDialog extends StatefulWidget {
  const _PullDialog({required this.result});
  final MachinePull result;

  @override
  State<_PullDialog> createState() => _PullDialogState();
}

class _PullDialogState extends State<_PullDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _a = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1800))
    ..forward()
    ..addStatusListener((st) {
      if (st == AnimationStatus.completed && mounted) {
        setState(() {});
        Audio.i.play(widget.result.duplicate ? Sfx.coin : Sfx.reward);
      }
    })
    ..addListener(_tick);

  late final List<String> _all = [
    for (final k in kSlippers) k.id,
    for (final b in kBelts) b.id,
  ];
  int _shown = 0;
  int _lastStep = -1;

  void _tick() {
    // fast at first, slower near the end (like a real machine)
    final v = Curves.easeOutCubic.transform(_a.value);
    final step = (v * 22).floor();
    if (step != _lastStep) {
      _lastStep = step;
      if (_a.value < 1) {
        setState(() => _shown = (_shown + 1) % _all.length);
        Audio.i.play(Sfx.click, volume: 0.5);
      } else {
        setState(() {});
      }
    }
  }

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final done = _a.isCompleted;
    final id = done ? widget.result.id : _all[_shown];
    final rarity = _skinRarity(id);
    final rc = kCosmeticRarityColor[rarity];
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      child: Panel(
        radius: 28,
        padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
        border: Border.all(color: done ? rc : C.ink, width: 4),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(
              done
                  ? (widget.result.duplicate ? 'تکراری بود!' : 'جایزه جدید!')
                  : 'داره می‌چرخه...',
              style: const TextStyle(
                  fontWeight: FontWeight.w900, fontSize: 24, color: C.ink)),
          const SizedBox(height: 12),
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: 170,
            height: 150,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: RadialGradient(colors: [
                done ? rc.withValues(alpha: 0.35) : const Color(0xFFF3ECFF),
                const Color(0xFFFFF7EA),
              ]),
            ),
            child: AnimatedScale(
              scale: done ? 1.15 : 1,
              duration: const Duration(milliseconds: 300),
              curve: Curves.elasticOut,
              child: CustomPaint(painter: _SkinPreview(id)),
            ),
          ),
          const SizedBox(height: 10),
          Opacity(
            opacity: done ? 1 : 0.35,
            child: Column(children: [
              Text(_skinName(id),
                  style: const TextStyle(
                      fontWeight: FontWeight.w900, fontSize: 20, color: C.ink)),
              Text(kCosmeticRarity[rarity],
                  style: TextStyle(
                      fontWeight: FontWeight.w900, fontSize: 14, color: rc)),
            ]),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 22,
            child: done && widget.result.duplicate
                ? Row(mainAxisSize: MainAxisSize.min, children: [
                    const CoinIcon(size: 18),
                    const SizedBox(width: 4),
                    Text('${fa(SaveData.machineRefund)} سکه برگشت',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: C.inkSoft)),
                  ])
                : null,
          ),
          const SizedBox(height: 10),
          if (done)
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              if (!widget.result.duplicate) ...[
                GameButton(
                  tone: Tone.teal,
                  height: 48,
                  onTap: () {
                    SaveData.i.equipCosmetic(id);
                    Navigator.of(context).pop();
                  },
                  child: const Text('استفاده کن',
                      style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          color: C.white)),
                ),
                const SizedBox(width: 10),
              ],
              GameButton(
                tone: Tone.white,
                height: 48,
                onTap: () => Navigator.of(context).pop(),
                child: const Text('باشه',
                    style: TextStyle(
                        fontWeight: FontWeight.w900, fontSize: 16, color: C.ink)),
              ),
            ])
          else
            const SizedBox(height: 54),
        ]),
      ),
    );
  }
}

class _SkinCard extends StatelessWidget {
  const _SkinCard({required this.id, required this.owned, required this.equipped});
  final String id;
  final bool owned;
  final bool equipped;

  @override
  Widget build(BuildContext context) {
    final rarity = _skinRarity(id);
    final rc = kCosmeticRarityColor[rarity];
    return Panel(
      radius: 20,
      padding: const EdgeInsets.all(6),
      border: Border.all(color: equipped ? C.teal : rc.withValues(alpha: 0.5), width: equipped ? 3 : 2),
      child: Column(children: [
        Expanded(
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: rc.withValues(alpha: 0.12),
            ),
            child: Stack(children: [
              Positioned.fill(
                child: Opacity(
                  opacity: owned ? 1 : 0.25,
                  child: CustomPaint(painter: _SkinPreview(id)),
                ),
              ),
              if (!owned)
                const Center(
                    child: Icon(Icons.lock_rounded, color: C.inkSoft, size: 26)),
            ]),
          ),
        ),
        const SizedBox(height: 4),
        Text(_skinName(id),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontWeight: FontWeight.w900, fontSize: 12, color: C.ink)),
        Text(kCosmeticRarity[rarity],
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 10, color: rc)),
        const SizedBox(height: 4),
        SizedBox(
          height: 30,
          child: !owned
              ? const Center(
                  child: Text('از دستگاه',
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                          color: C.inkSoft)))
              : equipped
                  ? const Center(
                      child: Icon(Icons.check_circle_rounded,
                          color: C.teal, size: 24))
                  : GameButton(
                      tone: Tone.teal,
                      height: 30,
                      radius: 12,
                      depth: 3,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      onTap: () => SaveData.i.equipCosmetic(id),
                      child: const Text('انتخاب',
                          style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                              color: C.white)),
                    ),
        ),
      ]),
    );
  }
}
