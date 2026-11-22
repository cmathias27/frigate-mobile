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
  String get liveLayoutAuto =>
      'Automatic layout: every camera, as large as possible';

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

  @override
  String get timelineCalendar => 'Calendar';

  @override
  String get calendarPreviousMonth => 'Previous month';

  @override
  String get calendarNextMonth => 'Next month';

  @override
  String get calendarFull => 'Full recording';

  @override
  String get calendarPartial => 'Partial recording (alerts, motion)';

  @override
  String get calendarGoTo => 'Go to a date and time';

  @override
  String get calendarGo => 'Go';

  @override
  String get calendarHourAgo => '1 h ago';

  @override
  String get calendarThisMorning => 'This morning';

  @override
  String get calendarLastEvening => 'Last evening';

  @override
  String get calendarOldest => 'Oldest';

  @override
  String calendarOldestAt(String date) {
    return 'Oldest recording: $date';
  }

  @override
  String get calendarLoadFailed => 'Couldn\'t read the recording history';

  @override
  String get ok => 'OK';

  @override
  String updateAvailableTitle(String version) {
    return 'Version $version available';
  }

  @override
  String updateInstalledVersion(String version) {
    return 'Installed version: $version';
  }

  @override
  String get updateNoNotes => 'No notes for this version.';

  @override
  String get updateInstall => 'Install';

  @override
  String get updateLater => 'Later';

  @override
  String get updateDownloading => 'Downloading and checking…';

  @override
  String get updatePermissionTitle => 'Allow installation';

  @override
  String get updatePermissionMessage =>
      'Android asks you to allow Frigate Mobile to install its own updates. Turn on “Allow from this source” in the settings about to open, then come back and tap Install.';

  @override
  String get updatePermissionOpen => 'Open settings';

  @override
  String get updateErrorNetwork => 'Couldn\'t reach GitHub. Try again later.';

  @override
  String get updateErrorChecksum =>
      'The downloaded file doesn\'t match its checksum: installation cancelled.';

  @override
  String get updateErrorTooLarge =>
      'The update file is unusually large: download stopped.';

  @override
  String get updateErrorFolder => 'Couldn\'t save the update on the phone.';

  @override
  String get updateErrorUnsupported => 'This version has no APK to install.';

  @override
  String get updateErrorPackage =>
      'The downloaded file isn\'t the expected version of Frigate Mobile.';

  @override
  String get updateErrorSignature =>
      'This version is signed with another key: uninstall the app to install it.';

  @override
  String get updateErrorInstall => 'Android\'s installer couldn\'t open.';

  @override
  String get updateAutoCheck => 'Check for updates';

  @override
  String get updateAutoCheckHint => 'Once a day at start-up, from GitHub';

  @override
  String get updateCheckNow => 'Look for an update';

  @override
  String get updateChecking => 'Checking…';

  @override
  String get updateUpToDate => 'The app is up to date';

  @override
  String get updateCheckHint => 'Latest version published on GitHub';

  @override
  String get releaseNotesTitle => 'Release notes';

  @override
  String whatsNewTitle(String version) {
    return 'What\'s new in version $version';
  }

  @override
  String get eventsAllCameras => 'All cameras';

  @override
  String eventsNewCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count new passages',
      one: '1 new passage',
    );
    return '$_temp0';
  }

  @override
  String eventsSince(String time) {
    return 'Motion passages since $time';
  }

  @override
  String eventsEmpty(String time) {
    return 'No motion passage since $time.';
  }

  @override
  String get eventsNew => 'New';

  @override
  String get eventsToday => 'Today';

  @override
  String get eventsYesterday => 'Yesterday';

  @override
  String eventsPassageTitle(String camera) {
    return 'Motion · $camera';
  }

  @override
  String eventsLoadMore(int hours) {
    return 'Show the previous $hours hours';
  }

  @override
  String get eventsLoadFailed => 'The recordings could not be read.';

  @override
  String get eventsHistoryStart => 'Start of the recorded history.';

  @override
  String durationSeconds(int seconds) {
    return '$seconds s';
  }

  @override
  String durationMinutes(int minutes, String seconds) {
    return '$minutes min $seconds s';
  }

  @override
  String durationHours(int hours, String minutes) {
    return '$hours h $minutes min';
  }

  @override
  String get timelineClip => 'Clip';

  @override
  String get timelinePhoto => 'Photo';

  @override
  String clipTitle(String camera) {
    return 'Clip · $camera';
  }

  @override
  String get clipStart => 'Start';

  @override
  String get clipEnd => 'End';

  @override
  String clipEarlier(int seconds) {
    return '$seconds s earlier';
  }

  @override
  String clipLater(int seconds) {
    return '$seconds s later';
  }

  @override
  String clipLength(String length) {
    return 'Length: $length';
  }

  @override
  String clipLengthMax(String length) {
    return 'Length: $length, the maximum';
  }

  @override
  String get clipPassage => 'Passage';

  @override
  String get clipSave => 'Save';

  @override
  String get clipShare => 'Share';

  @override
  String clipDownloading(String size) {
    return 'Downloading… $size MB';
  }

  @override
  String get clipCancel => 'Cancel';

  @override
  String clipSaved(String album) {
    return 'Clip saved in the $album album';
  }

  @override
  String get clipFailed => 'The clip could not be downloaded.';

  @override
  String get timelineSeekAll => 'All';

  @override
  String get timelineSeekAllHint =>
      'Previous and next passage on every camera, otherwise on the camera played';

  @override
  String get timelineImagePlayback => 'Images';

  @override
  String get timelineImagePlaybackTitle => 'Playing images';

  @override
  String get timelineImagePlaybackBody =>
      'This camera\'s video does not play on this phone, often because its picture is too large for the decoder. The recorded images are shown instead, a few per second, until the app is closed.';

  @override
  String timelineImagePlaybackDetail(String error) {
    return 'Detail: $error';
  }

  @override
  String get timelineRetryVideo => 'Retry the video';

  @override
  String get alertsViewAlerts => 'Alerts';

  @override
  String get alertsViewDetections => 'Detections';

  @override
  String get alertsViewMotion => 'Motion';

  @override
  String reviewUnseen(int count) {
    return '$count unseen';
  }

  @override
  String reviewSince(String time) {
    return 'Since $time';
  }

  @override
  String reviewSelected(int count) {
    return '$count selected';
  }

  @override
  String get reviewMarkSeen => 'Mark seen';

  @override
  String get reviewMarkUnseen => 'Mark unseen';

  @override
  String get reviewMarkAllSeen => 'Mark all seen';

  @override
  String get reviewMarkFailed => 'Frigate did not save the seen mark.';

  @override
  String reviewEmptyAlerts(String time) {
    return 'No alert since $time.';
  }

  @override
  String reviewEmptyDetections(String time) {
    return 'No detection since $time.';
  }

  @override
  String get reviewLoadMore => 'Show the previous day';

  @override
  String get reviewLoadFailed => 'The alerts could not be read.';

  @override
  String get reviewInProgress => 'ongoing';

  @override
  String get reviewUnknown => 'Event';

  @override
  String reviewTitle(String what, String camera) {
    return '$what · $camera';
  }

  @override
  String get objectPerson => 'Person';

  @override
  String get objectCar => 'Car';

  @override
  String get objectTruck => 'Truck';

  @override
  String get objectBus => 'Bus';

  @override
  String get objectMotorcycle => 'Motorcycle';

  @override
  String get objectBicycle => 'Bicycle';

  @override
  String get objectBoat => 'Boat';

  @override
  String get objectDog => 'Dog';

  @override
  String get objectCat => 'Cat';

  @override
  String get objectBird => 'Bird';

  @override
  String get objectHorse => 'Horse';

  @override
  String get objectPackage => 'Package';

  @override
  String get objectFace => 'Face';

  @override
  String get objectLicensePlate => 'License plate';

  @override
  String get objectBark => 'Barking';

  @override
  String get objectSpeech => 'Speech';

  @override
  String get objectScream => 'Scream';

  @override
  String get objectFireAlarm => 'Fire alarm';
}
