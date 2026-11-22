import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app/home_shell.dart';
import 'app/theme.dart';
import 'core/session/session_controller.dart';
import 'features/login/login_screen.dart';
import 'l10n/app_localizations.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final session = SessionController()..init();
  runApp(FrigateMobileApp(session: session));
}

class FrigateMobileApp extends StatelessWidget {
  final SessionController session;

  const FrigateMobileApp({super.key, required this.session});

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
              return HomeShell(controller: session);
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
