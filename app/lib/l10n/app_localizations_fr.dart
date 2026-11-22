// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'Frigate Mobile';

  @override
  String get tabLive => 'Direct';

  @override
  String get tabTimeline => 'Chronologie';

  @override
  String get tabEvents => 'Alertes';

  @override
  String get tabMore => 'Plus';

  @override
  String comingInVersion(String version) {
    return 'Arrive dans la version $version.';
  }

  @override
  String get liveDescription =>
      'Toutes vos caméras en direct, en grille ou une par une.';

  @override
  String get timelineDescription =>
      'Les enregistrements de toutes les caméras, avec le mouvement et les détections, sans limite de jours.';

  @override
  String get eventsDescription =>
      'Les passages de mouvement, puis les alertes et détections quand Frigate les produit.';

  @override
  String get moreDescription =>
      'Serveurs, réglages, mises à jour et notes de version.';

  @override
  String aboutVersion(String version) {
    return 'Version $version';
  }
}
