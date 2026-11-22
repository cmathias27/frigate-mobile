import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app/formatting.dart';
import '../../app/theme.dart';
import '../../core/frigate/client.dart';
import '../../core/frigate/vod_proxy.dart';
import '../../l10n/app_localizations.dart';
import '../live/photo.dart';
import 'clip_export.dart';
import 'motion_passages.dart';

/// What the timeline needs to export a clip or a photo of a recording;
/// the timeline offers neither without it.
class RecordingExport {
  /// Authenticated GET on Frigate, for the clip.
  final StreamOpener open;

  /// Recorded frame of a camera at a time, at full resolution.
  final Future<Uint8List> Function(String camera, DateTime time) frame;

  final Future<Directory> Function() cacheDirectory;
  final PhotoActions photos;
  final VideoActions videos;
  final void Function()? onAuthError;

  const RecordingExport({
    required this.open,
    required this.frame,
    required this.cacheDirectory,
    this.photos = const DevicePhotoActions(),
    this.videos = const DeviceVideoActions(),
    this.onAuthError,
  });
}

/// How the clip sheet was left.
enum ClipOutcome { saved, shared }

/// Sheet choosing and exporting a clip of [camera] around [playhead]
/// (mock-up screen 7, "Extrait").
Future<ClipOutcome?> showClipSheet(
  BuildContext context, {
  required RecordingExport export,
  required String camera,
  required String label,
  required DateTime playhead,
  required DateTime liveEdge,
  MotionPassage? passage,
}) => showModalBottomSheet<ClipOutcome>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => ClipSheet(
    export: export,
    camera: camera,
    label: label,
    playhead: playhead,
    liveEdge: liveEdge,
    passage: passage,
  ),
);

class ClipSheet extends StatefulWidget {
  final RecordingExport export;
  final String camera;
  final String label;
  final DateTime playhead;
  final DateTime liveEdge;
  final MotionPassage? passage;

  const ClipSheet({
    super.key,
    required this.export,
    required this.camera,
    required this.label,
    required this.playhead,
    required this.liveEdge,
    this.passage,
  });

  @override
  State<ClipSheet> createState() => _ClipSheetState();
}

class _ClipSheetState extends State<ClipSheet> {
  late ClipRange _range = defaultClipRange(
    widget.playhead,
    passage: widget.passage,
    liveEdge: widget.liveEdge,
  );
  ClipCancelToken? _download;
  int _received = 0;
  bool _failed = false;

  bool get _busy => _download != null;

  @override
  void dispose() {
    _download?.cancel();
    super.dispose();
  }

  void _set(ClipRange range) => setState(() {
    _range = clampClip(range, liveEdge: widget.liveEdge);
    _failed = false;
  });

  void _moveStart(Duration by) {
    final start = _range.start.add(by);
    if (!start.isBefore(_range.end)) return;
    // Moving the start keeps the end, unless the clip gets too long.
    var end = _range.end;
    if (end.difference(start) > ClipDefaults.maxLength) {
      end = start.add(ClipDefaults.maxLength);
    }
    _set((start: start, end: end));
  }

  void _moveEnd(Duration by) {
    final end = _range.end.add(by);
    if (!end.isAfter(_range.start) || end.isAfter(widget.liveEdge)) return;
    var start = _range.start;
    if (end.difference(start) > ClipDefaults.maxLength) {
      start = end.subtract(ClipDefaults.maxLength);
    }
    setState(() {
      _range = (start: start, end: end);
      _failed = false;
    });
  }

  Future<void> _export({required bool share}) async {
    if (_busy) return;
    final token = ClipCancelToken();
    setState(() {
      _download = token;
      _received = 0;
      _failed = false;
    });
    final export = widget.export;
    try {
      final file = await downloadClip(
        open: export.open,
        camera: widget.camera,
        range: _range,
        cache: await export.cacheDirectory(),
        name: photoName(widget.camera, _range.start),
        cancel: token,
        onProgress: (bytes) {
          if (mounted) setState(() => _received = bytes);
        },
      );
      if (token.cancelled) return;
      if (share) {
        await export.videos.share(file);
      } else {
        await export.videos.save(file);
      }
      if (mounted) {
        Navigator.of(
          context,
        ).pop(share ? ClipOutcome.shared : ClipOutcome.saved);
      }
    } on ClipCancelled {
      // Stopped from the sheet: nothing to report.
    } on FrigateAuthException {
      export.onAuthError?.call();
      if (mounted) setState(() => _failed = true);
    } catch (e) {
      debugPrint('Clip ${widget.camera}: $e');
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted && identical(_download, token)) {
        setState(() => _download = null);
      }
    }
  }

  void _cancel() {
    _download?.cancel();
    setState(() => _download = null);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final locale = Localizations.localeOf(context).toString();
    final time = DateFormat.Hms(locale);
    final passage = widget.passage;
    final step = ClipDefaults.step;
    final atMax = _range.length >= ClipDefaults.maxLength;

    Widget bound({
      required String title,
      required DateTime value,
      required VoidCallback? earlier,
      required VoidCallback? later,
      required String earlierTip,
      required String laterTip,
    }) => Row(
      children: [
        SizedBox(width: 64, child: Text(title, style: text.bodyMedium)),
        IconButton(
          tooltip: earlierTip,
          onPressed: _busy ? null : earlier,
          icon: const Icon(Icons.remove_rounded),
        ),
        Expanded(
          child: Text(
            time.format(value),
            textAlign: TextAlign.center,
            style: text.titleMedium?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
        IconButton(
          tooltip: laterTip,
          onPressed: _busy ? null : later,
          icon: const Icon(Icons.add_rounded),
        ),
      ],
    );

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 8,
          children: [
            Text(
              l.clipTitle(widget.label),
              style: text.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            Text(
              DateFormat.yMMMMEEEEd(locale).format(_range.start),
              style: text.bodySmall?.copyWith(color: AppColors.textDim),
            ),
            bound(
              title: l.clipStart,
              value: _range.start,
              earlier: () => _moveStart(-step),
              later: () => _moveStart(step),
              earlierTip: l.clipEarlier(step.inSeconds),
              laterTip: l.clipLater(step.inSeconds),
            ),
            bound(
              title: l.clipEnd,
              value: _range.end,
              earlier: () => _moveEnd(-step),
              later: _range.end.add(step).isAfter(widget.liveEdge)
                  ? null
                  : () => _moveEnd(step),
              earlierTip: l.clipEarlier(step.inSeconds),
              laterTip: l.clipLater(step.inSeconds),
            ),
            Text(
              atMax
                  ? l.clipLengthMax(formatDuration(_range.length, l))
                  : l.clipLength(formatDuration(_range.length, l)),
              style: text.bodySmall?.copyWith(color: AppColors.textDim),
            ),
            Wrap(
              spacing: 8,
              children: [
                if (passage != null)
                  ActionChip(
                    label: Text(l.clipPassage),
                    onPressed: _busy
                        ? null
                        : () => _set((start: passage.start, end: passage.end)),
                  ),
                for (final length in ClipDefaults.presets)
                  ActionChip(
                    label: Text(formatDuration(length, l)),
                    onPressed: _busy
                        ? null
                        : () => _set(
                            presetClip(
                              widget.playhead,
                              length,
                              liveEdge: widget.liveEdge,
                            ),
                          ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            if (_busy) ...[
              const LinearProgressIndicator(),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l.clipDownloading(
                        NumberFormat('0.0', locale).format(
                          _received / (1024 * 1024),
                        ),
                      ),
                      style: text.bodySmall,
                    ),
                  ),
                  TextButton(onPressed: _cancel, child: Text(l.clipCancel)),
                ],
              ),
            ] else ...[
              if (_failed)
                Text(
                  l.clipFailed,
                  style: text.bodySmall?.copyWith(color: AppColors.live),
                ),
              Row(
                spacing: 8,
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _export(share: true),
                      icon: const Icon(Icons.share_outlined),
                      label: Text(l.clipShare),
                    ),
                  ),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _export(share: false),
                      icon: const Icon(Icons.download_rounded),
                      label: Text(l.clipSave),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
