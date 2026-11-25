import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme.dart';
import '../../l10n/app_localizations.dart';
import 'release.dart';
import 'update_controller.dart';

/// The notes of every version, bundled with the app (CHANGELOG.md).
const changelogAsset = 'assets/CHANGELOG.md';

Future<List<ReleaseNotes>> loadChangelog([AssetBundle? bundle]) async {
  try {
    return parseChangelog(
      await (bundle ?? rootBundle).loadString(changelogAsset),
    );
  } on Exception {
    return const [];
  } on FlutterError {
    return const [];
  }
}

String updateErrorText(AppLocalizations l, String? code) => switch (code) {
  'checksum' => l.updateErrorChecksum,
  'too_large' => l.updateErrorTooLarge,
  'folder' => l.updateErrorFolder,
  'unsupported' => l.updateErrorUnsupported,
  'package' || 'version' => l.updateErrorPackage,
  'signature' => l.updateErrorSignature,
  'install' => l.updateErrorInstall,
  _ => l.updateErrorNetwork,
};

/// Release notes written in CHANGELOG.md's simple Markdown: paragraphs,
/// `- ` lists and `### ` titles.
class ReleaseNotesText extends StatelessWidget {
  final String notes;

  const ReleaseNotesText(this.notes, {super.key});

  static String _plain(String text) =>
      text.replaceAll('**', '').replaceAll('`', '').trim();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final children = <Widget>[];
    for (final raw in notes.split('\n')) {
      final line = raw.trimRight();
      if (line.trim().isEmpty) {
        if (children.isNotEmpty) children.add(const SizedBox(height: 8));
      } else if (line.startsWith('#')) {
        children.add(
          Text(
            _plain(line.replaceFirst(RegExp(r'^#+'), '')),
            style: text.titleSmall,
          ),
        );
      } else if (RegExp(r'^\s*[-*] ').hasMatch(line)) {
        children.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('•  '),
                Expanded(
                  child: Text(
                    _plain(line.replaceFirst(RegExp(r'^\s*[-*] '), '')),
                  ),
                ),
              ],
            ),
          ),
        );
      } else {
        children.add(Text(_plain(line)));
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }
}

/// Sheet of a newer version: its number and notes, "Install" or "Later".
Future<void> showUpdateSheet(BuildContext context, UpdateController update) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: AppColors.surface,
    builder: (context) => _UpdateSheet(update: update),
  );
}

class _UpdateSheet extends StatelessWidget {
  final UpdateController update;

  const _UpdateSheet({required this.update});

  Future<void> _install(BuildContext context) async {
    final l = AppLocalizations.of(context);
    if (await update.install()) return;
    if (!context.mounted) return;
    final open = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.updatePermissionTitle),
        content: Text(l.updatePermissionMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l.updatePermissionOpen),
          ),
        ],
      ),
    );
    if (open == true) await update.openInstallSettings();
  }

  /// Windows: the browser downloads the archive, the sheet closes.
  Future<void> _download(BuildContext context) async {
    await update.openDownload();
    if (context.mounted && update.status != UpdateStatus.failed) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    return ListenableBuilder(
      listenable: update,
      builder: (context, _) {
        final release = update.release;
        if (release == null) return const SizedBox.shrink();
        final downloading = update.status == UpdateStatus.downloading;
        final inApp = update.installsInApp;
        final ready = inApp ? release.installable : release.windowsZip != null;
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.8,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l.updateAvailableTitle(release.version),
                    style: text.titleLarge,
                  ),
                  if (update.currentVersion case final current?)
                    Text(
                      l.updateInstalledVersion(current),
                      style: text.bodySmall?.copyWith(
                        color: AppColors.textDim,
                      ),
                    ),
                  const SizedBox(height: 12),
                  Flexible(
                    child: SingleChildScrollView(
                      child: ReleaseNotesText(
                        release.notes.isEmpty ? l.updateNoNotes : release.notes,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (downloading) ...[
                    LinearProgressIndicator(value: update.progress),
                    const SizedBox(height: 4),
                    Text(l.updateDownloading, style: text.bodySmall),
                  ],
                  if (update.status == UpdateStatus.failed)
                    Text(
                      updateErrorText(l, update.error),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  if (!ready)
                    Text(l.updateErrorUnsupported, style: text.bodySmall)
                  else if (!inApp)
                    Text(l.updateWindowsHint, style: text.bodySmall),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(l.updateLater),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: downloading || !ready
                            ? null
                            : inApp
                            ? () => _install(context)
                            : () => _download(context),
                        child: Text(
                          inApp ? l.updateInstall : l.updateDownload,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// "What's new" once after an update: the notes of the version installed.
Future<void> showWhatsNew(
  BuildContext context, {
  required String version,
  required String notes,
}) {
  final l = AppLocalizations.of(context);
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l.whatsNewTitle(version)),
      content: SingleChildScrollView(child: ReleaseNotesText(notes)),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.ok),
        ),
      ],
    ),
  );
}

/// Shows "What's new" after an update, then the automatic check.
Future<void> runStartupUpdate(
  BuildContext context,
  UpdateController update, {
  AssetBundle? bundle,
}) async {
  if (await update.takeWhatsNew()) {
    final version = update.currentVersion!;
    final notes = (await loadChangelog(bundle))
        .where((s) => s.version == version)
        .firstOrNull;
    if (notes != null && notes.notes.isNotEmpty && context.mounted) {
      await showWhatsNew(context, version: version, notes: notes.notes);
    }
  }
  final release = await update.checkOnStartup();
  if (release != null && context.mounted) {
    await showUpdateSheet(context, update);
  }
}

/// Update settings of the "More" tab.
class UpdateSettings extends StatelessWidget {
  final UpdateController update;

  const UpdateSettings({super.key, required this.update});

  Future<void> _checkNow(BuildContext context) async {
    await update.check();
    if (update.status == UpdateStatus.available && context.mounted) {
      await showUpdateSheet(context, update);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: update,
      builder: (context, _) {
        final status = switch (update.status) {
          UpdateStatus.checking => l.updateChecking,
          UpdateStatus.upToDate => l.updateUpToDate,
          UpdateStatus.available ||
          UpdateStatus.downloading => l.updateAvailableTitle(
            update.release!.version,
          ),
          UpdateStatus.failed => updateErrorText(l, update.error),
          UpdateStatus.idle => l.updateCheckHint,
        };
        final shape = RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        );
        return Column(
          children: [
            SwitchListTile(
              secondary: const Icon(Icons.update_rounded),
              title: Text(l.updateAutoCheck),
              subtitle: Text(l.updateAutoCheckHint),
              value: update.autoCheck,
              onChanged: update.setAutoCheck,
              tileColor: AppColors.surface,
              shape: shape,
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.system_update_rounded),
              title: Text(l.updateCheckNow),
              subtitle: Text(status),
              trailing: update.status == UpdateStatus.checking
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : null,
              onTap: update.status == UpdateStatus.checking
                  ? null
                  : () => _checkNow(context),
              tileColor: AppColors.surface,
              shape: shape,
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.article_outlined),
              title: Text(l.releaseNotesTitle),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const ReleaseHistoryScreen(),
                ),
              ),
              tileColor: AppColors.surface,
              shape: shape,
            ),
          ],
        );
      },
    );
  }
}

/// Notes of every version, from the bundled CHANGELOG.md.
class ReleaseHistoryScreen extends StatelessWidget {
  final AssetBundle? bundle;

  const ReleaseHistoryScreen({super.key, this.bundle});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(l.releaseNotesTitle)),
      body: FutureBuilder<List<ReleaseNotes>>(
        future: loadChangelog(bundle),
        builder: (context, snapshot) {
          final sections = snapshot.data;
          if (sections == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final section in sections) ...[
                Text(l.aboutVersion(section.version), style: text.titleMedium),
                const SizedBox(height: 6),
                ReleaseNotesText(section.notes),
                const SizedBox(height: 20),
              ],
            ],
          );
        },
      ),
    );
  }
}
