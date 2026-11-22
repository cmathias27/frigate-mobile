import 'dart:math' as math;
import 'dart:ui' show Size;

/// Default grid settings (decision 0002: a default value now, an optional
/// setting later).
abstract final class GridFitDefaults {
  /// Tiles are cropped to a shape between these two width / height ratios:
  /// wide like most cameras, up to 4:3 to use a tall screen.
  static const widest = 16 / 9;
  static const tallest = 4 / 3;

  /// Below this width (logical pixels) a tile is too small to see anything:
  /// the automatic layout then spreads the cameras over pages.
  static const minTileWidth = 150.0;

  /// Space between tiles and around the grid.
  static const spacing = 4.0;
  static const padding = 6.0;
}

/// How a page of the live grid is laid out.
class GridFit {
  final int columns;
  final int rows;

  /// Cameras on a full page.
  final int perPage;

  /// Size of every tile, the same on all pages.
  final Size tile;

  const GridFit({
    required this.columns,
    required this.rows,
    required this.perPage,
    required this.tile,
  });

  /// Size of the grid of a full page, spacing included.
  Size get grid => Size(
    columns * tile.width + (columns - 1) * GridFitDefaults.spacing,
    rows * tile.height + (rows - 1) * GridFitDefaults.spacing,
  );

  @override
  String toString() =>
      'GridFit($columns×$rows, $perPage per page, '
      '${tile.width.toStringAsFixed(1)}×${tile.height.toStringAsFixed(1)})';
}

/// The largest tile showing [count] cameras in [area] (padding excluded),
/// trying every number of columns.
GridFit fitCameras(int count, Size area) {
  GridFit? best;
  for (var columns = 1; columns <= math.max(1, count); columns++) {
    final rows = (count / columns).ceil();
    final fit = _fit(columns, math.max(1, rows), count, area);
    if (best == null || _area(fit) > _area(best) + 0.5) best = fit;
  }
  return best!;
}

/// A fixed layout: [perPage] cameras on a square grid (1, 4, 9…), tiles as
/// large as the area allows.
GridFit fitFixed(int perPage, Size area) {
  final side = math.sqrt(perPage).ceil();
  return _fit(side, (perPage / side).ceil(), perPage, area);
}

/// The automatic layout: every camera on one page when its tiles stay wide
/// enough, otherwise as few pages as possible, evenly filled.
GridFit fitAuto(
  int count,
  Size area, {
  double minTileWidth = GridFitDefaults.minTileWidth,
}) {
  if (count <= 1) return fitCameras(1, area);
  for (var pages = 1; pages <= count; pages++) {
    final perPage = (count / pages).ceil();
    final fit = fitCameras(perPage, area);
    if (fit.tile.width >= minTileWidth || perPage == 1) return fit;
  }
  return fitCameras(1, area);
}

double _area(GridFit fit) => fit.tile.width * fit.tile.height;

GridFit _fit(int columns, int rows, int perPage, Size area) {
  const spacing = GridFitDefaults.spacing;
  final cellWidth = math.max(
    0.0,
    (area.width - (columns - 1) * spacing) / columns,
  );
  final cellHeight = math.max(0.0, (area.height - (rows - 1) * spacing) / rows);
  var width = cellWidth;
  var height = cellHeight;
  if (cellHeight == 0 || cellWidth / cellHeight > GridFitDefaults.widest) {
    // Wide cell: full height, width cut to the widest shape.
    width = height * GridFitDefaults.widest;
  } else if (cellWidth / cellHeight < GridFitDefaults.tallest) {
    // Tall cell: full width, height cut to the tallest shape.
    height = width / GridFitDefaults.tallest;
  }
  return GridFit(
    columns: columns,
    rows: rows,
    perPage: perPage,
    tile: Size(width, height),
  );
}
