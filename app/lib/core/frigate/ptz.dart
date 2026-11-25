/// Pan, tilt and zoom of a camera through Frigate's ONVIF support.
///
/// What a camera can do comes from `GET /api/<camera>/ptz/info`; commands go
/// through Frigate's WebSocket (`/ws`) on the `<camera>/ptz` topic, as its
/// own interface sends them.
library;

/// What the ONVIF camera offers, as Frigate reports it.
class PtzInfo {
  /// Frigate's feature names: `pt` (pan and tilt), `zoom`, `pt-r` and
  /// `zoom-r` (relative moves), `zoom-a`, `focus`, `pt-r-fov`.
  final Set<String> features;

  /// Positions saved in the camera, by name.
  final List<String> presets;

  const PtzInfo({this.features = const {}, this.presets = const []});

  static const none = PtzInfo();

  /// Reads the answer of `/api/<camera>/ptz/info`; anything unexpected
  /// means no control.
  factory PtzInfo.fromJson(Map<String, dynamic> json) {
    final features = json['features'];
    final presets = json['presets'];
    return PtzInfo(
      features: {
        if (features is List) ...features.whereType<String>(),
      },
      presets: [
        if (presets is List)
          for (final p in presets)
            if (p is String && p.trim().isNotEmpty) p,
      ],
    );
  }

  bool get panTilt => features.contains('pt');
  bool get zoom => features.contains('zoom');

  /// At least one control to show.
  bool get any => panTilt || zoom || presets.isNotEmpty;
}

/// A continuous move, until [PtzMove.stop].
enum PtzMove {
  up('MOVE_UP'),
  down('MOVE_DOWN'),
  left('MOVE_LEFT'),
  right('MOVE_RIGHT'),
  zoomIn('ZOOM_IN'),
  zoomOut('ZOOM_OUT'),
  stop('STOP');

  /// Payload of the `<camera>/ptz` message.
  final String payload;
  const PtzMove(this.payload);
}

/// Payload that sends the camera to the preset [name].
String ptzPresetPayload(String name) => 'preset_$name';
