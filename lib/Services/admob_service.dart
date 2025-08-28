import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdMobService {
  static const String appId = 'ca-app-pub-9136866657796541~9758284565';
  static const String interstitialAdUnitId = 'ca-app-pub-9136866657796541/8468111985';
  static const String bannerAdUnitId = 'ca-app-pub-9136866657796541/6897947810';

  static void initialize() {
    MobileAds.instance.initialize();
  }

  static InterstitialAd? _interstitialAd;

  static void loadInterstitialAd() {
    InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              loadInterstitialAd(); // Preload next ad
            },
          );
        },
        onAdFailedToLoad: (error) => print('InterstitialAd failed to load: $error'),
      ),
    );
  }

  static void showInterstitialAd() {
    if (_interstitialAd != null) {
      _interstitialAd!.show();
      _interstitialAd = null;
    }
  }

  static BannerAd getBannerAd() {
    return BannerAd(
      adUnitId: bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) => print('BannerAd loaded'),
        onAdFailedToLoad: (ad, error) {
          print('BannerAd failed to load: $error');
          ad.dispose();
        },
      ),
    )..load();
  }
}