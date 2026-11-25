import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app/theme.dart';
import '../../l10n/app_localizations.dart';
import 'camera_feed.dart';

/// One camera of the live grid: latest frame, live badge, time of the
/// frame and camera name (mock-up screen 2).
class FeedTile extends StatelessWidget {
  final CameraFeed feed;
  final String label;
  final VoidCallback? onTap;

  const FeedTile({
    super.key,
    required this.feed,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: onTap != null,
      label: label,
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ListenableBuilder(
            listenable: feed,
            builder: (context, _) => Stack(
              fit: StackFit.expand,
              children: [
                FeedImage(feed: feed, fit: BoxFit.cover),
                Positioned(
                  left: 6,
                  top: 5,
                  child: LiveBadge(stale: feed.isStale),
                ),
                if (feed.updatedAt != null)
                  Positioned(
                    right: 6,
                    top: 5,
                    child: _Overlay(
                      DateFormat.Hms(
                        Localizations.localeOf(context).toString(),
                      ).format(feed.updatedAt!),
                    ),
                  ),
                Positioned(left: 6, bottom: 5, child: _Overlay(label)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Frame of a [CameraFeed], or a waiting / unavailable placeholder.
class FeedImage extends StatelessWidget {
  final CameraFeed feed;
  final BoxFit fit;

  const FeedImage({super.key, required this.feed, required this.fit});

  @override
  Widget build(BuildContext context) {
    final image = feed.image;
    if (image == null) {
      if (!feed.failed) {
        return const Center(
          child: SizedBox.square(
            dimension: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        );
      }
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 4,
          children: [
            const Icon(Icons.videocam_off_outlined, color: AppColors.textDim),
            Text(
              AppLocalizations.of(context).liveUnavailable,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textDim),
            ),
          ],
        ),
      );
    }
    return Image.memory(
      image,
      fit: fit,
      gaplessPlayback: true,
      filterQuality: FilterQuality.medium,
      errorBuilder: (context, _, _) => const Center(
        child: Icon(Icons.broken_image_outlined, color: AppColors.textDim),
      ),
    );
  }
}

/// Stands where the video will be when images are not wanted: a spinner
/// while it connects, a retry button once it failed.
class VideoWaiting extends StatelessWidget {
  final bool failed;
  final VoidCallback onRetry;

  const VideoWaiting({super.key, required this.failed, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    if (!failed) {
      return const Center(
        child: SizedBox.square(
          dimension: 22,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    final l = AppLocalizations.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 4,
        children: [
          const Icon(Icons.videocam_off_outlined, color: AppColors.textDim),
          Text(
            l.liveVideoUnavailable,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textDim),
          ),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: Text(l.liveVideoRetry),
          ),
        ],
      ),
    );
  }
}

/// The live badge with a red dot while frames arrive, a grey "paused" badge when
/// the picture is frozen.
class LiveBadge extends StatelessWidget {
  final bool stale;

  const LiveBadge({super.key, required this.stale});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 4,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: stale ? AppColors.textDim : AppColors.live,
              ),
            ),
            Text(
              stale ? l.liveStale : l.liveBadge,
              style: const TextStyle(
                fontSize: 10,
                fontFamily: 'monospace',
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Overlay extends StatelessWidget {
  final String text;

  const _Overlay(this.text);

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 11,
            color: Colors.white,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }
}
