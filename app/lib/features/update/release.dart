/// A version published on GitHub and its notes (decision 0003).
library;

/// The latest release, as read from GitHub's `releases/latest`.
class AppRelease {
  /// Version without the `v` of the tag, for instance `0.1.0`.
  final String version;

  /// Release notes, the `## X.Y.Z` section of CHANGELOG.md.
  final String notes;

  /// The Android APK and the checksums published with it.
  final String? apkName;
  final Uri? apk;
  final Uri? sums;
  final int? apkSize;

  /// The portable Windows archive, downloaded by the browser.
  final Uri? windowsZip;

  const AppRelease({
    required this.version,
    required this.notes,
    this.apkName,
    this.apk,
    this.sums,
    this.apkSize,
    this.windowsZip,
  });

  /// Only a release with its APK and checksums can be installed.
  bool get installable => apk != null && sums != null && apkName != null;
}

/// Reads GitHub's answer; `null` for a draft, a pre-release or an
/// unusable answer.
AppRelease? parseRelease(Object? json) {
  if (json is! Map) return null;
  if (json['draft'] == true || json['prerelease'] == true) return null;
  final tag = json['tag_name'];
  if (tag is! String) return null;
  final version = tag.startsWith('v') ? tag.substring(1) : tag;
  if (parseVersion(version) == null) return null;
  String? apkName;
  Uri? apk;
  Uri? sums;
  int? size;
  Uri? windowsZip;
  final assets = json['assets'];
  if (assets is List) {
    for (final asset in assets) {
      if (asset is! Map) continue;
      final name = asset['name'];
      final url = asset['browser_download_url'];
      if (name is! String || url is! String) continue;
      final uri = Uri.tryParse(url);
      if (uri == null || uri.scheme != 'https') continue;
      if (name == 'SHA256SUMS') {
        sums = uri;
      } else if (name.endsWith('-windows.zip')) {
        windowsZip = uri;
      } else if (name.endsWith('-android.apk')) {
        apkName = name;
        apk = uri;
        final s = asset['size'];
        size = s is int ? s : null;
      }
    }
  }
  final body = json['body'];
  return AppRelease(
    version: version,
    notes: body is String ? body.trim() : '',
    apkName: apkName,
    apk: apk,
    sums: sums,
    apkSize: size,
    windowsZip: windowsZip,
  );
}

/// `X.Y.Z` as numbers; anything after (`+build`, `-beta`) is ignored.
List<int>? parseVersion(String version) {
  final match = RegExp(r'^(\d+)\.(\d+)\.(\d+)').firstMatch(version.trim());
  if (match == null) return null;
  return [for (var i = 1; i <= 3; i++) int.parse(match.group(i)!)];
}

/// True when [candidate] is a later version than [current]; an unknown
/// current version is older than any.
bool isNewer(String candidate, String? current) {
  final a = parseVersion(candidate);
  if (a == null) return false;
  final b = current == null ? null : parseVersion(current);
  if (b == null) return true;
  for (var i = 0; i < 3; i++) {
    if (a[i] != b[i]) return a[i] > b[i];
  }
  return false;
}

/// The SHA-256 of [file] in a `sha256sum` output, lower case.
String? expectedSha256(String sums, String file) {
  for (final line in sums.split('\n')) {
    final match = RegExp(
      r'^([0-9a-fA-F]{64})\s+\*?(.+?)\s*$',
    ).firstMatch(line.trim());
    if (match != null && match.group(2) == file) {
      return match.group(1)!.toLowerCase();
    }
  }
  return null;
}

/// One section of CHANGELOG.md.
typedef ReleaseNotes = ({String version, String notes});

/// Sections `## X.Y.Z` of CHANGELOG.md, newest first as written.
List<ReleaseNotes> parseChangelog(String markdown) {
  final sections = <ReleaseNotes>[];
  String? version;
  final lines = <String>[];
  void flush() {
    if (version case final v?) {
      sections.add((version: v, notes: lines.join('\n').trim()));
    }
    lines.clear();
  }

  for (final line in markdown.split('\n')) {
    if (line.startsWith('## ')) {
      flush();
      final title = line.substring(3).trim().replaceAll(RegExp(r'[\[\]]'), '');
      version = parseVersion(title) == null ? null : title.split(' ').first;
    } else if (version != null) {
      lines.add(line);
    }
  }
  flush();
  return sections;
}
