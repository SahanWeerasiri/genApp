import 'package:flutter/material.dart';
import '../services/admob_service.dart';
import '../utils/logger.dart';

class RewardedAdButton extends StatefulWidget {
  final VoidCallback? onRewardEarned;
  final Widget? child;
  final bool enabled;

  const RewardedAdButton({
    super.key,
    this.onRewardEarned,
    this.child,
    this.enabled = true,
  });

  @override
  State<RewardedAdButton> createState() => _RewardedAdButtonState();
}

class _RewardedAdButtonState extends State<RewardedAdButton> {
  bool _isLoading = false;
  bool _isAdReady = false;

  @override
  void initState() {
    super.initState();
    _checkAdStatus();
    _preloadAd();
  }

  void _checkAdStatus() {
    setState(() {
      _isAdReady = AdMobService.instance.isRewardedAdReady;
    });
  }

  Future<void> _preloadAd() async {
    if (!AdMobService.instance.isRewardedAdReady) {
      setState(() {
        _isLoading = true;
      });

      await AdMobService.instance.loadRewardedAd();

      // Wait a bit and check if ad is loaded
      await Future.delayed(const Duration(seconds: 2));

      if (mounted) {
        setState(() {
          _isLoading = false;
          _isAdReady = AdMobService.instance.isRewardedAdReady;
        });
      }
    }
  }

  Future<void> _showRewardedAd() async {
    if (!widget.enabled || _isLoading) return;

    try {
      setState(() {
        _isLoading = true;
      });

      // If ad is not ready, try to load it first
      if (!AdMobService.instance.isRewardedAdReady) {
        AppLogger.info('Ad not ready, loading...');
        await AdMobService.instance.loadRewardedAd();

        // Wait for ad to load
        await Future.delayed(const Duration(seconds: 3));

        if (!AdMobService.instance.isRewardedAdReady) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text(
                  'Ad is not ready yet. Please try again in a moment.',
                ),
                backgroundColor: Colors.orange,
                action: SnackBarAction(
                  label: 'Retry',
                  onPressed: () async {
                    await AdMobService.instance.loadRewardedAd();
                  },
                ),
              ),
            );
          }
          return;
        }
      }

      AppLogger.info('Showing rewarded ad...');
      final rewardEarned = await AdMobService.instance.showRewardedAd();

      if (mounted) {
        if (rewardEarned) {
          AppLogger.info(
            'User earned reward from ad - calling onRewardEarned callback',
          );
          print(
            'DEBUG: RewardedAdButton - User earned reward, calling callback...',
          );
          widget.onRewardEarned?.call();
          print('DEBUG: RewardedAdButton - Callback called');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🎉 Processing reward...'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          AppLogger.info(
            'User did not earn reward (ad was skipped or closed early)',
          );
          print('DEBUG: RewardedAdButton - User did not earn reward');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please watch the complete ad to earn tokens.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      AppLogger.error('Error showing rewarded ad: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to load ad. Please try again later.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _checkAdStatus();

        // Preload next ad
        Future.delayed(const Duration(seconds: 1), () {
          AdMobService.instance.loadRewardedAd();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (widget.child != null) {
      return InkWell(
        onTap: widget.enabled ? _showRewardedAd : null,
        child: widget.child,
      );
    }

    return ElevatedButton.icon(
      onPressed: widget.enabled && !_isLoading ? _showRewardedAd : null,
      icon: _isLoading
          ? SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  theme.colorScheme.primary,
                ),
              ),
            )
          : Icon(
              _isAdReady
                  ? Icons.play_circle_outline_rounded
                  : Icons.cloud_download_outlined,
            ),
      label: Text(
        _isLoading
            ? 'Loading...'
            : _isAdReady
            ? 'Watch Ad for Tokens'
            : 'Preparing Ad...',
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: theme.colorScheme.primary,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

/// Info widget that shows reward details
class RewardAdInfo extends StatelessWidget {
  const RewardAdInfo({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              AdMobService.instance.rewardInfo,
              style: TextStyle(color: Colors.blue.shade700, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
