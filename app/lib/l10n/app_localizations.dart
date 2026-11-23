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

  /// No description provided for @liveLayoutAuto.
  ///
  /// In fr, this message translates to:
  /// **'Disposition automatique : toutes les caméras, le plus grand possible'**
  String get liveLayoutAuto;

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

  /// No description provided for @ok.
  ///
  /// In fr, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @updateAvailableTitle.
  ///
  /// In fr, this message translates to:
  /// **'Version {version} disponible'**
  String updateAvailableTitle(String version);

  /// No description provided for @updateInstalledVersion.
  ///
  /// In fr, this message translates to:
  /// **'Version installée : {version}'**
  String updateInstalledVersion(String version);

  /// No description provided for @updateNoNotes.
  ///
  /// In fr, this message translates to:
  /// **'Pas de note pour cette version.'**
  String get updateNoNotes;

  /// No description provided for @updateInstall.
  ///
  /// In fr, this message translates to:
  /// **'Installer'**
  String get updateInstall;

  /// No description provided for @updateLater.
  ///
  /// In fr, this message translates to:
  /// **'Plus tard'**
  String get updateLater;

  /// No description provided for @updateDownloading.
  ///
  /// In fr, this message translates to:
  /// **'Téléchargement et vérification…'**
  String get updateDownloading;

  /// No description provided for @updatePermissionTitle.
  ///
  /// In fr, this message translates to:
  /// **'Autoriser l\'installation'**
  String get updatePermissionTitle;

  /// No description provided for @updatePermissionMessage.
  ///
  /// In fr, this message translates to:
  /// **'Android demande d\'autoriser Frigate Mobile à installer ses propres mises à jour. Active « Autoriser cette source » dans les réglages qui vont s\'ouvrir, puis reviens appuyer sur Installer.'**
  String get updatePermissionMessage;

  /// No description provided for @updatePermissionOpen.
  ///
  /// In fr, this message translates to:
  /// **'Ouvrir les réglages'**
  String get updatePermissionOpen;

  /// No description provided for @updateErrorNetwork.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de joindre GitHub. Réessaie plus tard.'**
  String get updateErrorNetwork;

  /// No description provided for @updateErrorChecksum.
  ///
  /// In fr, this message translates to:
  /// **'Le fichier téléchargé ne correspond pas à son empreinte : installation annulée.'**
  String get updateErrorChecksum;

  /// No description provided for @updateErrorTooLarge.
  ///
  /// In fr, this message translates to:
  /// **'Le fichier de mise à jour est anormalement gros : téléchargement arrêté.'**
  String get updateErrorTooLarge;

  /// No description provided for @updateErrorFolder.
  ///
  /// In fr, this message translates to:
  /// **'Impossible d\'enregistrer la mise à jour sur le téléphone.'**
  String get updateErrorFolder;

  /// No description provided for @updateErrorUnsupported.
  ///
  /// In fr, this message translates to:
  /// **'Cette version ne propose pas d\'APK à installer.'**
  String get updateErrorUnsupported;

  /// No description provided for @updateErrorPackage.
  ///
  /// In fr, this message translates to:
  /// **'Le fichier téléchargé n\'est pas la version attendue de Frigate Mobile.'**
  String get updateErrorPackage;

  /// No description provided for @updateErrorSignature.
  ///
  /// In fr, this message translates to:
  /// **'Cette version est signée par une autre clé : désinstalle l\'application pour l\'installer.'**
  String get updateErrorSignature;

  /// No description provided for @updateErrorInstall.
  ///
  /// In fr, this message translates to:
  /// **'L\'installateur d\'Android n\'a pas pu s\'ouvrir.'**
  String get updateErrorInstall;

  /// No description provided for @updateAutoCheck.
  ///
  /// In fr, this message translates to:
  /// **'Vérifier les mises à jour'**
  String get updateAutoCheck;

  /// No description provided for @updateAutoCheckHint.
  ///
  /// In fr, this message translates to:
  /// **'Une fois par jour au démarrage, auprès de GitHub'**
  String get updateAutoCheckHint;

  /// No description provided for @updateCheckNow.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher une mise à jour'**
  String get updateCheckNow;

  /// No description provided for @updateChecking.
  ///
  /// In fr, this message translates to:
  /// **'Recherche en cours…'**
  String get updateChecking;

  /// No description provided for @updateUpToDate.
  ///
  /// In fr, this message translates to:
  /// **'L\'application est à jour'**
  String get updateUpToDate;

  /// No description provided for @updateCheckHint.
  ///
  /// In fr, this message translates to:
  /// **'Dernière version publiée sur GitHub'**
  String get updateCheckHint;

  /// No description provided for @releaseNotesTitle.
  ///
  /// In fr, this message translates to:
  /// **'Notes de version'**
  String get releaseNotesTitle;

  /// No description provided for @whatsNewTitle.
  ///
  /// In fr, this message translates to:
  /// **'Nouveautés de la version {version}'**
  String whatsNewTitle(String version);

  /// No description provided for @eventsAllCameras.
  ///
  /// In fr, this message translates to:
  /// **'Toutes caméras'**
  String get eventsAllCameras;

  /// No description provided for @eventsNewCount.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{1 nouveau passage} other{{count} nouveaux passages}}'**
  String eventsNewCount(int count);

  /// No description provided for @eventsSince.
  ///
  /// In fr, this message translates to:
  /// **'Passages de mouvement depuis {time}'**
  String eventsSince(String time);

  /// No description provided for @eventsEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Aucun passage de mouvement depuis {time}.'**
  String eventsEmpty(String time);

  /// No description provided for @eventsNew.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau'**
  String get eventsNew;

  /// No description provided for @eventsToday.
  ///
  /// In fr, this message translates to:
  /// **'Aujourd\'hui'**
  String get eventsToday;

  /// No description provided for @eventsYesterday.
  ///
  /// In fr, this message translates to:
  /// **'Hier'**
  String get eventsYesterday;

  /// No description provided for @eventsPassageTitle.
  ///
  /// In fr, this message translates to:
  /// **'Mouvement · {camera}'**
  String eventsPassageTitle(String camera);

  /// No description provided for @eventsLoadMore.
  ///
  /// In fr, this message translates to:
  /// **'Voir les {hours} heures précédentes'**
  String eventsLoadMore(int hours);

  /// No description provided for @eventsLoadFailed.
  ///
  /// In fr, this message translates to:
  /// **'Les enregistrements n\'ont pas pu être lus.'**
  String get eventsLoadFailed;

  /// No description provided for @eventsHistoryStart.
  ///
  /// In fr, this message translates to:
  /// **'Début de l\'historique enregistré.'**
  String get eventsHistoryStart;

  /// No description provided for @durationSeconds.
  ///
  /// In fr, this message translates to:
  /// **'{seconds} s'**
  String durationSeconds(int seconds);

  /// No description provided for @durationMinutes.
  ///
  /// In fr, this message translates to:
  /// **'{minutes} min {seconds}'**
  String durationMinutes(int minutes, String seconds);

  /// No description provided for @durationHours.
  ///
  /// In fr, this message translates to:
  /// **'{hours} h {minutes}'**
  String durationHours(int hours, String minutes);

  /// No description provided for @timelineClip.
  ///
  /// In fr, this message translates to:
  /// **'Extrait'**
  String get timelineClip;

  /// No description provided for @timelinePhoto.
  ///
  /// In fr, this message translates to:
  /// **'Photo'**
  String get timelinePhoto;

  /// No description provided for @clipTitle.
  ///
  /// In fr, this message translates to:
  /// **'Extrait · {camera}'**
  String clipTitle(String camera);

  /// No description provided for @clipStart.
  ///
  /// In fr, this message translates to:
  /// **'Début'**
  String get clipStart;

  /// No description provided for @clipEnd.
  ///
  /// In fr, this message translates to:
  /// **'Fin'**
  String get clipEnd;

  /// No description provided for @clipEarlier.
  ///
  /// In fr, this message translates to:
  /// **'{seconds} s plus tôt'**
  String clipEarlier(int seconds);

  /// No description provided for @clipLater.
  ///
  /// In fr, this message translates to:
  /// **'{seconds} s plus tard'**
  String clipLater(int seconds);

  /// No description provided for @clipLength.
  ///
  /// In fr, this message translates to:
  /// **'Durée : {length}'**
  String clipLength(String length);

  /// No description provided for @clipLengthMax.
  ///
  /// In fr, this message translates to:
  /// **'Durée : {length}, le maximum'**
  String clipLengthMax(String length);

  /// No description provided for @clipPassage.
  ///
  /// In fr, this message translates to:
  /// **'Passage'**
  String get clipPassage;

  /// No description provided for @clipSave.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer'**
  String get clipSave;

  /// No description provided for @clipShare.
  ///
  /// In fr, this message translates to:
  /// **'Partager'**
  String get clipShare;

  /// No description provided for @clipDownloading.
  ///
  /// In fr, this message translates to:
  /// **'Téléchargement… {size} Mo'**
  String clipDownloading(String size);

  /// No description provided for @clipCancel.
  ///
  /// In fr, this message translates to:
  /// **'Annuler'**
  String get clipCancel;

  /// No description provided for @clipSaved.
  ///
  /// In fr, this message translates to:
  /// **'Extrait enregistré dans l\'album {album}'**
  String clipSaved(String album);

  /// No description provided for @clipFailed.
  ///
  /// In fr, this message translates to:
  /// **'L\'extrait n\'a pas pu être téléchargé.'**
  String get clipFailed;

  /// No description provided for @timelineSeekAll.
  ///
  /// In fr, this message translates to:
  /// **'Toutes'**
  String get timelineSeekAll;

  /// No description provided for @timelineSeekAllHint.
  ///
  /// In fr, this message translates to:
  /// **'Passage préc. et suiv. sur toutes les caméras, sinon sur la caméra lue'**
  String get timelineSeekAllHint;

  /// No description provided for @timelineImagePlayback.
  ///
  /// In fr, this message translates to:
  /// **'Images'**
  String get timelineImagePlayback;

  /// No description provided for @timelineImagePlaybackTitle.
  ///
  /// In fr, this message translates to:
  /// **'Lecture en images'**
  String get timelineImagePlaybackTitle;

  /// No description provided for @timelineImagePlaybackBody.
  ///
  /// In fr, this message translates to:
  /// **'La vidéo de cette caméra ne passe pas sur ce téléphone, souvent parce que son image est trop grande pour le décodeur. Les images enregistrées sont montrées à la place, quelques-unes par seconde, jusqu\'à la fermeture de l\'application.'**
  String get timelineImagePlaybackBody;

  /// No description provided for @timelineImagePlaybackDetail.
  ///
  /// In fr, this message translates to:
  /// **'Détail : {error}'**
  String timelineImagePlaybackDetail(String error);

  /// No description provided for @timelineRetryVideo.
  ///
  /// In fr, this message translates to:
  /// **'Réessayer la vidéo'**
  String get timelineRetryVideo;

  /// No description provided for @alertsViewAlerts.
  ///
  /// In fr, this message translates to:
  /// **'Alertes'**
  String get alertsViewAlerts;

  /// No description provided for @alertsViewDetections.
  ///
  /// In fr, this message translates to:
  /// **'Détections'**
  String get alertsViewDetections;

  /// No description provided for @alertsViewMotion.
  ///
  /// In fr, this message translates to:
  /// **'Mouvement'**
  String get alertsViewMotion;

  /// No description provided for @reviewUnseen.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{1 non vue} other{{count} non vues}}'**
  String reviewUnseen(int count);

  /// No description provided for @reviewSince.
  ///
  /// In fr, this message translates to:
  /// **'Depuis {time}'**
  String reviewSince(String time);

  /// No description provided for @reviewSelected.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{1 sélectionnée} other{{count} sélectionnées}}'**
  String reviewSelected(int count);

  /// No description provided for @reviewMarkSeen.
  ///
  /// In fr, this message translates to:
  /// **'Marquer vu'**
  String get reviewMarkSeen;

  /// No description provided for @reviewMarkUnseen.
  ///
  /// In fr, this message translates to:
  /// **'Marquer non vu'**
  String get reviewMarkUnseen;

  /// No description provided for @reviewMarkAllSeen.
  ///
  /// In fr, this message translates to:
  /// **'Tout marquer vu'**
  String get reviewMarkAllSeen;

  /// No description provided for @reviewMarkFailed.
  ///
  /// In fr, this message translates to:
  /// **'Frigate n\'a pas enregistré la marque « vu ».'**
  String get reviewMarkFailed;

  /// No description provided for @reviewEmptyAlerts.
  ///
  /// In fr, this message translates to:
  /// **'Aucune alerte depuis {time}.'**
  String reviewEmptyAlerts(String time);

  /// No description provided for @reviewEmptyDetections.
  ///
  /// In fr, this message translates to:
  /// **'Aucune détection depuis {time}.'**
  String reviewEmptyDetections(String time);

  /// No description provided for @reviewLoadMore.
  ///
  /// In fr, this message translates to:
  /// **'Voir le jour précédent'**
  String get reviewLoadMore;

  /// No description provided for @reviewLoadFailed.
  ///
  /// In fr, this message translates to:
  /// **'Les alertes n\'ont pas pu être lues.'**
  String get reviewLoadFailed;

  /// No description provided for @reviewInProgress.
  ///
  /// In fr, this message translates to:
  /// **'en cours'**
  String get reviewInProgress;

  /// No description provided for @reviewUnknown.
  ///
  /// In fr, this message translates to:
  /// **'Événement'**
  String get reviewUnknown;

  /// No description provided for @reviewTitle.
  ///
  /// In fr, this message translates to:
  /// **'{what} · {camera}'**
  String reviewTitle(String what, String camera);

  /// No description provided for @objectPerson.
  ///
  /// In fr, this message translates to:
  /// **'Personne'**
  String get objectPerson;

  /// No description provided for @objectCar.
  ///
  /// In fr, this message translates to:
  /// **'Voiture'**
  String get objectCar;

  /// No description provided for @objectTruck.
  ///
  /// In fr, this message translates to:
  /// **'Camion'**
  String get objectTruck;

  /// No description provided for @objectBus.
  ///
  /// In fr, this message translates to:
  /// **'Bus'**
  String get objectBus;

  /// No description provided for @objectMotorcycle.
  ///
  /// In fr, this message translates to:
  /// **'Moto'**
  String get objectMotorcycle;

  /// No description provided for @objectBicycle.
  ///
  /// In fr, this message translates to:
  /// **'Vélo'**
  String get objectBicycle;

  /// No description provided for @objectBoat.
  ///
  /// In fr, this message translates to:
  /// **'Bateau'**
  String get objectBoat;

  /// No description provided for @objectDog.
  ///
  /// In fr, this message translates to:
  /// **'Chien'**
  String get objectDog;

  /// No description provided for @objectCat.
  ///
  /// In fr, this message translates to:
  /// **'Chat'**
  String get objectCat;

  /// No description provided for @objectBird.
  ///
  /// In fr, this message translates to:
  /// **'Oiseau'**
  String get objectBird;

  /// No description provided for @objectHorse.
  ///
  /// In fr, this message translates to:
  /// **'Cheval'**
  String get objectHorse;

  /// No description provided for @objectPackage.
  ///
  /// In fr, this message translates to:
  /// **'Colis'**
  String get objectPackage;

  /// No description provided for @objectFace.
  ///
  /// In fr, this message translates to:
  /// **'Visage'**
  String get objectFace;

  /// No description provided for @objectLicensePlate.
  ///
  /// In fr, this message translates to:
  /// **'Plaque'**
  String get objectLicensePlate;

  /// No description provided for @objectBark.
  ///
  /// In fr, this message translates to:
  /// **'Aboiement'**
  String get objectBark;

  /// No description provided for @objectSpeech.
  ///
  /// In fr, this message translates to:
  /// **'Parole'**
  String get objectSpeech;

  /// No description provided for @objectScream.
  ///
  /// In fr, this message translates to:
  /// **'Cri'**
  String get objectScream;

  /// No description provided for @objectFireAlarm.
  ///
  /// In fr, this message translates to:
  /// **'Alarme incendie'**
  String get objectFireAlarm;

  /// No description provided for @timelineLive.
  ///
  /// In fr, this message translates to:
  /// **'Direct'**
  String get timelineLive;

  /// No description provided for @timelineGoLive.
  ///
  /// In fr, this message translates to:
  /// **'Revenir au direct'**
  String get timelineGoLive;

  /// No description provided for @timelineLiveBadge.
  ///
  /// In fr, this message translates to:
  /// **'DIRECT'**
  String get timelineLiveBadge;

  /// No description provided for @timelineSpeed.
  ///
  /// In fr, this message translates to:
  /// **'Vitesse de lecture'**
  String get timelineSpeed;
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
