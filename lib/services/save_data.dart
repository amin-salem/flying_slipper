import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../game/characters.dart';
import '../game/cosmetics.dart';
import '../game/world.dart' show Ability, PowerKind;
import 'missions.dart';

/// Result of one pull of the prize machine.
class MachinePull {
  const MachinePull(this.id, this.duplicate);
  final String id;
  final bool duplicate;
}

enum PrizeKind { coins, pillow, grandma, box }

/// A prize from the lucky wheel or a mystery box.
class Prize {
  const Prize(this.kind, this.amount);
  final PrizeKind kind;
  final int amount;
}

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
  int mysteryBoxes = 0;
  Set<String> repairs = {}; // house repairs done
  int huntWeek = -1;
  int xp = 0;
  int bestScore = 0;
  int huntTokens = 0;
  String wordDay = '';
  int wordProgress = 0; // letters of today's word collected
  int starterOfferStart = 0; // when the 24h starter offer began (ms)
  Map<String, int> powerLevels = {}; // character id -> 1..3
  Map<String, int> boostLevels = {}; // in-run power-up name -> 1..5
  String missionDay = '';
  List<int> missionProgress = [0, 0, 0];
  List<bool> missionClaimed = [false, false, false];
  Set<String> ownedCosmetics = {'slipper_classic', 'belt_classic'};
  String equippedSlipper = 'slipper_classic';
  String equippedBelt = 'belt_classic';

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
    mysteryBoxes = _p.getInt('mysteryBoxes') ?? 0;
    repairs = (_p.getStringList('repairs') ?? const <String>[]).toSet();
    huntWeek = _p.getInt('huntWeek') ?? -1;
    xp = _p.getInt('xp') ?? 0;
    bestScore = _p.getInt('bestScore') ?? 0;
    huntTokens = _p.getInt('huntTokens') ?? 0;
    wordDay = _p.getString('wordDay') ?? '';
    wordProgress = _p.getInt('wordProgress') ?? 0;
    starterOfferStart = _p.getInt('starterOfferStart') ?? 0;
    boostLevels = {
      for (final e in _p.getStringList('boostLevels') ?? const <String>[])
        if (e.contains(':')) e.split(':')[0]: int.tryParse(e.split(':')[1]) ?? 1
    };
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

    ownedCosmetics = (_p.getStringList('ownedCosmetics') ?? const <String>[]).toSet()
      ..addAll(const ['slipper_classic', 'belt_classic']);
    equippedSlipper = _p.getString('equippedSlipper') ?? 'slipper_classic';
    equippedBelt = _p.getString('equippedBelt') ?? 'belt_classic';
    if (!ownedCosmetics.contains(equippedSlipper)) equippedSlipper = 'slipper_classic';
    if (!ownedCosmetics.contains(equippedBelt)) equippedBelt = 'belt_classic';
    currentSlipper = slipperById(equippedSlipper);
    currentBelt = beltById(equippedBelt);
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
    await _p.setInt('mysteryBoxes', mysteryBoxes);
    await _p.setStringList('repairs', repairs.toList());
    await _p.setInt('huntWeek', huntWeek);
    await _p.setInt('xp', xp);
    await _p.setInt('bestScore', bestScore);
    await _p.setInt('huntTokens', huntTokens);
    await _p.setString('wordDay', wordDay);
    await _p.setInt('wordProgress', wordProgress);
    await _p.setInt('starterOfferStart', starterOfferStart);
    await _p.setStringList('boostLevels',
        [for (final e in boostLevels.entries) '${e.key}:${e.value}']);
    await _p.setString('missionDay', missionDay);
    await _p.setStringList(
        'missionProgress', [for (final v in missionProgress) '$v']);
    await _p.setStringList(
        'missionClaimed', [for (final v in missionClaimed) v ? '1' : '0']);
    await _p.setStringList('ownedCosmetics', ownedCosmetics.toList());
    await _p.setString('equippedSlipper', equippedSlipper);
    await _p.setString('equippedBelt', equippedBelt);
  }

  Character get character => characterById(skin);

  // ---- In-run power-up upgrades (magnet, double coins, skate, balloon) ----
  static const boostMaxLevel = 5;
  static const boostCosts = [0, 500, 1200, 2500, 5000]; // cost to reach level 2..5

  int boostLevel(PowerKind k) => boostLevels[k.name] ?? 1;

  /// Seconds the power-up lasts at its current level.
  double boostDuration(PowerKind k, [int? level]) {
    final l = (level ?? boostLevel(k)) - 1;
    return switch (k) {
      PowerKind.magnet => 8 + 2.5 * l,
      PowerKind.doubleCoins => 10 + 3.0 * l,
      PowerKind.skate => 12 + 4.0 * l,
      PowerKind.balloon => 4 + 1.0 * l,
    };
  }

  Map<PowerKind, double> get boostDurations =>
      {for (final k in PowerKind.values) k: boostDuration(k)};

  bool upgradeBoost(PowerKind k) {
    final l = boostLevel(k);
    if (l >= boostMaxLevel) return false;
    if (!spend(boostCosts[l])) return false;
    boostLevels[k.name] = l + 1;
    _save();
    return true;
  }

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

  // ---- Ranks & score ----
  int get rank => rankForXp(xp);
  String get rankTitle => kRankTitles[rank];
  int get scoreMultiplier => rank + 1;

  /// XP needed for the next rank (null at the top).
  int? get nextRankXp => rank + 1 < kRankXp.length ? kRankXp[rank + 1] : null;

  /// Returns true if this XP gave a new rank.
  bool addXp(int n) {
    final before = rank;
    xp += n;
    _save();
    return rank > before;
  }

  bool submitBestScore(int score) {
    if (score <= bestScore) return false;
    bestScore = score;
    _save();
    return true;
  }

  // ---- Weekly hunt ----
  int get thisWeek => weekNumber(DateTime.now());
  HuntToken get huntToken => tokenForWeek(thisWeek);

  int get weekTokens {
    if (huntWeek != thisWeek) {
      huntWeek = thisWeek;
      huntTokens = 0;
    }
    return huntTokens;
  }

  /// Adds tokens and gives every reward passed. Returns the rewards reached.
  List<List<int>> addHuntTokens(int n) {
    if (n <= 0) return const [];
    final before = weekTokens;
    huntTokens = before + n;
    final reached = <List<int>>[];
    for (final r in kHuntTrack) {
      if (before < r[0] && huntTokens >= r[0]) {
        reached.add(r);
        xp += 1;
        coins += r[1];
        mysteryBoxes += r[2];
        pillows += r[3];
        grandmas += r[4];
      }
    }
    _save();
    return reached;
  }

  // ---- Fix the house ----
  bool doRepair(String id, int cost) {
    if (repairs.contains(id)) return false;
    if (!spend(cost)) return false;
    repairs.add(id);
    xp += 2;
    _save();
    return true;
  }

  // ---- Daily word hunt ----
  String get todayWord => wordFor(DateTime.now());

  int get todayWordProgress {
    if (wordDay != _today) {
      wordDay = _today;
      wordProgress = 0;
    }
    return wordProgress;
  }

  bool get wordDone => todayWordProgress >= lettersOf(todayWord).length;

  /// Saves how many letters are collected; gives the prize when complete.
  /// Returns true if the word was just finished.
  bool setWordProgress(int n) {
    final before = todayWordProgress;
    final len = lettersOf(todayWord).length;
    wordProgress = n < 0 ? 0 : (n > len ? len : n);
    final finished = before < len && wordProgress >= len;
    if (finished) {
      coins += kWordReward;
      mysteryBoxes += 1;
      xp += 2;
    }
    _save();
    return finished;
  }

  // ---- Mystery boxes & prizes ----
  void addBoxes(int n) {
    if (n <= 0) return;
    mysteryBoxes += n;
    _save();
  }

  bool useBox() {
    if (mysteryBoxes <= 0) return false;
    mysteryBoxes--;
    _save();
    return true;
  }

  void applyPrize(Prize p) {
    switch (p.kind) {
      case PrizeKind.coins:
        coins += p.amount;
      case PrizeKind.pillow:
        pillows += p.amount;
      case PrizeKind.grandma:
        grandmas += p.amount;
      case PrizeKind.box:
        mysteryBoxes += p.amount;
    }
    _save();
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
    xp += 1;
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

  // ---- Prize machine (slipper and belt skins) ----
  static const machineCost = 1000;
  static const machineRefund = 400;

  /// Pulls the prize machine. Returns null if there are not enough coins.
  MachinePull? pullMachine() {
    if (!spend(machineCost)) return null;
    final pool = <(String, int)>[
      for (final s in kSlippers)
        if (s.id != 'slipper_classic') (s.id, s.rarity),
      for (final b in kBelts)
        if (b.id != 'belt_classic') (b.id, b.rarity),
    ];
    final total = pool.fold<int>(0, (a, e) => a + kRarityWeight[e.$2]);
    int roll = Random().nextInt(total);
    String id = pool.last.$1;
    for (final e in pool) {
      roll -= kRarityWeight[e.$2];
      if (roll < 0) {
        id = e.$1;
        break;
      }
    }
    final dup = ownedCosmetics.contains(id);
    if (dup) {
      coins += machineRefund;
    } else {
      ownedCosmetics.add(id);
    }
    _save();
    return MachinePull(id, dup);
  }

  void equipCosmetic(String id) {
    if (!ownedCosmetics.contains(id)) return;
    if (id.startsWith('slipper_')) {
      equippedSlipper = id;
      currentSlipper = slipperById(id);
    } else {
      equippedBelt = id;
      currentBelt = beltById(id);
    }
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
