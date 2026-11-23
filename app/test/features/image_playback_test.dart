import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frigate_mobile/features/timeline/image_playback.dart';
import 'package:frigate_mobile/features/timeline/recording_player.dart';

/// Frigate cutting recorded frames: records every request, fails on demand.
class _Frames {
  final asked = <(String, DateTime, int?)>[];
  bool failing = false;

  Future<Uint8List> fetch(String camera, DateTime time, {int? height}) async {
    asked.add((camera, time, height));
    if (failing) throw Exception('404');
    return Uint8List.fromList([1, 2, 3]);
  }
}

/// A video player whose failures and frozen time are scripted.
class _Video extends RecordingPlayer {
  final opened = <String>[];
  bool failOpen = false;
  @override
  PlayerStatus status = PlayerStatus.idle;
  @override
  String? camera;
  @override
  DateTime? start;
  @override
  DateTime? end;
  @override
  DateTime? time;
  @override
  bool playing = false;
  @override
  bool completed = false;
  @override
  String? videoError;
  @override
  double speed = 1;

  @override
  Future<void> setSpeed(double speed) async => this.speed = speed;

  @override
  Future<void> open(String camera, DateTime start, DateTime end) async {
    opened.add(camera);
    this.camera = camera;
    this.start = start;
    this.end = end;
    time = start;
    playing = false;
    status = failOpen ? PlayerStatus.failed : PlayerStatus.ready;
    videoError = failOpen ? 'Decoder init failed: picture too large' : null;
    notifyListeners();
  }

  @override
  Future<void> play() async {
    playing = true;
    notifyListeners();
  }

  @override
  Future<void> pause() async {
    playing = false;
    notifyListeners();
  }

  @override
  Future<void> seek(DateTime time) async => this.time = time;

  @override
  Widget buildView() => const SizedBox();
}

void main() {
  final start = DateTime(2026, 1, 10, 12);
  final end = start.add(const Duration(minutes: 1));
  late DateTime now;
  DateTime clock() => now;

  setUp(() => now = DateTime(2026, 1, 10, 20));

  group('ImageRecordingPlayer', () {
    testWidgets('plays recorded frames in real time up to the end', (
      tester,
    ) async {
      final frames = _Frames();
      final player = ImageRecordingPlayer(frames.fetch, clock: clock);

      await player.open('cam_a', start, end);
      expect(player.status, PlayerStatus.ready);
      expect(player.imagePlayback, isTrue);
      expect(frames.asked.single, ('cam_a', start, 720));
      expect(player.time, start);

      await player.play();
      expect(player.playing, isTrue);
      now = now.add(const Duration(seconds: 3));
      await tester.pump(const Duration(milliseconds: 250));
      expect(player.time, start.add(const Duration(seconds: 3)));
      expect(frames.asked.last.$2, start.add(const Duration(seconds: 3)));

      await player.pause();
      now = now.add(const Duration(seconds: 30));
      expect(player.time, start.add(const Duration(seconds: 3)));

      // Beyond the end: stops there, completed.
      await player.seek(end.subtract(const Duration(seconds: 1)));
      await player.play();
      now = now.add(const Duration(seconds: 5));
      await tester.pump(const Duration(milliseconds: 250));
      expect(player.playing, isFalse);
      expect(player.completed, isTrue);
      expect(player.time, end);

      // Seeking stays inside the range.
      await player.seek(start.subtract(const Duration(hours: 1)));
      expect(player.time, start);
      expect(player.completed, isFalse);
      player.dispose();
    });

    testWidgets('plays faster or slower from the time reached', (
      tester,
    ) async {
      final player = ImageRecordingPlayer(_Frames().fetch, clock: clock);
      await player.open('cam_a', start, end);
      await player.setSpeed(4);
      expect(player.speed, 4);
      await player.play();
      now = now.add(const Duration(seconds: 2));
      expect(player.time, start.add(const Duration(seconds: 8)));

      // Slowing down keeps the 8 s reached.
      await player.setSpeed(0.5);
      now = now.add(const Duration(seconds: 4));
      expect(player.time, start.add(const Duration(seconds: 10)));

      // Kept across an opening.
      await player.open('cam_b', start, end);
      expect(player.speed, 0.5);
      player.dispose();
    });

    testWidgets('a frame that cannot be read fails the opening', (
      tester,
    ) async {
      final frames = _Frames()..failing = true;
      final player = ImageRecordingPlayer(frames.fetch, clock: clock);
      await player.open('cam_a', start, end);
      expect(player.status, PlayerStatus.failed);
      player.dispose();
    });
  });

  group('FallbackRecordingPlayer', () {
    late _Video video;
    late _Frames frames;
    late FallbackRecordingPlayer player;

    setUp(() {
      video = _Video();
      frames = _Frames();
      player = FallbackRecordingPlayer(
        video: video,
        images: ImageRecordingPlayer(frames.fetch, clock: clock),
        clock: clock,
      );
    });

    tearDown(() => player.dispose());

    testWidgets('a video that fails is played as images, for that camera', (
      tester,
    ) async {
      video.failOpen = true;
      await player.open('cam_a', start, end);
      await tester.pump();
      expect(player.imagePlayback, isTrue);
      expect(player.status, PlayerStatus.ready);
      expect(player.camera, 'cam_a');
      expect(player.videoError, contains('too large'));

      // The same camera goes straight to images; another one tries video.
      video.failOpen = false;
      await player.open('cam_a', start, end);
      expect(video.opened, ['cam_a']);
      expect(player.imagePlayback, isTrue);
      await player.open('cam_b', start, end);
      expect(video.opened, ['cam_a', 'cam_b']);
      expect(player.imagePlayback, isFalse);
      expect(player.status, PlayerStatus.ready);

      // Retrying the video of the first camera.
      await player.open('cam_a', start, end);
      await player.retryVideo();
      expect(player.imagePlayback, isFalse);
      expect(video.opened.last, 'cam_a');
    });

    testWidgets('the speed goes to the video and to the images', (
      tester,
    ) async {
      await player.setSpeed(2);
      expect(video.speed, 2);
      expect(player.speed, 2);
      video.failOpen = true;
      await player.open('cam_a', start, end);
      await tester.pump();
      expect(player.imagePlayback, isTrue);
      expect(player.speed, 2);
    });

    testWidgets('a frozen video switches to images where it stopped', (
      tester,
    ) async {
      await player.open('cam_a', start, end);
      await player.play();
      final at = start.add(const Duration(seconds: 4));
      video.time = at;
      for (var i = 0; i < 6; i++) {
        now = now.add(ImagePlaybackDefaults.frameCheck);
        await tester.pump(ImagePlaybackDefaults.frameCheck);
      }
      expect(player.imagePlayback, isTrue);
      expect(player.playing, isTrue);
      expect(video.playing, isFalse);
      expect(frames.asked.last.$2, at);
      expect(player.videoError, 'frozen');
      await player.pause();
    });

    testWidgets('a paused or moving video is not frozen', (tester) async {
      await player.open('cam_a', start, end);
      await player.play();
      for (var i = 0; i < 8; i++) {
        now = now.add(ImagePlaybackDefaults.frameCheck);
        video.time = video.time!.add(ImagePlaybackDefaults.frameCheck);
        await tester.pump(ImagePlaybackDefaults.frameCheck);
      }
      await player.pause();
      for (var i = 0; i < 8; i++) {
        now = now.add(ImagePlaybackDefaults.frameCheck);
        await tester.pump(ImagePlaybackDefaults.frameCheck);
      }
      expect(player.imagePlayback, isFalse);
    });

    testWidgets('no image either: the video failure stays, not remembered', (
      tester,
    ) async {
      video.failOpen = true;
      frames.failing = true;
      await player.open('cam_a', start, end);
      await tester.pump();
      expect(player.imagePlayback, isFalse);
      expect(player.status, PlayerStatus.failed);

      // Recorded again later: the video is tried, not the images.
      video.failOpen = false;
      frames.failing = false;
      await player.open('cam_a', start, end);
      expect(player.imagePlayback, isFalse);
      expect(player.status, PlayerStatus.ready);
    });
  });
}
