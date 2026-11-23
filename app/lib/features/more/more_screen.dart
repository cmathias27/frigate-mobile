import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/session/session_controller.dart';
import '../../l10n/app_localizations.dart';
import '../login/session_error_text.dart';

/// Screen for server details, settings, and disconnection (the "Plus" tab).
class MoreScreen extends StatelessWidget {
  final SessionController controller;

  /// Version installed, when known.
  final String? appVersion;

  /// Update settings, built by the app shell (features stay independent).
  final Widget? updates;

  /// Entry of the settings screen, built by the app shell.
  final Widget? settings;

  const MoreScreen({
    super.key,
    required this.controller,
    this.appVersion,
    this.updates,
    this.settings,
  });

  Future<void> _confirmDisconnect(BuildContext context) async {
    final l = AppLocalizations.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.disconnectConfirmTitle),
        content: Text(l.disconnectConfirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(l.confirm),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await controller.disconnect();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final config = controller.config;
        final caps = controller.capabilities;
        final client = controller.client;

        final cameraCount = caps?.cameras.length ?? 0;
        final continuousDays = caps?.cameras.values.isNotEmpty == true
            ? caps!.cameras.values.first.continuousDays
            : 0.0;

        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            if (config != null) ...[
              Card(
                color: AppColors.surface,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: AppColors.surfaceHigh,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.videocam_rounded,
                              color: AppColors.accent,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  config.name,
                                  style: text.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  client?.activeBaseUrl ?? config.localUrl,
                                  style: text.bodySmall?.copyWith(
                                    color: AppColors.textDim,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (caps != null && caps.version.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceHigh,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'v${caps.version}',
                                style: text.labelSmall?.copyWith(
                                  color: AppColors.textDim,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const Divider(height: 24),
                      _InfoRow(
                        icon: Icons.camera_alt_outlined,
                        label: l.serverInfoCameras(cameraCount),
                      ),
                      const SizedBox(height: 8),
                      _InfoRow(
                        icon: Icons.analytics_outlined,
                        label: caps?.anyObjectDetection == true
                            ? l.detectionModeObjects
                            : l.detectionModeMotionOnly,
                      ),
                      if (continuousDays > 0) ...[
                        const SizedBox(height: 8),
                        _InfoRow(
                          icon: Icons.history_rounded,
                          label: l.continuousDays(
                            continuousDays.toStringAsFixed(0),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.refresh_rounded),
                title: Text(l.refresh),
                tileColor: AppColors.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                onTap: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  final ok = await controller.refreshCapabilities();
                  final error = controller.error ?? SessionError.unexpected;
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        ok
                            ? l.refreshSuccess
                            : l.refreshFailed(sessionErrorText(l, error)),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: Icon(
                  Icons.logout_rounded,
                  color: Theme.of(context).colorScheme.error,
                ),
                title: Text(
                  l.disconnectButton,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
                tileColor: AppColors.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                onTap: () => _confirmDisconnect(context),
              ),
            ],
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                'FRIGATE MOBILE',
                style: text.labelSmall?.copyWith(
                  color: AppColors.textDim,
                  letterSpacing: 1.1,
                ),
              ),
            ),
            const SizedBox(height: 8),
            if (settings case final settings?) ...[
              settings,
              const SizedBox(height: 8),
            ],
            if (updates case final updates?) ...[
              updates,
              const SizedBox(height: 8),
            ],
            ListTile(
              leading: const Icon(Icons.info_outline_rounded),
              title: Text(l.aboutVersion(appVersion ?? '—')),
              subtitle: Text(l.moreDescription),
              tileColor: AppColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.textDim),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}
