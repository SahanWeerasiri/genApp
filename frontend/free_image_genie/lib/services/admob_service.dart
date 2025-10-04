import 'dart:async';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../config/admob_config.dart';
import '../utils/logger.dart';

class AdMobService {
  static AdMobService? _instance;
  static AdMobService get instance => _instance ??= AdMobService._();

  AdMobService._();

  RewardedAd? _rewardedAd;
  bool _isRewardedAdReady = false;

  // Use AdMobConfig for ad unit IDs
  String get rewardedAdUnitId => AdMobConfig.rewardedAdUnitId;

  /// Initialize the AdMob SDK
  static Future<void> initialize() async {
    try {
      // Configure test devices before initialization
      final RequestConfiguration configuration = RequestConfiguration(
        testDeviceIds: AdMobConfig.testDeviceIds,
      );
      MobileAds.instance.updateRequestConfiguration(configuration);

      await MobileAds.instance.initialize();
      AppLogger.info('AdMob initialized successfully');

      if (AdMobConfig.isTestMode) {
        AppLogger.info('AdMob running in TEST MODE with test ads');
        AppLogger.info('Test device IDs: ${AdMobConfig.testDeviceIds}');
      } else {
        AppLogger.info('AdMob running in PRODUCTION MODE');
      }

      // Print device ID for debugging
      AppLogger.info(
        'Add this device ID to test devices if you see "Invalid Ad Request" errors',
      );
    } catch (e) {
      AppLogger.error('Failed to initialize AdMob: $e');
    }
  }

  /// Load a rewarded ad
  Future<void> loadRewardedAd() async {
    try {
      AppLogger.info('Loading rewarded ad...');

      // Configure ad request with test device settings
      final AdRequest adRequest = AdRequest(
        keywords: ['gaming', 'entertainment'],
        nonPersonalizedAds: false,
      );

      await RewardedAd.load(
        adUnitId: rewardedAdUnitId,
        request: adRequest,
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (RewardedAd ad) {
            AppLogger.info('Rewarded ad loaded successfully');
            _rewardedAd = ad;
            _isRewardedAdReady = true;
          },
          onAdFailedToLoad: (LoadAdError error) {
            AppLogger.error('Rewarded ad failed to load: $error');
            AppLogger.error(
              'Error code: ${error.code}, domain: ${error.domain}, message: ${error.message}',
            );
            _rewardedAd = null;
            _isRewardedAdReady = false;

            // Handle specific error codes
            switch (error.code) {
              case 0: // Internal error
                AppLogger.info('Internal error - will retry in 60 seconds');
                Future.delayed(const Duration(seconds: 60), () {
                  if (!_isRewardedAdReady) loadRewardedAd();
                });
                break;
              case 1: // Invalid request
                AppLogger.info(
                  'Invalid request - check ad unit ID and device configuration',
                );
                break;
              case 2: // Network error
                AppLogger.info('Network error - will retry in 30 seconds');
                Future.delayed(const Duration(seconds: 30), () {
                  if (!_isRewardedAdReady) loadRewardedAd();
                });
                break;
              case 3: // No fill
                AppLogger.info('No fill error - will retry in 30 seconds');
                Future.delayed(const Duration(seconds: 30), () {
                  if (!_isRewardedAdReady) loadRewardedAd();
                });
                break;
              default:
                AppLogger.info('Unknown error code: ${error.code}');
            }
          },
        ),
      );
    } catch (e) {
      AppLogger.error('Error loading rewarded ad: $e');
      _isRewardedAdReady = false;
    }
  }

  /// Show rewarded ad and handle reward
  Future<bool> showRewardedAd() async {
    if (!_isRewardedAdReady || _rewardedAd == null) {
      AppLogger.error('Rewarded ad is not ready');
      return false;
    }

    final Completer<bool> rewardCompleter = Completer<bool>();
    bool adDismissed = false;
    bool rewardEarned = false;

    // Set up callbacks before showing the ad
    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (RewardedAd ad) {
        AppLogger.info('Rewarded ad showed full screen content');
        print('DEBUG: AdMobService - Ad showed full screen');
      },
      onAdDismissedFullScreenContent: (RewardedAd ad) {
        AppLogger.info('Rewarded ad dismissed full screen content');
        print(
          'DEBUG: AdMobService - Ad dismissed, reward earned: $rewardEarned',
        );

        adDismissed = true;

        // Complete with the reward status
        if (!rewardCompleter.isCompleted) {
          rewardCompleter.complete(rewardEarned);
        }

        ad.dispose();
        _rewardedAd = null;
        _isRewardedAdReady = false;
        // Load a new ad for next time
        loadRewardedAd();
      },
      onAdFailedToShowFullScreenContent: (RewardedAd ad, AdError error) {
        AppLogger.error(
          'Rewarded ad failed to show full screen content: $error',
        );
        print('DEBUG: AdMobService - Ad failed to show: $error');

        if (!rewardCompleter.isCompleted) {
          rewardCompleter.complete(false);
        }

        ad.dispose();
        _rewardedAd = null;
        _isRewardedAdReady = false;
        // Load a new ad for next time
        loadRewardedAd();
      },
    );

    try {
      print('DEBUG: AdMobService - About to show ad');
      await _rewardedAd!.show(
        onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
          AppLogger.info('User earned reward: ${reward.amount} ${reward.type}');
          print(
            'DEBUG: AdMobService - User earned reward: ${reward.amount} ${reward.type}',
          );
          rewardEarned = true;

          // If ad is already dismissed, complete immediately
          if (adDismissed && !rewardCompleter.isCompleted) {
            rewardCompleter.complete(true);
          }
        },
      );
      print('DEBUG: AdMobService - Ad.show() completed');

      // Wait for the ad to be dismissed and check reward status
      return await rewardCompleter.future.timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          AppLogger.info(
            'Reward callback timeout - user might have closed ad early',
          );
          print('DEBUG: AdMobService - Reward callback timeout');
          return false;
        },
      );
    } catch (e) {
      AppLogger.error('Error showing rewarded ad: $e');
      print('DEBUG: AdMobService - Error showing rewarded ad: $e');
      if (!rewardCompleter.isCompleted) {
        rewardCompleter.complete(false);
      }
      return false;
    }
  }

  /// Check if rewarded ad is ready to show
  bool get isRewardedAdReady => _isRewardedAdReady && _rewardedAd != null;

  /// Dispose of the current rewarded ad
  void dispose() {
    _rewardedAd?.dispose();
    _rewardedAd = null;
    _isRewardedAdReady = false;
  }

  /// Get reward information
  String get rewardInfo {
    final mode = AdMobConfig.isTestMode ? '(Test Mode)' : '';
    return 'Watch a video ad to earn 2 tokens! $mode';
  }

  /// Preload ads for better user experience
  Future<void> preloadAds() async {
    await loadRewardedAd();
  }
}
