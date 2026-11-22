import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('fr'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In fr, this message translates to:
  /// **'Frigate Mobile'**
  String get appTitle;

  /// No description provided for @tabLive.
  ///
  /// In fr, this message translates to:
  /// **'Direct'**
  String get tabLive;

  /// No description provided for @tabTimeline.
  ///
  /// In fr, this message translates to:
  /// **'Chronologie'**
  String get tabTimeline;

  /// No description provided for @tabEvents.
  ///
  /// In fr, this message translates to:
  /// **'Alertes'**
  String get tabEvents;

  /// No description provided for @tabMore.
  ///
  /// In fr, this message translates to:
  /// **'Plus'**
  String get tabMore;

  /// No description provided for @comingInVersion.
  ///
  /// In fr, this message translates to:
  /// **'Arrive dans la version {version}.'**
  String comingInVersion(String version);

  /// No description provided for @liveDescription.
  ///
  /// In fr, this message translates to:
  /// **'Toutes vos caméras en direct, en grille ou une par une.'**
  String get liveDescription;

  /// No description provided for @timelineDescription.
  ///
  /// In fr, this message translates to:
  /// **'Les enregistrements de toutes les caméras, avec le mouvement et les détections, sans limite de jours.'**
  String get timelineDescription;

  /// No description provided for @eventsDescription.
  ///
  /// In fr, this message translates to:
  /// **'Les passages de mouvement, puis les alertes et détections quand Frigate les produit.'**
  String get eventsDescription;

  /// No description provided for @moreDescription.
  ///
  /// In fr, this message translates to:
  /// **'Serveurs, réglages, mises à jour et notes de version.'**
  String get moreDescription;

  /// No description provided for @aboutVersion.
  ///
  /// In fr, this message translates to:
  /// **'Version {version}'**
  String aboutVersion(String version);

  /// No description provided for @loginTitle.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter un serveur'**
  String get loginTitle;

  /// No description provided for @loginSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Comme dans DS cam : un serveur, plusieurs caméras.'**
  String get loginSubtitle;

  /// No description provided for @serverNameLabel.
  ///
  /// In fr, this message translates to:
  /// **'Nom du serveur'**
  String get serverNameLabel;

  /// No description provided for @localUrlLabel.
  ///
  /// In fr, this message translates to:
  /// **'Adresse locale (port 8971)'**
  String get localUrlLabel;

  /// No description provided for @localUrlHint.
  ///
  /// In fr, this message translates to:
  /// **'https://192.168.1.53:8971'**
  String get localUrlHint;

  /// No description provided for @remoteUrlLabel.
  ///
  /// In fr, this message translates to:
  /// **'Adresse à distance (optionnelle)'**
  String get remoteUrlLabel;

  /// No description provided for @remoteUrlHint.
  ///
  /// In fr, this message translates to:
  /// **'https://frigate.exemple.fr'**
  String get remoteUrlHint;

  /// No description provided for @usernameLabel.
  ///
  /// In fr, this message translates to:
  /// **'Utilisateur'**
  String get usernameLabel;

  /// No description provided for @passwordLabel.
  ///
  /// In fr, this message translates to:
  /// **'Mot de passe'**
  String get passwordLabel;

  /// No description provided for @selfSignedLabel.
  ///
  /// In fr, this message translates to:
  /// **'Certificat auto-signé accepté sur le réseau local'**
  String get selfSignedLabel;

  /// No description provided for @connectButton.
  ///
  /// In fr, this message translates to:
  /// **'Se connecter'**
  String get connectButton;

  /// No description provided for @connectingStatus.
  ///
  /// In fr, this message translates to:
  /// **'Connexion en cours…'**
  String get connectingStatus;

  /// No description provided for @connectedTitle.
  ///
  /// In fr, this message translates to:
  /// **'Serveur connecté'**
  String get connectedTitle;

  /// No description provided for @serverInfoCameras.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{1 caméra en ligne} other{{count} caméras en ligne}}'**
  String serverInfoCameras(int count);

  /// No description provided for @detectionModeMotionOnly.
  ///
  /// In fr, this message translates to:
  /// **'Mode mouvement seul (sans détection d\'objets)'**
  String get detectionModeMotionOnly;

  /// No description provided for @detectionModeObjects.
  ///
  /// In fr, this message translates to:
  /// **'Détection d\'objets active'**
  String get detectionModeObjects;

  /// No description provided for @continuousDays.
  ///
  /// In fr, this message translates to:
  /// **'Rétention continu : {days} jours'**
  String continuousDays(String days);

  /// No description provided for @disconnectButton.
  ///
  /// In fr, this message translates to:
  /// **'Se déconnecter'**
  String get disconnectButton;

  /// No description provided for @disconnectConfirmTitle.
  ///
  /// In fr, this message translates to:
  /// **'Déconnexion'**
  String get disconnectConfirmTitle;

  /// No description provided for @disconnectConfirmMessage.
  ///
  /// In fr, this message translates to:
  /// **'Voulez-vous vous déconnecter de ce serveur Frigate ?'**
  String get disconnectConfirmMessage;

  /// No description provided for @cancel.
  ///
  /// In fr, this message translates to:
  /// **'Annuler'**
  String get cancel;

  /// No description provided for @confirm.
  ///
  /// In fr, this message translates to:
  /// **'Confirmer'**
  String get confirm;

  /// No description provided for @refresh.
  ///
  /// In fr, this message translates to:
  /// **'Actualiser'**
  String get refresh;

  /// No description provided for @refreshSuccess.
  ///
  /// In fr, this message translates to:
  /// **'Capacités actualisées'**
  String get refreshSuccess;

  /// No description provided for @requiredField.
  ///
  /// In fr, this message translates to:
  /// **'Ce champ est obligatoire'**
  String get requiredField;

  /// No description provided for @invalidUrl.
  ///
  /// In fr, this message translates to:
  /// **'Adresse invalide (commencez par https://)'**
  String get invalidUrl;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'fr':
      return AppLocalizationsFr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
