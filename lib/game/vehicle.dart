import 'dart:math';
import 'dart:ui';
import 'constants.dart';
import 'city_map.dart';

enum VehicleType {
  sedan, sports, truck, taxi, policeCar, ambulance, fireTruck,
}

class VehicleInfo {
  final String name;
  final Color color;
  final double maxSpeed, accel, length, width;
  final bool isLawEnforcement;
  const VehicleInfo({
    required this.name, required this.color,
    this.maxSpeed = kCarMaxSpeed, this.accel = kCarAccel,
    this.length = kCarLength, this.width = kCarWidth,
    this.isLawEnforcement = false,
  });
}

const _vehicleData = <VehicleType, VehicleInfo>{
  VehicleType.sedan: VehicleInfo(name: 'Sedan', color: Color(0xFF885544)),
  VehicleType.sports: VehicleInfo(name: 'Sports', color: Color(0xFFCC3333), maxSpeed: 520, accel: 280),
  VehicleType.truck: VehicleInfo(name: 'Truck', color: Color(0xFF556655), maxSpeed: 300, accel: 140, length: 44, width: 20),
  VehicleType.taxi: VehicleInfo(name: 'Taxi', color: Color(0xFFCCBB33)),
  VehicleType.policeCar: VehicleInfo(name: 'Police', color: kColorPoliceCarBody, maxSpeed: 480, accel: 250, isLawEnforcement: true),
  VehicleType.ambulance: VehicleInfo(name: 'Ambulance', color: Color(0xFFDDDDDD), maxSpeed: 380, accel: 200, length: 40, width: 18),
  VehicleType.fireTruck: VehicleInfo(name: 'FireTruck', color: Color(0xFFCC2222), maxSpeed: 340, accel: 160, length: 48, width: 20),
};

final _civilianColors = [
  const Color(0xFF885544), const Color(0xFF445588), const Color(0xFF558844),
  const Color(0xFF884488), const Color(0xFF888844), const Color(0xFF448888),
  const Color(0xFF666666), const Color(0xFFAA6633), const Color(0xFF336699),
  const Color(0xFF993333), const Color(0xFF339933), const Color(0xFFCC8844),
];

class Vehicle {
  double x, y, angle;
  double speed = 0;
  double steer = 0;
  double health = 100;
  VehicleType type;
  late VehicleInfo info;
  Color bodyColor;
  bool occupied = false;
  bool isPlayerVehicle = false;

  // AI
  List<Offset> waypoints = [];
  int waypointIdx = 0;
  bool isPoliceChase = false;
  double aiThrottle = 0;
  double aiSteer = 0;

  Vehicle(this.x, this.y, this.angle, this.type, [Color? color])
      : bodyColor = color ?? _vehicleData[type]!.color {
    info = _vehicleData[type]!;
  }

  double get length => info.length;
  double get width => info.width;
  double get maxSpeed => info.maxSpeed;

  Rect get bounds => Rect.fromCenter(
    center: Offset(x, y), width: length + 4, height: width + 4,
  );

  void update(double dt, CityMap map, {double throttle = 0, double steering = 0}) {
    if (health <= 0) return;

    final t = occupied && isPlayerVehicle ? throttle : aiThrottle;
    final s = occupied && isPlayerVehicle ? steering : aiSteer;

    if (t > 0) {
      speed += info.accel * t * dt;
    } else if (t < 0) {
      speed -= kCarBrake * dt;
    }
    speed = speed.clamp(-maxSpeed * 0.3, maxSpeed);
    speed *= kCarFriction;

    if (speed.abs() > 5) {
      angle += s * kCarSteer * dt * (speed / maxSpeed).clamp(-1, 1);
    }

    final nx = x + cos(angle) * speed * dt;
    final ny = y + sin(angle) * speed * dt;

    if (!map.isSolid(nx, ny, width / 2)) {
      x = nx;
      y = ny;
    } else {
      speed *= -0.3;
    }

    x = x.clamp(0, kWorldW);
    y = y.clamp(0, kWorldH);
  }

  void updateAI(double dt, CityMap map, {double? chaseX, double? chaseY}) {
    if (isPlayerVehicle && occupied) return;
    if (health <= 0) { aiThrottle = 0; return; }

    if (isPoliceChase && chaseX != null && chaseY != null) {
      _chaseTarget(dt, chaseX, chaseY);
      return;
    }

    if (waypoints.isEmpty || waypointIdx >= waypoints.length) {
      waypoints = map.roadWaypoints(x, y, 8);
      waypointIdx = 0;
    }

    if (waypointIdx < waypoints.length) {
      final wp = waypoints[waypointIdx];
      final dx = wp.dx - x;
      final dy = wp.dy - y;
      final dist = sqrt(dx * dx + dy * dy);
      if (dist < 30) {
        waypointIdx++;
      } else {
        final targetAngle = atan2(dy, dx);
        var diff = targetAngle - angle;
        while (diff > pi) diff -= 2 * pi;
        while (diff < -pi) diff += 2 * pi;
        aiSteer = diff.clamp(-1.0, 1.0);
        aiThrottle = dist > 60 ? 0.6 : 0.3;
      }
    }
  }

  void _chaseTarget(double dt, double tx, double ty) {
    final dx = tx - x;
    final dy = ty - y;
    final dist = sqrt(dx * dx + dy * dy);
    final targetAngle = atan2(dy, dx);
    var diff = targetAngle - angle;
    while (diff > pi) diff -= 2 * pi;
    while (diff < -pi) diff += 2 * pi;
    aiSteer = diff.clamp(-1.0, 1.0);
    aiThrottle = dist > 40 ? 0.9 : 0.4;
  }

  void takeDamage(double dmg) {
    health = max(0, health - dmg);
  }

  static Vehicle randomCivilian(Random rng, double x, double y) {
    final types = [VehicleType.sedan, VehicleType.sedan, VehicleType.sports,
                   VehicleType.truck, VehicleType.taxi];
    final type = types[rng.nextInt(types.length)];
    final color = type == VehicleType.taxi ? null : _civilianColors[rng.nextInt(_civilianColors.length)];
    final angle = rng.nextDouble() * 2 * pi;
    return Vehicle(x, y, angle, type, color);
  }
}
