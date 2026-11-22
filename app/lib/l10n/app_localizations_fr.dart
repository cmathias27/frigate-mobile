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
}
