import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frigate_mobile/app/theme.dart';
import 'package:frigate_mobile/core/storage/preferences.dart';
import 'package:frigate_mobile/features/update/release.dart';
import 'package:frigate_mobile/features/update/update_controller.dart';
import 'package:frigate_mobile/features/update/update_service.dart';
import 'package:frigate_mobile/features/update/update_widgets.dart';
import 'package:frigate_mobile/l10n/app_localizations.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _apkName = 'frigate-mobile-0.2.0-android.apk';
final _apkBytes = utf8.encode('fake apk content');
final _apkHash = sha256.convert(_apkBytes).toString();

Map<String, Object?> _releaseJson({
  String tag = 'v0.2.0',
  bool assets = true,
  bool windows = false,
}) => {
  'tag_name': tag,
  'draft': false,
  'prerelease': false,
  'body': '- Calendrier.\n- Mise à jour dans l’appli.',
  'assets': [
    if (assets) ...[
      {
        'name': _apkName,
        'size': _apkBytes.length,
        'browser_download_url': 'https://example.org/$_apkName',
      },
      {
        'name': 'SHA256SUMS',
        'browser_download_url': 'https://example.org/SHA256SUMS',
      },
      if (windows)
        {
          'name': 'frigate-mobile-0.2.0-windows.zip',
          'browser_download_url':
              'https://github.com/o/r/releases/download/v0.2.0/'
              'frigate-mobile-0.2.0-windows.zip',
        },
    ],
  ],
};

/// GitHub and its downloads, with what was asked.
class _FakeGitHub {
  Object? release = _releaseJson();
  int releaseStatus = 200;
  String sums = '$_apkHash  $_apkName\n';
  List<int> apk = _apkBytes;
  final asked = <String>[];

  late final client = MockClient.streaming((request, _) async {
    asked.add(request.url.path);
    final (status, body) = switch (request.url.path) {
      final p when p.endsWith('/releases/latest') => (
        releaseStatus,
        utf8.encode(jsonEncode(release)),
      ),
      '/SHA256SUMS' => (200, utf8.encode(sums)),
      '/$_apkName' => (200, apk),
      _ => (404, <int>[]),
    };
    return http.StreamedResponse(
      Stream.value(body),
      status,
      contentLength: body.length,
    );
  });
}

class _FakePlatform extends UpdatePlatform {
  final Directory cache;
  String? version = '0.1.0';

  /// Windows: the browser downloads the archive.
  bool windows = false;
  final opened = <Uri?>[];
  bool allowed = true;
  bool settingsOpened = false;
  final installed = <(String, String)>[];

  /// Holds [currentVersion] back while set, like a slow platform channel.
  Completer<void>? hold;

  _FakePlatform(this.cache);

  @override
  Future<String?> currentVersion() async {
    await hold?.future;
    return version;
  }

  @override
  Future<Directory> cacheDirectory() async => cache;
  @override
  Future<bool> canInstall() async => allowed;
  @override
  Future<void> openInstallSettings() async => settingsOpened = true;
  @override
  Future<void> install(File apk, String version) async =>
      installed.add((apk.path, version));

  @override
  bool get installsInApp => !windows;

  @override
  Future<void> openDownload(AppRelease release) async {
    if (release.windowsZip == null) throw const UpdateException('unsupported');
    opened.add(release.windowsZip);
  }
}

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
  home: Scaffold(body: child),
);

class _Changelog extends CachingAssetBundle {
  final String text;
  _Changelog(this.text);

  @override
  Future<ByteData> load(String key) async =>
      ByteData.sublistView(utf8.encode(text));
}

void main() {
  late Directory cache;
  late _FakeGitHub github;
  late _FakePlatform platform;
  late Preferences preferences;
  var now = DateTime(2026, 1, 10, 12);

  UpdateController controller() => UpdateController(
    service: UpdateService(client: github.client),
    platform: platform,
    preferences: preferences,
    clock: () => now,
  );

  setUp(() {
    cache = Directory.systemTemp.createTempSync('fm_update_');
    github = _FakeGitHub();
    platform = _FakePlatform(cache);
    preferences = Preferences.inMemory();
    now = DateTime(2026, 1, 10, 12);
  });

  tearDown(() => cache.deleteSync(recursive: true));

  group('release', () {
    test('reads the APK and checksums of the latest release', () {
      final release = parseRelease(_releaseJson())!;
      expect(release.version, '0.2.0');
      expect(release.apkName, _apkName);
      expect(release.installable, isTrue);
      expect(release.notes, startsWith('- Calendrier.'));
      expect(release.windowsZip, isNull);
      expect(
        parseRelease(_releaseJson(windows: true))!.windowsZip?.path,
        endsWith('-windows.zip'),
      );
      expect(parseRelease(_releaseJson(assets: false))!.installable, isFalse);
      expect(parseRelease({..._releaseJson(), 'prerelease': true}), isNull);
      expect(parseRelease(_releaseJson(tag: 'nightly')), isNull);
      expect(parseRelease('nope'), isNull);
    });

    test('versions compare by numbers', () {
      expect(isNewer('0.10.0', '0.9.3'), isTrue);
      expect(isNewer('0.1.0', '0.1.0+2'), isFalse);
      expect(isNewer('0.1.0', '1.0.0'), isFalse);
      expect(isNewer('0.1.0', null), isTrue);
      expect(isNewer('x', '0.1.0'), isFalse);
    });

    test('checksum of a file in SHA256SUMS', () {
      final sums = '${'a' * 64}  other.apk\n${'B' * 64} *$_apkName\n';
      expect(expectedSha256(sums, _apkName), 'b' * 64);
      expect(expectedSha256(sums, 'missing.apk'), isNull);
    });

    test('changelog sections', () {
      final sections = parseChangelog(
        '# Notes\n\nIntro.\n\n## 0.2.0\n\n- B\n\n## [0.1.0]\n\n- A\n',
      );
      expect(sections.map((s) => s.version), ['0.2.0', '0.1.0']);
      expect(sections.first.notes, '- B');
    });

    test('the bundled changelog has the version of the app', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      final version = RegExp(
        r'^version: (\d+\.\d+\.\d+)',
        multiLine: true,
      ).firstMatch(pubspec)!.group(1);
      final sections = parseChangelog(
        File(changelogAsset).readAsStringSync(),
      );
      expect(sections.map((s) => s.version), contains(version));
    });
  });

  group('UpdateService', () {
    test('no release yet is not an error', () async {
      github.releaseStatus = 404;
      expect(await UpdateService(client: github.client).latest(), isNull);
    });

    test('downloads, checks and keeps only the new APK', () async {
      final old = File('${cache.path}/updates/old.apk')
        ..createSync(recursive: true);
      final service = UpdateService(client: github.client);
      final progress = <double?>[];
      final apk = await service.download(
        parseRelease(_releaseJson())!,
        cache,
        onProgress: progress.add,
      );
      expect(apk.path, '${cache.path}/updates/$_apkName');
      expect(apk.readAsBytesSync(), _apkBytes);
      expect(old.existsSync(), isFalse);
      expect(progress.last, 1.0);

      // Already there and intact: not downloaded again.
      github.asked.clear();
      await service.download(parseRelease(_releaseJson())!, cache);
      expect(github.asked, ['/SHA256SUMS']);
    });

    test('a wrong checksum is refused and nothing is kept', () async {
      github.apk = utf8.encode('tampered');
      final service = UpdateService(client: github.client);
      await expectLater(
        service.download(parseRelease(_releaseJson())!, cache),
        throwsA(
          isA<UpdateException>().having((e) => e.code, 'code', 'checksum'),
        ),
      );
      expect(Directory('${cache.path}/updates').listSync(), isEmpty);
    });

    test('a too large download is stopped', () async {
      final service = UpdateService(client: github.client, maxBytes: 4);
      await expectLater(
        service.download(parseRelease(_releaseJson())!, cache),
        throwsA(
          isA<UpdateException>().having((e) => e.code, 'code', 'too_large'),
        ),
      );
    });
  });

  group('UpdateController', () {
    test('checks at start-up at most once a day, unless off', () async {
      final update = controller();
      await update.init();
      expect((await update.checkOnStartup())?.version, '0.2.0');
      expect(update.status, UpdateStatus.available);

      github.asked.clear();
      now = now.add(const Duration(hours: 5));
      expect(await controller().checkOnStartup(), isNull);
      expect(github.asked, isEmpty);

      now = now.add(const Duration(days: 1));
      final off = controller();
      await off.init();
      await off.setAutoCheck(false);
      expect(await off.checkOnStartup(), isNull);
      expect(github.asked, isEmpty);

      // The setting is kept.
      final again = controller();
      await again.init();
      expect(again.autoCheck, isFalse);
    });

    test('same version is up to date, a failure is reported', () async {
      platform.version = '0.2.0';
      final update = controller();
      await update.init();
      await update.check();
      expect(update.status, UpdateStatus.upToDate);

      github.releaseStatus = 500;
      await update.check();
      expect(update.status, UpdateStatus.failed);
      expect(update.error, 'network');
    });

    test('installs once allowed', () async {
      final update = controller();
      await update.init();
      await update.check();

      platform.allowed = false;
      expect(await update.install(), isFalse);
      expect(platform.installed, isEmpty);

      platform.allowed = true;
      expect(await update.install(), isTrue);
      expect(platform.installed.single, (
        '${cache.path}/updates/$_apkName',
        '0.2.0',
      ));
    });

    test("what's new only after an update, once", () async {
      final update = controller();
      await update.init();
      // First installation.
      expect(await update.takeWhatsNew(), isFalse);
      expect(await update.takeWhatsNew(), isFalse);

      platform.version = '0.2.0';
      final updated = controller();
      await updated.init();
      expect(await updated.takeWhatsNew(), isTrue);
      expect(await updated.takeWhatsNew(), isFalse);
    });

    test('the start-up steps wait for a slow start', () async {
      final first = controller();
      await first.init();
      await first.takeWhatsNew();
      await first.setAutoCheck(false);

      platform
        ..version = '0.2.0'
        ..hold = Completer<void>();
      final update = controller();
      unawaited(update.init());
      final whatsNew = update.takeWhatsNew();
      final release = update.checkOnStartup();
      platform.hold!.complete();

      expect(await whatsNew, isTrue);
      expect(await release, isNull);
      expect(github.asked, isEmpty);
    });
  });

  group('screens', () {
    testWidgets('sheet of a new version, then permission explained', (
      tester,
    ) async {
      final update = controller();
      await tester.runAsync(() async {
        await update.init();
        await update.check();
      });
      platform.allowed = false;
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (context) => TextButton(
              onPressed: () => showUpdateSheet(context, update),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Version 0.2.0 disponible'), findsOneWidget);
      expect(find.text('Version installée\u00a0: 0.1.0'), findsOneWidget);
      expect(find.text('Calendrier.'), findsOneWidget);

      await tester.tap(find.text('Installer'));
      await tester.pumpAndSettle();
      expect(find.text("Autoriser l'installation"), findsOneWidget);
      await tester.tap(find.text('Ouvrir les réglages'));
      await tester.pumpAndSettle();
      expect(platform.settingsOpened, isTrue);

      await tester.tap(find.text('Plus tard'));
      await tester.pumpAndSettle();
      expect(find.text('Version 0.2.0 disponible'), findsNothing);
    });

    testWidgets('Windows: the browser downloads the archive', (tester) async {
      platform.windows = true;
      final update = controller();
      await tester.runAsync(() async {
        await update.init();
        await update.check();
      });
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (context) => TextButton(
              onPressed: () => showUpdateSheet(context, update),
              child: const Text('open'),
            ),
          ),
        ),
      );

      // No archive in this release: nothing to download.
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.textContaining('pas de fichier'), findsOneWidget);
      final none = find.widgetWithText(FilledButton, 'Télécharger');
      expect(tester.widget<FilledButton>(none).onPressed, isNull);
      await tester.tap(find.text('Plus tard'));
      await tester.pumpAndSettle();

      github.release = _releaseJson(windows: true);
      await tester.runAsync(update.check);
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.textContaining('décompressez'), findsOneWidget);
      expect(find.text('Installer'), findsNothing);
      await tester.tap(find.text('Télécharger'));
      await tester.pumpAndSettle();
      expect(platform.opened.single?.path, endsWith('-windows.zip'));
      expect(find.text('Version 0.2.0 disponible'), findsNothing);
    });

    testWidgets("what's new after an update, then the check", (tester) async {
      await preferences.write('fm_update_seen_version', '0.0.1');
      final update = controller();
      await tester.runAsync(update.init);
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (context) => TextButton(
              onPressed: () => runStartupUpdate(
                context,
                update,
                bundle: _Changelog('## 0.1.0\n\n- Nouveau calendrier.\n'),
              ),
              child: const Text('start'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('start'));
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pumpAndSettle();
      expect(find.text('Nouveautés de la version 0.1.0'), findsOneWidget);
      expect(find.text('Nouveau calendrier.'), findsOneWidget);
      await tester.tap(find.text('OK'));
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pumpAndSettle();
      expect(find.text('Version 0.2.0 disponible'), findsOneWidget);
    });

    testWidgets('settings: turn off and check now', (tester) async {
      platform.version = '0.2.0';
      final update = controller();
      await tester.runAsync(update.init);
      await tester.pumpWidget(_app(UpdateSettings(update: update)));
      expect(find.text('Vérifier les mises à jour'), findsOneWidget);
      await tester.tap(find.byType(Switch));
      await tester.pump();
      expect(update.autoCheck, isFalse);

      await tester.tap(find.text('Rechercher une mise à jour'));
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pumpAndSettle();
      expect(find.text("L'application est à jour"), findsOneWidget);
    });
  });
}
