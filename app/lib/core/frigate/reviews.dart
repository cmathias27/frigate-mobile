/// Review items of Frigate (`GET /api/review`): alerts and detections made
/// from tracked objects or detected sounds, seen or not by the user.
library;

enum ReviewSeverity { alert, detection }

class ReviewItem {
  final String id;
  final String camera;
  final DateTime start;

  /// `null` while the item is still going on.
  final DateTime? end;
  final ReviewSeverity severity;

  /// Seen by the user signed in (Frigate keeps it per user).
  final bool reviewed;

  /// Objects tracked (`person`, `car`…), sounds heard (`bark`…), names
  /// recognised (faces, plates) and zones entered.
  final List<String> objects;
  final List<String> audio;
  final List<String> subLabels;
  final List<String> zones;

  /// Path of the thumbnail on the server (`/clips/review/…webp`), or `null`.
  final String? thumbnail;

  const ReviewItem({
    required this.id,
    required this.camera,
    required this.start,
    required this.end,
    required this.severity,
    required this.reviewed,
    this.objects = const [],
    this.audio = const [],
    this.subLabels = const [],
    this.zones = const [],
    this.thumbnail,
  });

  /// What was seen or heard, without duplicates: objects then sounds.
  List<String> get labels => {...objects, ...audio}.toList();

  Duration? get duration => end?.difference(start);

  ReviewItem copyWith({bool? reviewed}) => ReviewItem(
    id: id,
    camera: camera,
    start: start,
    end: end,
    severity: severity,
    reviewed: reviewed ?? this.reviewed,
    objects: objects,
    audio: audio,
    subLabels: subLabels,
    zones: zones,
    thumbnail: thumbnail,
  );

  @override
  String toString() => 'ReviewItem($id, $camera, $severity, $start)';
}

/// Parses the answer of `GET /api/review`; malformed entries are skipped.
List<ReviewItem> parseReviews(Object? json) {
  if (json is! List) throw const FormatException('review list expected');
  final items = <ReviewItem>[];
  for (final raw in json) {
    if (raw is! Map) continue;
    final id = raw['id'];
    final camera = raw['camera'];
    final start = _time(raw['start_time']);
    final severity = switch (raw['severity']) {
      'alert' => ReviewSeverity.alert,
      'detection' => ReviewSeverity.detection,
      _ => null,
    };
    if (id is! String || camera is! String || start == null) continue;
    if (severity == null) continue;
    final data = raw['data'] is Map ? raw['data'] as Map : const {};
    final reviewed = raw['has_been_reviewed'];
    items.add(
      ReviewItem(
        id: id,
        camera: camera,
        start: start,
        end: _time(raw['end_time']),
        severity: severity,
        reviewed: reviewed == true || reviewed == 1,
        objects: _strings(data['objects']),
        audio: _strings(data['audio']),
        subLabels: _strings(data['sub_labels']),
        zones: _strings(data['zones']),
        thumbnail: thumbnailPath(raw['thumb_path']),
      ),
    );
  }
  return items;
}

/// `/media/frigate/clips/review/thumb-x.webp` → `/clips/review/thumb-x.webp`,
/// the path nginx serves to signed-in users.
String? thumbnailPath(Object? path) {
  if (path is! String || path.isEmpty) return null;
  const media = '/media/frigate/';
  if (path.startsWith(media)) return '/${path.substring(media.length)}';
  return path.startsWith('/clips/') ? path : null;
}

DateTime? _time(Object? v) {
  if (v is num) {
    return DateTime.fromMillisecondsSinceEpoch((v * 1000).round());
  }
  if (v is String) return DateTime.tryParse(v)?.toLocal();
  return null;
}

List<String> _strings(Object? v) => v is List
    ? {
        for (final s in v)
          if (s is String && s.isNotEmpty) s,
      }.toList()
    : const [];
