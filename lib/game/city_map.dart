import 'dart:math';
import 'dart:ui';
import 'constants.dart';

class Building {
  final Rect rect;
  final Color color;
  final Color roofColor;
  final double height;
  Building(this.rect, this.color, this.roofColor, this.height);
}

class CityMap {
  final List<Building> buildings = [];
  final List<Rect> roads = [];
  final List<Rect> sidewalks = [];
  final List<Rect> parks = [];
  final List<Rect> waterAreas = [];
  final Random _rng = Random(42);

  void generate() {
    buildings.clear();
    roads.clear();
    sidewalks.clear();
    parks.clear();
    waterAreas.clear();

    final stride = kBlockSize + kRoadWidth;

    // Water borders
    waterAreas.add(Rect.fromLTWH(-200, -200, kWorldW + 400, 200));
    waterAreas.add(Rect.fromLTWH(-200, kWorldH, kWorldW + 400, 200));
    waterAreas.add(Rect.fromLTWH(-200, -200, 200, kWorldH + 400));
    waterAreas.add(Rect.fromLTWH(kWorldW, -200, 200, kWorldH + 400));

    // Horizontal roads
    for (int y = 0; y <= kCityBlocksY; y++) {
      final ry = y * stride;
      roads.add(Rect.fromLTWH(0, ry, kWorldW, kRoadWidth));
      sidewalks.add(Rect.fromLTWH(0, ry - kSidewalkWidth, kWorldW, kSidewalkWidth));
      sidewalks.add(Rect.fromLTWH(0, ry + kRoadWidth, kWorldW, kSidewalkWidth));
    }

    // Vertical roads
    for (int x = 0; x <= kCityBlocksX; x++) {
      final rx = x * stride;
      roads.add(Rect.fromLTWH(rx, 0, kRoadWidth, kWorldH));
      sidewalks.add(Rect.fromLTWH(rx - kSidewalkWidth, 0, kSidewalkWidth, kWorldH));
      sidewalks.add(Rect.fromLTWH(rx + kRoadWidth, 0, kSidewalkWidth, kWorldH));
    }

    // City blocks
    for (int bx = 0; bx < kCityBlocksX; bx++) {
      for (int by = 0; by < kCityBlocksY; by++) {
        final ox = kRoadWidth + bx * stride;
        final oy = kRoadWidth + by * stride;
        final blockRect = Rect.fromLTWH(ox, oy, kBlockSize, kBlockSize);
        final dist = districtAt(ox, oy);

        // Some blocks are parks
        if (_rng.nextDouble() < 0.12) {
          parks.add(blockRect);
          continue;
        }

        _generateBlockBuildings(blockRect, dist);
      }
    }
  }

  void _generateBlockBuildings(Rect block, District dist) {
    final margin = 4.0;
    final inner = block.deflate(margin);
    int divisions = dist == District.commercial ? _rng.nextInt(2) + 2 : _rng.nextInt(3) + 1;

    if (dist == District.industrial) {
      // Large warehouses
      final cols = _rng.nextInt(2) + 1;
      final rows = _rng.nextInt(2) + 1;
      final cw = inner.width / cols;
      final rh = inner.height / rows;
      for (int c = 0; c < cols; c++) {
        for (int r = 0; r < rows; r++) {
          final br = Rect.fromLTWH(
            inner.left + c * cw + 2, inner.top + r * rh + 2,
            cw - 4, rh - 4,
          );
          final colors = [kColorBuilding1, kColorBuilding4];
          buildings.add(Building(
            br, colors[_rng.nextInt(colors.length)],
            kColorBuildingRoof, 10 + _rng.nextDouble() * 15,
          ));
        }
      }
    } else if (dist == District.commercial) {
      // Tall office buildings
      final cols = _rng.nextInt(2) + 2;
      final rows = _rng.nextInt(2) + 2;
      final cw = inner.width / cols;
      final rh = inner.height / rows;
      for (int c = 0; c < cols; c++) {
        for (int r = 0; r < rows; r++) {
          if (_rng.nextDouble() < 0.15) continue;
          final br = Rect.fromLTWH(
            inner.left + c * cw + 2, inner.top + r * rh + 2,
            cw - 4, rh - 4,
          );
          final colors = [kColorBuilding1, kColorBuilding2, kColorBuilding3];
          buildings.add(Building(
            br, colors[_rng.nextInt(colors.length)],
            kColorBuildingRoof, 20 + _rng.nextDouble() * 40,
          ));
        }
      }
    } else {
      // Suburban houses
      final cols = _rng.nextInt(2) + 2;
      final rows = _rng.nextInt(2) + 2;
      final cw = inner.width / cols;
      final rh = inner.height / rows;
      for (int c = 0; c < cols; c++) {
        for (int r = 0; r < rows; r++) {
          if (_rng.nextDouble() < 0.25) continue;
          final hw = cw * (0.5 + _rng.nextDouble() * 0.3);
          final hh = rh * (0.5 + _rng.nextDouble() * 0.3);
          final br = Rect.fromLTWH(
            inner.left + c * cw + (cw - hw) / 2,
            inner.top + r * rh + (rh - hh) / 2,
            hw, hh,
          );
          final colors = [kColorBuilding2, kColorBuilding4, const Color(0xFF9B8B7B)];
          buildings.add(Building(
            br, colors[_rng.nextInt(colors.length)],
            const Color(0xFF8B4444), 8 + _rng.nextDouble() * 8,
          ));
        }
      }
    }
  }

  bool isRoad(double x, double y) {
    final stride = kBlockSize + kRoadWidth;
    final mx = x % stride;
    final my = y % stride;
    return mx < kRoadWidth || my < kRoadWidth;
  }

  bool isSolid(double x, double y, double radius) {
    for (final b in buildings) {
      if (b.rect.inflate(radius).contains(Offset(x, y))) return true;
    }
    for (final w in waterAreas) {
      if (w.inflate(radius).contains(Offset(x, y))) return true;
    }
    return x < 0 || y < 0 || x > kWorldW || y > kWorldH;
  }

  Offset nearestRoadCenter(double x, double y) {
    final stride = kBlockSize + kRoadWidth;
    final bx = (x / stride).floor();
    final by = (y / stride).floor();
    final roadCenterX = bx * stride + kRoadWidth / 2;
    final roadCenterY = by * stride + kRoadWidth / 2;
    final mx = x % stride;
    final my = y % stride;
    if (mx < kRoadWidth) return Offset(roadCenterX, y);
    if (my < kRoadWidth) return Offset(x, roadCenterY);
    return Offset(roadCenterX, roadCenterY);
  }

  List<Offset> roadWaypoints(double x, double y, int count) {
    final stride = kBlockSize + kRoadWidth;
    final half = kRoadWidth / 2;
    final lane = kRoadWidth * 0.25;
    final pts = <Offset>[];
    var cx = x;
    var cy = y;
    final rng = Random();
    for (int i = 0; i < count; i++) {
      final bx = (cx / stride).floor();
      final by = (cy / stride).floor();
      // Pick random adjacent intersection
      final dirs = <Offset>[];
      if (bx > 0) dirs.add(Offset((bx) * stride + half, (by) * stride + half + lane));
      if (bx < kCityBlocksX) dirs.add(Offset((bx + 1) * stride + half, (by) * stride + half + lane));
      if (by > 0) dirs.add(Offset((bx) * stride + half + lane, (by) * stride + half));
      if (by < kCityBlocksY) dirs.add(Offset((bx) * stride + half + lane, (by + 1) * stride + half));
      if (dirs.isEmpty) break;
      final next = dirs[rng.nextInt(dirs.length)];
      pts.add(next);
      cx = next.dx;
      cy = next.dy;
    }
    return pts;
  }
}
