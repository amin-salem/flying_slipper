import 'dart:async';

import 'package:flutter/material.dart';

import '../services/api.dart';
import '../services/audio.dart';
import '../services/save_data.dart';
import '../theme.dart';

/// Account page: secure this account (email + password, phone when SMS works)
/// or log in to an account from another phone.
class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key, this.startWithLogin = false});

  /// Open on the "I played before" tab (first start, new phone).
  final bool startWithLogin;

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  late bool _loginTab = widget.startWithLogin;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: WarmBackground(
        child: SafeArea(
          child: ListenableBuilder(
            listenable: SaveData.i,
            builder: (context, _) => ListView(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
              children: [
                Row(children: [
                  RoundButton(
                      icon: Icons.arrow_back_rounded,
                      label: 'بازگشت',
                      onTap: () => Navigator.of(context).pop()),
                  const SizedBox(width: 12),
                  const Expanded(child: OutlinedTitle('حساب کاربری', size: 28)),
                ]),
                const SizedBox(height: 12),
                _status(),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: _tab('امن کردن این حساب', !_loginTab, () => setState(() => _loginTab = false))),
                  const SizedBox(width: 8),
                  Expanded(child: _tab('قبلاً بازی کردم', _loginTab, () => setState(() => _loginTab = true))),
                ]),
                const SizedBox(height: 12),
                if (_loginTab) const _LoginPanel() else const _SecurePanel(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _tab(String label, bool on, VoidCallback onTap) => GameButton(
        tone: on ? Tone.red : Tone.white,
        height: 44,
        onTap: on ? null : onTap,
        child: Text(label, style: const TextStyle(fontSize: 14)),
      );

  Widget _status() {
    final api = Api.i;
    if (api.secured) {
      return Panel(
        radius: 20,
        color: const Color(0xFFE6F8EE),
        border: Border.all(color: C.green, width: 2),
        child: Row(children: [
          const Icon(Icons.verified_user_rounded, color: C.greenDark, size: 36),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('حسابت امنه!', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
              if (api.phone != null)
                Text('موبایل: ${api.phone}', textDirection: TextDirection.ltr, style: kSmall),
              if (api.email != null)
                Text('ایمیل: ${api.email}', textDirection: TextDirection.ltr, style: kSmall),
              const Text('روی هر گوشی می‌تونی وارد حسابت بشی.', style: kSmall),
            ]),
          ),
        ]),
      );
    }
    return Panel(
      radius: 20,
      color: const Color(0xFFFFF1E0),
      border: Border.all(color: C.goldDark, width: 2),
      child: Row(children: [
        const Icon(Icons.warning_amber_rounded, color: C.goldDark, size: 36),
        const SizedBox(width: 10),
        const Expanded(
          child: Text(
              'الان مهمانی! اگه بازی رو پاک کنی یا گوشیت عوض بشه، سکه‌ها و شخصیت‌هات از دست میرن. '
              'حسابت رو امن کن و ۵۰۰ سکه هدیه بگیر.',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, height: 1.6)),
        ),
      ]),
    );
  }
}

void _toast(BuildContext context, String msg) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    behavior: SnackBarBehavior.floating,
    backgroundColor: C.ink,
    content: Text(msg, style: const TextStyle(fontFamily: 'Vazirmatn', fontWeight: FontWeight.w700)),
    duration: const Duration(seconds: 3),
  ));
}

InputDecoration _field(String hint, {IconData? icon}) => InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: C.white,
      prefixIcon: icon == null ? null : Icon(icon),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );

Widget _sectionTitle(String t, [String? sub]) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(t, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: C.ink)),
        if (sub != null) Text(sub, style: kSmall),
      ]),
    );

/// Phone number + SMS code. [onVerified] gets (phone, code).
class _PhoneCodeBox extends StatefulWidget {
  const _PhoneCodeBox({required this.button, required this.onVerified});
  final String button;
  final Future<void> Function(String phone, String code) onVerified;

  @override
  State<_PhoneCodeBox> createState() => _PhoneCodeBoxState();
}

class _PhoneCodeBoxState extends State<_PhoneCodeBox> {
  final _phone = TextEditingController();
  final _code = TextEditingController();
  bool _sent = false;
  bool _busy = false;
  int _wait = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _countdown(int secs) {
    _timer?.cancel();
    setState(() => _wait = secs);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _wait = _wait > 0 ? _wait - 1 : 0);
      if (_wait == 0) t.cancel();
    });
  }

  Future<void> _send() async {
    setState(() => _busy = true);
    final (wait, devCode, err) = await Api.i.sendOtp(_phone.text);
    if (!mounted) return;
    setState(() => _busy = false);
    if (wait > 0) _countdown(wait);
    if (err != null) {
      _toast(context, err);
      return;
    }
    setState(() => _sent = true);
    _toast(context, devCode != null ? 'کد تست: $devCode' : 'کد برات پیامک شد');
    if (devCode != null) _code.text = devCode;
  }

  Future<void> _verify() async {
    setState(() => _busy = true);
    await widget.onVerified(_phone.text, _code.text);
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Expanded(
          child: TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            textDirection: TextDirection.ltr,
            enabled: !_busy,
            decoration: _field('09xxxxxxxxx', icon: Icons.phone_android_rounded),
          ),
        ),
        const SizedBox(width: 8),
        GameButton(
          tone: Tone.teal,
          height: 48,
          onTap: _busy || _wait > 0 ? null : _send,
          child: Text(_wait > 0 ? fa(_wait) : (_sent ? 'دوباره' : 'ارسال کد'),
              style: const TextStyle(fontSize: 14)),
        ),
      ]),
      if (_sent) ...[
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: TextField(
              controller: _code,
              keyboardType: TextInputType.number,
              textDirection: TextDirection.ltr,
              maxLength: 5,
              decoration: _field('کد ۵ رقمی', icon: Icons.sms_rounded).copyWith(counterText: ''),
            ),
          ),
          const SizedBox(width: 8),
          GameButton(
            tone: Tone.green,
            height: 48,
            onTap: _busy ? null : _verify,
            child: Text(widget.button, style: const TextStyle(fontSize: 14)),
          ),
        ]),
      ],
    ]);
  }
}

// ---------------------------------------------------------------- secure this account

class _SecurePanel extends StatefulWidget {
  const _SecurePanel();

  @override
  State<_SecurePanel> createState() => _SecurePanelState();
}

class _SecurePanelState extends State<_SecurePanel> {
  final _user = TextEditingController();
  final _pass = TextEditingController();
  bool _busy = false;

  void _reward(String? text) {
    if (text != null && text.isNotEmpty) {
      Audio.i.play(Sfx.reward);
      _toast(context, 'حسابت امن شد! هدیه: $text');
    } else {
      _toast(context, 'ذخیره شد');
    }
  }

  Future<void> _linkPhone(String phone, String code) async {
    final (reward, err, taken) = await Api.i.linkPhone(phone, code);
    if (!mounted) return;
    if (err == null) {
      _reward(reward);
      return;
    }
    if (!taken) {
      _toast(context, err);
      return;
    }
    // the number already has an account: offer to switch to it
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: C.cream,
        title: const Text('این شماره حساب داره', style: TextStyle(fontWeight: FontWeight.w900)),
        content: const Text('می‌خوای وارد اون حساب بشی؟ پیشرفت این گوشی جایگزین میشه.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('نه')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('وارد شو')),
        ],
      ),
    );
    if (go != true || !mounted) return;
    final loginErr = await Api.i.loginWithPhone(phone, code);
    if (!mounted) return;
    _toast(context, loginErr ?? 'وارد حسابت شدی!');
    if (loginErr == null) Navigator.of(context).pop();
  }

  Future<void> _saveEmail() async {
    setState(() => _busy = true);
    final (reward, err) = await Api.i.setEmail(_user.text.trim(), _pass.text);
    if (!mounted) return;
    setState(() => _busy = false);
    if (err != null) {
      _toast(context, err);
    } else {
      _pass.clear();
      _reward(reward);
    }
  }

  @override
  Widget build(BuildContext context) {
    final api = Api.i;
    final sms = api.config?.smsEnabled ?? false;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Panel(
        radius: 20,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _sectionTitle('ایمیل و رمز', api.email == null
              ? 'با همین ایمیل و رمز روی هر گوشی وارد حسابت میشی'
              : 'برای عوض کردن رمز، رمز جدید رو بزن'),
          if (api.email != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text('ثبت شده: ${api.email}', textDirection: TextDirection.ltr,
                  style: const TextStyle(fontWeight: FontWeight.w900, color: C.greenDark)),
            )
          else ...[
            TextField(
              controller: _user,
              enabled: !_busy,
              keyboardType: TextInputType.emailAddress,
              textDirection: TextDirection.ltr,
              decoration: _field('ایمیل', icon: Icons.email_rounded),
            ),
            const SizedBox(height: 8),
          ],
          TextField(
            controller: _pass,
            obscureText: true,
            enabled: !_busy,
            textDirection: TextDirection.ltr,
            decoration: _field(api.email == null ? 'رمز (حداقل ۶ حرف)' : 'رمز جدید', icon: Icons.lock_rounded),
          ),
          const SizedBox(height: 10),
          GameButton(
            tone: Tone.green,
            height: 48,
            onTap: _busy
                ? null
                : () {
                    if (api.email != null) _user.text = '';
                    _saveEmailOrPassword();
                  },
            child: Text(api.email == null ? 'ثبت' : 'عوض کردن رمز', style: const TextStyle(fontSize: 15)),
          ),
        ]),
      ),
      if (sms) ...[
        const SizedBox(height: 12),
        Panel(
          radius: 20,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _sectionTitle('شماره موبایل', 'یه راه دیگه برای بازیابی حساب'),
            if (api.phone != null)
              Text('وصل شده: ${api.phone}', textDirection: TextDirection.ltr,
                  style: const TextStyle(fontWeight: FontWeight.w900, color: C.greenDark))
            else
              _PhoneCodeBox(button: 'تأیید', onVerified: _linkPhone),
          ]),
        ),
      ],
    ]);
  }

  /// First time: email + password. Later: only a new password for the saved email.
  Future<void> _saveEmailOrPassword() async {
    if (Api.i.email != null) {
      // the server needs the full email; we only know the masked one, so the
      // player types it once more
      final full = await _askEmail();
      if (full == null) return;
      _user.text = full;
    }
    await _saveEmail();
  }

  Future<String?> _askEmail() async {
    final c = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: C.cream,
        title: const Text('ایمیلت رو بنویس', style: TextStyle(fontWeight: FontWeight.w900)),
        content: TextField(
          controller: c,
          keyboardType: TextInputType.emailAddress,
          textDirection: TextDirection.ltr,
          decoration: InputDecoration(hintText: Api.i.email),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('انصراف')),
          FilledButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: const Text('تأیید')),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- log in to an old account

class _LoginPanel extends StatefulWidget {
  const _LoginPanel();

  @override
  State<_LoginPanel> createState() => _LoginPanelState();
}

class _LoginPanelState extends State<_LoginPanel> {
  final _user = TextEditingController();
  final _pass = TextEditingController();
  bool _busy = false;

  Future<bool> _confirm() async {
    // nothing to lose on a fresh install
    if (SaveData.i.gamesPlayed == 0) return true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: C.cream,
        title: const Text('مطمئنی؟', style: TextStyle(fontWeight: FontWeight.w900)),
        content: const Text('پیشرفت فعلی این گوشی با حساب قبلیت جایگزین میشه.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('نه')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('آره، وارد شو')),
        ],
      ),
    );
    return ok == true;
  }

  void _done(String? err) {
    if (!mounted) return;
    _toast(context, err ?? 'خوش برگشتی! پیشرفتت برگشت.');
    if (err == null) {
      Audio.i.play(Sfx.reward);
      Navigator.of(context).pop();
    }
  }

  Future<void> _byPhone(String phone, String code) async {
    if (!await _confirm()) return;
    _done(await Api.i.loginWithPhone(phone, code));
  }

  Future<void> _byPassword() async {
    if (!await _confirm()) return;
    setState(() => _busy = true);
    final err = await Api.i.loginWithEmail(_user.text.trim(), _pass.text);
    if (mounted) setState(() => _busy = false);
    _done(err);
  }

  @override
  Widget build(BuildContext context) {
    final sms = Api.i.config?.smsEnabled ?? false;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Panel(
        radius: 20,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _sectionTitle('ورود با ایمیل'),
          TextField(
            controller: _user,
            keyboardType: TextInputType.emailAddress,
            textDirection: TextDirection.ltr,
            decoration: _field('ایمیل', icon: Icons.email_rounded),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _pass,
            obscureText: true,
            textDirection: TextDirection.ltr,
            decoration: _field('رمز', icon: Icons.lock_rounded),
          ),
          const SizedBox(height: 10),
          GameButton(
            tone: Tone.green,
            height: 48,
            onTap: _busy ? null : _byPassword,
            child: const Text('ورود', style: TextStyle(fontSize: 15)),
          ),
        ]),
      ),
      if (sms) ...[
        const SizedBox(height: 12),
        Panel(
          radius: 20,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _sectionTitle('ورود با شماره موبایل'),
            _PhoneCodeBox(button: 'ورود', onVerified: _byPhone),
          ]),
        ),
      ],
    ]);
  }
}

// ---------------------------------------------------------------- prompts

/// Home screen banner for guests (after a couple of games).
class SecureBanner extends StatelessWidget {
  const SecureBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final api = Api.i;
    if (!api.enabled || api.secured || api.inviteCode.isEmpty || SaveData.i.gamesPlayed < 2) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: GestureDetector(
        onTap: () {
          Audio.i.play(Sfx.click);
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AccountScreen()));
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF26C6BE), Color(0xFF1C6FA8)]),
            borderRadius: BorderRadius.circular(16),
            boxShadow: kSoftShadow,
          ),
          child: const Row(children: [
            Icon(Icons.shield_rounded, color: C.white),
            SizedBox(width: 8),
            Expanded(
              child: Text('حسابت رو امن کن تا پیشرفتت گم نشه · ۵۰۰ سکه هدیه',
                  style: TextStyle(color: C.white, fontWeight: FontWeight.w900, fontSize: 13)),
            ),
            Icon(Icons.chevron_left_rounded, color: C.white),
          ]),
        ),
      ),
    );
  }
}

/// First start on a phone: "new player, or did you play before?"
Future<void> askReturningPlayer(BuildContext context) async {
  final api = Api.i;
  final s = SaveData.i;
  if (!api.enabled || api.secured || s.gamesPlayed > 0 || s.askedReturning) return;
  s.setAskedReturning();
  final played = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: C.cream,
      title: const Text('سلام! 👋', style: TextStyle(fontWeight: FontWeight.w900)),
      content: const Text('قبلاً روی گوشی دیگه‌ای «دمپایی پرنده» بازی کردی؟'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('آره، حسابم رو برگردون')),
        FilledButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('نه، تازه‌کارم')),
      ],
    ),
  );
  if (played == true && context.mounted) {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AccountScreen(startWithLogin: true)));
  }
}
