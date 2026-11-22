/// What a Frigate server and each of its cameras can do, read from
/// `GET /api/config` and `GET /api/go2rtc/streams` (decision 0002).
///
/// The app never assumes a feature: every screen asks these objects whether
/// to show a control, so enabling detection, face recognition or PTZ in
/// Frigate later makes the matching controls appear without a new version.
library;

/// Features of the whole server.
class ServerCapabilities {
  final String version;
  final bool faceRecognition;
  final bool licensePlates;
  final bool semanticSearch;
  final bool generativeAi;
  final Map<String, CameraCapabilities> cameras;

  const ServerCapabilities({
    required this.version,
    required this.faceRecognition,
    required this.licensePlates,
    required this.semanticSearch,
    required this.generativeAi,
    required this.cameras,
  });

  /// True when at least one camera tracks objects, so the app has alerts and
  /// detections to show; otherwise it works on motion only.
  bool get anyObjectDetection => cameras.values.any((c) => c.objectDetection);

  /// Builds the capabilities from the decoded JSON of `/api/config`, the
  /// decoded JSON of `/api/go2rtc/streams` (may be empty when go2rtc does not
  /// answer) and the version string of `/api/version`.
  factory ServerCapabilities.fromJson({
    required Map<String, dynamic> config,
    Map<String, dynamic> streams = const {},
    String version = '',
  }) {
    final rawCameras = _map(config['cameras']);
    final cameras = <String, CameraCapabilities>{};
    for (final entry in rawCameras.entries) {
      final cam = _map(entry.value);
      if (cam['enabled'] == false) continue;
      cameras[entry.key] = CameraCapabilities._fromJson(
        entry.key,
        cam,
        streams,
      );
    }
    return ServerCapabilities(
      version: version,
      faceRecognition: _enabled(config['face_recognition']),
      licensePlates: _enabled(config['lpr']),
      semanticSearch: _enabled(config['semantic_search']),
      generativeAi: _enabled(config['genai']),
      cameras: cameras,
    );
  }
}

/// Features of one camera.
class CameraCapabilities {
  /// Frigate's camera name (`cam_portier`).
  final String name;

  /// Label shown to the user: Frigate's `friendly_name` when set, otherwise
  /// the name without its `cam_` prefix, underscores turned into spaces.
  final String label;

  /// Object tracking is on: Frigate produces alerts and detections.
  final bool objectDetection;

  /// Objects tracked when [objectDetection] is on (`person`, `car`…).
  final List<String> trackedObjects;

  /// Recording is on, so the timeline can play the past back.
  final bool recording;

  /// Days kept for continuous recording, motion recording and alerts.
  final double continuousDays;
  final double motionDays;
  final double alertDays;

  /// Audio detection (barking, glass breaking…) is on.
  final bool audioDetection;

  /// An ONVIF host is configured: pan, tilt and zoom may be available.
  final bool ptz;

  /// The camera accepts audio sent to it (go2rtc backchannel): "Talk".
  final bool talk;

  /// The camera has a sound track that can be listened to.
  final bool sound;

  /// go2rtc stream names for live view, in Frigate's order (the first is the
  /// main quality).
  final List<String> liveStreams;

  const CameraCapabilities({
    required this.name,
    required this.label,
    required this.objectDetection,
    required this.trackedObjects,
    required this.recording,
    required this.continuousDays,
    required this.motionDays,
    required this.alertDays,
    required this.audioDetection,
    required this.ptz,
    required this.talk,
    required this.sound,
    required this.liveStreams,
  });

  factory CameraCapabilities._fromJson(
    String name,
    Map<String, dynamic> cam,
    Map<String, dynamic> streams,
  ) {
    final record = _map(cam['record']);
    final liveStreams = _map(_map(cam['live'])['streams']).values
        .whereType<String>()
        .toList();
    // Frigate 0.14+ lists live streams under live.streams; older configs
    // only had live.stream_name, and a camera without either uses its name.
    if (liveStreams.isEmpty) {
      final single = _map(cam['live'])['stream_name'];
      liveStreams.add(single is String && single.isNotEmpty ? single : name);
    }
    final medias = [
      for (final stream in liveStreams) ..._medias(streams[stream]),
    ];
    final friendly = cam['friendly_name'];
    return CameraCapabilities(
      name: name,
      label: friendly is String && friendly.trim().isNotEmpty
          ? friendly.trim()
          : defaultLabel(name),
      objectDetection: _enabled(cam['detect']),
      trackedObjects: _map(cam['objects'])['track'] is List
          ? List<String>.from(
              (_map(cam['objects'])['track'] as List).whereType<String>(),
            )
          : const [],
      recording: _enabled(record),
      continuousDays: _days(_map(record['continuous'])['days']),
      motionDays: _days(_map(record['motion'])['days']),
      alertDays: _days(_map(_map(record['alerts'])['retain'])['days']),
      audioDetection: _enabled(cam['audio']),
      ptz: '${_map(cam['onvif'])['host'] ?? ''}'.trim().isNotEmpty,
      talk: medias.any(_isTalkMedia),
      sound: medias.any(_isSoundMedia),
      liveStreams: List.unmodifiable(liveStreams),
    );
  }

  /// `cam_sous_sol` → `Sous sol`.
  static String defaultLabel(String name) {
    var s = name.startsWith('cam_') ? name.substring(4) : name;
    s = s.replaceAll('_', ' ').trim();
    if (s.isEmpty) return name;
    return s[0].toUpperCase() + s.substring(1);
  }
}

/// go2rtc describes each media as `"audio, sendonly, L16/16000"`, seen from
/// the camera: `sendonly` audio is what the camera accepts (backchannel).
bool _isTalkMedia(String media) {
  final parts = media.split(',').map((p) => p.trim().toLowerCase()).toList();
  return parts.length >= 2 && parts[0] == 'audio' && parts[1] == 'sendonly';
}

bool _isSoundMedia(String media) {
  final parts = media.split(',').map((p) => p.trim().toLowerCase()).toList();
  return parts.length >= 2 && parts[0] == 'audio' && parts[1] == 'recvonly';
}

List<String> _medias(Object? stream) {
  final producers = _map(stream)['producers'];
  if (producers is! List) return const [];
  return [
    for (final p in producers)
      if (_map(p)['medias'] is List)
        ...(_map(p)['medias'] as List).whereType<String>(),
  ];
}

Map<String, dynamic> _map(Object? v) =>
    v is Map ? v.cast<String, dynamic>() : const {};

bool _enabled(Object? section) => _map(section)['enabled'] == true;

double _days(Object? v) => v is num ? v.toDouble() : 0;
