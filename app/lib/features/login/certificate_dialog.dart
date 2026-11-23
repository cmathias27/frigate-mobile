import 'package:flutter/material.dart';

import '../../core/frigate/client.dart';
import '../../core/frigate/server_config.dart';
import '../../l10n/app_localizations.dart';

/// Asks the user to confirm the self-signed certificate of the local
/// address (decision 0004, point 4); true when trusted.
Future<bool> showCertificateDialog(
  BuildContext context,
  FrigateCertificateException certificate,
) async {
  final l = AppLocalizations.of(context);
  final trusted = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l.certificateTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              certificate.changed ? l.certificateChanged : l.certificateNew,
            ),
            const SizedBox(height: 12),
            SelectableText(
              certificate.fingerprint,
              key: const Key('certificateFingerprint'),
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
            ),
            const SizedBox(height: 12),
            Text(
              l.certificateHint,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l.certificateTrust),
        ),
      ],
    ),
  );
  return trusted ?? false;
}

/// Validator of a server address field: https only, never port 5000
/// (decision 0004).
String? addressError(
  AppLocalizations l,
  String? value, {
  required bool required,
}) {
  if (value == null || value.trim().isEmpty) {
    return required ? l.requiredField : null;
  }
  return switch (ServerConfig.addressProblem(value)) {
    null => null,
    AddressProblem.invalid => l.invalidUrl,
    AddressProblem.notHttps => l.addressNotHttps,
    AddressProblem.unauthenticated => l.addressUnauthenticatedPort,
  };
}
