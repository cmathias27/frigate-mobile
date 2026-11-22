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

  @override
  String get loginTitle => 'Ajouter un serveur';

  @override
  String get loginSubtitle =>
      'Comme dans DS cam : un serveur, plusieurs caméras.';

  @override
  String get serverNameLabel => 'Nom du serveur';

  @override
  String get localUrlLabel => 'Adresse locale (port 8971)';

  @override
  String get localUrlHint => 'https://192.168.1.10:8971';

  @override
  String get remoteUrlLabel => 'Adresse à distance (optionnelle)';

  @override
  String get remoteUrlHint => 'https://frigate.exemple.fr';

  @override
  String get usernameLabel => 'Utilisateur';

  @override
  String get passwordLabel => 'Mot de passe';

  @override
  String get selfSignedLabel =>
      'Certificat auto-signé accepté sur le réseau local';

  @override
  String get connectButton => 'Se connecter';

  @override
  String get connectingStatus => 'Connexion en cours…';

  @override
  String get connectedTitle => 'Serveur connecté';

  @override
  String serverInfoCameras(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count caméras en ligne',
      one: '1 caméra en ligne',
    );
    return '$_temp0';
  }

  @override
  String get detectionModeMotionOnly =>
      'Mode mouvement seul (sans détection d\'objets)';

  @override
  String get detectionModeObjects => 'Détection d\'objets active';

  @override
  String continuousDays(String days) {
    return 'Rétention continu : $days jours';
  }

  @override
  String get disconnectButton => 'Se déconnecter';

  @override
  String get disconnectConfirmTitle => 'Déconnexion';

  @override
  String get disconnectConfirmMessage =>
      'Voulez-vous vous déconnecter de ce serveur Frigate ?';

  @override
  String get cancel => 'Annuler';

  @override
  String get confirm => 'Confirmer';

  @override
  String get refresh => 'Actualiser';

  @override
  String get refreshSuccess => 'Capacités actualisées';

  @override
  String get requiredField => 'Ce champ est obligatoire';

  @override
  String get invalidUrl => 'Adresse invalide (commencez par https://)';

  @override
  String get liveBadge => 'LIVE';

  @override
  String get liveStale => 'FIGÉ';

  @override
  String get liveUnavailable => 'Image indisponible';

  @override
  String get liveNoCamera => 'Aucune caméra active sur ce serveur.';

  @override
  String liveLayout(int count) {
    return '$count par page';
  }

  @override
  String get liveLayoutAuto =>
      'Disposition automatique : toutes les caméras, le plus grand possible';

  @override
  String livePage(int current, int total) {
    return 'Page $current sur $total';
  }

  @override
  String liveModeSnapshots(int seconds) {
    return 'Images · toutes les $seconds s';
  }

  @override
  String get liveFullScreen => 'Plein écran';

  @override
  String get liveModeVideo => 'Vidéo en direct';

  @override
  String get liveVideoConnecting => 'Connexion vidéo…';

  @override
  String get liveVideoUnavailable => 'Vidéo indisponible';

  @override
  String get liveVideoRetry => 'Réessayer la vidéo';

  @override
  String get liveSoundOn => 'Activer le son';

  @override
  String get liveSoundOff => 'Couper le son';

  @override
  String get liveQuality => 'Qualité';

  @override
  String liveStream(int number) {
    return 'Flux $number';
  }

  @override
  String liveStreamMain(int number) {
    return 'Flux $number (principal)';
  }

  @override
  String get livePhoto => 'Photo';

  @override
  String livePhotoSaved(String album) {
    return 'Photo enregistrée dans l\'album $album';
  }

  @override
  String get livePhotoShare => 'Partager';

  @override
  String get livePhotoFailed => 'Impossible d\'enregistrer la photo';

  @override
  String get liveSound => 'Son';

  @override
  String timelinePlaying(String camera) {
    return 'Lecture · $camera';
  }

  @override
  String get timelineCamera => 'Caméra en lecture';

  @override
  String get timelineAllCameras => 'Toutes les caméras';

  @override
  String timelineZoomHours(int hours) {
    return '$hours h';
  }

  @override
  String get timelineZoomAll => 'Tout';

  @override
  String get timelinePreviousPassage => 'Passage préc.';

  @override
  String get timelineNextPassage => 'Passage suiv.';

  @override
  String timelineBack(int seconds) {
    return 'Reculer de $seconds s';
  }

  @override
  String timelineForward(int seconds) {
    return 'Avancer de $seconds s';
  }

  @override
  String timelineSeconds(int seconds) {
    return '$seconds s';
  }

  @override
  String get timelinePlay => 'Lecture';

  @override
  String get timelinePause => 'Pause';

  @override
  String get timelinePreviousDay => 'Jour précédent';

  @override
  String get timelineNextDay => 'Jour suivant';

  @override
  String timelineNoPassage(int hours) {
    return 'Aucun passage de mouvement dans les $hours h';
  }

  @override
  String get timelineNoRecording => 'Pas d\'enregistrement à ce moment';

  @override
  String get timelinePlaybackFailed => 'Lecture impossible';

  @override
  String get timelineRetry => 'Réessayer';

  @override
  String get timelineEnd => 'Fin des enregistrements';

  @override
  String get timelineLoading => 'Chargement de la chronologie…';

  @override
  String get timelineNoRecordingCamera =>
      'Aucune caméra n\'enregistre sur ce serveur';

  @override
  String get timelineCalendar => 'Calendrier';

  @override
  String get calendarPreviousMonth => 'Mois précédent';

  @override
  String get calendarNextMonth => 'Mois suivant';

  @override
  String get calendarFull => 'Enregistrement complet';

  @override
  String get calendarPartial => 'Enregistrement partiel (alertes, mouvement)';

  @override
  String get calendarGoTo => 'Aller à une date et une heure';

  @override
  String get calendarGo => 'Aller';

  @override
  String get calendarHourAgo => 'Il y a 1 h';

  @override
  String get calendarThisMorning => 'Ce matin';

  @override
  String get calendarLastEvening => 'Hier soir';

  @override
  String get calendarOldest => 'Le plus ancien';

  @override
  String calendarOldestAt(String date) {
    return 'Plus ancien enregistrement : $date';
  }

  @override
  String get calendarLoadFailed =>
      'Impossible de lire l\'historique des enregistrements';

  @override
  String get ok => 'OK';

  @override
  String updateAvailableTitle(String version) {
    return 'Version $version disponible';
  }

  @override
  String updateInstalledVersion(String version) {
    return 'Version installée : $version';
  }

  @override
  String get updateNoNotes => 'Pas de note pour cette version.';

  @override
  String get updateInstall => 'Installer';

  @override
  String get updateLater => 'Plus tard';

  @override
  String get updateDownloading => 'Téléchargement et vérification…';

  @override
  String get updatePermissionTitle => 'Autoriser l\'installation';

  @override
  String get updatePermissionMessage =>
      'Android demande d\'autoriser Frigate Mobile à installer ses propres mises à jour. Active « Autoriser cette source » dans les réglages qui vont s\'ouvrir, puis reviens appuyer sur Installer.';

  @override
  String get updatePermissionOpen => 'Ouvrir les réglages';

  @override
  String get updateErrorNetwork =>
      'Impossible de joindre GitHub. Réessaie plus tard.';

  @override
  String get updateErrorChecksum =>
      'Le fichier téléchargé ne correspond pas à son empreinte : installation annulée.';

  @override
  String get updateErrorTooLarge =>
      'Le fichier de mise à jour est anormalement gros : téléchargement arrêté.';

  @override
  String get updateErrorFolder =>
      'Impossible d\'enregistrer la mise à jour sur le téléphone.';

  @override
  String get updateErrorUnsupported =>
      'Cette version ne propose pas d\'APK à installer.';

  @override
  String get updateErrorPackage =>
      'Le fichier téléchargé n\'est pas la version attendue de Frigate Mobile.';

  @override
  String get updateErrorSignature =>
      'Cette version est signée par une autre clé : désinstalle l\'application pour l\'installer.';

  @override
  String get updateErrorInstall =>
      'L\'installateur d\'Android n\'a pas pu s\'ouvrir.';

  @override
  String get updateAutoCheck => 'Vérifier les mises à jour';

  @override
  String get updateAutoCheckHint =>
      'Une fois par jour au démarrage, auprès de GitHub';

  @override
  String get updateCheckNow => 'Rechercher une mise à jour';

  @override
  String get updateChecking => 'Recherche en cours…';

  @override
  String get updateUpToDate => 'L\'application est à jour';

  @override
  String get updateCheckHint => 'Dernière version publiée sur GitHub';

  @override
  String get releaseNotesTitle => 'Notes de version';

  @override
  String whatsNewTitle(String version) {
    return 'Nouveautés de la version $version';
  }

  @override
  String get eventsAllCameras => 'Toutes caméras';

  @override
  String eventsNewCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count nouveaux passages',
      one: '1 nouveau passage',
    );
    return '$_temp0';
  }

  @override
  String eventsSince(String time) {
    return 'Passages de mouvement depuis $time';
  }

  @override
  String eventsEmpty(String time) {
    return 'Aucun passage de mouvement depuis $time.';
  }

  @override
  String get eventsNew => 'Nouveau';

  @override
  String get eventsToday => 'Aujourd\'hui';

  @override
  String get eventsYesterday => 'Hier';

  @override
  String eventsPassageTitle(String camera) {
    return 'Mouvement · $camera';
  }

  @override
  String eventsLoadMore(int hours) {
    return 'Voir les $hours heures précédentes';
  }

  @override
  String get eventsLoadFailed => 'Les enregistrements n\'ont pas pu être lus.';

  @override
  String get eventsHistoryStart => 'Début de l\'historique enregistré.';

  @override
  String durationSeconds(int seconds) {
    return '$seconds s';
  }

  @override
  String durationMinutes(int minutes, String seconds) {
    return '$minutes min $seconds';
  }

  @override
  String durationHours(int hours, String minutes) {
    return '$hours h $minutes';
  }

  @override
  String get timelineClip => 'Extrait';

  @override
  String get timelinePhoto => 'Photo';

  @override
  String clipTitle(String camera) {
    return 'Extrait · $camera';
  }

  @override
  String get clipStart => 'Début';

  @override
  String get clipEnd => 'Fin';

  @override
  String clipEarlier(int seconds) {
    return '$seconds s plus tôt';
  }

  @override
  String clipLater(int seconds) {
    return '$seconds s plus tard';
  }

  @override
  String clipLength(String length) {
    return 'Durée : $length';
  }

  @override
  String clipLengthMax(String length) {
    return 'Durée : $length, le maximum';
  }

  @override
  String get clipPassage => 'Passage';

  @override
  String get clipSave => 'Enregistrer';

  @override
  String get clipShare => 'Partager';

  @override
  String clipDownloading(String size) {
    return 'Téléchargement… $size Mo';
  }

  @override
  String get clipCancel => 'Annuler';

  @override
  String clipSaved(String album) {
    return 'Extrait enregistré dans l\'album $album';
  }

  @override
  String get clipFailed => 'L\'extrait n\'a pas pu être téléchargé.';

  @override
  String get timelineSeekAll => 'Toutes';

  @override
  String get timelineSeekAllHint =>
      'Passage préc. et suiv. sur toutes les caméras, sinon sur la caméra lue';

  @override
  String get timelineImagePlayback => 'Images';

  @override
  String get timelineImagePlaybackTitle => 'Lecture en images';

  @override
  String get timelineImagePlaybackBody =>
      'La vidéo de cette caméra ne passe pas sur ce téléphone, souvent parce que son image est trop grande pour le décodeur. Les images enregistrées sont montrées à la place, quelques-unes par seconde, jusqu\'à la fermeture de l\'application.';

  @override
  String timelineImagePlaybackDetail(String error) {
    return 'Détail : $error';
  }

  @override
  String get timelineRetryVideo => 'Réessayer la vidéo';
}
