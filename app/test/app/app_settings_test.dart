import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frigate_mobile/app/app_settings.dart';
import 'package:frigate_mobile/app/theme.dart';
import 'package:frigate_mobile/core/frigate/capabilities.dart';
import 'package:frigate_mobile/core/frigate/recordings.dart';
import 'package:frigate_mobile/core/storage/preferences.dart';
import 'package:frigate_mobile/features/more/settings_screen.dart';
import 'package:frigate_mobile/features/timeline/motion_passages.dart';
import 'package:frigate_mobile/features/timeline/timeline_data.dart';
import 'package:frigate_mobile/l10n/app_localizations.dart';

CameraCapabilities _camera(
  String name,
  String label, {
  bool recording = true,
  bool talk = false,
}) => CameraCapabilities(
  name: name,
  label: label,
  objectDetection: false,
  trackedObjects: const [],
  recording: recording,
  continuousDays: 3,
  motionDays: 0,
  alertDays: 0,
  audioDetection: false,
  ptz: false,
  talk: talk,
  sound: false,
  liveStreams: [name, '${name}_sub'],
);

final _cameras = [
  _camera('cam_a', 'Entrée'),
  _camera('cam_b', 'Cour'),
  _camera('cam_door', 'Portail', recording: false),
];

List<String> _names(List<CameraCapabilities> cameras) => [
  for (final c in cameras) c.name,
];

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

void main() {
  group('AppSettings', () {
    test('defaults without anything stored', () async {
      final settings = AppSettings(Preferences.inMemory());
      await settings.load();
      expect(settings.quality, LiveQuality.auto);
      expect(settings.liveMode, LiveMode.auto);
      expect(settings.fullScreenLightFirst, isFalse);
      expect(settings.timelineLightFirst, isTrue);
      expect(settings.tryOtherStreams, isTrue);
      expect(settings.imageFallback, isTrue);
      expect(settings.tileSize, TileSize.medium);
      expect(settings.talk, isTrue);
      expect(settings.talkAllowed('cam_door'), isTrue);
      expect(_names(settings.arrange(_cameras)), [
        'cam_a',
        'cam_b',
        'cam_door',
      ]);
      expect(settings.passages.mergeGap, const Duration(seconds: 30));
    });

    test('changes are kept and read back', () async {
      final preferences = Preferences.inMemory();
      final settings = AppSettings(preferences)
        ..quality = LiveQuality.light
        ..liveMode = LiveMode.video
        ..tryOtherStreams = false
        ..imageFallback = false
        ..tileSize = TileSize.large
        ..minPassage = const Duration(seconds: 10)
        ..mergeGap = const Duration(minutes: 1)
        ..reorder(['cam_b', 'cam_a'])
        ..setHidden('cam_door', true)
        ..setThreshold('cam_a', 80)
        ..setCameraTalk('cam_door', false);
      await Future<void>.delayed(Duration.zero);

      final read = AppSettings(preferences);
      await read.load();
      expect(read.talk, isTrue);
      expect(read.talkAllowed('cam_door'), isFalse);
      expect(read.talkAllowed('cam_a'), isTrue);
      read.talk = false;
      expect(read.talkAllowed('cam_a'), isFalse);
      expect(read.quality, LiveQuality.light);
      expect(read.fullScreenLightFirst, isTrue);
      expect(read.liveMode, LiveMode.video);
      expect(read.tryOtherStreams, isFalse);
      expect(read.imageFallback, isFalse);
      expect(read.tileSize, TileSize.large);
      expect(read.minPassage, const Duration(seconds: 10));
      expect(read.mergeGap, const Duration(minutes: 1));
      expect(_names(read.arrange(_cameras)), ['cam_b', 'cam_a']);
      expect(_names(read.arrange(_cameras, withHidden: true)), [
        'cam_b',
        'cam_a',
        'cam_door',
      ]);
      expect(read.threshold('cam_a'), 80);
      settings.setThreshold('cam_a', null);
      expect(settings.threshold('cam_a'), isNull);
    });

    test('groups are added, changed, removed and kept', () async {
      final preferences = Preferences.inMemory();
      final settings = AppSettings(preferences)
        ..setGroup(const CameraGroup('Dehors', ['cam_b', 'cam_door']))
        ..setGroup(const CameraGroup('Dedans', ['cam_a']))
        ..setGroup(const CameraGroup('Devant', ['cam_door']), index: 0);
      expect(settings.group('Devant')?.cameras, ['cam_door']);
      expect(settings.group('Dehors'), isNull);
      settings.removeGroup(1);
      await Future<void>.delayed(Duration.zero);

      final read = AppSettings(preferences);
      await read.load();
      expect(read.groups, [
        const CameraGroup('Devant', ['cam_door']),
      ]);
    });

    test('a broken or odd document keeps the defaults', () async {
      for (final stored in [
        'not json',
        '[1, 2]',
        jsonEncode({
          'quality': 'ultra',
          'order': 'cam_a',
          'thresholds': {'cam_a': -3, 'cam_b': 'x'},
          'mergeGap': -1,
          'groups': [
            {'name': ' ', 'cameras': <String>[]},
            {'name': 'A'},
            'B',
          ],
        }),
      ]) {
        final settings = AppSettings(
          Preferences.inMemory({AppSettings.key: stored}),
        );
        await settings.load();
        expect(settings.quality, LiveQuality.auto, reason: stored);
        expect(settings.threshold('cam_a'), isNull, reason: stored);
        expect(settings.mergeGap, const Duration(seconds: 30), reason: stored);
        expect(settings.groups, isEmpty, reason: stored);
      }
    });

    test('a camera threshold changes its passages only', () async {
      final start = DateTime(2026, 1, 10, 20);
      RecordingSegment segment(int i, int motion) => RecordingSegment(
        start: start.add(Duration(seconds: 10 * i)),
        end: start.add(Duration(seconds: 10 * i + 10)),
        motion: motion,
      );
      final segments = [
        for (var i = 0; i < 20; i++) segment(i, i == 10 ? 50 : 5),
      ];
      final data = TimelineData(
        cameras: const ['cam_a', 'cam_b'],
        fetch: (camera, after, before) async => segments,
        clock: () => start.add(const Duration(minutes: 30)),
      );
      addTearDown(data.dispose);
      data.ensure(start, start.add(const Duration(minutes: 5)), focus: 'cam_a');
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(data.passages('cam_a'), hasLength(1));

      final settings = AppSettings()..setThreshold('cam_a', 60);
      data.settings = settings.passages;
      expect(data.threshold('cam_a'), 60);
      expect(data.passages('cam_a'), isEmpty);
      expect(data.passages('cam_b'), hasLength(1));
      expect(
        const PassageSettings(thresholds: {'cam_a': 7})
            .forCamera('cam_a')
            .threshold,
        7,
      );
    });
  });

  group('SettingsScreen', () {
    testWidgets('live and timeline choices', (tester) async {
      final settings = AppSettings(Preferences.inMemory());
      await tester.pumpWidget(
        _app(SettingsScreen(settings: settings, cameras: _cameras)),
      );
      expect(find.text('3 affichées sur 3'), findsOneWidget);

      // Images only: the stream choices go away.
      await tester.tap(find.text('Automatique').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Images seulement').last);
      await tester.pumpAndSettle();
      expect(settings.liveMode, LiveMode.images);
      expect(find.text('Flux ouvert d\'abord'), findsNothing);
      expect(find.text('Essayer les autres flux'), findsNothing);
      await tester.tap(find.text('Images seulement'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Vidéo seulement').last);
      await tester.pumpAndSettle();
      expect(settings.liveMode, LiveMode.video);
      expect(
        find.text(
          'Jamais d\'images\u00a0: la vidéo, ou un bouton pour la réessayer',
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('Automatique'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Léger').last);
      await tester.pumpAndSettle();
      expect(settings.quality, LiveQuality.light);
      expect(
        find.text(
          'Flux léger partout\u00a0: moins de données, lisible par tout téléphone',
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('Essayer les autres flux'));
      await tester.pump();
      expect(settings.tryOtherStreams, isFalse);

      await tester.scrollUntilVisible(
        find.text('Réunir les passages proches'),
        100,
      );
      await tester.tap(find.text('Lecture en images si la vidéo échoue'));
      await tester.pump();
      expect(settings.imageFallback, isFalse);
      await tester.tap(find.text('30\u00a0s'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('2\u00a0min').last);
      await tester.pumpAndSettle();
      expect(settings.mergeGap, const Duration(minutes: 2));
    });

    testWidgets('talk: everywhere, then camera by camera', (tester) async {
      final settings = AppSettings(Preferences.inMemory());
      final cameras = [
        _camera('cam_a', 'Entrée', talk: true),
        _camera('cam_b', 'Cour'),
        _camera('cam_door', 'Portail', talk: true),
      ];
      await tester.pumpWidget(
        _app(SettingsScreen(settings: settings, cameras: cameras)),
      );
      const talk = 'Bouton «\u00a0Parler\u00a0»';
      await tester.scrollUntilVisible(find.text(talk), 100);
      expect(find.text(talk), findsOneWidget);
      // Only the cameras with a loudspeaker.
      await tester.scrollUntilVisible(find.text('Portail'), 100);
      expect(find.text('Portail'), findsOneWidget);
      expect(find.text('Cour'), findsNothing);
      await tester.tap(find.text('Portail'));
      await tester.pump();
      expect(settings.talkAllowed('cam_door'), isFalse);
      expect(settings.talkAllowed('cam_a'), isTrue);

      await tester.tap(find.text(talk));
      await tester.pump();
      expect(settings.talk, isFalse);
      expect(find.text('Portail'), findsNothing);

      // Images only: no video connection, no talk.
      settings.liveMode = LiveMode.images;
      await tester.pump();
      expect(find.text(talk), findsNothing);
    });

    testWidgets('no talk setting without a camera that accepts sound', (
      tester,
    ) async {
      final settings = AppSettings(Preferences.inMemory());
      await tester.pumpWidget(
        _app(SettingsScreen(settings: settings, cameras: _cameras)),
      );
      expect(find.text('Bouton «\u00a0Parler\u00a0»'), findsNothing);
    });

    testWidgets('groups: create, rename, delete', (tester) async {
      final settings = AppSettings(Preferences.inMemory())
        ..setGroup(const CameraGroup('Dedans', ['cam_a']));
      await tester.pumpWidget(
        _app(GroupsScreen(settings: settings, cameras: _cameras)),
      );
      expect(find.text('1 caméra'), findsOneWidget);

      await tester.tap(find.text('Nouveau groupe'));
      await tester.pumpAndSettle();
      final save = find.widgetWithText(TextButton, 'Enregistrer');
      expect(tester.widget<TextButton>(save).onPressed, isNull);
      await tester.enterText(find.byType(TextField), 'Dedans');
      await tester.pump();
      expect(find.text('Un autre groupe porte déjà ce nom'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Dehors');
      await tester.tap(find.text('Portail'));
      await tester.tap(find.text('Cour'));
      await tester.pump();
      await tester.tap(save);
      await tester.pumpAndSettle();
      // Kept in the order of the cameras, not of the taps.
      expect(
        settings.groups.last,
        const CameraGroup('Dehors', ['cam_b', 'cam_door']),
      );
      expect(find.text('2 caméras'), findsOneWidget);

      await tester.tap(find.text('Dedans'));
      await tester.pumpAndSettle();
      expect(find.text('Modifier le groupe'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Maison');
      await tester.pump();
      await tester.tap(find.widgetWithText(TextButton, 'Enregistrer'));
      await tester.pumpAndSettle();
      expect(settings.groups.first, const CameraGroup('Maison', ['cam_a']));

      await tester.tap(find.byTooltip('Supprimer le groupe').first);
      await tester.pump();
      expect(settings.groups.map((g) => g.name), ['Dehors']);
    });

    testWidgets('cameras: hide, never the last one, and threshold', (
      tester,
    ) async {
      final settings = AppSettings(Preferences.inMemory());
      await tester.pumpWidget(
        _app(
          CameraSettingsScreen(
            settings: settings,
            cameras: _cameras,
            autoThreshold: (camera) => camera == 'cam_a' ? 42 : null,
          ),
        ),
      );
      expect(
        find.text('Seuil de mouvement\u00a0: automatique (42)'),
        findsOneWidget,
      );
      expect(
        find.text('Seuil de mouvement\u00a0: automatique'),
        findsOneWidget,
      );

      Switch switchOf(String label) => tester.widget<Switch>(
        find.descendant(
          of: find.widgetWithText(ListTile, label),
          matching: find.byType(Switch),
        ),
      );
      await tester.tap(find.byType(Switch).at(1));
      await tester.tap(find.byType(Switch).at(2));
      await tester.pump();
      expect(settings.hidden('cam_b'), isTrue);
      expect(settings.hidden('cam_door'), isTrue);
      // The last camera shown cannot be hidden.
      expect(switchOf('Entrée').onChanged, isNull);

      await tester.tap(find.text('Entrée'));
      await tester.pumpAndSettle();
      expect(find.text('Actuellement 42'), findsOneWidget);
      await tester.tap(find.text('Automatique'));
      await tester.pump();
      await tester.enterText(find.byType(TextField), '0');
      await tester.pump();
      expect(find.text('Un nombre entier supérieur à 0'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '75');
      await tester.pump();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(settings.threshold('cam_a'), 75);
      expect(find.text('Seuil de mouvement\u00a0: 75'), findsOneWidget);
    });
  });
}
