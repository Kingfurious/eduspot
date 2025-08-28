// services/ad_service.dart
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdService {
  static String get interstitialAdUnitId {
    // Use the provided ad unit ID
    return 'ca-app-pub-9136866657796541/8449500927';
  }

  // For testing purposes
  static String get testInterstitialAdUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-3940256099942544/1033173712'; // Android test ID
    } else if (Platform.isIOS) {
      return 'ca-app-pub-3940256099942544/4411468910'; // iOS test ID
    } else {
      throw UnsupportedError('Unsupported platform');
    }
  }

  static bool _isAdReady = false;
  static InterstitialAd? _interstitialAd;
  static bool _isAdLoading = false;

  // Initialize the Mobile Ads SDK
  static Future<void> initialize() async {
    if (kDebugMode) {
      print('Initializing AdMob SDK...');
    }

    await MobileAds.instance.initialize();
    loadInterstitialAd(); // Start preloading the ad
  }

  // Load the interstitial ad
  static Future<void> loadInterstitialAd() async {
    if (_isAdLoading) return;

    _isAdLoading = true;
    _isAdReady = false;

    if (kDebugMode) {
      print('Loading interstitial ad...');
    }

    try {
      await InterstitialAd.load(
        adUnitId: interstitialAdUnitId,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (InterstitialAd ad) {
            if (kDebugMode) {
              print('Interstitial ad loaded successfully');
            }
            _interstitialAd = ad;
            _isAdReady = true;
            _isAdLoading = false;

            // Set up ad event listeners
            _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
              onAdDismissedFullScreenContent: (ad) {
                if (kDebugMode) {
                  print('Ad was dismissed');
                }
                ad.dispose();
                _isAdReady = false;
                loadInterstitialAd(); // Load the next ad
              },
              onAdFailedToShowFullScreenContent: (ad, error) {
                if (kDebugMode) {
                  print('Ad failed to show: $error');
                }
                ad.dispose();
                _isAdReady = false;
                loadInterstitialAd(); // Try to load another ad
              },
              onAdShowedFullScreenContent: (ad) {
                if (kDebugMode) {
                  print('Ad showed fullscreen content');
                }
              },
            );
          },
          onAdFailedToLoad: (LoadAdError error) {
            if (kDebugMode) {
              print('Interstitial ad failed to load: $error');
            }
            _isAdReady = false;
            _isAdLoading = false;
            // Retry after a delay
            Future.delayed(const Duration(minutes: 1), () {
              loadInterstitialAd();
            });
          },
        ),
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error loading interstitial ad: $e');
      }
      _isAdReady = false;
      _isAdLoading = false;
    }
  }

  // Show the interstitial ad
  static Future<bool> showInterstitialAd() async {
    if (!_isAdReady || _interstitialAd == null) {
      if (kDebugMode) {
        print('Tried to show ad, but ad is not ready. Loading a new one...');
      }
      loadInterstitialAd();
      return false;
    }

    try {
      await _interstitialAd!.show();
      _isAdReady = false;
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error showing interstitial ad: $e');
      }
      _isAdReady = false;
      loadInterstitialAd();
      return false;
    }
  }

  // Dispose the ad
  static void dispose() {
    _interstitialAd?.dispose();
    _interstitialAd = null;
    _isAdReady = false;
  }
}