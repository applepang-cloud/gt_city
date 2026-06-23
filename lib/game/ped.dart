import 'dart:math';
import 'dart:ui';
import 'constants.dart';
import 'city_map.dart';

enum PedState { idle, walking, fleeing, dead }
enum PedType { civilian, police, paramedic }

final _skinColors = [
  const Color(0xFFDDBB99), const Color(0xFFCCAA88), const Color(0xFFBB9977),
  const Color(0xFFAA8866), const Color(0xFF997755),
];
final _shirtColors = [
  const Color(0xFFDD4444), const Color(0xFF4444DD), const Color(0xFF44AA44),
  const Color(0xFFDDDD44), const Color(0xFFDD44DD), const Color(0xFF44DDDD),
  const Color(0xFFFFFFFF), const Color(0xFF333333), const Color(0xFFFF8800),
];

class Ped {
  double x, y, angle;
  double speed = 0;
  double health = 50;
  PedState state = PedState.walking;
  PedType type;
  Color skinColor;
  Color shirtColor;
  double targetX, targetY;
  double stateTimer = 0;
  double fleeFromX = 0, fleeFromY = 0;

  // Police AI
  bool chasing = false;
  double shootCooldown = 0;

  Ped(this.x, this.y, this.type, Random rng)
      : angle = rng.nextDouble() * 2 * pi,
        targetX = x,
        targetY = y,
        skinColor = type == PedType.police ? const Color(0xFFDDBB99) : _skinColors[rng.nextInt(_skinColors.length)],
        shirtColor = type == PedType.police ? kColorPolicePed : _shirtColors[rng.nextInt(_shirtColors.length)];

  double get radius => kPedRadius;
  bool get alive => state != PedState.dead && health > 0;

  void update(double dt, CityMap map, Random rng, {double? playerX, double? playerY, int wantedLevel = 0}) {
    if (!alive) return;
    stateTimer -= dt;
    shootCooldown = max(0, shootCooldown - dt);

    switch (state) {
      case PedState.idle:
        speed = 0;
        if (stateTimer <= 0) {
          _pickWalkTarget(rng, map);
          state = PedState.walking;
        }
        break;
      case PedState.walking:
        if (type == PedType.police && chasing && playerX != null) {
          _chasePlayer(dt, playerX, playerY!, wantedLevel);
        } else {
          _walkToTarget(dt, rng, map);
        }
        break;
      case PedState.fleeing:
        _flee(dt, map);
        if (stateTimer <= 0) {
          state = PedState.walking;
          _pickWalkTarget(rng, map);
        }
        break;
      case PedState.dead:
        break;
    }

    if (speed.abs() > 0.1) {
      final nx = x + cos(angle) * speed * dt;
      final ny = y + sin(angle) * speed * dt;
      if (!map.isSolid(nx, ny, radius)) {
        x = nx;
        y = ny;
      } else {
        angle += pi / 2;
      }
    }

    x = x.clamp(2.0, kWorldW - 2);
    y = y.clamp(2.0, kWorldH - 2);
  }

  void _pickWalkTarget(Random rng, CityMap map) {
    final road = map.nearestRoadCenter(x, y);
    targetX = road.dx + (rng.nextDouble() - 0.5) * 200;
    targetY = road.dy + (rng.nextDouble() - 0.5) * 200;
    stateTimer = 3 + rng.nextDouble() * 8;
  }

  void _walkToTarget(double dt, Random rng, CityMap map) {
    final dx = targetX - x;
    final dy = targetY - y;
    final dist = sqrt(dx * dx + dy * dy);
    if (dist < 10 || stateTimer <= 0) {
      state = PedState.idle;
      stateTimer = 1 + rng.nextDouble() * 4;
      return;
    }
    angle = atan2(dy, dx);
    speed = kPedSpeed;
  }

  void _chasePlayer(double dt, double px, double py, int wantedLevel) {
    final dx = px - x;
    final dy = py - y;
    final dist = sqrt(dx * dx + dy * dy);
    angle = atan2(dy, dx);
    speed = kPedSpeed * (1.2 + wantedLevel * 0.1);
    if (dist < 200 && wantedLevel >= 2) {
      shootCooldown = max(0, shootCooldown);
    }
  }

  void _flee(double dt, CityMap map) {
    final dx = x - fleeFromX;
    final dy = y - fleeFromY;
    angle = atan2(dy, dx);
    speed = kPedFleeSpeed;
  }

  void startFleeing(double fromX, double fromY, Random rng) {
    if (type == PedType.police) return;
    state = PedState.fleeing;
    fleeFromX = fromX;
    fleeFromY = fromY;
    stateTimer = 3 + rng.nextDouble() * 4;
  }

  void takeDamage(double dmg) {
    health = max(0, health - dmg);
    if (health <= 0) {
      state = PedState.dead;
      speed = 0;
    }
  }
}
