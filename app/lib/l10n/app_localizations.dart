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
  /// **'https://192.168.1.10:8971'**
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

  /// No description provided for @liveBadge.
  ///
  /// In fr, this message translates to:
  /// **'LIVE'**
  String get liveBadge;

  /// No description provided for @liveStale.
  ///
  /// In fr, this message translates to:
  /// **'FIGÉ'**
  String get liveStale;

  /// No description provided for @liveUnavailable.
  ///
  /// In fr, this message translates to:
  /// **'Image indisponible'**
  String get liveUnavailable;

  /// No description provided for @liveNoCamera.
  ///
  /// In fr, this message translates to:
  /// **'Aucune caméra active sur ce serveur.'**
  String get liveNoCamera;

  /// No description provided for @liveLayout.
  ///
  /// In fr, this message translates to:
  /// **'{count} par page'**
  String liveLayout(int count);

  /// No description provided for @livePage.
  ///
  /// In fr, this message translates to:
  /// **'Page {current} sur {total}'**
  String livePage(int current, int total);

  /// No description provided for @liveModeSnapshots.
  ///
  /// In fr, this message translates to:
  /// **'Images · toutes les {seconds} s'**
  String liveModeSnapshots(int seconds);

  /// No description provided for @liveFullScreen.
  ///
  /// In fr, this message translates to:
  /// **'Plein écran'**
  String get liveFullScreen;

  /// No description provided for @liveModeVideo.
  ///
  /// In fr, this message translates to:
  /// **'Vidéo en direct'**
  String get liveModeVideo;

  /// No description provided for @liveVideoConnecting.
  ///
  /// In fr, this message translates to:
  /// **'Connexion vidéo…'**
  String get liveVideoConnecting;

  /// No description provided for @liveVideoUnavailable.
  ///
  /// In fr, this message translates to:
  /// **'Vidéo indisponible'**
  String get liveVideoUnavailable;

  /// No description provided for @liveVideoRetry.
  ///
  /// In fr, this message translates to:
  /// **'Réessayer la vidéo'**
  String get liveVideoRetry;

  /// No description provided for @liveSoundOn.
  ///
  /// In fr, this message translates to:
  /// **'Activer le son'**
  String get liveSoundOn;

  /// No description provided for @liveSoundOff.
  ///
  /// In fr, this message translates to:
  /// **'Couper le son'**
  String get liveSoundOff;

  /// No description provided for @liveQuality.
  ///
  /// In fr, this message translates to:
  /// **'Qualité'**
  String get liveQuality;

  /// No description provided for @liveStream.
  ///
  /// In fr, this message translates to:
  /// **'Flux {number}'**
  String liveStream(int number);

  /// No description provided for @liveStreamMain.
  ///
  /// In fr, this message translates to:
  /// **'Flux {number} (principal)'**
  String liveStreamMain(int number);

  /// No description provided for @livePhoto.
  ///
  /// In fr, this message translates to:
  /// **'Photo'**
  String get livePhoto;

  /// No description provided for @livePhotoSaved.
  ///
  /// In fr, this message translates to:
  /// **'Photo enregistrée dans l\'album {album}'**
  String livePhotoSaved(String album);

  /// No description provided for @livePhotoShare.
  ///
  /// In fr, this message translates to:
  /// **'Partager'**
  String get livePhotoShare;

  /// No description provided for @livePhotoFailed.
  ///
  /// In fr, this message translates to:
  /// **'Impossible d\'enregistrer la photo'**
  String get livePhotoFailed;

  /// No description provided for @liveSound.
  ///
  /// In fr, this message translates to:
  /// **'Son'**
  String get liveSound;

  /// No description provided for @timelinePlaying.
  ///
  /// In fr, this message translates to:
  /// **'Lecture · {camera}'**
  String timelinePlaying(String camera);

  /// No description provided for @timelineCamera.
  ///
  /// In fr, this message translates to:
  /// **'Caméra en lecture'**
  String get timelineCamera;

  /// No description provided for @timelineAllCameras.
  ///
  /// In fr, this message translates to:
  /// **'Toutes les caméras'**
  String get timelineAllCameras;

  /// No description provided for @timelineZoomHours.
  ///
  /// In fr, this message translates to:
  /// **'{hours} h'**
  String timelineZoomHours(int hours);

  /// No description provided for @timelineZoomAll.
  ///
  /// In fr, this message translates to:
  /// **'Tout'**
  String get timelineZoomAll;

  /// No description provided for @timelinePreviousPassage.
  ///
  /// In fr, this message translates to:
  /// **'Passage préc.'**
  String get timelinePreviousPassage;

  /// No description provided for @timelineNextPassage.
  ///
  /// In fr, this message translates to:
  /// **'Passage suiv.'**
  String get timelineNextPassage;

  /// No description provided for @timelineBack.
  ///
  /// In fr, this message translates to:
  /// **'Reculer de {seconds} s'**
  String timelineBack(int seconds);

  /// No description provided for @timelineForward.
  ///
  /// In fr, this message translates to:
  /// **'Avancer de {seconds} s'**
  String timelineForward(int seconds);

  /// No description provided for @timelineSeconds.
  ///
  /// In fr, this message translates to:
  /// **'{seconds} s'**
  String timelineSeconds(int seconds);

  /// No description provided for @timelinePlay.
  ///
  /// In fr, this message translates to:
  /// **'Lecture'**
  String get timelinePlay;

  /// No description provided for @timelinePause.
  ///
  /// In fr, this message translates to:
  /// **'Pause'**
  String get timelinePause;

  /// No description provided for @timelinePreviousDay.
  ///
  /// In fr, this message translates to:
  /// **'Jour précédent'**
  String get timelinePreviousDay;

  /// No description provided for @timelineNextDay.
  ///
  /// In fr, this message translates to:
  /// **'Jour suivant'**
  String get timelineNextDay;

  /// No description provided for @timelineNoPassage.
  ///
  /// In fr, this message translates to:
  /// **'Aucun passage de mouvement dans les {hours} h'**
  String timelineNoPassage(int hours);

  /// No description provided for @timelineNoRecording.
  ///
  /// In fr, this message translates to:
  /// **'Pas d\'enregistrement à ce moment'**
  String get timelineNoRecording;

  /// No description provided for @timelinePlaybackFailed.
  ///
  /// In fr, this message translates to:
  /// **'Lecture impossible'**
  String get timelinePlaybackFailed;

  /// No description provided for @timelineRetry.
  ///
  /// In fr, this message translates to:
  /// **'Réessayer'**
  String get timelineRetry;

  /// No description provided for @timelineEnd.
  ///
  /// In fr, this message translates to:
  /// **'Fin des enregistrements'**
  String get timelineEnd;

  /// No description provided for @timelineLoading.
  ///
  /// In fr, this message translates to:
  /// **'Chargement de la chronologie…'**
  String get timelineLoading;

  /// No description provided for @timelineNoRecordingCamera.
  ///
  /// In fr, this message translates to:
  /// **'Aucune caméra n\'enregistre sur ce serveur'**
  String get timelineNoRecordingCamera;

  /// No description provided for @timelineCalendar.
  ///
  /// In fr, this message translates to:
  /// **'Calendrier'**
  String get timelineCalendar;

  /// No description provided for @calendarPreviousMonth.
  ///
  /// In fr, this message translates to:
  /// **'Mois précédent'**
  String get calendarPreviousMonth;

  /// No description provided for @calendarNextMonth.
  ///
  /// In fr, this message translates to:
  /// **'Mois suivant'**
  String get calendarNextMonth;

  /// No description provided for @calendarFull.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrement complet'**
  String get calendarFull;

  /// No description provided for @calendarPartial.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrement partiel (alertes, mouvement)'**
  String get calendarPartial;

  /// No description provided for @calendarGoTo.
  ///
  /// In fr, this message translates to:
  /// **'Aller à une date et une heure'**
  String get calendarGoTo;

  /// No description provided for @calendarGo.
  ///
  /// In fr, this message translates to:
  /// **'Aller'**
  String get calendarGo;

  /// No description provided for @calendarHourAgo.
  ///
  /// In fr, this message translates to:
  /// **'Il y a 1 h'**
  String get calendarHourAgo;

  /// No description provided for @calendarThisMorning.
  ///
  /// In fr, this message translates to:
  /// **'Ce matin'**
  String get calendarThisMorning;

  /// No description provided for @calendarLastEvening.
  ///
  /// In fr, this message translates to:
  /// **'Hier soir'**
  String get calendarLastEvening;

  /// No description provided for @calendarOldest.
  ///
  /// In fr, this message translates to:
  /// **'Le plus ancien'**
  String get calendarOldest;

  /// No description provided for @calendarOldestAt.
  ///
  /// In fr, this message translates to:
  /// **'Plus ancien enregistrement : {date}'**
  String calendarOldestAt(String date);

  /// No description provided for @calendarLoadFailed.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de lire l\'historique des enregistrements'**
  String get calendarLoadFailed;
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
