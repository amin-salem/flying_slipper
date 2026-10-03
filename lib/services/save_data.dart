import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../game/characters.dart';

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
  String freeAdDay = '';
  int freeAdCount = 0;
  int gamesPlayed = 0;
  bool soundOn = true;
  bool musicOn = true;

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
    freeAdDay = _p.getString('freeAdDay') ?? '';
    freeAdCount = _p.getInt('freeAdCount') ?? 0;
    gamesPlayed = _p.getInt('gamesPlayed') ?? 0;
    soundOn = _p.getBool('soundOn') ?? true;
    musicOn = _p.getBool('musicOn') ?? true;

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
    await _p.setString('freeAdDay', freeAdDay);
    await _p.setInt('freeAdCount', freeAdCount);
    await _p.setInt('gamesPlayed', gamesPlayed);
    await _p.setBool('soundOn', soundOn);
    await _p.setBool('musicOn', musicOn);
  }

  Character get character => characterById(skin);

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

  void setMusic(bool on) {
    musicOn = on;
    _save();
  }

  // ---- Daily reward ----
  bool get canClaimDaily => lastDaily != _today;

  int claimDaily() {
    if (!canClaimDaily) return 0;
    lastDaily = _today;
    const reward = 100;
    coins += reward;
    _save();
    return reward;
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
      case 'vip_monthly':
        vip = true;
        break;
    }
    _save();
  }
}
