import 'package:flutter/material.dart';

import '../core/session/session_controller.dart';
import '../features/live/live_grid_screen.dart';
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
  int _liveLayout = 4;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final serverName = widget.controller.config?.name ?? l.appTitle;
    final cameras =
        widget.controller.capabilities?.cameras.values.toList() ?? const [];
    final cameraCount = cameras.length;
    final client = widget.controller.client;

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
        actions: [
          if (_index == 0)
            for (final layout in liveLayouts)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: _LayoutButton(
                  layout: layout,
                  selected: layout == _liveLayout,
                  onPressed: () => setState(() => _liveLayout = layout),
                ),
              ),
          const SizedBox(width: 8),
        ],
      ),
      body: switch (_index) {
        0 when client != null => LiveGridScreen(
          cameras: cameras,
          fetch: client.fetchLatestImage,
          layout: _liveLayout,
          onAuthError: widget.controller.sessionExpired,
        ),
        3 => MoreScreen(controller: widget.controller),
        _ => _Placeholder(
          icon: icon,
          description: description,
          version: '0.1',
        ),
      },
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

/// "1", "4" or "9" button of the live grid layouts (mock-up screen 2).
class _LayoutButton extends StatelessWidget {
  final int layout;
  final bool selected;
  final VoidCallback onPressed;

  const _LayoutButton({
    required this.layout,
    required this.selected,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: AppLocalizations.of(context).liveLayout(layout),
      child: Semantics(
        selected: selected,
        button: true,
        child: Material(
          color: selected ? AppColors.accent : AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: onPressed,
            child: SizedBox.square(
              dimension: 32,
              child: Center(
                child: Text(
                  '$layout',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: selected ? AppColors.background : null,
                  ),
                ),
              ),
            ),
          ),
        ),
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
