import 'dart:ui';

const double kTileSize = 40.0;
const int kCityBlocksX = 12;
const int kCityBlocksY = 12;
const int kBlockTiles = 8;
const double kBlockSize = kTileSize * kBlockTiles;
const double kRoadWidth = kTileSize * 2;
const double kSidewalkWidth = kTileSize * 0.5;
const double kWorldW = kCityBlocksX * (kBlockSize + kRoadWidth) + kRoadWidth;
const double kWorldH = kCityBlocksY * (kBlockSize + kRoadWidth) + kRoadWidth;

const double kPlayerSpeed = 160.0;
const double kPlayerRunSpeed = 260.0;
const double kPlayerRadius = 8.0;
const double kPlayerMaxHealth = 100.0;
const double kPlayerMaxArmor = 100.0;

const double kCarMaxSpeed = 400.0;
const double kCarAccel = 200.0;
const double kCarBrake = 300.0;
const double kCarSteer = 2.8;
const double kCarFriction = 0.97;
const double kCarLength = 32.0;
const double kCarWidth = 16.0;

const double kPedSpeed = 80.0;
const double kPedFleeSpeed = 180.0;
const double kPedRadius = 6.0;
const double kPedSpawnRange = 800.0;
const double kPedDespawnRange = 1200.0;
const int kMaxPeds = 40;
const int kMaxTrafficCars = 20;

const double kBulletSpeed = 600.0;
const double kMeleeRange = 28.0;

const double kMinimapSize = 140.0;
const double kMinimapRange = 600.0;

const Color kColorRoad = Color(0xFF3A3A3A);
const Color kColorSidewalk = Color(0xFF8A8A7A);
const Color kColorGrass = Color(0xFF2D6E2D);
const Color kColorWater = Color(0xFF1A4A7A);
const Color kColorBuilding1 = Color(0xFF6B6B6B);
const Color kColorBuilding2 = Color(0xFF8B7B6B);
const Color kColorBuilding3 = Color(0xFF5B6B7B);
const Color kColorBuilding4 = Color(0xFF7B6B5B);
const Color kColorBuildingRoof = Color(0xFF555555);
const Color kColorPlayer = Color(0xFF4488FF);
const Color kColorPed = Color(0xFFCCBB99);
const Color kColorPolicePed = Color(0xFF3355AA);
const Color kColorPoliceCarBody = Color(0xFF223388);

enum District { industrial, commercial, suburban }

District districtAt(double x, double y) {
  final fx = x / kWorldW;
  final fy = y / kWorldH;
  if (fx < 0.35) return District.industrial;
  if (fx > 0.65 || fy > 0.6) return District.suburban;
  return District.commercial;
}
