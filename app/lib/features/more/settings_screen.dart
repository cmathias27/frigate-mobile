import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_settings.dart';
import '../../app/theme.dart';
import '../../core/frigate/capabilities.dart';
import '../../l10n/app_localizations.dart';

/// Automatic motion threshold of a camera from the recordings fetched so
/// far, `null` when none were.
typedef AutoThreshold = int? Function(String camera);

/// The settings of the app: cameras, live, timeline (decision 0002: every
/// value has a default, nothing here is required).
class SettingsScreen extends StatelessWidget {
  final AppSettings settings;

  /// Cameras of the server, in its order.
  final List<CameraCapabilities> cameras;
  final AutoThreshold? autoThreshold;

  const SettingsScreen({
    super.key,
    required this.settings,
    required this.cameras,
    this.autoThreshold,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.settingsTitle)),
      body: ListenableBuilder(
        listenable: settings,
        builder: (context, _) {
          final shown = cameras.where((c) => !settings.hidden(c.name)).length;
          final recorded = cameras.any((c) => c.recording);
          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              if (cameras.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.videocam_outlined),
                  title: Text(l.settingsCameras),
                  subtitle: Text(
                    l.settingsCamerasSummary(shown, cameras.length),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => CameraSettingsScreen(
                        settings: settings,
                        cameras: cameras,
                        autoThreshold: autoThreshold,
                      ),
                    ),
                  ),
                ),
              _Header(l.settingsLive),
              _Choice<LiveQuality>(
                title: l.settingsQuality,
                help: switch (settings.quality) {
                  LiveQuality.auto => l.settingsQualityAutoHelp,
                  LiveQuality.high => l.settingsQualityHighHelp,
                  LiveQuality.light => l.settingsQualityLightHelp,
                },
                value: settings.quality,
                values: LiveQuality.values,
                label: (q) => switch (q) {
                  LiveQuality.auto => l.settingsQualityAuto,
                  LiveQuality.high => l.settingsQualityHigh,
                  LiveQuality.light => l.settingsQualityLight,
                },
                onChanged: (q) => settings.quality = q,
              ),
              SwitchListTile(
                title: Text(l.settingsOtherStreams),
                subtitle: Text(l.settingsOtherStreamsHelp),
                value: settings.tryOtherStreams,
                onChanged: (v) => settings.tryOtherStreams = v,
              ),
              _Choice<TileSize>(
                title: l.settingsTileSize,
                help: l.settingsTileSizeHelp,
                value: settings.tileSize,
                values: TileSize.values,
                label: (s) => switch (s) {
                  TileSize.small => l.settingsTileSmall,
                  TileSize.medium => l.settingsTileMedium,
                  TileSize.large => l.settingsTileLarge,
                },
                onChanged: (s) => settings.tileSize = s,
              ),
              if (recorded) ...[
                _Header(l.settingsTimeline),
                SwitchListTile(
                  title: Text(l.settingsImageFallback),
                  subtitle: Text(l.settingsImageFallbackHelp),
                  value: settings.imageFallback,
                  onChanged: (v) => settings.imageFallback = v,
                ),
                _Choice<Duration>(
                  title: l.settingsMinPassage,
                  value: settings.minPassage,
                  values: _with(
                    SettingsDefaults.minPassages,
                    settings.minPassage,
                  ),
                  label: (d) => d == Duration.zero
                      ? l.settingsNoMinimum
                      : _duration(l, d),
                  onChanged: (d) => settings.minPassage = d,
                ),
                _Choice<Duration>(
                  title: l.settingsMergeGap,
                  help: l.settingsMergeGapHelp,
                  value: settings.mergeGap,
                  values: _with(SettingsDefaults.mergeGaps, settings.mergeGap),
                  label: (d) => _duration(l, d),
                  onChanged: (d) => settings.mergeGap = d,
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  /// [values] with [current] among them, so a stored value always shows.
  static List<Duration> _with(List<Duration> values, Duration current) =>
      values.contains(current) ? values : ([...values, current]..sort());

  static String _duration(AppLocalizations l, Duration d) =>
      d.inSeconds % 60 == 0 && d.inSeconds > 0
      ? l.settingsMinutes(d.inMinutes)
      : l.settingsSeconds(d.inSeconds);
}

/// Order, visibility and motion threshold of each camera.
class CameraSettingsScreen extends StatelessWidget {
  final AppSettings settings;
  final List<CameraCapabilities> cameras;
  final AutoThreshold? autoThreshold;

  const CameraSettingsScreen({
    super.key,
    required this.settings,
    required this.cameras,
    this.autoThreshold,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(l.settingsCameras)),
      body: ListenableBuilder(
        listenable: settings,
        builder: (context, _) {
          final ordered = settings.arrange(cameras, withHidden: true);
          final shown = ordered.where((c) => !settings.hidden(c.name)).length;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text(
                  l.settingsCamerasHelp,
                  style: text.bodySmall?.copyWith(color: AppColors.textDim),
                ),
              ),
              Expanded(
                child: ReorderableListView.builder(
                  buildDefaultDragHandles: false,
                  itemCount: ordered.length,
                  onReorderItem: (from, to) {
                    final names = [for (final c in ordered) c.name];
                    final moved = names.removeAt(from);
                    names.insert(to, moved);
                    settings.reorder(names);
                  },
                  itemBuilder: (context, i) {
                    final camera = ordered[i];
                    final hidden = settings.hidden(camera.name);
                    return ListTile(
                      key: ValueKey(camera.name),
                      leading: ReorderableDragStartListener(
                        index: i,
                        child: const Icon(Icons.drag_handle_rounded),
                      ),
                      title: Text(camera.label),
                      subtitle: camera.recording
                          ? Text(_thresholdText(l, camera.name))
                          : null,
                      trailing: Switch(
                        value: !hidden,
                        // The last camera shown stays.
                        onChanged: !hidden && shown <= 1
                            ? null
                            : (v) => settings.setHidden(camera.name, !v),
                      ),
                      onTap: camera.recording
                          ? () => _editThreshold(context, camera)
                          : null,
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _thresholdText(AppLocalizations l, String camera) {
    if (settings.threshold(camera) case final fixed?) {
      return l.settingsThresholdFixed(fixed);
    }
    return switch (autoThreshold?.call(camera)) {
      final auto? => l.settingsThresholdAutoValue(auto),
      null => l.settingsThresholdAuto,
    };
  }

  Future<void> _editThreshold(
    BuildContext context,
    CameraCapabilities camera,
  ) async {
    final result = await showDialog<_ThresholdChoice>(
      context: context,
      builder: (_) => _ThresholdDialog(
        camera: camera.label,
        fixed: settings.threshold(camera.name),
        auto: autoThreshold?.call(camera.name),
      ),
    );
    if (result != null) settings.setThreshold(camera.name, result.value);
  }
}

/// `value` is `null` for the automatic threshold.
typedef _ThresholdChoice = ({int? value});

class _ThresholdDialog extends StatefulWidget {
  final String camera;
  final int? fixed;
  final int? auto;

  const _ThresholdDialog({required this.camera, this.fixed, this.auto});

  @override
  State<_ThresholdDialog> createState() => _ThresholdDialogState();
}

class _ThresholdDialogState extends State<_ThresholdDialog> {
  late bool _automatic = widget.fixed == null;
  late final _field = TextEditingController(
    text: '${widget.fixed ?? widget.auto ?? ''}',
  );

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  int? get _value {
    final v = int.tryParse(_field.text.trim());
    return v != null && v > 0 ? v : null;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final valid = _automatic || _value != null;
    return AlertDialog(
      title: Text(l.settingsThresholdTitle(widget.camera)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.settingsThresholdHelp),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l.settingsThresholdAutoSwitch),
            subtitle: widget.auto == null
                ? null
                : Text(l.settingsThresholdNow(widget.auto!)),
            value: _automatic,
            onChanged: (v) => setState(() => _automatic = v),
          ),
          TextField(
            controller: _field,
            enabled: !_automatic,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: l.settingsThresholdField,
              errorText: valid ? null : l.settingsThresholdInvalid,
            ),
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.cancel),
        ),
        FilledButton(
          onPressed: valid
              ? () => Navigator.of(
                  context,
                ).pop<_ThresholdChoice>((value: _automatic ? null : _value))
              : null,
          child: Text(l.ok),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  final String label;
  const _Header(this.label);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
    child: Text(
      label.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: AppColors.textDim,
        letterSpacing: 1.1,
      ),
    ),
  );
}

/// A setting chosen among a few values, in a menu.
class _Choice<T> extends StatelessWidget {
  final String title;
  final String? help;
  final T value;
  final List<T> values;
  final String Function(T) label;
  final ValueChanged<T> onChanged;

  const _Choice({
    super.key,
    required this.title,
    this.help,
    required this.value,
    required this.values,
    required this.label,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => ListTile(
    title: Text(title),
    subtitle: help == null ? null : Text(help!),
    trailing: DropdownButton<T>(
      value: value,
      underline: const SizedBox.shrink(),
      items: [
        for (final v in values)
          DropdownMenuItem(value: v, child: Text(label(v))),
      ],
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    ),
  );
}
