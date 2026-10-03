import 'dart:async';

import 'package:flutter/material.dart';

import '../theme.dart';
import 'save_data.dart';

/// Ads. RIGHT NOW THESE ARE TEST ADS (a fake 3-second screen),
/// so you can test the whole game flow before signing up anywhere.
///
/// Later: replace the inside of these two functions with the
/// Tapsell Plus (or Adivery) Flutter plugin. Nothing else in the
/// game needs to change.
class AdService {
  static int _gameOvers = 0;

  /// Rewarded ad: the player chooses to watch it and gets a reward.
  /// Returns true if the ad was watched to the end.
  static Future<bool> showRewarded(BuildContext context) async {
    final watched = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _TestAd(label: 'تبلیغ جایزه‌دار (آزمایشی)'),
    );
    return watched ?? false;
  }

  /// Forced ad between games. Shown after every 3rd game over,
  /// never for players who bought "remove ads" or VIP.
  static Future<void> maybeShowInterstitial(BuildContext context) async {
    if (SaveData.i.adsOff) return;
    _gameOvers++;
    if (_gameOvers % 3 != 0) return;
    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _TestAd(label: 'تبلیغ بین بازی (آزمایشی)'),
    );
  }
}

class _TestAd extends StatefulWidget {
  const _TestAd({required this.label});
  final String label;

  @override
  State<_TestAd> createState() => _TestAdState();
}

class _TestAdState extends State<_TestAd> {
  int _left = 3;
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _left--);
      if (_left <= 0) {
        t.cancel();
        Navigator.of(context).pop(true);
      }
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: C.ink,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.ondemand_video, color: C.gold, size: 56),
            const SizedBox(height: 12),
            Text(widget.label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: C.cream, fontWeight: FontWeight.w900, fontSize: 18)),
            const SizedBox(height: 8),
            Text('${fa(_left)} ثانیه',
                style: const TextStyle(color: C.gold, fontSize: 16)),
          ],
        ),
      ),
    );
  }
}
