import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:frigate_mobile/features/live/camera_feed.dart';
import 'package:frigate_mobile/features/live/grid_fit.dart';

void main() {
  // Body of the Direct tab on a common phone, bars excluded.
  const portrait = Size(348, 600);
  const landscape = Size(760, 300);

  double ratio(GridFit fit) => fit.tile.width / fit.tile.height;

  group('fitAuto', () {
    test('six cameras on a phone held upright: one page, 2 columns', () {
      final fit = fitAuto(6, portrait);
      expect((fit.columns, fit.rows, fit.perPage), (2, 3, 6));
      // Taller than 16:9 to use the screen, cropped at most to 4:3.
      expect(fit.tile.width, 172);
      expect(ratio(fit), closeTo(4 / 3, 0.001));
      expect(fit.grid.height, lessThanOrEqualTo(portrait.height));
    });

    test('six cameras on a phone turned: 3 columns, 2 rows', () {
      final fit = fitAuto(6, landscape);
      expect((fit.columns, fit.rows, fit.perPage), (3, 2, 6));
      expect(fit.grid.width, lessThanOrEqualTo(landscape.width));
      expect(fit.grid.height, lessThanOrEqualTo(landscape.height));
    });

    test('one camera fills the width', () {
      final fit = fitAuto(1, portrait);
      expect((fit.columns, fit.rows, fit.perPage), (1, 1, 1));
      expect(fit.tile.width, portrait.width);
    });

    test('many cameras: even pages of wide enough tiles', () {
      final fit = fitAuto(20, portrait);
      expect(
        fit.tile.width,
        greaterThanOrEqualTo(GridFitDefaults.minTileWidth),
      );
      final pages = (20 / fit.perPage).ceil();
      // Pages are filled evenly: no last page with a single camera.
      expect(20 - (pages - 1) * fit.perPage, greaterThan(fit.perPage ~/ 2));
    });

    test('tiles always fit the area and keep a camera shape', () {
      for (final area in [portrait, landscape, const Size(800, 600)]) {
        for (var n = 1; n <= 16; n++) {
          final fit = fitAuto(n, area);
          expect(fit.grid.width, lessThanOrEqualTo(area.width + 0.01));
          expect(fit.grid.height, lessThanOrEqualTo(area.height + 0.01));
          expect(ratio(fit), inInclusiveRange(4 / 3 - 0.001, 16 / 9 + 0.001));
          expect(fit.columns * fit.rows, greaterThanOrEqualTo(fit.perPage));
        }
      }
    });

    test('no room at all does not throw', () {
      final fit = fitAuto(4, Size.zero);
      expect(fit.tile, Size.zero);
    });
  });

  test('fixed layouts use square grids as large as possible', () {
    expect((fitFixed(4, portrait).columns, fitFixed(4, portrait).rows), (2, 2));
    expect((fitFixed(9, portrait).columns, fitFixed(9, portrait).rows), (3, 3));
    expect(fitFixed(1, portrait).tile.width, portrait.width);
    expect(fitFixed(6, landscape).perPage, 6);
  });

  test('thumbnail height follows the size of the tile on screen', () {
    expect(LiveDefaults.thumbnailHeightFor(150), 240);
    expect(LiveDefaults.thumbnailHeightFor(390), 360);
    expect(LiveDefaults.thumbnailHeightFor(460), 480);
    expect(LiveDefaults.thumbnailHeightFor(560), 480);
    expect(LiveDefaults.thumbnailHeightFor(700), 720);
    expect(LiveDefaults.thumbnailHeightFor(2000), 720);
  });
}
