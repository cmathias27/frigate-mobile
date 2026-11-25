import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Exchanges a WebRTC offer for the server's answer (see
/// `FrigateClient.negotiateWebRtc`).
typedef WebRtcNegotiator = Future<String> Function(String stream, String offer);

/// Opens a live video of a go2rtc stream. Screens take it as optional:
/// without one, or when the video fails, they show images.
///
/// With [talk], the connection also sends the microphone to the camera
/// (go2rtc backchannel), microphone on from the start.
typedef LiveVideoFactory = LiveVideo Function(String stream, {bool talk});

enum LiveVideoStatus { connecting, playing, failed }

/// A live video stream shown in full screen.
///
/// The screen only talks to this interface, so WebRTC can be swapped for
/// another transport (or a fake in tests) without touching it.
abstract class LiveVideo extends ChangeNotifier {
  /// go2rtc stream name.
  String get stream;

  LiveVideoStatus get status;

  /// The server sends a sound track the phone can play (go2rtc only offers
  /// it when the camera's audio is Opus, PCMA or PCMU, or transcoded so).
  bool get hasAudio;

  bool get muted;
  set muted(bool value);

  /// The frame on screen as a JPEG at the stream's resolution, or null
  /// when no frame can be captured (the caller then uses an image).
  Future<Uint8List?> captureFrame();

  /// Opened with the microphone: the camera may hear the phone.
  bool get withTalk => false;

  /// The server takes the sound sent (its answer receives audio); known
  /// once the connection is negotiated.
  bool get canTalk => false;

  /// The microphone could not be opened (permission refused, no device).
  bool get microphoneFailed => false;

  /// The microphone is sent; only meaningful [withTalk].
  bool get talking => false;
  set talking(bool value) {}

  /// Starts connecting; [status] then moves to playing or failed.
  Future<void> start();

  /// The video, letterboxed or cropped as [fit] asks.
  Widget buildView(BoxFit fit);
}

/// Default live video settings (decision 0002: a default value now, an
/// optional setting later).
abstract final class LiveVideoDefaults {
  /// Give up on video and keep images after this long without a frame.
  static const connectTimeout = Duration(seconds: 10);

  /// Longest wait for the phone's own ICE candidates before sending the
  /// offer; go2rtc does not take candidates trickled later.
  static const iceGatheringTimeout = Duration(seconds: 3);

  /// Sound starts muted, like DS cam: no surprise noise when opening a
  /// camera.
  static const startMuted = true;

  /// Talking shows the "Talk" button on the cameras that accept sound
  /// (a setting can hide it, for all cameras or one).
  static const talk = true;

  /// How often the frames decoded are counted once the video plays.
  static const frameCheck = Duration(seconds: 2);

  /// A video that decodes fewer than [minFrameRate] frames per second over
  /// this period is frozen: the phone cannot decode it (too large) or
  /// frames are lost.
  static const frozenAfter = Duration(seconds: 6);
  static const minFrameRate = 1.0;

  /// When a stream fails, the full screen tries the camera's next stream
  /// (often a lighter sub-stream) before falling back to images.
  static const tryOtherStreams = true;
}

/// Tells a frozen video from a playing one, from the count of frames
/// decoded read at regular times.
class FrameWatch {
  final Duration window;
  final double minFrameRate;
  final _samples = <(DateTime, int)>[];

  FrameWatch({
    this.window = LiveVideoDefaults.frozenAfter,
    this.minFrameRate = LiveVideoDefaults.minFrameRate,
  });

  /// Records [frames] decoded so far at [time]; true when fewer than
  /// [minFrameRate] frames per second were decoded over the last [window].
  bool frozen(DateTime time, int frames) {
    _samples.add((time, frames));
    // Keep the newest sample at least [window] old as the reference.
    while (_samples.length > 2 && time.difference(_samples[1].$1) >= window) {
      _samples.removeAt(0);
    }
    final (since, first) = _samples.first;
    final elapsed = time.difference(since);
    if (elapsed < window) return false;
    final rate = (frames - first) / (elapsed.inMilliseconds / 1000);
    return rate < minFrameRate;
  }
}

/// True when the SDP [answer] takes the sound the phone sends: an
/// `m=audio` section with a non-zero port that receives (`recvonly` or
/// `sendrecv`, the default when no direction is given).
bool sdpReceivesAudio(String answer) {
  var inAudio = false;
  var open = false;
  var receives = true;
  bool done() => inAudio && open && receives;
  for (final raw in answer.split('\n')) {
    final line = raw.trim();
    if (line.startsWith('m=')) {
      if (done()) return true;
      final parts = line.substring(2).split(' ');
      inAudio = parts.first == 'audio';
      open = inAudio && parts.length > 1 && parts[1] != '0';
      receives = true;
    } else if (inAudio && (line == 'a=sendonly' || line == 'a=inactive')) {
      receives = false;
    }
  }
  return done();
}

/// True when the SDP [answer] carries a sound track: an `m=audio` section
/// with a non-zero port whose direction is not `inactive` (go2rtc marks it
/// inactive when no codec matches).
bool sdpHasAudio(String answer) {
  var inAudio = false;
  var audioActive = false;
  for (final raw in answer.split('\n')) {
    final line = raw.trim();
    if (line.startsWith('m=')) {
      if (inAudio && audioActive) return true;
      final parts = line.substring(2).split(' ');
      inAudio = parts.first == 'audio';
      audioActive = inAudio && parts.length > 1 && parts[1] != '0';
    } else if (inAudio && line == 'a=inactive') {
      audioActive = false;
    }
  }
  return inAudio && audioActive;
}
