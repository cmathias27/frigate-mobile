import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:video_player_media_kit/video_player_media_kit.dart';

import 'app/home_shell.dart';
import 'app/theme.dart';
import 'core/session/session_controller.dart';
import 'core/storage/preferences.dart';
import 'features/login/login_screen.dart';
import 'features/update/update_controller.dart';
import 'features/update/update_service.dart';
import 'l10n/app_localizations.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Recordings on Windows: video_player has no Windows player of its own,
  // media_kit (libmpv) plays Frigate's HLS there (decision 0005).
  VideoPlayerMediaKit.ensureInitialized(windows: true);
  final session = SessionController()..init();
  // Back from the background, possibly on another network.
  AppLifecycleListener(onResume: session.resumed);
  final update = UpdateController(
    service: UpdateService(),
    platform: Platform.isWindows
        ? WindowsUpdatePlatform()
        : AndroidUpdatePlatform(),
    preferences: Preferences(),
  )..init();
  runApp(FrigateMobileApp(session: session, update: update));
}

class FrigateMobileApp extends StatelessWidget {
  final SessionController session;
  final UpdateController? update;

  /// Storage of the app settings; the device's secure storage by default.
  final Preferences? preferences;

  const FrigateMobileApp({
    super.key,
    required this.session,
    this.update,
    this.preferences,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      theme: buildDarkTheme(),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: ListenableBuilder(
        listenable: session,
        builder: (context, _) {
          switch (session.status) {
            case SessionStatus.initializing:
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            case SessionStatus.authenticated:
              return HomeShell(
                controller: session,
                update: update,
                preferences: preferences,
              );
            case SessionStatus.unauthenticated:
            case SessionStatus.loading:
            case SessionStatus.connectionError:
              return LoginScreen(controller: session);
          }
        },
      ),
    );
  }
}
