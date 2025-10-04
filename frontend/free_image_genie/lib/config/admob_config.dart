import 'dart:io';

class AdMobConfig {
  // Production Ad Unit IDs (provided by you)
  static const String _prodAndroidAppId =
      'ca-app-pub-1262150100678081~9792477222';
  static const String _prodAndroidRewardedId =
      'ca-app-pub-1262150100678081/1571206425';
  static const String _prodIosAppId =
      'ca-app-pub-1262150100678081~9792477222'; // You might need iOS specific ID
  static const String _prodIosRewardedId =
      'ca-app-pub-1262150100678081/1571206425'; // You might need iOS specific ID

  // Test Ad Unit IDs (for development)
  static const String _testAndroidAppId =
      'ca-app-pub-3940256099942544~3347511713';
  static const String _testAndroidRewardedId =
      'ca-app-pub-3940256099942544/5224354917';
  static const String _testIosAppId = 'ca-app-pub-3940256099942544~1458002511';
  static const String _testIosRewardedId =
      'ca-app-pub-3940256099942544/1712485313';

  // Toggle this for testing vs production
  static const bool _useTestAds = true; // Set to true for testing

  static String get appId {
    if (_useTestAds) {
      return Platform.isAndroid ? _testAndroidAppId : _testIosAppId;
    } else {
      return Platform.isAndroid ? _prodAndroidAppId : _prodIosAppId;
    }
  }

  static String get rewardedAdUnitId {
    if (_useTestAds) {
      return Platform.isAndroid ? _testAndroidRewardedId : _testIosRewardedId;
    } else {
      return Platform.isAndroid ? _prodAndroidRewardedId : _prodIosRewardedId;
    }
  }

  static bool get isTestMode => _useTestAds;

  // Test device IDs - Add your device ID from the logs
  static List<String> get testDeviceIds => [
    '6EA6B993AB3CC41779E04DDA83251829', // Your device ID from logs
    // Add more test device IDs as needed
  ];
}
