import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:flying_slipper/game/world.dart';
import 'package:flying_slipper/theme.dart';

void main() {
  test('Persian number formatting', () {
    expect(fa(0), '۰');
    expect(fa(1250), '۱٬۲۵۰');
    expect(fa(15000), '۱۵٬۰۰۰');
  });

  test('Game world runs and the kid can jump', () {
    final w = GameWorld()..setViewport(const Size(390, 844));
    w.reset();
    w.press();
    expect(w.onGround, isFalse);
    w.releasePress();
    for (int i = 0; i < 120; i++) {
      w.update(1 / 60);
    }
    expect(w.traveled, greaterThan(0));
  });
}
