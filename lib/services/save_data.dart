import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../game/characters.dart';
import '../game/world.dart' show Ability;
import 'missions.dart';

/// One day's prize in the 7-day login calendar.
class DailyReward {
  const DailyReward(this.coins, {this.pillows = 0, this.grandmas = 0});
  final int coins;
  final int pillows;
  final int grandmas;
}

/// Everything saved on the phone. No server needed.
class SaveData extends ChangeNotifier {
  SaveData._();
  static final SaveData i = SaveData._();

  late SharedPreferences _p;

  int coins = 0;
  int best = 0;
  int pillows = 1; // shield power-up
  int grandmas = 1; // clears the screen
  bool noAds = false;
  bool vip = false;
  bool starterBought = false;
  Set<String> owned = {'ali'};
  String skin = 'ali';
  String lastDaily = '';
  int loginDay = 0; // next calendar day to claim (0..6)
  String freeAdDay = '';
  int freeAdCount = 0;
  int gamesPlayed = 0;
  bool soundOn = true;
  bool musicOn = true;
  bool tutorialDone = false;
  int piggy = 0; // coins waiting in the piggy bank
  int starterOfferStart = 0; // when the 24h starter offer began (ms)
  Map<String, int> powerLevels = {}; // character id -> 1..3
  String missionDay = '';
  List<int> missionProgress = [0, 0, 0];
  List<bool> missionClaimed = [false, false, false];

  Future<void> load() async {
    _p = await SharedPreferences.getInstance();
    coins = _p.getInt('coins') ?? 200;
    best = _p.getInt('best') ?? 0;
    pillows = _p.getInt('pillows') ?? 1;
    grandmas = _p.getInt('grandmas') ?? 1;
    noAds = _p.getBool('noAds') ?? false;
    vip = _p.getBool('vip') ?? false;
    starterBought = _p.getBool('starterBought') ?? false;
    owned = (_p.getStringList('owned') ?? ['ali']).toSet();
    skin = _p.getString('skin') ?? 'ali';
    lastDaily = _p.getString('lastDaily') ?? '';
    loginDay = _p.getInt('loginDay') ?? 0;
    freeAdDay = _p.getString('freeAdDay') ?? '';
    freeAdCount = _p.getInt('freeAdCount') ?? 0;
    gamesPlayed = _p.getInt('gamesPlayed') ?? 0;
    soundOn = _p.getBool('soundOn') ?? true;
    musicOn = _p.getBool('musicOn') ?? true;
    // players who already played before the tutorial existed skip it
    tutorialDone = _p.getBool('tutorialDone') ?? (gamesPlayed > 0);
    powerLevels = {
      for (final e in _p.getStringList('powerLevels') ?? const <String>[])
        if (e.contains(':')) e.split(':')[0]: int.tryParse(e.split(':')[1]) ?? 1
    };
    piggy = _p.getInt('piggy') ?? 0;
    starterOfferStart = _p.getInt('starterOfferStart') ?? 0;
    missionDay = _p.getString('missionDay') ?? '';
    final mp = _p.getStringList('missionProgress') ?? const ['0', '0', '0'];
    missionProgress = [for (final v in mp) int.tryParse(v) ?? 0];
    final mc = _p.getStringList('missionClaimed') ?? const ['0', '0', '0'];
    missionClaimed = [for (final v in mc) v == '1'];
    if (missionProgress.length != 3) missionProgress = [0, 0, 0];
    if (missionClaimed.length != 3) missionClaimed = [false, false, false];

    // Older versions used different character ids.
    owned.add('ali');
    owned.removeWhere((id) => !kCharacters.any((c) => c.id == id));
    if (!owned.contains(skin)) skin = 'ali';
  }

  Future<void> _save() async {
    notifyListeners();
    await _p.setInt('coins', coins);
    await _p.setInt('best', best);
    await _p.setInt('pillows', pillows);
    await _p.setInt('grandmas', grandmas);
    await _p.setBool('noAds', noAds);
    await _p.setBool('vip', vip);
    await _p.setBool('starterBought', starterBought);
    await _p.setStringList('owned', owned.toList());
    await _p.setString('skin', skin);
    await _p.setString('lastDaily', lastDaily);
    await _p.setInt('loginDay', loginDay);
    await _p.setString('freeAdDay', freeAdDay);
    await _p.setInt('freeAdCount', freeAdCount);
    await _p.setInt('gamesPlayed', gamesPlayed);
    await _p.setBool('soundOn', soundOn);
    await _p.setBool('musicOn', musicOn);
    await _p.setBool('tutorialDone', tutorialDone);
    await _p.setStringList('powerLevels',
        [for (final e in powerLevels.entries) '${e.key}:${e.value}']);
    await _p.setInt('piggy', piggy);
    await _p.setInt('starterOfferStart', starterOfferStart);
    await _p.setString('missionDay', missionDay);
    await _p.setStringList(
        'missionProgress', [for (final v in missionProgress) '$v']);
    await _p.setStringList(
        'missionClaimed', [for (final v in missionClaimed) v ? '1' : '0']);
  }

  Character get character => characterById(skin);

  // ---- Power levels ----
  int levelOf(String id) => powerLevels[id] ?? 1;

  /// The selected character's power at its current level.
  Ability get ability => character.abilityAt(levelOf(skin));

  bool upgradePower(Character c) {
    final lvl = levelOf(c.id);
    if (!owned.contains(c.id) || !c.upgradable || lvl >= 3) return false;
    if (!spend(kUpgradeCost[lvl])) return false;
    powerLevels[c.id] = lvl + 1;
    _save();
    return true;
  }

  bool get adsOff => noAds || vip;

  String get _today {
    final d = DateTime.now();
    return '${d.year}-${d.month}-${d.day}';
  }

  void addCoins(int n) {
    if (n == 0) return;
    coins += n;
    _save();
  }

  bool spend(int n) {
    if (coins < n) return false;
    coins -= n;
    _save();
    return true;
  }

  /// Returns true if this is a new record.
  bool submitScore(int meters) {
    final record = meters > best;
    if (record) best = meters;
    gamesPlayed++;
    _save();
    return record;
  }

  void setSound(bool on) {
    soundOn = on;
    _save();
  }

  void setTutorialDone(bool done) {
    tutorialDone = done;
    _save();
  }

  void setMusic(bool on) {
    musicOn = on;
    _save();
  }

  // ---- 7-day login calendar ----
  static const List<DailyReward> calendar = [
    DailyReward(100),
    DailyReward(150),
    DailyReward(200, pillows: 1),
    DailyReward(300),
    DailyReward(400, grandmas: 1),
    DailyReward(500),
    DailyReward(1000, pillows: 2, grandmas: 1),
  ];

  String get _yesterday {
    final d = DateTime.now().subtract(const Duration(days: 1));
    return '${d.year}-${d.month}-${d.day}';
  }

  bool get canClaimDaily => lastDaily != _today;

  /// Today's box in the calendar (0..6). Missing a day starts again at day 1.
  int get calendarToday {
    if (!canClaimDaily) return (loginDay + 6) % 7;
    if (lastDaily.isEmpty || lastDaily == _yesterday) return loginDay;
    return 0;
  }

  /// True if the player missed a day and the streak restarted.
  bool get streakBroken =>
      canClaimDaily && lastDaily.isNotEmpty && lastDaily != _yesterday && loginDay != 0;

  DailyReward? claimDaily() {
    if (!canClaimDaily) return null;
    final day = calendarToday;
    final r = calendar[day];
    coins += r.coins;
    pillows += r.pillows;
    grandmas += r.grandmas;
    loginDay = (day + 1) % 7;
    lastDaily = _today;
    _save();
    return r;
  }

  // ---- Piggy bank ----
  static const piggyMax = 3000;
  static const piggyMinToBreak = 500;

  /// 20% of every run's coins also drop into the piggy bank (as a bonus).
  int addToPiggy(int runCoins) {
    var add = (runCoins * 0.2).round();
    if (add > piggyMax - piggy) add = piggyMax - piggy;
    if (add <= 0) return 0;
    piggy += add;
    _save();
    return add;
  }

  // ---- Starter offer (24 hours, shown after the 3rd game) ----
  static const offerHours = 24;
  bool get shouldShowStarterOffer =>
      !starterBought && starterOfferStart == 0 && gamesPlayed >= 3;

  void startStarterOffer() {
    starterOfferStart = DateTime.now().millisecondsSinceEpoch;
    _save();
  }

  /// Time left on the starter offer, or null if not running / expired.
  Duration? get starterOfferLeft {
    if (starterBought || starterOfferStart == 0) return null;
    final end = DateTime.fromMillisecondsSinceEpoch(starterOfferStart)
        .add(const Duration(hours: offerHours));
    final left = end.difference(DateTime.now());
    return left.isNegative ? null : left;
  }

  // ---- Weekend event: double coins on Thursday and Friday ----
  bool get weekendEvent {
    final d = DateTime.now().weekday;
    return d == DateTime.thursday || d == DateTime.friday;
  }

  // ---- Daily missions ----
  /// Today's 3 missions (progress resets every day).
  List<Mission> get missions {
    if (missionDay != _today) {
      missionDay = _today;
      missionProgress = [0, 0, 0];
      missionClaimed = [false, false, false];
    }
    return missionsFor(DateTime.now());
  }

  bool missionDone(int i) => missionProgress[i] >= missions[i].target;

  int get missionsToClaim {
    final m = missions;
    int n = 0;
    for (int i = 0; i < m.length; i++) {
      if (!missionClaimed[i] && missionProgress[i] >= m[i].target) n++;
    }
    return n;
  }

  /// Adds a run's results; returns the missions that were just completed.
  List<Mission> recordRun(RunStats r) {
    final m = missions;
    final done = <Mission>[];
    for (int i = 0; i < m.length; i++) {
      final before = missionProgress[i];
      missionProgress[i] = m[i].progressFrom(r, before);
      if (before < m[i].target && missionProgress[i] >= m[i].target) {
        done.add(m[i]);
      }
    }
    _save();
    return done;
  }

  bool claimMission(int i) {
    final m = missions;
    if (missionClaimed[i] || missionProgress[i] < m[i].target) return false;
    missionClaimed[i] = true;
    coins += m[i].reward;
    _save();
    return true;
  }

  // ---- Free coins for watching ads (5 per day) ----
  static const freeAdsPerDay = 5;
  int get freeAdsLeft =>
      freeAdDay == _today ? freeAdsPerDay - freeAdCount : freeAdsPerDay;

  void useFreeAd() {
    if (freeAdDay != _today) {
      freeAdDay = _today;
      freeAdCount = 0;
    }
    freeAdCount++;
    _save();
  }

  // ---- Characters ----
  bool buyCharacter(Character c) {
    if (owned.contains(c.id)) return true;
    if (!spend(c.price)) return false;
    owned.add(c.id);
    skin = c.id;
    _save();
    return true;
  }

  void selectCharacter(String id) {
    if (!owned.contains(id)) return;
    skin = id;
    _save();
  }

  // ---- Power-ups ----
  void addPillows(int n) {
    pillows += n;
    _save();
  }

  void addGrandmas(int n) {
    grandmas += n;
    _save();
  }

  bool usePillow() {
    if (pillows <= 0) return false;
    pillows--;
    _save();
    return true;
  }

  bool useGrandma() {
    if (grandmas <= 0) return false;
    grandmas--;
    _save();
    return true;
  }

  // ---- Real-money purchases (called after the store confirms) ----
  void grantProduct(String productId) {
    switch (productId) {
      case 'coins_small':
        coins += 1000;
        break;
      case 'coins_medium':
        coins += 5000;
        break;
      case 'coins_large':
        coins += 15000;
        break;
      case 'remove_ads':
        noAds = true;
        break;
      case 'starter_pack':
        starterBought = true;
        noAds = true;
        coins += 5000;
        owned.add('football');
        skin = 'football';
        break;
      case 'piggy_bank':
        coins += piggy;
        piggy = 0;
        break;
      case 'vip_monthly':
        vip = true;
        break;
    }
    _save();
  }
}
