// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Frigate Mobile';

  @override
  String get tabLive => 'Live';

  @override
  String get tabTimeline => 'Timeline';

  @override
  String get tabEvents => 'Alerts';

  @override
  String get tabMore => 'More';

  @override
  String comingInVersion(String version) {
    return 'Coming in version $version.';
  }

  @override
  String get liveDescription =>
      'All your cameras live, in a grid or one at a time.';

  @override
  String get timelineDescription =>
      'Recordings of every camera, with motion and detections, with no day limit.';

  @override
  String get eventsDescription =>
      'Motion passages, then alerts and detections when Frigate produces them.';

  @override
  String get moreDescription => 'Servers, settings, updates and release notes.';

  @override
  String aboutVersion(String version) {
    return 'Version $version';
  }

  @override
  String get loginTitle => 'Add a server';

  @override
  String get loginSubtitle => 'Just like DS cam: one server, multiple cameras.';

  @override
  String get serverNameLabel => 'Server name';

  @override
  String get localUrlLabel => 'Local address (port 8971)';

  @override
  String get localUrlHint => 'https://192.168.1.10:8971';

  @override
  String get remoteUrlLabel => 'Remote address (optional)';

  @override
  String get remoteUrlHint => 'https://frigate.example.com';

  @override
  String get usernameLabel => 'Username';

  @override
  String get passwordLabel => 'Password';

  @override
  String get selfSignedLabel =>
      'Accept self-signed certificate on local network';

  @override
  String get connectButton => 'Connect';

  @override
  String get connectingStatus => 'Connecting…';

  @override
  String get connectedTitle => 'Connected server';

  @override
  String serverInfoCameras(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count cameras online',
      one: '1 camera online',
    );
    return '$_temp0';
  }

  @override
  String get detectionModeMotionOnly => 'Motion-only mode (no object tracking)';

  @override
  String get detectionModeObjects => 'Object tracking active';

  @override
  String continuousDays(String days) {
    return 'Continuous retention: $days days';
  }

  @override
  String get disconnectButton => 'Disconnect';

  @override
  String get disconnectConfirmTitle => 'Disconnect';

  @override
  String get disconnectConfirmMessage =>
      'Do you want to disconnect from this Frigate server?';

  @override
  String get cancel => 'Cancel';

  @override
  String get confirm => 'Confirm';

  @override
  String get refresh => 'Refresh';

  @override
  String get refreshSuccess => 'Capabilities refreshed';

  @override
  String get requiredField => 'This field is required';

  @override
  String get invalidUrl => 'Invalid address (start with https://)';

  @override
  String get liveBadge => 'LIVE';

  @override
  String get liveStale => 'FROZEN';

  @override
  String get liveUnavailable => 'Image unavailable';

  @override
  String get liveNoCamera => 'No active camera on this server.';

  @override
  String liveLayout(int count) {
    return '$count per page';
  }

  @override
  String livePage(int current, int total) {
    return 'Page $current of $total';
  }

  @override
  String liveModeSnapshots(int seconds) {
    return 'Images · every $seconds s';
  }

  @override
  String get liveFullScreen => 'Full screen';

  @override
  String get liveModeVideo => 'Live video';

  @override
  String get liveVideoConnecting => 'Connecting video…';

  @override
  String get liveVideoUnavailable => 'Video unavailable';

  @override
  String get liveVideoRetry => 'Retry video';

  @override
  String get liveSoundOn => 'Turn sound on';

  @override
  String get liveSoundOff => 'Mute';

  @override
  String get liveQuality => 'Quality';

  @override
  String liveStream(int number) {
    return 'Stream $number';
  }

  @override
  String liveStreamMain(int number) {
    return 'Stream $number (main)';
  }

  @override
  String get livePhoto => 'Photo';

  @override
  String livePhotoSaved(String album) {
    return 'Photo saved in the $album album';
  }

  @override
  String get livePhotoShare => 'Share';

  @override
  String get livePhotoFailed => 'Could not save the photo';

  @override
  String get liveSound => 'Sound';

  @override
  String timelinePlaying(String camera) {
    return 'Playing · $camera';
  }

  @override
  String get timelineCamera => 'Camera playing';

  @override
  String get timelineAllCameras => 'All cameras';

  @override
  String timelineZoomHours(int hours) {
    return '$hours h';
  }

  @override
  String get timelineZoomAll => 'All';

  @override
  String get timelinePreviousPassage => 'Prev. motion';

  @override
  String get timelineNextPassage => 'Next motion';

  @override
  String timelineBack(int seconds) {
    return 'Back $seconds s';
  }

  @override
  String timelineForward(int seconds) {
    return 'Forward $seconds s';
  }

  @override
  String timelineSeconds(int seconds) {
    return '$seconds s';
  }

  @override
  String get timelinePlay => 'Play';

  @override
  String get timelinePause => 'Pause';

  @override
  String get timelinePreviousDay => 'Previous day';

  @override
  String get timelineNextDay => 'Next day';

  @override
  String timelineNoPassage(int hours) {
    return 'No motion within $hours h';
  }

  @override
  String get timelineNoRecording => 'No recording at this time';

  @override
  String get timelinePlaybackFailed => 'Playback failed';

  @override
  String get timelineRetry => 'Retry';

  @override
  String get timelineEnd => 'End of recordings';

  @override
  String get timelineLoading => 'Loading timeline…';

  @override
  String get timelineNoRecordingCamera => 'No camera records on this server';
}
