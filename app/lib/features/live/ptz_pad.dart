import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/frigate/ptz.dart';
import '../../l10n/app_localizations.dart';

/// Reads what a camera's ONVIF control offers and sends it commands
/// (`FrigateClient.fetchPtzInfo` and `sendPtz`).
class PtzSource {
  final Future<PtzInfo> Function(String camera) info;
  final Future<void> Function(String camera, String payload) send;

  const PtzSource({required this.info, required this.send});
}

/// Pan, tilt, zoom and presets of one camera, over the full screen picture.
/// A move lasts as long as its button is held, then stops.
class PtzPad extends StatefulWidget {
  final String camera;
  final PtzInfo info;
  final PtzSource source;

  /// A command could not be sent.
  final VoidCallback? onError;

  const PtzPad({
    super.key,
    required this.camera,
    required this.info,
    required this.source,
    this.onError,
  });

  @override
  State<PtzPad> createState() => _PtzPadState();
}

class _PtzPadState extends State<PtzPad> {
  /// The move held, stopped when released or when the pad goes away.
  PtzMove? _held;

  Future<void> _send(String payload) async {
    try {
      await widget.source.send(widget.camera, payload);
    } catch (e) {
      debugPrint('PTZ ${widget.camera} $payload: $e');
      widget.onError?.call();
    }
  }

  void _start(PtzMove move) {
    setState(() => _held = move);
    _send(move.payload);
  }

  void _stop() {
    // The release may come after the pad went away (it already stopped).
    if (_held == null || !mounted) return;
    setState(() => _held = null);
    _send(PtzMove.stop.payload);
  }

  @override
  void dispose() {
    // Never leave the camera turning.
    if (_held != null) _send(PtzMove.stop.payload);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final info = widget.info;
    Widget hold(PtzMove move, IconData icon, String tooltip) => _HoldButton(
      icon: icon,
      tooltip: tooltip,
      active: _held == move,
      onStart: () => _start(move),
      onEnd: _stop,
    );
    // Taps on the pad do not reach the picture (bars shown or hidden).
    return GestureDetector(
      onTap: () {},
      child: _pad(context, l, info, hold),
    );
  }

  Widget _pad(
    BuildContext context,
    AppLocalizations l,
    PtzInfo info,
    Widget Function(PtzMove, IconData, String) hold,
  ) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 12,
          children: [
            if (info.panTilt)
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  hold(PtzMove.up, Icons.keyboard_arrow_up_rounded, l.ptzUp),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      hold(
                        PtzMove.left,
                        Icons.keyboard_arrow_left_rounded,
                        l.ptzLeft,
                      ),
                      const SizedBox.square(dimension: 44),
                      hold(
                        PtzMove.right,
                        Icons.keyboard_arrow_right_rounded,
                        l.ptzRight,
                      ),
                    ],
                  ),
                  hold(
                    PtzMove.down,
                    Icons.keyboard_arrow_down_rounded,
                    l.ptzDown,
                  ),
                ],
              ),
            if (info.zoom || info.presets.isNotEmpty)
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (info.zoom) ...[
                    hold(PtzMove.zoomIn, Icons.zoom_in_rounded, l.ptzZoomIn),
                    hold(PtzMove.zoomOut, Icons.zoom_out_rounded, l.ptzZoomOut),
                  ],
                  if (info.presets.isNotEmpty)
                    PopupMenuButton<String>(
                      tooltip: l.ptzPresets,
                      icon: const Icon(
                        Icons.bookmarks_outlined,
                        color: Colors.white,
                      ),
                      onSelected: (p) => _send(ptzPresetPayload(p)),
                      itemBuilder: (context) => [
                        for (final p in info.presets)
                          PopupMenuItem(value: p, child: Text(p)),
                      ],
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// A button that acts while pressed: [onStart] on press, [onEnd] on
/// release or cancel (finger slid away, mouse left).
class _HoldButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool active;
  final VoidCallback onStart;
  final VoidCallback onEnd;

  const _HoldButton({
    required this.icon,
    required this.tooltip,
    required this.active,
    required this.onStart,
    required this.onEnd,
  });

  @override
  Widget build(BuildContext context) {
    // Raw pointer events: no gesture (long press, page swipe) can take the
    // release away, so a move always ends with a stop.
    return Tooltip(
      message: tooltip,
      triggerMode: TooltipTriggerMode.manual,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (_) => onStart(),
        onPointerUp: (_) => onEnd(),
        onPointerCancel: (_) => onEnd(),
        child: SizedBox.square(
          dimension: 44,
          child: Icon(
            icon,
            size: 32,
            color: active ? AppColors.accent : Colors.white,
          ),
        ),
      ),
    );
  }
}
