import '../../core/session/session_controller.dart';
import '../../l10n/app_localizations.dart';

/// What [error] means for the user.
String sessionErrorText(AppLocalizations l, SessionError error) =>
    switch (error) {
      SessionError.badCredentials => l.sessionErrorBadCredentials,
      SessionError.tooManyAttempts => l.sessionErrorTooManyAttempts,
      SessionError.serverError => l.sessionErrorServer,
      SessionError.unreachable => l.sessionErrorUnreachable,
      SessionError.timeout => l.sessionErrorTimeout,
      SessionError.certificate => l.sessionErrorCertificate,
      SessionError.certificateToConfirm => l.sessionErrorCertificateToConfirm,
      SessionError.invalidResponse => l.sessionErrorInvalidResponse,
      SessionError.sessionExpired => l.sessionErrorExpired,
      SessionError.unexpected => l.sessionErrorUnexpected,
    };
