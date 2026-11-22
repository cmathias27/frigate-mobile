import 'dart:typed_data';

import 'package:gal/gal.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

/// Saves or shares a photo taken from a camera; injected so screens can be
/// tested without the gallery or the share sheet.
abstract class PhotoActions {
  /// Saves [jpeg] in the phone's gallery under [name] (no extension).
  Future<void> save(Uint8List jpeg, String name);

  /// Opens the Android share sheet with [jpeg].
  Future<void> share(Uint8List jpeg, String name);
}

/// Gallery album and share sheet of the device.
class DevicePhotoActions implements PhotoActions {
  /// Album created in the gallery for the app's photos.
  static const album = 'Frigate';

  const DevicePhotoActions();

  @override
  Future<void> save(Uint8List jpeg, String name) async {
    if (!await Gal.hasPermission(toAlbum: true)) {
      // Only asked on Android 9 and older; newer versions need no
      // permission to add a picture.
      await Gal.requestPermission(toAlbum: true);
    }
    await Gal.putImageBytes(jpeg, album: album, name: name);
  }

  @override
  Future<void> share(Uint8List jpeg, String name) async {
    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile.fromData(jpeg, mimeType: 'image/jpeg', name: '$name.jpg'),
        ],
      ),
    );
  }
}

/// `cam_portier_20261122_143208`: sorts by camera then time in a gallery.
String photoName(String camera, DateTime at) =>
    '${camera}_${DateFormat('yyyyMMdd_HHmmss').format(at)}';
