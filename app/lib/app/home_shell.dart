import 'package:flutter/material.dart';

import '../core/session/session_controller.dart';
import '../features/more/more_screen.dart';
import '../l10n/app_localizations.dart';
import 'theme.dart';

/// The four tabs of the mock-ups.
class HomeShell extends StatefulWidget {
  final SessionController controller;

  const HomeShell({super.key, required this.controller});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final serverName = widget.controller.config?.name ?? l.appTitle;
    final cameraCount = widget.controller.capabilities?.cameras.length ?? 0;

    final tabs = [
      (l.tabLive, Icons.grid_view_rounded, l.liveDescription),
      (l.tabTimeline, Icons.timeline_rounded, l.timelineDescription),
      (l.tabEvents, Icons.notifications_none_rounded, l.eventsDescription),
      (l.tabMore, Icons.menu_rounded, l.moreDescription),
    ];
    final (title, icon, description) = tabs[_index];

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _index == 3 ? title : serverName,
              style: text.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            if (_index != 3 && cameraCount > 0)
              Text(
                l.serverInfoCameras(cameraCount),
                style: text.bodySmall?.copyWith(color: AppColors.textDim),
              ),
          ],
        ),
      ),
      body: _index == 3
          ? MoreScreen(controller: widget.controller)
          : _Placeholder(
              icon: icon,
              description: description,
              version: '0.1',
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          for (final (label, icon, _) in tabs)
            NavigationDestination(icon: Icon(icon), label: label),
        ],
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  final IconData icon;
  final String description;
  final String version;

  const _Placeholder({
    required this.icon,
    required this.description,
    required this.version,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 12,
          children: [
            Icon(icon, size: 48, color: AppColors.textDim),
            Text(
              description,
              textAlign: TextAlign.center,
              style: text.bodyLarge,
            ),
            Text(
              l.comingInVersion(version),
              style: text.bodySmall?.copyWith(color: AppColors.textDim),
            ),
          ],
        ),
      ),
    );
  }
}
