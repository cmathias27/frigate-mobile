import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import 'live_video.dart';

/// Live video from go2rtc over WebRTC, receive only.
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
  Timer? _timeout;

  LiveVideoStatus _status = LiveVideoStatus.connecting;
  bool _hasAudio = false;
  bool _muted = LiveVideoDefaults.startMuted;
  bool _disposed = false;

  WebRtcLiveVideo({required this.stream, required this._negotiate});

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
      // Sound of a camera is media, played on the loudspeaker, not a call.
      await Helper.setAndroidAudioConfiguration(
        AndroidAudioConfiguration.media,
      ).catchError((Object _) {});
      await _renderer.initialize();
      _renderer.onFirstFrameRendered = () =>
          _setStatus(LiveVideoStatus.playing);

      final pc = await createPeerConnection({
        'iceServers': <Map<String, dynamic>>[],
        'sdpSemantics': 'unified-plan',
      });
      if (_disposed) {
        await pc.close();
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

      for (final kind in [
        RTCRtpMediaType.RTCRtpMediaTypeVideo,
        RTCRtpMediaType.RTCRtpMediaTypeAudio,
      ]) {
        await pc.addTransceiver(
          kind: kind,
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
      await pc.setRemoteDescription(RTCSessionDescription(answer, 'answer'));
      notifyListeners();
    } catch (e) {
      _fail(e);
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
    if (event.streams.isNotEmpty) {
      _renderer.srcObject = event.streams.first;
    } else {
      final media = await createLocalMediaStream('frigate-$stream');
      await media.addTrack(track);
      if (!_disposed) _renderer.srcObject = media;
    }
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
    final pc = _pc;
    _pc = null;
    unawaited(_release(pc));
    super.dispose();
  }

  Future<void> _release(RTCPeerConnection? pc) async {
    try {
      await pc?.close();
      await _renderer.dispose();
    } catch (e) {
      debugPrint('WebRTC $stream release: $e');
    }
  }
}
