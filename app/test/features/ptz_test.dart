import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frigate_mobile/app/theme.dart';
import 'package:frigate_mobile/core/frigate/capabilities.dart';
import 'package:frigate_mobile/core/frigate/client.dart';
import 'package:frigate_mobile/core/frigate/ptz.dart';
import 'package:frigate_mobile/features/live/camera_full_screen.dart';
import 'package:frigate_mobile/features/live/ptz_pad.dart';
import 'package:frigate_mobile/l10n/app_localizations.dart';

/// Smallest valid PNG (1×1, transparent).
final _pixel = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

CameraCapabilities _camera(String name, {bool ptz = true}) =>
    CameraCapabilities(
      name: name,
      label: CameraCapabilities.defaultLabel(name),
      objectDetection: false,
      trackedObjects: const [],
      recording: true,
      continuousDays: 3,
      motionDays: 0,
      alertDays: 0,
      audioDetection: false,
      ptz: ptz,
      talk: false,
      sound: false,
      liveStreams: [name],
    );

Widget _app(Widget child) => MaterialApp(
  theme: buildDarkTheme(),
  locale: const Locale('fr'),
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: AppLocalizations.supportedLocales,
  home: child,
);

/// Frigate's ONVIF side: what each camera offers and the commands received.
class _FakePtz {
  final infos = <String, PtzInfo>{};
  final asked = <String>[];
  final sent = <(String, String)>[];
  bool infoFails = false;
  bool sendFails = false;

  late final source = PtzSource(
    info: (camera) async {
      asked.add(camera);
      if (infoFails) throw const FrigateNetworkException('down');
      return infos[camera] ?? PtzInfo.none;
    },
    send: (camera, payload) async {
      sent.add((camera, payload));
      if (sendFails) throw const FrigateNetworkException('down');
    },
  );
}

void main() {
  late _FakePtz ptz;

  Future<Uint8List> fetch(String camera, {int? height}) async => _pixel;

  Future<void> open(
    WidgetTester tester,
    List<CameraCapabilities> cams, {
    bool withPtz = true,
  }) async {
    await tester.pumpWidget(
      _app(
        CameraFullScreen(
          cameras: cams,
          initialCamera: cams.first.name,
          fetch: fetch,
          ptz: withPtz ? ptz.source : null,
        ),
      ),
    );
    await tester.pump();
  }

  setUp(() => ptz = _FakePtz());

  group('PtzInfo', () {
    test('reads features and presets, ignores the unexpected', () {
      final info = PtzInfo.fromJson({
        'name': 'cam_door',
        'features': ['pt', 'zoom', 'pt-r', 3],
        'presets': ['gate', ' ', 7, 'yard'],
      });
      expect(info.panTilt, isTrue);
      expect(info.zoom, isTrue);
      expect(info.presets, ['gate', 'yard']);
      expect(info.any, isTrue);
      expect(PtzInfo.fromJson({'features': 'pt'}).any, isFalse);
    });
  });

  group('CameraFullScreen PTZ', () {
    testWidgets('hold a direction to move, release to stop', (tester) async {
      ptz.infos['cam_door'] = const PtzInfo(
        features: {'pt', 'zoom'},
        presets: ['gate'],
      );
      await open(tester, [_camera('cam_door')]);
      expect(ptz.asked, ['cam_door']);

      // Hidden until asked for.
      expect(find.byTooltip('Monter'), findsNothing);
      await tester.tap(find.byTooltip("Afficher les commandes d'orientation"));
      await tester.pump();

      final hold = await tester.startGesture(
        tester.getCenter(find.byTooltip('Monter')),
      );
      await tester.pump();
      expect(ptz.sent, [('cam_door', 'MOVE_UP')]);
      await hold.up();
      await tester.pump();
      expect(ptz.sent.last, ('cam_door', 'STOP'));

      ptz.sent.clear();
      final zoom = await tester.startGesture(
        tester.getCenter(find.byTooltip('Zoom avant')),
      );
      await zoom.up();
      await tester.pump();
      expect(ptz.sent, [('cam_door', 'ZOOM_IN'), ('cam_door', 'STOP')]);

      // A tap on the pad leaves the bars where they are.
      expect(find.byTooltip("Masquer les commandes d'orientation"), findsOne);

      ptz.sent.clear();
      await tester.tap(find.byTooltip('Positions enregistrées'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('gate'));
      await tester.pumpAndSettle();
      expect(ptz.sent, [('cam_door', 'preset_gate')]);

      await tester.tap(find.byTooltip("Masquer les commandes d'orientation"));
      await tester.pump();
      expect(find.byTooltip('Monter'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('leaving while a move is held stops the camera', (
      tester,
    ) async {
      ptz.infos['cam_door'] = const PtzInfo(features: {'pt'});
      await open(tester, [_camera('cam_door')]);
      await tester.tap(find.byTooltip("Afficher les commandes d'orientation"));
      await tester.pump();
      expect(find.byTooltip('Zoom avant'), findsNothing);

      final hold = await tester.startGesture(
        tester.getCenter(find.byTooltip('À gauche')),
      );
      await tester.pump();
      await tester.pumpWidget(const SizedBox());
      expect(ptz.sent, [('cam_door', 'MOVE_LEFT'), ('cam_door', 'STOP')]);
      await hold.up();
    });

    testWidgets('a command not sent says so', (tester) async {
      ptz.infos['cam_door'] = const PtzInfo(features: {'pt'});
      ptz.sendFails = true;
      await open(tester, [_camera('cam_door')]);
      await tester.tap(find.byTooltip("Afficher les commandes d'orientation"));
      await tester.pump();
      final hold = await tester.startGesture(
        tester.getCenter(find.byTooltip('Descendre')),
      );
      await hold.up();
      await tester.pump();
      expect(
        find.text("La caméra n'a pas reçu la commande d'orientation."),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('no control without ONVIF, source, features or answer', (
      tester,
    ) async {
      const show = "Afficher les commandes d'orientation";
      ptz.infos['cam_door'] = const PtzInfo(features: {'pt'});

      await open(tester, [_camera('cam_door', ptz: false)]);
      expect(find.byTooltip(show), findsNothing);
      expect(ptz.asked, isEmpty);

      await open(tester, [_camera('cam_door')], withPtz: false);
      expect(find.byTooltip(show), findsNothing);

      await open(tester, [_camera('cam_yard')]);
      expect(find.byTooltip(show), findsNothing);

      await tester.pumpWidget(const SizedBox());
      ptz.infoFails = true;
      await open(tester, [_camera('cam_door')]);
      expect(find.byTooltip(show), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });
  });
}
