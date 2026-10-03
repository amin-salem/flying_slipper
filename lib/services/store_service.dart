import 'package:flutter/material.dart';

import '../theme.dart';
import 'audio.dart';
import 'save_data.dart';

/// A real-money product sold through Cafe Bazaar.
class Product {
  const Product(this.id, this.title, this.subtitle, this.priceLabel);

  /// Must match the product ID you create in the Bazaar developer panel.
  final String id;
  final String title;
  final String subtitle;

  /// Set your prices here (in Toman) after checking similar games on Bazaar.
  final String priceLabel;
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
    if (ok == true) {
      SaveData.i.grantProduct(p.id);
      Audio.i.play(Sfx.reward);
      return true;
    }
    return false;
  }
}
