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
}
