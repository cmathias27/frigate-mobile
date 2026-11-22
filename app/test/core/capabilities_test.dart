import 'package:flutter_test/flutter_test.dart';
import 'package:frigate_mobile/core/frigate/capabilities.dart';

// Shapes copied from a Frigate 0.18 server, with neutral names and no
// addresses or credentials.
Map<String, dynamic> _camera({
  bool detect = false,
  Map<String, dynamic>? live,
  String? onvifHost,
  String? friendlyName,
  bool enabled = true,
}) => {
  'enabled': enabled,
  'friendly_name': ?friendlyName,
  'detect': {'enabled': detect, 'width': 640, 'height': 360, 'fps': 2},
  'objects': {
    'track': ['person', 'car'],
  },
  'record': {
    'enabled': true,
    'continuous': {'days': 3.0},
    'motion': {'days': 3.0},
    'alerts': {
      'retain': {'days': 10.0},
    },
  },
  'audio': {'enabled': false},
  'onvif': {'host': onvifHost ?? '', 'port': 8000},
  'live': ?live,
};

void main() {
  final streams = {
    'cam_door': {
      'producers': [
        {
          'medias': [
            'video, recvonly, H264',
            'audio, recvonly, L16/16000',
            'audio, sendonly, L16/16000',
          ],
        },
      ],
    },
    'cam_garden': {
      'producers': [
        {
          'medias': [
            'video, recvonly, H264',
            'audio, recvonly, MPEG4-GENERIC/16000',
          ],
        },
      ],
    },
    'cam_garage_1': {
      'producers': [
        {
          'medias': ['video, recvonly, H264'],
        },
      ],
    },
  };

  ServerCapabilities read(
    Map<String, dynamic> cameras, {
    Map<String, dynamic>? config,
  }) => ServerCapabilities.fromJson(
    config: {'cameras': cameras, ...?config},
    streams: streams,
    version: '0.18.3',
  );

  test('a camera whose stream accepts audio can talk, others cannot', () {
    final caps = read({
      'cam_door': _camera(
        live: {
          'streams': {'Stream 1': 'cam_door'},
        },
      ),
      'cam_garden': _camera(
        live: {
          'streams': {'Stream 1': 'cam_garden'},
        },
      ),
    });
    expect(caps.cameras['cam_door']!.talk, isTrue);
    expect(caps.cameras['cam_door']!.sound, isTrue);
    expect(caps.cameras['cam_garden']!.talk, isFalse);
    expect(caps.cameras['cam_garden']!.sound, isTrue);
  });

  test('talk is found on any of the live streams of a camera', () {
    final caps = read({
      'cam_garage': _camera(
        live: {
          'streams': {'Stream 1': 'cam_garage_1', 'Stream 2': 'cam_door'},
        },
      ),
    });
    final garage = caps.cameras['cam_garage']!;
    expect(garage.liveStreams, ['cam_garage_1', 'cam_door']);
    expect(garage.talk, isTrue);
  });

  test('a camera without live streams uses its own name as stream', () {
    final caps = read({'cam_door': _camera()});
    expect(caps.cameras['cam_door']!.liveStreams, ['cam_door']);
    expect(caps.cameras['cam_door']!.talk, isTrue);
  });

  test('motion-only server: no object detection anywhere', () {
    final caps = read({'cam_door': _camera(), 'cam_garden': _camera()});
    expect(caps.anyObjectDetection, isFalse);
    expect(caps.faceRecognition, isFalse);
  });

  test('detection, PTZ and server features are read when enabled', () {
    final caps = read(
      {'cam_door': _camera(detect: true, onvifHost: '10.0.0.5')},
      config: {
        'face_recognition': {'enabled': true},
        'lpr': {'enabled': false},
        'semantic_search': {'enabled': true},
      },
    );
    final door = caps.cameras['cam_door']!;
    expect(caps.anyObjectDetection, isTrue);
    expect(door.objectDetection, isTrue);
    expect(door.trackedObjects, ['person', 'car']);
    expect(door.ptz, isTrue);
    expect(caps.faceRecognition, isTrue);
    expect(caps.licensePlates, isFalse);
    expect(caps.semanticSearch, isTrue);
    expect(caps.version, '0.18.3');
  });

  test('retention days are read for the timeline', () {
    final door = read({'cam_door': _camera()}).cameras['cam_door']!;
    expect(door.recording, isTrue);
    expect(door.continuousDays, 3);
    expect(door.motionDays, 3);
    expect(door.alertDays, 10);
  });

  test('disabled cameras are left out', () {
    final caps = read({
      'cam_door': _camera(),
      'cam_old': _camera(enabled: false),
    });
    expect(caps.cameras.keys, ['cam_door']);
  });

  test('labels: friendly name first, otherwise a readable camera name', () {
    final caps = read({
      'cam_sous_sol': _camera(),
      'cam_door': _camera(friendlyName: ' Porte d\'entrée '),
    });
    expect(caps.cameras['cam_sous_sol']!.label, 'Sous sol');
    expect(caps.cameras['cam_door']!.label, 'Porte d\'entrée');
    expect(CameraCapabilities.defaultLabel('garage'), 'Garage');
  });

  test('missing go2rtc answer: no talk, no sound, nothing breaks', () {
    final caps = ServerCapabilities.fromJson(
      config: {
        'cameras': {'cam_door': _camera()},
      },
    );
    expect(caps.cameras['cam_door']!.talk, isFalse);
    expect(caps.cameras['cam_door']!.sound, isFalse);
  });
}
