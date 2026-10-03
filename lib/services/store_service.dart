import 'dart:math';

import 'package:flutter/material.dart';

import '../theme.dart';
import 'api.dart';
import 'audio.dart';
import 'save_data.dart';

/// A real-money product sold through Cafe Bazaar.
class Product {
  const Product(this.id, this.title, this.subtitle, this.defaultPrice);

  /// Must match the product ID you create in the Bazaar developer panel.
  final String id;
  final String title;
  final String subtitle;

  /// Shown when the server is not available. Real price labels come from
  /// the server's remote config ("prices"), so you can change them any time.
  final String defaultPrice;

  String get priceLabel => Api.i.config?.price(id) ?? defaultPrice;
}

class Products {
  static const starter = Product('starter_pack', 'بسته شروع',
      'حذف تبلیغات + ۵٬۰۰۰ سکه + علی فوتبالیست', '[قیمت] تومان');
  static const coinsSmall =
      Product('coins_small', 'یه مشت سکه', '۱٬۰۰۰ سکه', '[قیمت] تومان');
  static const coinsMedium =
      Product('coins_medium', 'کیسه سکه', '۵٬۰۰۰ سکه', '[قیمت] تومان');
  static const coinsLarge =
      Product('coins_large', 'صندوقچه سکه', '۱۵٬۰۰۰ سکه', '[قیمت] تومان');
  static const removeAds = Product('remove_ads', 'حذف تبلیغات',
      'تبلیغ‌های اجباری برای همیشه حذف', '[قیمت] تومان');
  static const piggy = Product('piggy_bank', 'شکستن قلک',
      'همه سکه‌های قلک مال تو میشه', '[قیمت] تومان');
  static const vip = Product('vip_monthly', 'اشتراک VIP',
      'بدون تبلیغ، ادامه رایگان بعد از باخت', '[قیمت] / ماه');
}

/// Purchases. RIGHT NOW THIS IS A TEST STORE: it asks "buy?" and gives
/// the item for free, so you can test everything.
///
/// Later: replace the inside of [buy] with Cafe Bazaar's Poolakey
/// Flutter plugin (flutter_poolakey). When Bazaar says the payment
/// succeeded, call SaveData.i.grantProduct(productId) exactly like below.
class StoreService {
  static Future<bool> buy(BuildContext context, Product p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: C.cream,
        title: Text('خرید آزمایشی: ${p.title}',
            style: const TextStyle(fontWeight: FontWeight.w900)),
        content: const Text(
            'این یک خرید آزمایشی است و پولی پرداخت نمی‌شود.\nبعداً اینجا درگاه کافه‌بازار قرار می‌گیرد.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('انصراف')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('خرید')),
        ],
      ),
    );
    if (ok != true) return false;
    Api.i.track('purchase_try', {'product': p.id});
    if (Api.i.enabled) {
      // The server checks the purchase and says what to give.
      // With Poolakey, use the real purchaseToken from Bazaar here.
      final token = 'test-${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(1 << 30)}';
      final r = await Api.i.verifyPurchase(p.id, token);
      if (r.ok) {
        if (r.status == 'granted') SaveData.i.applyGrants(r.grants);
        Audio.i.play(Sfx.reward);
        Api.i.syncNow();
        return true;
      }
      if (r.status != 'offline') {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('خرید تأیید نشد (${r.reason})',
                  style: const TextStyle(fontFamily: 'Vazirmatn'))));
        }
        return false;
      }
      // no internet: fall through to the offline test purchase
    }
    SaveData.i.grantProduct(p.id);
    Audio.i.play(Sfx.reward);
    return true;
  }
}
