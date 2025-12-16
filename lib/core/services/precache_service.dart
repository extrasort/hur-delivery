import 'package:flutter/widgets.dart';

class PrecacheService {
  static Future<void> preloadCoreAssets(BuildContext context) async {
    final assets = <ImageProvider>[
      const AssetImage('assets/icons/googlemaps.png'),
      const AssetImage('assets/icons/waze.png'),
    ];
    for (final provider in assets) {
      try {
        await precacheImage(provider, context);
      } catch (_) {}
    }
  }
}

