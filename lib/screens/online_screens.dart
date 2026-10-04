import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../game/characters.dart';
import '../services/api.dart';
import '../services/audio.dart';
import '../services/save_data.dart';
import '../theme.dart';

void _toast(BuildContext context, String msg) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    behavior: SnackBarBehavior.floating,
    backgroundColor: C.ink,
    content: Text(msg, style: const TextStyle(fontFamily: 'Vazirmatn', fontWeight: FontWeight.w700)),
    duration: const Duration(seconds: 3),
  ));
}

// ---------------------------------------------------------------- home row

/// "Leaderboard" and "gift inbox" buttons on the home screen.
class OnlineRow extends StatelessWidget {
  const OnlineRow({super.key});

  @override
  Widget build(BuildContext context) {
    if (!Api.i.enabled) return const SizedBox.shrink();
    final gifts = Api.i.inboxCount;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        _chip(context, Icons.emoji_events_rounded, 'جدول هفته', C.goldDark, () {
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LeaderboardScreen()));
        }),
        const SizedBox(width: 10),
        Stack(clipBehavior: Clip.none, children: [
          _chip(context, Icons.mail_rounded, 'صندوق هدیه', C.purpleDark, () => showInbox(context)),
          if (gifts > 0)
            Positioned(
              top: -6,
              left: -6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: C.red,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: C.white, width: 2),
                ),
                child: Text(fa(gifts),
                    style: const TextStyle(color: C.white, fontWeight: FontWeight.w900, fontSize: 12)),
              ),
            ),
        ]),
      ]),
    );
  }

  Widget _chip(BuildContext context, IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: () {
        Audio.i.play(Sfx.click);
        onTap();
      },
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: C.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color, width: 2),
          boxShadow: kSoftShadow,
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w900)),
        ]),
      ),
    );
  }
}

// ---------------------------------------------------------------- forced update / maintenance

/// Shows a blocking dialog if the server says "update" or "maintenance".
Future<void> checkServerNotice(BuildContext context) async {
  final cfg = Api.i.config;
  if (cfg == null || !context.mounted) return;
  final mustUpdate = kAppBuild < cfg.minVersion;
  if (!mustUpdate && !cfg.maintenance) return;
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => PopScope(
      canPop: false,
      child: AlertDialog(
        backgroundColor: C.cream,
        title: Text(mustUpdate ? 'نسخه جدید اومده!' : 'در حال تعمیر',
            style: const TextStyle(fontWeight: FontWeight.w900)),
        content: Text(mustUpdate
            ? 'برای ادامه بازی، نسخه جدید رو از کافه‌بازار نصب کن.'
            : cfg.maintenanceMessage),
        actions: [
          if (mustUpdate)
            FilledButton(
              onPressed: () => Clipboard.setData(ClipboardData(text: cfg.updateUrl)).then((_) {
                if (ctx.mounted) _toast(ctx, 'لینک کپی شد، در مرورگر باز کن');
              }),
              child: const Text('کپی لینک'),
            )
          else
            FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('باشه')),
        ],
      ),
    ),
  );
}

// ---------------------------------------------------------------- leaderboard

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  String _period = 'week';
  late Future<Leaderboard?> _future = Api.i.leaderboard(_period);

  void _load(String period) {
    setState(() {
      _period = period;
      _future = Api.i.leaderboard(period);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: WarmBackground(
        child: SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
              child: Row(children: [
                RoundButton(
                    icon: Icons.arrow_back_rounded,
                    label: 'بازگشت',
                    onTap: () => Navigator.of(context).pop()),
                const SizedBox(width: 12),
                const Expanded(child: OutlinedTitle('جدول قهرمان‌ها', size: 28)),
                RoundButton(icon: Icons.edit_rounded, label: 'اسم من', onTap: _editName),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(children: [
                Expanded(child: _tab('این هفته', 'week')),
                const SizedBox(width: 8),
                Expanded(child: _tab('همیشه', 'all')),
              ]),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: FutureBuilder<Leaderboard?>(
                future: _future,
                builder: (context, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator(color: C.red));
                  }
                  final lb = snap.data;
                  if (lb == null) {
                    return Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        const Text('اتصال به سرور برقرار نشد', style: kBody),
                        if (Api.i.lastError.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(24, 6, 24, 0),
                            child: Text(Api.i.lastError,
                                textAlign: TextAlign.center,
                                textDirection: TextDirection.ltr,
                                style: const TextStyle(fontSize: 11, color: C.inkSoft)),
                          ),
                        const SizedBox(height: 10),
                        GameButton(
                            tone: Tone.teal,
                            height: 46,
                            onTap: () => _load(_period),
                            child: const Text('دوباره')),
                      ]),
                    );
                  }
                  return _list(lb);
                },
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _tab(String label, String period) {
    final on = _period == period;
    return GameButton(
      tone: on ? Tone.red : Tone.white,
      height: 44,
      onTap: on ? null : () => _load(period),
      child: Text(label, style: const TextStyle(fontSize: 15)),
    );
  }

  Widget _list(Leaderboard lb) {
    final me = lb.me;
    final ends = lb.endsAt;
    String? endsText;
    if (ends != null) {
      final left = DateTime.fromMillisecondsSinceEpoch(ends * 1000).difference(SaveData.now());
      endsText = left.inDays > 0
          ? '${fa(left.inDays)} روز تا پایان هفته'
          : '${fa(left.inHours.clamp(0, 24))} ساعت تا پایان هفته';
    }
    return Column(children: [
      if (endsText != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text('$endsText · نفرات برتر جایزه می‌گیرن!', style: kSmall),
        ),
      Expanded(
        child: lb.top.isEmpty
            ? const Center(child: Text('هنوز کسی بازی نکرده. اولین نفر باش!', style: kBody))
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                itemCount: lb.top.length,
                itemBuilder: (_, i) => _row(lb.top[i]),
              ),
      ),
      if (me != null && !lb.top.any((r) => r.me))
        Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 12), child: _row(me)),
      if (me == null)
        const Padding(
          padding: EdgeInsets.only(bottom: 14),
          child: Text('یه بازی کن تا اسمت تو جدول بیاد!', style: kBody),
        ),
    ]);
  }

  Widget _row(LeaderRow r) {
    final medal = switch (r.rank) {
      1 => C.gold,
      2 => const Color(0xFFC9CED8),
      3 => const Color(0xFFD99A5B),
      _ => null,
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Panel(
        radius: 18,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        color: r.me ? const Color(0xFFFFF1C9) : C.white,
        border: r.me ? Border.all(color: C.goldDark, width: 2) : null,
        child: Row(children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: medal ?? const Color(0xFFF1E6F7), shape: BoxShape.circle),
            child: Text(fa(r.rank), style: const TextStyle(fontWeight: FontWeight.w900, color: C.ink)),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 40,
            height: 46,
            child: CustomPaint(painter: _AvatarPainter(characterById(r.character))),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(r.me ? '${r.nickname} (تو)' : r.nickname,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: C.ink)),
              Text('${fa(r.meters)} متر', style: kSmall),
            ]),
          ),
          Text(fa(r.score), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: C.redDark)),
        ]),
      ),
    );
  }

  Future<void> _editName() async {
    final ctrl = TextEditingController(text: Api.i.nickname);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: C.cream,
        title: const Text('اسمت تو جدول', style: TextStyle(fontWeight: FontWeight.w900)),
        content: TextField(
          controller: ctrl,
          maxLength: 16,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'مثلاً: علی شیطون'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('انصراف')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text('ذخیره')),
        ],
      ),
    );
    if (name == null || name.trim().isEmpty || !mounted) return;
    final err = await Api.i.setNickname(name.trim());
    if (!mounted) return;
    if (err != null) {
      _toast(context, err);
    } else {
      _load(_period);
    }
  }
}

class _AvatarPainter extends CustomPainter {
  _AvatarPainter(this.ch);
  final Character ch;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    drawCharacter(canvas, ch, Offset(size.width / 2, size.height + 4), 0.34, phase: 0.25);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_AvatarPainter old) => old.ch.id != ch.id;
}

// ---------------------------------------------------------------- inbox

Future<void> showInbox(BuildContext context) async {
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => const _InboxSheet(),
  );
}

class _InboxSheet extends StatefulWidget {
  const _InboxSheet();

  @override
  State<_InboxSheet> createState() => _InboxSheetState();
}

class _InboxSheetState extends State<_InboxSheet> {
  late Future<List<InboxGift>> _future = Api.i.inbox();
  final Set<String> _busy = {};

  Future<void> _claim(InboxGift g) async {
    setState(() => _busy.add(g.id));
    final text = await Api.i.claim(g);
    if (!mounted) return;
    if (text != null) {
      Audio.i.play(Sfx.reward);
      _toast(context, text.isEmpty ? 'دریافت شد!' : 'دریافت شد: $text');
    }
    setState(() {
      _busy.remove(g.id);
      _future = Api.i.inbox();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 22),
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
      decoration: BoxDecoration(color: C.cream, borderRadius: BorderRadius.circular(28), boxShadow: kSoftShadow),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const OutlinedTitle('صندوق هدیه', size: 28),
        const SizedBox(height: 10),
        Flexible(
          child: FutureBuilder<List<InboxGift>>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(color: C.red),
                );
              }
              final gifts = snap.data ?? const [];
              if (gifts.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('فعلاً هدیه‌ای نیست. بعداً سر بزن!', style: kBody),
                );
              }
              return ListView(shrinkWrap: true, children: [
                for (final g in gifts)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Panel(
                      radius: 18,
                      child: Row(children: [
                        const Icon(Icons.card_giftcard_rounded, color: C.purpleDark, size: 34),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(g.title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                            if (g.message.isNotEmpty) Text(g.message, style: kSmall),
                          ]),
                        ),
                        GameButton(
                          tone: Tone.green,
                          height: 42,
                          onTap: _busy.contains(g.id) ? null : () => _claim(g),
                          child: const Text('بگیر', style: TextStyle(fontSize: 15)),
                        ),
                      ]),
                    ),
                  ),
              ]);
            },
          ),
        ),
      ]),
    );
  }
}

// ---------------------------------------------------------------- account & invites

Future<void> showAccountSheet(BuildContext context) async {
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => const _AccountSheet(),
  );
}

class _AccountSheet extends StatefulWidget {
  const _AccountSheet();

  @override
  State<_AccountSheet> createState() => _AccountSheetState();
}

class _AccountSheetState extends State<_AccountSheet> {
  final _invite = TextEditingController();
  final _transfer = TextEditingController();
  String? _myTransferCode;
  bool _busy = false;

  Future<void> _run(Future<void> Function() job) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await job();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final code = Api.i.inviteCode;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 22),
        decoration: BoxDecoration(color: C.cream, borderRadius: BorderRadius.circular(28), boxShadow: kSoftShadow),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Center(child: OutlinedTitle('دعوت دوستان', size: 28)),
            const SizedBox(height: 8),
            const Text('دوستت با کد تو وارد بازی بشه: اون ۵۰۰ سکه و یه جعبه شانس می‌گیره، تو ۱٬۰۰۰ سکه!',
                style: kBody, textAlign: TextAlign.center),
            const SizedBox(height: 10),
            Panel(
              radius: 18,
              child: Row(children: [
                const Text('کد من:', style: kBody),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(code.isEmpty ? '...' : code,
                      textDirection: TextDirection.ltr,
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 22, letterSpacing: 3)),
                ),
                GameButton(
                  tone: Tone.teal,
                  height: 42,
                  onTap: code.isEmpty
                      ? null
                      : () => SharePlus.instance.share(ShareParams(
                          text: 'بیا «دمپایی پرنده» بازی کنیم! موقع شروع کد دعوت منو بزن: $code\n'
                              '${Api.i.config?.updateUrl ?? ''}')),
                  child: const Text('بفرست', style: TextStyle(fontSize: 15)),
                ),
              ]),
            ),
            if (!Api.i.referred) ...[
              const SizedBox(height: 14),
              const Text('کد دعوت دوستت رو داری؟', style: TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: _invite,
                    textDirection: TextDirection.ltr,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(hintText: 'ABC123', filled: true, fillColor: C.white),
                  ),
                ),
                const SizedBox(width: 8),
                GameButton(
                  tone: Tone.green,
                  height: 46,
                  onTap: _busy
                      ? null
                      : () => _run(() async {
                            final (reward, err) = await Api.i.redeemInvite(_invite.text);
                            if (!mounted) return;
                            if (err != null) {
                              _toast(context, err);
                            } else {
                              Audio.i.play(Sfx.reward);
                              _toast(context, 'هدیه گرفتی: $reward');
                            }
                          }),
                  child: const Text('ثبت', style: TextStyle(fontSize: 15)),
                ),
              ]),
            ],
            const Divider(height: 30),
            const Center(child: Text('انتقال به گوشی جدید', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17))),
            const SizedBox(height: 6),
            const Text('روی گوشی قدیمی «گرفتن کد» رو بزن و کد رو روی گوشی جدید وارد کن. همه سکه‌ها و شخصیت‌ها منتقل میشن.',
                style: kSmall, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            if (_myTransferCode != null)
              Center(
                child: SelectableText(_myTransferCode!,
                    textDirection: TextDirection.ltr,
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 26, letterSpacing: 4)),
              )
            else
              GameButton(
                tone: Tone.white,
                height: 44,
                onTap: _busy
                    ? null
                    : () => _run(() async {
                          await Api.i.syncNow();
                          final c = await Api.i.makeTransferCode();
                          if (!mounted) return;
                          if (c == null) {
                            _toast(context, 'اتصال به سرور برقرار نیست');
                          } else {
                            setState(() => _myTransferCode = c);
                          }
                        }),
                child: const Text('گرفتن کد (گوشی قدیمی)', style: TextStyle(fontSize: 15)),
              ),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _transfer,
                  textDirection: TextDirection.ltr,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(hintText: 'کد انتقال', filled: true, fillColor: C.white),
                ),
              ),
              const SizedBox(width: 8),
              GameButton(
                tone: Tone.red,
                height: 46,
                onTap: _busy ? null : _confirmTransfer,
                child: const Text('انتقال', style: TextStyle(fontSize: 15)),
              ),
            ]),
          ]),
        ),
      ),
    );
  }

  Future<void> _confirmTransfer() async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: C.cream,
        title: const Text('مطمئنی؟', style: TextStyle(fontWeight: FontWeight.w900)),
        content: const Text('بازی این گوشی با حساب گوشی قدیمی جایگزین میشه.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('نه')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('آره، منتقل کن')),
        ],
      ),
    );
    if (sure != true) return;
    await _run(() async {
      final err = await Api.i.useTransferCode(_transfer.text);
      if (!mounted) return;
      _toast(context, err ?? 'حساب منتقل شد!');
      if (err == null) Navigator.of(context).pop();
    });
  }
}
