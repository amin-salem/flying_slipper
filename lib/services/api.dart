import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'save_data.dart';

/// Server address: the live server on Liara by default.
/// Another server for testing:
///   flutter run -d R5CRC0PR5WT --dart-define=API_URL=http://192.168.1.5:8000
/// No server at all (fully offline):  --dart-define=API_URL=
const String kApiUrl = String.fromEnvironment('API_URL', defaultValue: 'https://flyingslippers.liara.run');

/// The app's build number (pubspec version after the "+"); used for forced updates.
const int kAppBuild = int.fromEnvironment('APP_BUILD', defaultValue: 13);

/// Settings downloaded from the server (prices, events, forced update...).
class RemoteConfig {
  RemoteConfig(this.raw);
  final Map<String, dynamic> raw;

  int get minVersion => _int(raw['min_version'], 1);
  int get latestVersion => _int(raw['latest_version'], 1);
  String get updateUrl => '${raw['update_url'] ?? ''}';
  bool get maintenance => raw['maintenance'] == true;
  String get maintenanceMessage => '${raw['maintenance_message'] ?? ''}';
  bool get leaderboardEnabled => raw['leaderboard_enabled'] != false;
  String? price(String productId) {
    final p = raw['prices'];
    return p is Map && p[productId] is String ? p[productId] as String : null;
  }

  List<Map<String, dynamic>> get news => [
        for (final n in (raw['news'] is List ? raw['news'] as List : const []))
          if (n is Map) n.cast<String, dynamic>()
      ];

  static int _int(Object? v, int d) => v is int ? v : d;
}

class LeaderRow {
  LeaderRow(Map<String, dynamic> j)
      : rank = j['rank'] as int,
        nickname = '${j['nickname']}',
        character = '${j['character']}',
        score = j['score'] as int,
        meters = j['meters'] as int,
        me = j['me'] == true;
  final int rank;
  final String nickname;
  final String character;
  final int score;
  final int meters;
  final bool me;
}

class Leaderboard {
  Leaderboard(Map<String, dynamic> j)
      : period = '${j['period']}',
        endsAt = j['ends_at'] as int?,
        top = [for (final r in j['top'] as List) LeaderRow((r as Map).cast<String, dynamic>())],
        me = j['me'] == null ? null : LeaderRow((j['me'] as Map).cast<String, dynamic>());
  final String period;
  final int? endsAt;
  final List<LeaderRow> top;
  final LeaderRow? me;
}

class InboxGift {
  InboxGift(Map<String, dynamic> j)
      : id = '${j['id']}',
        title = '${j['title']}',
        message = '${j['message'] ?? ''}',
        grants = (j['grants'] as List?) ?? const [];
  final String id;
  final String title;
  final String message;
  final List<dynamic> grants;
}

class RunFinish {
  RunFinish(Map<String, dynamic> j)
      : accepted = j['accepted'] == true,
        score = (j['score'] as int?) ?? 0,
        bestWeek = (j['best_week'] as int?) ?? 0,
        rankWeek = j['rank_week'] as int?;
  final bool accepted;
  final int score;
  final int bestWeek;
  final int? rankWeek;
}

class PurchaseResult {
  PurchaseResult(this.status, this.grants, this.consume, [this.reason = '']);
  final String status; // granted | already_granted | rejected | offline
  final List<dynamic> grants;
  final bool consume;
  final String reason;
  bool get ok => status == 'granted' || status == 'already_granted';
}

class ApiException implements Exception {
  ApiException(this.status, this.detail);
  final int status;
  final Object? detail;
  @override
  String toString() => 'ApiException($status, $detail)';
}

/// Everything that talks to the game server. Every method is safe to call
/// without a server or without internet: it just returns null / does nothing.
class Api {
  Api._();
  static final Api i = Api._();

  bool get enabled => kApiUrl.isNotEmpty;

  late SharedPreferences _p;
  final http.Client _http = http.Client();
  String? _playerId;
  String? _secret;
  String? _token;
  int _tokenExp = 0;

  /// Finishes when the first connection attempt is done (success or not).
  Future<void>? started;

  RemoteConfig? config;
  String nickname = '';
  String inviteCode = '';
  bool referred = false;
  String? phone; // masked, e.g. 0912***4567
  String? username;
  bool secured = false; // can be recovered on another phone
  int inboxCount = 0;

  Timer? _syncTimer;
  bool _syncing = false;
  bool _ready = false;
  final List<Map<String, dynamic>> _events = [];

  // ---------------------------------------------------------------- start

  /// Call once at app start (doesn't block the game if the server is down).
  Future<void> init() async {
    if (!enabled) return;
    _p = await SharedPreferences.getInstance();
    _playerId = _p.getString('api_player');
    _secret = _p.getString('api_secret');
    _token = _p.getString('api_token');
    _tokenExp = _p.getInt('api_token_exp') ?? 0;
    SaveData.onSaved = scheduleSync;
    try {
      await loadConfig();
      await _ensureLogin();
      _ready = true;
      await refreshProfile();
      await _firstSync();
      await refreshInbox();
    } catch (_) {
      // no internet / server down: try again later
    }
  }

  Future<void> loadConfig() async {
    final j = await _call('GET', '/v1/config', auth: false) as Map<String, dynamic>;
    config = RemoteConfig(j);
    final serverTime = j['server_time'];
    if (serverTime is int) {
      SaveData.clockOffset = DateTime.fromMillisecondsSinceEpoch(serverTime * 1000).difference(DateTime.now());
      // small differences are just network delay
      if (SaveData.clockOffset.inSeconds.abs() < 60) SaveData.clockOffset = Duration.zero;
    }
    final we = j['weekend_event'];
    if (we is Map) {
      SaveData.weekendEnabled = we['enabled'] != false;
      if (we['days'] is List) SaveData.weekendDays = (we['days'] as List).whereType<int>().toList();
    }
  }

  String _deviceId() {
    var id = _p.getString('api_device');
    if (id == null) {
      final r = Random.secure();
      id = List.generate(16, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
      _p.setString('api_device', id);
    }
    return id;
  }

  Future<void> _ensureLogin() async {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    if (_token != null && _tokenExp - now > 3600) return;
    if (_playerId == null || _secret == null) {
      final j = await _call('POST', '/v1/auth/register',
          auth: false, body: {'device_id': _deviceId(), 'app_version': kAppBuild}) as Map<String, dynamic>;
      await _storeLogin(j);
      return;
    }
    final Map<String, dynamic> j;
    try {
      j = await _call('POST', '/v1/auth/login',
          auth: false,
          body: {'player_id': _playerId, 'secret': _secret, 'app_version': kAppBuild}) as Map<String, dynamic>;
    } on ApiException catch (e) {
      if (e.status != 401) rethrow;
      // This account was moved to another phone: start a new one here.
      _playerId = null;
      _secret = null;
      await SaveData.i.setCloudVersion(0);
      return _ensureLogin();
    }
    _token = j['token'] as String;
    _tokenExp = j['expires_at'] as int;
    await _p.setString('api_token', _token!);
    await _p.setInt('api_token_exp', _tokenExp);
  }

  Future<void> _storeLogin(Map<String, dynamic> j) async {
    _playerId = j['player_id'] as String;
    _secret = j['secret'] as String;
    _token = j['token'] as String;
    _tokenExp = j['expires_at'] as int;
    await _p.setString('api_player', _playerId!);
    await _p.setString('api_secret', _secret!);
    await _p.setString('api_token', _token!);
    await _p.setInt('api_token_exp', _tokenExp);
  }

  // ---------------------------------------------------------------- http

  Future<Object?> _call(String method, String path,
      {Object? body, bool auth = true, bool retried = false}) async {
    final uri = Uri.parse('$kApiUrl$path');
    final headers = {'Content-Type': 'application/json'};
    if (auth) {
      await _ensureLogin();
      headers['Authorization'] = 'Bearer $_token';
    }
    final data = body == null ? null : jsonEncode(body);
    final http.Response r;
    const t = Duration(seconds: 12);
    switch (method) {
      case 'GET':
        r = await _http.get(uri, headers: headers).timeout(t);
      case 'PUT':
        r = await _http.put(uri, headers: headers, body: data).timeout(t);
      case 'PATCH':
        r = await _http.patch(uri, headers: headers, body: data).timeout(t);
      default:
        r = await _http.post(uri, headers: headers, body: data).timeout(t);
    }
    final text = utf8.decode(r.bodyBytes);
    final decoded = text.isEmpty ? null : jsonDecode(text);
    if (r.statusCode == 401 && auth && !retried) {
      // token expired or account moved: log in again once
      _token = null;
      _tokenExp = 0;
      return _call(method, path, body: body, auth: auth, retried: true);
    }
    if (r.statusCode >= 400) {
      throw ApiException(r.statusCode, decoded is Map ? decoded['detail'] : decoded);
    }
    return decoded;
  }

  // ---------------------------------------------------------------- profile

  Future<void> refreshProfile() async {
    if (!_ready) return;
    try {
      final j = await _call('GET', '/v1/me') as Map<String, dynamic>;
      nickname = '${j['nickname']}';
      inviteCode = '${j['invite_code']}';
      referred = j['referred'] == true;
      phone = j['phone'] as String?;
      username = j['username'] as String?;
      secured = j['secured'] == true;
      final vip = j['vip_until'];
      if (vip is int && vip != SaveData.i.vipUntil) {
        SaveData.i.applyGrants([{'type': 'vip_until', 'ts': vip}]);
      }
    } catch (_) {}
  }

  /// Returns null if OK, or an error message in Persian.
  Future<String?> setNickname(String name) async {
    if (!_ready) return 'اتصال به سرور برقرار نیست';
    try {
      final j = await _call('PATCH', '/v1/me', body: {'nickname': name}) as Map<String, dynamic>;
      nickname = '${j['nickname']}';
      return null;
    } on ApiException catch (e) {
      return e.status == 422 ? 'این اسم قابل قبول نیست' : 'خطا، دوباره امتحان کن';
    } catch (_) {
      return 'اتصال به سرور برقرار نیست';
    }
  }

  // ---------------------------------------------------------------- cloud save

  /// Upload the save a few seconds after the last change (not on every coin).
  void scheduleSync() {
    if (!enabled) return;
    _syncTimer?.cancel();
    _syncTimer = Timer(const Duration(seconds: 6), syncNow);
  }

  Future<void> syncNow() async {
    if (_syncing || !await _reconnect()) return;
    _syncing = true;
    try {
      await _push();
    } catch (_) {
    } finally {
      _syncing = false;
    }
  }

  Future<void> _push({bool force = false}) async {
    final s = SaveData.i;
    try {
      final j = await _call('PUT', '/v1/save',
          body: {'base_version': s.cloudVersion, 'data': s.toJson(), 'force': force}) as Map<String, dynamic>;
      await s.setCloudVersion(j['version'] as int);
    } on ApiException catch (e) {
      if (e.status != 409) rethrow;
      // Someone else saved first (another phone, or an older install).
      final server = ((e.detail as Map)['server'] as Map).cast<String, dynamic>();
      final data = (server['data'] as Map).cast<String, dynamic>();
      final version = server['version'] as int;
      if (SaveData.progressOf(data) > SaveData.progressOf(s.toJson())) {
        await s.importJson(data, version); // the server copy is further along
      } else {
        await s.setCloudVersion(version);
        await _push(force: true); // this phone is further along
      }
    }
  }

  /// First start on this phone: if the account already has a save on the
  /// server (e.g. after moving phones), use whichever save is further along.
  Future<void> _firstSync() async {
    final j = await _call('GET', '/v1/save') as Map<String, dynamic>;
    final version = j['version'] as int;
    final data = (j['data'] as Map).cast<String, dynamic>();
    final s = SaveData.i;
    if (version == s.cloudVersion) {
      await _push();
    } else if (version > 0 && SaveData.progressOf(data) > SaveData.progressOf(s.toJson())) {
      await s.importJson(data, version);
    } else {
      await s.setCloudVersion(version);
      await _push(force: true);
    }
  }

  // ---------------------------------------------------------------- runs

  String? _runId;
  DateTime? _runStart;

  Future<void> startRun(String character) async {
    _runId = null;
    _runStart = DateTime.now();
    if (!await _reconnect()) return;
    try {
      final j = await _call('POST', '/v1/runs/start', body: {'character': character}) as Map<String, dynamic>;
      _runId = j['run_id'] as String;
    } catch (_) {}
  }

  Future<RunFinish?> finishRun(
      {required int meters, required int coins, required int nearMisses, required int scoreMul}) async {
    // the run id is kept: after "continue" the same run is sent again
    final id = _runId;
    final start = _runStart;
    if (!_ready || id == null || start == null) return null;
    try {
      final j = await _call('POST', '/v1/runs/$id/finish', body: {
        'meters': meters,
        'coins': coins,
        'near_misses': nearMisses,
        'duration_ms': DateTime.now().difference(start).inMilliseconds,
        'score_mul': scoreMul,
      }) as Map<String, dynamic>;
      return RunFinish(j);
    } catch (_) {
      return null;
    }
  }

  DateTime? _lastTry;

  /// If the first connection failed (offline at start), try again now
  /// (at most once a minute).
  Future<bool> _reconnect() async {
    if (_ready) return true;
    if (!enabled) return false;
    final now = DateTime.now();
    if (_lastTry != null && now.difference(_lastTry!).inSeconds < 60) return false;
    _lastTry = now;
    try {
      if (config == null) await loadConfig();
      await _ensureLogin();
      _ready = true;
      await refreshProfile();
      await _firstSync();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<Leaderboard?> leaderboard(String period) async {
    if (!await _reconnect()) return null;
    try {
      return Leaderboard(await _call('GET', '/v1/leaderboard?period=$period') as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  // ---------------------------------------------------------------- purchases

  Future<PurchaseResult> verifyPurchase(String productId, String purchaseToken) async {
    if (!enabled) return PurchaseResult('offline', const [], false);
    try {
      final j = await _call('POST', '/v1/purchases/verify',
          body: {'product_id': productId, 'purchase_token': purchaseToken}) as Map<String, dynamic>;
      return PurchaseResult('${j['status']}', (j['grants'] as List?) ?? const [], j['consume'] == true,
          '${j['reason'] ?? ''}');
    } catch (e) {
      return PurchaseResult('offline', const [], false, '$e');
    }
  }

  // ---------------------------------------------------------------- inbox

  Future<List<InboxGift>> inbox() async {
    if (!await _reconnect()) return const [];
    try {
      final list = await _call('GET', '/v1/inbox') as List;
      final gifts = [for (final g in list) InboxGift((g as Map).cast<String, dynamic>())];
      inboxCount = gifts.length;
      SaveData.i.refresh();
      return gifts;
    } catch (_) {
      return const [];
    }
  }

  Future<void> refreshInbox() async => inbox();

  /// Claims a gift and gives it to the player. Returns the description.
  Future<String?> claim(InboxGift g) async {
    try {
      final j = await _call('POST', '/v1/inbox/${g.id}/claim') as Map<String, dynamic>;
      inboxCount = max(0, inboxCount - 1);
      return SaveData.i.applyGrants(j['grants'] as List);
    } catch (_) {
      return null;
    }
  }

  // ---------------------------------------------------------------- invites & transfer

  /// Returns (reward text, error text).
  Future<(String?, String?)> redeemInvite(String code) async {
    if (!_ready) return (null, 'اتصال به سرور برقرار نیست');
    try {
      final j = await _call('POST', '/v1/referrals/redeem', body: {'code': code.trim()}) as Map<String, dynamic>;
      referred = true;
      return (SaveData.i.applyGrants(j['grants'] as List), null);
    } on ApiException catch (e) {
      return (null, switch (e.detail) {
        'bad_code' => 'این کد پیدا نشد',
        'already_redeemed' => 'قبلاً کد دعوت وارد کردی',
        'only_for_new_players' => 'کد دعوت فقط برای بازیکن‌های تازه است',
        'same_device' => 'نمی‌شه با گوشی خودت خودت رو دعوت کنی!',
        _ => 'خطا، دوباره امتحان کن',
      });
    } catch (_) {
      return (null, 'اتصال به سرور برقرار نیست');
    }
  }

  Future<String?> makeTransferCode() async {
    if (!_ready) return null;
    try {
      final j = await _call('POST', '/v1/auth/transfer-code') as Map<String, dynamic>;
      return '${j['code']}';
    } catch (_) {
      return null;
    }
  }

  /// Moves an account from the old phone to this one. Returns an error or null.
  Future<String?> useTransferCode(String code) async {
    if (!enabled) return 'اتصال به سرور برقرار نیست';
    try {
      final j = await _call('POST', '/v1/auth/transfer',
          auth: false, body: {'code': code.trim(), 'device_id': _deviceId()}) as Map<String, dynamic>;
      await _storeLogin(j);
      _ready = true;
      final save = await _call('GET', '/v1/save') as Map<String, dynamic>;
      await SaveData.i.importJson((save['data'] as Map).cast<String, dynamic>(), save['version'] as int);
      await refreshProfile();
      return null;
    } on ApiException catch (e) {
      return e.status == 404 ? 'کد اشتباه است یا تاریخش گذشته' : 'خطا، دوباره امتحان کن';
    } catch (_) {
      return 'اتصال به سرور برقرار نیست';
    }
  }

  // ---------------------------------------------------------------- permanent account

  static String _err(Object? detail) {
    final d = detail is Map ? detail['error'] : detail;
    return switch (d) {
      'bad_phone' => 'شماره موبایل درست نیست',
      'wait' => 'یه کم صبر کن و دوباره کد بخواه',
      'too_many_codes' => 'تعداد درخواست کد زیاد شد، یک ساعت دیگه امتحان کن',
      'sms_failed' => 'ارسال پیامک انجام نشد، دوباره امتحان کن',
      'code_expired' => 'کد منقضی شده، دوباره کد بگیر',
      'wrong_code' => 'کد اشتباهه',
      'too_many_attempts' => 'چند بار اشتباه زدی، کد جدید بگیر',
      'phone_taken' => 'این شماره به یه حساب دیگه وصله',
      'no_account' => 'با این شماره حسابی پیدا نشد',
      'bad_username' => 'نام کاربری: ۳ تا ۱۶ حرف انگلیسی یا عدد، با حرف شروع بشه',
      'bad_password' => 'رمز باید حداقل ۶ حرف باشه',
      'username_taken' => 'این نام کاربری قبلاً گرفته شده',
      'username_cant_change' => 'نام کاربری رو نمی‌شه عوض کرد',
      'wrong_login' => 'نام کاربری یا رمز اشتباهه',
      'banned' => 'این حساب مسدود شده',
      'too_many_requests' => 'خیلی سریع امتحان کردی، کمی صبر کن',
      _ => 'خطا، دوباره امتحان کن',
    };
  }

  /// Asks the server to send an SMS code. Returns (seconds to wait, dev code, error).
  Future<(int, String?, String?)> sendOtp(String phoneNumber) async {
    if (!await _reconnect()) return (0, null, 'اتصال به سرور برقرار نیست');
    try {
      final j = await _call('POST', '/v1/account/otp', auth: false, body: {'phone': phoneNumber})
          as Map<String, dynamic>;
      return ((j['retry_after'] as int?) ?? 60, j['dev_code'] as String?, null);
    } on ApiException catch (e) {
      final wait = e.detail is Map ? ((e.detail as Map)['retry_after'] as int? ?? 0) : 0;
      return (wait, null, _err(e.detail));
    } catch (_) {
      return (0, null, 'اتصال به سرور برقرار نیست');
    }
  }

  /// Links a phone number to this account. Returns (reward text, error, phone belongs to another account).
  Future<(String?, String?, bool)> linkPhone(String phoneNumber, String code) async {
    try {
      final j = await _call('POST', '/v1/account/phone', body: {'phone': phoneNumber, 'code': code})
          as Map<String, dynamic>;
      _readProfile((j['profile'] as Map).cast<String, dynamic>());
      final grants = (j['grants'] as List?) ?? const [];
      return (grants.isEmpty ? '' : SaveData.i.applyGrants(grants), null, false);
    } on ApiException catch (e) {
      return (null, _err(e.detail), e.detail == 'phone_taken');
    } catch (_) {
      return (null, 'اتصال به سرور برقرار نیست', false);
    }
  }

  /// Chooses a username + password (or changes the password). Returns (reward text, error).
  Future<(String?, String?)> setUsername(String name, String password) async {
    try {
      final j = await _call('POST', '/v1/account/username', body: {'username': name, 'password': password})
          as Map<String, dynamic>;
      _readProfile((j['profile'] as Map).cast<String, dynamic>());
      final grants = (j['grants'] as List?) ?? const [];
      return (grants.isEmpty ? '' : SaveData.i.applyGrants(grants), null);
    } on ApiException catch (e) {
      return (null, _err(e.detail));
    } catch (_) {
      return (null, 'اتصال به سرور برقرار نیست');
    }
  }

  /// Logs in to an existing account with an SMS code (progress on this phone is replaced).
  Future<String?> loginWithPhone(String phoneNumber, String code) => _loginWith(
      '/v1/account/login/phone', {'phone': phoneNumber, 'code': code});

  /// Logs in to an existing account with username + password.
  Future<String?> loginWithPassword(String name, String password) => _loginWith(
      '/v1/account/login/password', {'username': name, 'password': password});

  Future<String?> _loginWith(String path, Map<String, dynamic> body) async {
    if (!enabled) return 'اتصال به سرور برقرار نیست';
    try {
      final j = await _call('POST', path, auth: false, body: {...body, 'device_id': _deviceId()})
          as Map<String, dynamic>;
      await _storeLogin(j);
      _ready = true;
      final save = await _call('GET', '/v1/save') as Map<String, dynamic>;
      final data = (save['data'] as Map).cast<String, dynamic>();
      if (data.isNotEmpty) {
        await SaveData.i.importJson(data, save['version'] as int);
      } else {
        await SaveData.i.setCloudVersion(save['version'] as int);
      }
      await refreshProfile();
      await refreshInbox();
      return null;
    } on ApiException catch (e) {
      return _err(e.detail);
    } catch (_) {
      return 'اتصال به سرور برقرار نیست';
    }
  }

  void _readProfile(Map<String, dynamic> j) {
    phone = j['phone'] as String?;
    username = j['username'] as String?;
    secured = j['secured'] == true;
    SaveData.i.refresh();
  }

  // ---------------------------------------------------------------- analytics

  /// Records an event; events are sent in small batches.
  void track(String name, [Map<String, dynamic> props = const {}]) {
    if (!enabled) return;
    _events.add({'name': name, 'props': props, 'ts': DateTime.now().millisecondsSinceEpoch ~/ 1000});
    if (_events.length >= 20) flushEvents();
  }

  Future<void> flushEvents() async {
    if (!_ready || _events.isEmpty) return;
    final batch = List<Map<String, dynamic>>.from(_events.take(100));
    try {
      await _call('POST', '/v1/events', body: {'events': batch});
      _events.removeRange(0, batch.length);
    } catch (_) {
      if (_events.length > 500) _events.removeRange(0, _events.length - 500);
    }
  }
}
