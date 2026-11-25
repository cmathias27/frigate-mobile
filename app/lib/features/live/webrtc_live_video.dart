import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import 'live_video.dart';

/// Live video from go2rtc over WebRTC: receive only, or with the
/// microphone sent to the camera when opened [withTalk] (backchannel).
///
/// Signalling goes through Frigate's authenticated port (decision 0004);
/// media then flows straight from go2rtc's WebRTC port (8555 by default)
/// to the phone, using the candidates Frigate's go2rtc announces.
class WebRtcLiveVideo extends LiveVideo {
  @override
  final String stream;
  final WebRtcNegotiator _negotiate;

  final RTCVideoRenderer _renderer = RTCVideoRenderer();
  RTCPeerConnection? _pc;
  final _audioTracks = <MediaStreamTrack>[];
  MediaStreamTrack? _videoTrack;

  /// Stream made here when the track came without one; freed on dispose.
  MediaStream? _localStream;

  @override
  final bool withTalk;

  /// The microphone, when [withTalk].
  MediaStream? _microphone;
  bool _microphoneFailed = false;
  bool _canTalk = false;
  bool _talking = false;
  Timer? _timeout;
  Timer? _frameCheck;
  final _frames = FrameWatch();

  LiveVideoStatus _status = LiveVideoStatus.connecting;
  bool _hasAudio = false;
  bool _muted = LiveVideoDefaults.startMuted;
  bool _disposed = false;

  WebRtcLiveVideo({
    required this.stream,
    required this._negotiate,
    this.withTalk = false,
  });

  @override
  bool get canTalk => _canTalk;

  @override
  bool get microphoneFailed => _microphoneFailed;

  @override
  bool get talking => _talking;

  @override
  set talking(bool value) {
    if (_talking == value || !withTalk) return;
    _talking = value;
    for (final track in [...?_microphone?.getAudioTracks()]) {
      track.enabled = value;
    }
    notifyListeners();
  }

  @override
  LiveVideoStatus get status => _status;

  @override
  bool get hasAudio => _hasAudio;

  @override
  bool get muted => _muted;

  @override
  set muted(bool value) {
    if (_muted == value) return;
    _muted = value;
    for (final track in _audioTracks) {
      track.enabled = !value;
    }
    notifyListeners();
  }

  @override
  Future<void> start() async {
    _timeout = Timer(LiveVideoDefaults.connectTimeout, () {
      if (_status == LiveVideoStatus.connecting) _fail('timeout');
    });
    try {
      // Sound of a camera is media, played on the loudspeaker, not a call;
      // talking is a call, with echo cancellation, on the loudspeaker too.
      await _quietly(
        'audio',
        () => Helper.setAndroidAudioConfiguration(
          withTalk
              ? AndroidAudioConfiguration.communication
              : AndroidAudioConfiguration.media,
        ),
      );
      if (withTalk) await _openMicrophone();
      if (_disposed) return;
      await _renderer.initialize();
      _renderer.onFirstFrameRendered = () {
        _setStatus(LiveVideoStatus.playing);
        _watchFrames();
      };

      final pc = await createPeerConnection({
        'iceServers': <Map<String, dynamic>>[],
        'sdpSemantics': 'unified-plan',
      });
      if (_disposed) {
        await _closePeer(pc);
        return;
      }
      _pc = pc;
      pc.onTrack = _onTrack;
      pc.onConnectionState = (state) {
        if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
            state ==
                RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
          _fail('connection $state');
        }
      };

      await pc.addTransceiver(
        kind: RTCRtpMediaType.RTCRtpMediaTypeVideo,
        init: RTCRtpTransceiverInit(direction: TransceiverDirection.RecvOnly),
      );
      final microphone = _microphone;
      final voice = microphone?.getAudioTracks().firstOrNull;
      if (microphone != null && voice != null) {
        // One audio section both ways: the camera's sound comes back on it.
        await pc.addTransceiver(
          track: voice,
          kind: RTCRtpMediaType.RTCRtpMediaTypeAudio,
          init: RTCRtpTransceiverInit(
            direction: TransceiverDirection.SendRecv,
            streams: [microphone],
          ),
        );
      } else {
        await pc.addTransceiver(
          kind: RTCRtpMediaType.RTCRtpMediaTypeAudio,
          init: RTCRtpTransceiverInit(direction: TransceiverDirection.RecvOnly),
        );
      }

      final gathered = Completer<void>();
      pc.onIceGatheringState = (state) {
        if (state == RTCIceGatheringState.RTCIceGatheringStateComplete &&
            !gathered.isCompleted) {
          gathered.complete();
        }
      };
      await pc.setLocalDescription(await pc.createOffer());
      // go2rtc's HTTP API takes the offer once: wait for our candidates,
      // but not forever (its own candidates are enough on a LAN).
      await gathered.future.timeout(
        LiveVideoDefaults.iceGatheringTimeout,
        onTimeout: () {},
      );
      final offer = await pc.getLocalDescription();
      if (_disposed || offer?.sdp == null) return;

      final answer = await _negotiate(stream, offer!.sdp!);
      if (_disposed) return;
      _hasAudio = sdpHasAudio(answer);
      _canTalk = _microphone != null && sdpReceivesAudio(answer);
      await pc.setRemoteDescription(RTCSessionDescription(answer, 'answer'));
      notifyListeners();
    } catch (e) {
      _fail(e);
    }
  }

  /// Opens the microphone, on from the start: the user asked to talk.
  Future<void> _openMicrophone() async {
    try {
      final microphone = await navigator.mediaDevices.getUserMedia({
        'audio': {
          'echoCancellation': true,
          'noiseSuppression': true,
          'autoGainControl': true,
        },
        'video': false,
      });
      if (_disposed) {
        await _quietly('microphone', microphone.dispose);
        return;
      }
      _microphone = microphone;
      _talking = true;
      await _quietly('speaker', () => Helper.setSpeakerphoneOn(true));
    } catch (e) {
      // The video still opens, without the microphone.
      debugPrint('WebRTC $stream microphone: $e');
      _microphoneFailed = true;
    }
  }

  Future<void> _onTrack(RTCTrackEvent event) async {
    if (_disposed) return;
    final track = event.track;
    if (track.kind == 'audio') {
      track.enabled = !_muted;
      _audioTracks.add(track);
      return;
    }
    if (track.kind != 'video') return;
    _videoTrack = track;
    if (event.streams.isNotEmpty) {
      _renderer.srcObject = event.streams.first;
    } else {
      final media = await createLocalMediaStream('frigate-$stream');
      if (_disposed) {
        await media.dispose();
        return;
      }
      _localStream = media;
      await media.addTrack(track);
      if (!_disposed) _renderer.srcObject = media;
    }
  }

  @override
  Future<Uint8List?> captureFrame() async {
    final track = _videoTrack;
    if (track == null || _status != LiveVideoStatus.playing) return null;
    try {
      // Android writes the frame as a JPEG.
      return (await track.captureFrame()).asUint8List();
    } catch (e) {
      debugPrint('WebRTC $stream capture: $e');
      return null;
    }
  }

  /// A first frame is not enough: a stream too large for the phone's
  /// decoder shows one frame, then freezes.
  void _watchFrames() {
    _frameCheck?.cancel();
    _frameCheck = Timer.periodic(LiveVideoDefaults.frameCheck, (_) async {
      final pc = _pc;
      if (pc == null || _status != LiveVideoStatus.playing) return;
      try {
        final frames = framesDecoded(await pc.getStats());
        if (frames != null && _frames.frozen(DateTime.now(), frames)) {
          _fail('frozen at $frames frames');
        }
      } catch (e) {
        debugPrint('WebRTC $stream stats: $e');
      }
    });
  }

  void _setStatus(LiveVideoStatus status) {
    if (_disposed || _status == status) return;
    if (_status == LiveVideoStatus.failed) return;
    _status = status;
    if (status != LiveVideoStatus.connecting) _timeout?.cancel();
    notifyListeners();
  }

  void _fail(Object reason) {
    debugPrint('WebRTC $stream: $reason');
    _frameCheck?.cancel();
    _setStatus(LiveVideoStatus.failed);
  }

  @override
  Widget buildView(BoxFit fit) => RTCVideoView(
    _renderer,
    objectFit: fit == BoxFit.cover
        ? RTCVideoViewObjectFit.RTCVideoViewObjectFitCover
        : RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
  );

  @override
  void dispose() {
    _disposed = true;
    _timeout?.cancel();
    _frameCheck?.cancel();
    final pc = _pc;
    _pc = null;
    unawaited(_release(pc));
    super.dispose();
  }

  Future<void> _release(RTCPeerConnection? pc) async {
    final media = _localStream;
    _localStream = null;
    final microphone = _microphone;
    _microphone = null;
    if (microphone != null) {
      for (final track in microphone.getAudioTracks()) {
        await _quietly('microphone', track.stop);
      }
      await _quietly('microphone', microphone.dispose);
    }
    // Each step on its own: a failed one must not keep the others allocated.
    await _quietly('renderer', () async => _renderer.srcObject = null);
    if (media != null) await _quietly('stream', media.dispose);
    if (pc != null) await _closePeer(pc);
    await _quietly('renderer', _renderer.dispose);
    if (withTalk) {
      await _quietly(
        'audio',
        () => Helper.setAndroidAudioConfiguration(
          AndroidAudioConfiguration.media,
        ),
      );
    }
  }

  /// Closes the connection, then frees its native side: close alone leaves
  /// the peer connection and its received tracks allocated.
  Future<void> _closePeer(RTCPeerConnection pc) async {
    await _quietly('close', pc.close);
    await _quietly('dispose', pc.dispose);
  }

  Future<void> _quietly(String step, Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      debugPrint('WebRTC $stream $step: $e');
    }
  }
}

/// Frames decoded by the received video, from WebRTC statistics.
int? framesDecoded(List<StatsReport> reports) {
  for (final report in reports) {
    final values = report.values;
    final kind = values['kind'] ?? values['mediaType'];
    if (report.type == 'inbound-rtp' && kind == 'video') {
      final frames = values['framesDecoded'];
      if (frames is num) return frames.toInt();
    }
  }
  return null;
}
