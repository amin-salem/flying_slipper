import 'package:flutter/material.dart';

/// Cosmetic skins for Mom's slipper and Dad's belt (won from the prize
/// machine). They change how the thrown slippers and the belt look.

class SlipperSkin {
  const SlipperSkin(this.id, this.name, this.sole, this.edge, this.strap,
      {this.rarity = 0, this.pattern = 0});
  final String id;
  final String name;
  final Color sole;
  final Color edge; // darker side of the sole
  final Color strap;
  final int rarity; // 0 common, 1 rare, 2 epic, 3 legendary
  final int pattern; // 0 none, 1 stars, 2 stripes, 3 sparkle
}

class BeltSkin {
  const BeltSkin(this.id, this.name, this.color, this.buckle, {this.rarity = 0, this.pattern = 0});
  final String id;
  final String name;
  final Color color;
  final Color buckle;
  final int rarity;
  final int pattern; // 0 plain, 1 snake scales, 2 sparkle
}

const List<SlipperSkin> kSlippers = [
  SlipperSkin('slipper_classic', 'دمپایی آبی', Color(0xFF3F70C8), Color(0xFF1F3F86), Color(0xFFE53935)),
  SlipperSkin('slipper_pink', 'صورتی مامان', Color(0xFFFF8FB1), Color(0xFFD45C86), Color(0xFFFFFFFF)),
  SlipperSkin('slipper_green', 'سبز فسفری', Color(0xFF7CD34A), Color(0xFF4E9A2A), Color(0xFFFFD34D)),
  SlipperSkin('slipper_zebra', 'راه‌راه', Color(0xFFFFFFFF), Color(0xFF9AA3B2), Color(0xFF2B1B3A),
      rarity: 1, pattern: 2),
  SlipperSkin('slipper_isfahan', 'کاشی اصفهان', Color(0xFF1C8C9E), Color(0xFF0E5F70), Color(0xFFF2B33D),
      rarity: 1, pattern: 1),
  SlipperSkin('slipper_yalda', 'شب یلدا', Color(0xFF3A2A6E), Color(0xFF241A46), Color(0xFFE53935),
      rarity: 2, pattern: 1),
  SlipperSkin('slipper_gold', 'دمپایی طلایی', Color(0xFFFFD34D), Color(0xFFC07A0E), Color(0xFFE53935),
      rarity: 3, pattern: 3),
];

const List<BeltSkin> kBelts = [
  BeltSkin('belt_classic', 'کمربند قهوه‌ای', Color(0xFF6B3E1E), Color(0xFFFFD34D)),
  BeltSkin('belt_black', 'چرم مشکی', Color(0xFF26222E), Color(0xFFD5D9E2)),
  BeltSkin('belt_red', 'قرمز جیغ', Color(0xFFD32F2F), Color(0xFFFFD34D), rarity: 1),
  BeltSkin('belt_snake', 'پوست ماری', Color(0xFF4E7A3A), Color(0xFFD5D9E2), rarity: 2, pattern: 1),
  BeltSkin('belt_gold', 'کمربند طلایی', Color(0xFFE0A531), Color(0xFFFFF0A8), rarity: 3, pattern: 2),
];

/// What the game draws right now (set from the saved choice).
SlipperSkin currentSlipper = kSlippers.first;
BeltSkin currentBelt = kBelts.first;

SlipperSkin slipperById(String id) =>
    kSlippers.firstWhere((s) => s.id == id, orElse: () => kSlippers.first);
BeltSkin beltById(String id) => kBelts.firstWhere((b) => b.id == id, orElse: () => kBelts.first);

const List<String> kCosmeticRarity = ['عادی', 'کمیاب', 'حماسی', 'افسانه‌ای'];
const List<Color> kCosmeticRarityColor = [
  Color(0xFF8C7D99),
  Color(0xFF2F7BE0),
  Color(0xFF7646E8),
  Color(0xFFC07A0E),
];

/// Chance weight per rarity in the prize machine.
const List<int> kRarityWeight = [40, 25, 10, 3];
