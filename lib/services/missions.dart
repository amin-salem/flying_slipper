import 'dart:math';

/// What happened in one run (or one part of a run, after "continue").
class RunStats {
  const RunStats({
    this.meters = 0,
    this.coins = 0,
    this.nearMisses = 0,
    this.slippersDodged = 0,
    this.beltsDodged = 0,
    this.jumps = 0,
    this.games = 0,
  });
  final int meters; // distance of this run (used as "best run today")
  final int coins;
  final int nearMisses;
  final int slippersDodged;
  final int beltsDodged;
  final int jumps;
  final int games;
}

enum MissionType {
  bestRun,
  totalMeters,
  coins,
  nearMisses,
  slippers,
  belts,
  games,
  jumps,
}

class Mission {
  const Mission(this.type, this.target, this.reward);
  final MissionType type;
  final int target;
  final int reward;

  String get title {
    final n = _fa(target);
    return switch (type) {
      MissionType.bestRun => 'در یک بازی $n متر فرار کن',
      MissionType.totalMeters => 'امروز در کل $n متر بدو',
      MissionType.coins => '$n سکه جمع کن',
      MissionType.nearMisses => '$n بار «جاخالی» بده',
      MissionType.slippers => 'از $n دمپایی فرار کن',
      MissionType.belts => 'از $n کمربند بابا جاخالی بده',
      MissionType.games => '$n بار بازی کن',
      MissionType.jumps => '$n بار بپر',
    };
  }

  /// How much a run adds to this mission's progress.
  int progressFrom(RunStats r, int current) => switch (type) {
        MissionType.bestRun => max(current, r.meters),
        MissionType.totalMeters => current + r.meters,
        MissionType.coins => current + r.coins,
        MissionType.nearMisses => current + r.nearMisses,
        MissionType.slippers => current + r.slippersDodged,
        MissionType.belts => current + r.beltsDodged,
        MissionType.games => current + r.games,
        MissionType.jumps => current + r.jumps,
      };
}

/// Possible targets and rewards for each mission type (easy → hard).
const Map<MissionType, List<List<int>>> _pool = {
  MissionType.bestRun: [[500, 150], [900, 250], [1400, 400]],
  MissionType.totalMeters: [[1500, 150], [3000, 250], [5000, 400]],
  MissionType.coins: [[120, 150], [250, 250], [400, 350]],
  MissionType.nearMisses: [[4, 150], [8, 250], [14, 400]],
  MissionType.slippers: [[10, 150], [20, 250], [35, 350]],
  MissionType.belts: [[3, 150], [6, 250], [10, 400]],
  MissionType.games: [[3, 120], [5, 200], [8, 300]],
  MissionType.jumps: [[50, 120], [100, 200], [180, 300]],
};

/// Today's 3 missions: the same all day, different every day.
List<Mission> missionsFor(DateTime day) {
  final seed = day.year * 1000 + day.month * 40 + day.day;
  final rng = Random(seed);
  final types = MissionType.values.toList()..shuffle(rng);
  final out = <Mission>[];
  for (int i = 0; i < 3; i++) {
    final t = types[i];
    // one easy, one medium, one hard
    final opt = _pool[t]![i];
    out.add(Mission(t, opt[0], opt[1]));
  }
  return out;
}

String _fa(int n) {
  final s = n.toString();
  final buf = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write('٬');
    buf.write(s[i]);
  }
  const digits = '۰۱۲۳۴۵۶۷۸۹';
  return buf
      .toString()
      .split('')
      .map((ch) {
        final k = int.tryParse(ch);
        return k == null ? ch : digits[k];
      })
      .join();
}
