import 'dart:math';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'constants.dart';
import 'city_map.dart';
import 'vehicle.dart';
import 'ped.dart';
import 'weapon.dart';
import 'pickup.dart';
import 'wanted.dart';
import 'projectile.dart';
import 'mission.dart';
import 'audio.dart';
import 'sprites.dart';

class GtCityGame extends FlameGame with KeyboardEvents {
  final CityMap cityMap = CityMap();
  final Random rng = Random();
  final WantedSystem wanted = WantedSystem();
  final WeaponInventory weapons = WeaponInventory();
  final MissionSystem missions = MissionSystem();
  final AudioManager audio = AudioManager();
  bool showMissionMenu = false;

  // Player state
  double playerX = 0, playerY = 0, playerAngle = 0;
  double playerWalkPhase = 0;
  double _shootSndCd = 0;
  double playerHealth = kPlayerMaxHealth;
  double playerArmor = 0;
  int playerMoney = 0;
  bool playerInVehicle = false;
  Vehicle? playerVehicle;
  double enterVehicleCooldown = 0;

  // Input
  double joyX = 0, joyY = 0;
  bool fireHeld = false;
  bool runHeld = false;

  // Entities
  final List<Vehicle> vehicles = [];
  final List<Ped> peds = [];
  final List<Pickup> pickups = [];
  final List<Projectile> projectiles = [];
  final List<BulletTrail> trails = [];
  final List<Explosion> explosions = [];
  final List<FlameParticle> flames = [];

  // Camera
  double camX = 0, camY = 0;

  // Keys held
  final Set<LogicalKeyboardKey> _keys = {};
  int? joyPointer;

  // Notify HUD
  final ValueNotifier<int> hudNotifier = ValueNotifier(0);
  String? messageText;
  double messageTimer = 0;

  // Expose held keys for the on-screen control display
  Set<LogicalKeyboardKey> get heldKeys => _keys;

  @override
  Future<void> onLoad() async {
    await audio.init();
    cityMap.generate();

    // Spawn player at center of map
    final stride = kBlockSize + kRoadWidth;
    playerX = 6 * stride + kRoadWidth / 2;
    playerY = 6 * stride + kRoadWidth / 2;

    _spawnInitialEntities();
    _spawnPickups();
    missions.generate(rng, kWorldW, kWorldH);
  }

  void _spawnInitialEntities() {
    // Spawn traffic
    for (int i = 0; i < kMaxTrafficCars; i++) {
      _spawnTrafficCar();
    }
    // Spawn peds
    for (int i = 0; i < kMaxPeds; i++) {
      _spawnPed();
    }
  }

  void _spawnTrafficCar() {
    final stride = kBlockSize + kRoadWidth;
    final lane = kRoadWidth * 0.3;
    for (int attempt = 0; attempt < 20; attempt++) {
      final bx = rng.nextInt(kCityBlocksX + 1);
      final by = rng.nextInt(kCityBlocksY + 1);
      final onHoriz = rng.nextBool();
      double sx, sy, sa;
      if (onHoriz) {
        sx = bx * stride + kRoadWidth + rng.nextDouble() * kBlockSize;
        sy = by * stride + lane;
        sa = 0;
      } else {
        sx = bx * stride + lane;
        sy = by * stride + kRoadWidth + rng.nextDouble() * kBlockSize;
        sa = pi / 2;
      }
      sx = sx.clamp(5.0, kWorldW - 5);
      sy = sy.clamp(5.0, kWorldH - 5);
      if (_tooCloseToPlayer(sx, sy, 300)) continue;
      if (cityMap.isSolid(sx, sy, kCarWidth)) continue;
      final v = Vehicle.randomCivilian(rng, sx, sy);
      v.angle = sa;
      v.waypoints = cityMap.roadWaypoints(sx, sy, 8);
      vehicles.add(v);
      return;
    }
  }

  void _spawnPed() {
    for (int attempt = 0; attempt < 20; attempt++) {
      final sx = rng.nextDouble() * kWorldW;
      final sy = rng.nextDouble() * kWorldH;
      if (cityMap.isSolid(sx, sy, kPedRadius)) continue;
      if (_tooCloseToPlayer(sx, sy, 100)) continue;
      peds.add(Ped(sx, sy, PedType.civilian, rng));
      return;
    }
  }

  void _spawnPickups() {
    final stride = kBlockSize + kRoadWidth;
    final half = kRoadWidth / 2;
    // Weapon pickups at intersections
    final weaponTypes = [
      WeaponType.baseballBat, WeaponType.colt45, WeaponType.uzi,
      WeaponType.shotgun, WeaponType.ak47, WeaponType.m16,
      WeaponType.sniperRifle, WeaponType.rocketLauncher,
      WeaponType.flamethrower, WeaponType.molotov, WeaponType.grenade,
    ];
    for (int i = 0; i < 30; i++) {
      final bx = rng.nextInt(kCityBlocksX);
      final by = rng.nextInt(kCityBlocksY);
      final px = bx * stride + half + kBlockSize / 2 + rng.nextDouble() * 60 - 30;
      final py = by * stride + half + kBlockSize / 2 + rng.nextDouble() * 60 - 30;
      if (cityMap.isSolid(px, py, 10)) continue;
      final wt = weaponTypes[rng.nextInt(weaponTypes.length)];
      final ammo = weaponData[wt]!.magSize * (2 + rng.nextInt(3));
      pickups.add(Pickup(px, py, PickupType.weapon, weaponType: wt, amount: ammo));
    }
    // Health/Armor/Money
    for (int i = 0; i < 20; i++) {
      final px = rng.nextDouble() * kWorldW;
      final py = rng.nextDouble() * kWorldH;
      if (cityMap.isSolid(px, py, 10)) continue;
      final types = [PickupType.health, PickupType.armor, PickupType.money];
      final t = types[rng.nextInt(types.length)];
      final amt = t == PickupType.money ? 100 + rng.nextInt(400) : 25;
      pickups.add(Pickup(px, py, t, amount: amt));
    }
  }

  bool _tooCloseToPlayer(double x, double y, double dist) {
    final dx = x - playerX;
    final dy = y - playerY;
    return dx * dx + dy * dy < dist * dist;
  }

  @override
  void update(double dt) {
    super.update(dt);
    final cdt = dt.clamp(0.0, 0.05);

    _processInput();
    _updatePlayer(cdt);
    _updateVehicles(cdt);
    _updatePeds(cdt);
    _updateProjectiles(cdt);
    _updatePickups(cdt);
    _updateExplosions(cdt);
    wanted.update(cdt);
    weapons.update(cdt);
    missions.update(cdt);
    missions.onSurviveTick(cdt, wanted.level);
    missions.checkReachLocation(playerX, playerY);
    _checkMissionComplete();
    _managePopulation();
    _spawnPolice();
    _updateCamera();
    _updateMessage(cdt);
    enterVehicleCooldown = max(0, enterVehicleCooldown - cdt);
    _shootSndCd = max(0, _shootSndCd - cdt);

    // Audio beds
    audio.setEngine(playerInVehicle,
        (playerVehicle?.speed.abs() ?? 0) / kCarMaxSpeed);
    audio.setSiren(wanted.level >= 1);

    hudNotifier.value++;
  }

  void _processInput() {
    // Keyboard → virtual joystick
    double kx = 0, ky = 0;
    if (_keys.contains(LogicalKeyboardKey.keyW) || _keys.contains(LogicalKeyboardKey.arrowUp)) ky -= 1;
    if (_keys.contains(LogicalKeyboardKey.keyS) || _keys.contains(LogicalKeyboardKey.arrowDown)) ky += 1;
    if (_keys.contains(LogicalKeyboardKey.keyA) || _keys.contains(LogicalKeyboardKey.arrowLeft)) kx -= 1;
    if (_keys.contains(LogicalKeyboardKey.keyD) || _keys.contains(LogicalKeyboardKey.arrowRight)) kx += 1;
    runHeld = _keys.contains(LogicalKeyboardKey.shiftLeft) || _keys.contains(LogicalKeyboardKey.shiftRight);

    if (kx != 0 || ky != 0) {
      final len = sqrt(kx * kx + ky * ky);
      joyX = kx / len;
      joyY = ky / len;
    } else if (joyPointer == null) {
      joyX = 0;
      joyY = 0;
    }

    if (_keys.contains(LogicalKeyboardKey.space)) fireHeld = true;
  }

  void _updatePlayer(double dt) {
    if (playerHealth <= 0) {
      _onPlayerDeath();
      return;
    }

    if (playerInVehicle && playerVehicle != null) {
      _updatePlayerInVehicle(dt);
    } else {
      _updatePlayerOnFoot(dt);
    }

    // Fire weapon (on foot or drive-by)
    if (fireHeld) {
      _fireWeapon();
    }
    fireHeld = false;
  }

  void _updatePlayerOnFoot(double dt) {
    if (joyX != 0 || joyY != 0) {
      playerAngle = atan2(joyY, joyX);
      final spd = runHeld ? kPlayerRunSpeed : kPlayerSpeed;
      final nx = playerX + joyX * spd * dt;
      final ny = playerY + joyY * spd * dt;
      if (!cityMap.isSolid(nx, ny, kPlayerRadius)) {
        playerX = nx;
        playerY = ny;
      }
      playerWalkPhase += spd * dt * 0.045;
    }

    // Collect money from dead peds nearby
    for (final p in peds) {
      if (p.alive) continue;
      final dx = p.x - playerX;
      final dy = p.y - playerY;
      if (dx * dx + dy * dy < 25 * 25) {
        p.x = -9999; // mark collected
      }
    }
  }

  void _updatePlayerInVehicle(double dt) {
    final v = playerVehicle!;
    double throttle = 0, steering = 0;
    if (joyY < -0.3) throttle = 1;
    if (joyY > 0.3) throttle = -1;
    if (joyX < -0.3) steering = -1;
    if (joyX > 0.3) steering = 1;
    v.update(dt, cityMap, throttle: throttle, steering: steering);
    playerX = v.x;
    playerY = v.y;
    playerAngle = v.angle;

    // Run over peds
    for (final p in peds) {
      if (!p.alive) continue;
      final dx = p.x - v.x;
      final dy = p.y - v.y;
      if (dx * dx + dy * dy < (v.width / 2 + p.radius) * (v.width / 2 + p.radius) &&
          v.speed.abs() > 50) {
        p.takeDamage(v.speed.abs() * 0.5);
        if (!p.alive) {
          if (p.type == PedType.police) {
            wanted.onCopKilled();
          } else {
            wanted.onPedKilled();
          }
          playerMoney += 10;
        }
      }
    }
  }

  void _fireWeapon() {
    final w = weapons.current;
    if (!w.tryFire()) return;
    final info = w.info;

    switch (info.fireType) {
      case WeaponFire.melee:
        _doMelee(info.damage, info.range);
        break;
      case WeaponFire.instantHit:
        _doInstantHit(info);
        break;
      case WeaponFire.projectile:
        _doProjectile(w.type, info);
        break;
      case WeaponFire.areaEffect:
        _doFlame(info);
        break;
    }
  }

  void _doMelee(double damage, double range) {
    final tx = playerX + cos(playerAngle) * range;
    final ty = playerY + sin(playerAngle) * range;
    for (final p in peds) {
      if (!p.alive) continue;
      final dx = p.x - tx;
      final dy = p.y - ty;
      if (dx * dx + dy * dy < 20 * 20) {
        p.takeDamage(damage);
        audio.sfx('punch', volume: 0.7);
        if (!p.alive) {
          _onPedKilled(p);
        }
        break;
      }
    }
  }

  void _doInstantHit(WeaponInfo info) {
    final spread = (rng.nextDouble() - 0.5) * info.spread;
    final a = playerAngle + spread;
    final ex = playerX + cos(a) * info.range;
    final ey = playerY + sin(a) * info.range;
    trails.add(BulletTrail(playerX, playerY, ex, ey));
    if (_shootSndCd <= 0) {
      audio.sfx('shoot', volume: 0.55);
      _shootSndCd = 0.06;
    }
    wanted.addHeat(2);
    _fleePedsNear(playerX, playerY, 200);

    // Hit check
    double bestDist = info.range;
    dynamic bestTarget;
    for (final p in peds) {
      if (!p.alive) continue;
      final d = _pointLineDistance(p.x, p.y, playerX, playerY, ex, ey);
      final along = _projectionAlong(p.x, p.y, playerX, playerY, a);
      if (d < p.radius + 4 && along > 0 && along < bestDist) {
        bestDist = along;
        bestTarget = p;
      }
    }
    for (final v in vehicles) {
      if (v == playerVehicle) continue;
      final d = _pointLineDistance(v.x, v.y, playerX, playerY, ex, ey);
      final along = _projectionAlong(v.x, v.y, playerX, playerY, a);
      if (d < v.width && along > 0 && along < bestDist) {
        bestDist = along;
        bestTarget = v;
      }
    }
    if (bestTarget is Ped) {
      bestTarget.takeDamage(info.damage);
      if (!bestTarget.alive) _onPedKilled(bestTarget);
    } else if (bestTarget is Vehicle) {
      bestTarget.takeDamage(info.damage);
      if (bestTarget.health <= 0) _onVehicleDestroyed(bestTarget);
    }
  }

  void _doProjectile(WeaponType wt, WeaponInfo info) {
    projectiles.add(Projectile(
      x: playerX, y: playerY, angle: playerAngle,
      speed: info.projectileSpeed, damage: info.damage,
      blastRadius: info.blastRadius, sourceWeapon: wt,
    ));
    audio.sfx('shoot', volume: 0.5);
    wanted.addHeat(5);
    _fleePedsNear(playerX, playerY, 300);
  }

  void _doFlame(WeaponInfo info) {
    final a = playerAngle + (rng.nextDouble() - 0.5) * info.spread;
    final spd = 150 + rng.nextDouble() * 100;
    flames.add(FlameParticle(
      playerX + cos(playerAngle) * 15, playerY + sin(playerAngle) * 15,
      cos(a) * spd, sin(a) * spd,
    ));
    // Damage nearby in cone
    for (final p in peds) {
      if (!p.alive) continue;
      final dx = p.x - playerX;
      final dy = p.y - playerY;
      final dist = sqrt(dx * dx + dy * dy);
      if (dist > info.range) continue;
      final pa = atan2(dy, dx);
      var diff = pa - playerAngle;
      while (diff > pi) diff -= 2 * pi;
      while (diff < -pi) diff += 2 * pi;
      if (diff.abs() < 0.4) {
        p.takeDamage(info.damage);
        if (!p.alive) _onPedKilled(p);
      }
    }
    wanted.addHeat(1);
  }

  void _onPedKilled(Ped p) {
    if (p.type == PedType.police) {
      wanted.onCopKilled();
    } else {
      wanted.onPedKilled();
    }
    final earn = 10 + rng.nextInt(20);
    playerMoney += earn;
    missions.onPedKilled();
    missions.onMoneyCollected(earn);
  }

  void _onVehicleDestroyed(Vehicle v) {
    explosions.add(Explosion(v.x, v.y, 50));
    audio.sfx('explosion', volume: 1.0);
    if (v.info.isLawEnforcement) {
      wanted.onCopCarDestroyed();
    } else {
      wanted.onVehicleDestroyed();
    }
    missions.onVehicleDestroyed();
    // Blast damage
    for (final p in peds) {
      if (!p.alive) continue;
      final dx = p.x - v.x;
      final dy = p.y - v.y;
      if (dx * dx + dy * dy < 60 * 60) {
        p.takeDamage(80);
        if (!p.alive) _onPedKilled(p);
      }
    }
  }

  void _fleePedsNear(double x, double y, double range) {
    for (final p in peds) {
      if (!p.alive || p.type == PedType.police) continue;
      final dx = p.x - x;
      final dy = p.y - y;
      if (dx * dx + dy * dy < range * range) {
        p.startFleeing(x, y, rng);
      }
    }
  }

  void _updateVehicles(double dt) {
    for (final v in vehicles) {
      v.updateAI(dt, cityMap,
        chaseX: wanted.level > 0 ? playerX : null,
        chaseY: wanted.level > 0 ? playerY : null,
      );
      if (!(v.isPlayerVehicle && v.occupied)) {
        v.update(dt, cityMap);
      }
    }
  }

  void _updatePeds(double dt) {
    for (final p in peds) {
      p.update(dt, cityMap, rng,
        playerX: playerX, playerY: playerY,
        wantedLevel: wanted.level,
      );
      // Police shoot at player
      if (p.type == PedType.police && p.chasing && p.shootCooldown <= 0 && wanted.level >= 2) {
        final dx = playerX - p.x;
        final dy = playerY - p.y;
        final dist = sqrt(dx * dx + dy * dy);
        if (dist < 200 && dist > 30) {
          p.shootCooldown = 1.5 - wanted.level * 0.15;
          final a = atan2(dy, dx) + (rng.nextDouble() - 0.5) * 0.15;
          trails.add(BulletTrail(p.x, p.y,
            p.x + cos(a) * 200, p.y + sin(a) * 200));
          // Hit check on player
          final spread = (rng.nextDouble() - 0.5) * 0.1;
          final hitA = a + spread;
          final hitDist = _projectionAlong(playerX, playerY, p.x, p.y, hitA);
          final perpDist = _pointLineDistance(playerX, playerY, p.x, p.y,
            p.x + cos(hitA) * 300, p.y + sin(hitA) * 300);
          if (perpDist < kPlayerRadius + 5 && hitDist > 0 && hitDist < 250) {
            _playerTakeDamage(12);
          }
        }
      }
    }
  }

  void _updateProjectiles(double dt) {
    for (final p in projectiles) {
      p.update(dt);
      if (!p.alive) continue;

      // Hit building
      if (cityMap.isSolid(p.x, p.y, 2)) {
        _explodeProjectile(p);
        continue;
      }

      // Hit peds
      for (final ped in peds) {
        if (!ped.alive) continue;
        final dx = ped.x - p.x;
        final dy = ped.y - p.y;
        if (dx * dx + dy * dy < 15 * 15) {
          _explodeProjectile(p);
          break;
        }
      }

      // Hit vehicles
      for (final v in vehicles) {
        if (v == playerVehicle) continue;
        final dx = v.x - p.x;
        final dy = v.y - p.y;
        if (dx * dx + dy * dy < v.width * v.width) {
          _explodeProjectile(p);
          break;
        }
      }
    }
    projectiles.removeWhere((p) => !p.alive);
  }

  void _explodeProjectile(Projectile p) {
    p.exploded = true;
    if (p.blastRadius > 0) {
      explosions.add(Explosion(p.x, p.y, p.blastRadius));
      audio.sfx('explosion', volume: 0.9);
      // Blast damage
      for (final ped in peds) {
        if (!ped.alive) continue;
        final dx = ped.x - p.x;
        final dy = ped.y - p.y;
        if (dx * dx + dy * dy < p.blastRadius * p.blastRadius) {
          ped.takeDamage(p.damage);
          if (!ped.alive) _onPedKilled(ped);
        }
      }
      for (final v in vehicles) {
        final dx = v.x - p.x;
        final dy = v.y - p.y;
        if (dx * dx + dy * dy < p.blastRadius * p.blastRadius) {
          v.takeDamage(p.damage);
          if (v.health <= 0) _onVehicleDestroyed(v);
        }
      }
      // Player blast
      final dx = playerX - p.x;
      final dy = playerY - p.y;
      if (dx * dx + dy * dy < p.blastRadius * p.blastRadius) {
        _playerTakeDamage(p.damage * 0.5);
      }
    }
  }

  void _updatePickups(double dt) {
    for (final pk in pickups) {
      pk.update(dt);
      if (pk.collected) continue;
      final dx = playerX - pk.x;
      final dy = playerY - pk.y;
      if (dx * dx + dy * dy < 20 * 20) {
        _collectPickup(pk);
      }
    }
  }

  void _collectPickup(Pickup pk) {
    pk.collected = true;
    pk.respawnTimer = 60;
    audio.sfx('pickup', volume: 0.7);
    switch (pk.type) {
      case PickupType.health:
        playerHealth = min(kPlayerMaxHealth, playerHealth + pk.amount);
        _showMessage('+${pk.amount} Health');
        break;
      case PickupType.armor:
        playerArmor = min(kPlayerMaxArmor, playerArmor + pk.amount);
        _showMessage('+${pk.amount} Armor');
        break;
      case PickupType.money:
        playerMoney += pk.amount;
        missions.onMoneyCollected(pk.amount);
        _showMessage('+\$${pk.amount}');
        break;
      case PickupType.weapon:
        if (pk.weaponType != null) {
          weapons.add(pk.weaponType!, pk.amount);
          _showMessage('${weaponData[pk.weaponType]!.name} +${pk.amount}');
        }
        break;
    }
  }

  void _updateExplosions(double dt) {
    for (final e in explosions) e.update(dt);
    explosions.removeWhere((e) => !e.alive);
    for (final t in trails) t.update(dt);
    trails.removeWhere((t) => !t.alive);
    for (final f in flames) f.update(dt);
    flames.removeWhere((f) => !f.alive);
  }

  void _managePopulation() {
    // Remove far-away entities, spawn new ones
    vehicles.removeWhere((v) {
      if (v == playerVehicle) return false;
      if (v.health <= 0) return true;
      final dx = v.x - playerX;
      final dy = v.y - playerY;
      return dx * dx + dy * dy > kPedDespawnRange * kPedDespawnRange * 2;
    });
    peds.removeWhere((p) {
      if (!p.alive) return true;
      final dx = p.x - playerX;
      final dy = p.y - playerY;
      return dx * dx + dy * dy > kPedDespawnRange * kPedDespawnRange;
    });

    while (vehicles.length < kMaxTrafficCars) _spawnTrafficCar();
    while (peds.length < kMaxPeds) _spawnPed();
  }

  void _spawnPolice() {
    if (!wanted.shouldSpawnPolice()) return;

    // Spawn police ped
    final a = rng.nextDouble() * 2 * pi;
    final d = 300 + rng.nextDouble() * 200;
    final px = playerX + cos(a) * d;
    final py = playerY + sin(a) * d;
    if (!cityMap.isSolid(px, py, kPedRadius) && px > 0 && py > 0 && px < kWorldW && py < kWorldH) {
      final cop = Ped(px, py, PedType.police, rng);
      cop.chasing = true;
      peds.add(cop);
    }

    // Spawn police car at higher levels
    if (wanted.level >= 3) {
      final va = rng.nextDouble() * 2 * pi;
      final vd = 400 + rng.nextDouble() * 200;
      final vx = playerX + cos(va) * vd;
      final vy = playerY + sin(va) * vd;
      if (!cityMap.isSolid(vx, vy, kCarWidth) && vx > 0 && vy > 0 && vx < kWorldW && vy < kWorldH) {
        final cop = Vehicle(vx, vy, atan2(playerY - vy, playerX - vx), VehicleType.policeCar);
        cop.isPoliceChase = true;
        vehicles.add(cop);
      }
    }
  }

  void _playerTakeDamage(double dmg) {
    if (playerArmor > 0) {
      final absorbed = min(playerArmor, dmg * 0.7);
      playerArmor -= absorbed;
      dmg -= absorbed;
    }
    playerHealth = max(0, playerHealth - dmg);
    audio.sfx('hurt', volume: 0.6);
  }

  void _onPlayerDeath() {
    playerHealth = kPlayerMaxHealth;
    playerArmor = 0;
    playerMoney = max(0, playerMoney - 500);
    wanted.heat = 0;
    wanted.level = 0;
    if (playerInVehicle) exitVehicle();
    // Respawn at center
    final stride = kBlockSize + kRoadWidth;
    playerX = 6 * stride + kRoadWidth / 2;
    playerY = 6 * stride + kRoadWidth / 2;
    weapons.slots.clear();
    weapons.slots.add(Weapon(WeaponType.unarmed));
    weapons.currentIndex = 0;
    _showMessage('WASTED - \$500');
  }

  void _checkMissionComplete() {
    final m = missions.current;
    if (m == null) return;
    if (m.completed) {
      playerMoney += m.reward;
      _showMessage('MISSION PASSED! +\$${m.reward}');
      missions.current = null;
      missions.generate(rng, kWorldW, kWorldH);
    } else if (m.failed) {
      _showMessage('MISSION FAILED');
      missions.current = null;
    }
  }

  void _updateCamera() {
    camX = playerX - size.x / 2;
    camY = playerY - size.y / 2;
  }

  void _updateMessage(double dt) {
    if (messageTimer > 0) {
      messageTimer -= dt;
      if (messageTimer <= 0) messageText = null;
    }
  }

  void _showMessage(String msg) {
    messageText = msg;
    messageTimer = 2.0;
  }

  // Vehicle interaction
  void tryEnterVehicle() {
    if (enterVehicleCooldown > 0) return;
    if (playerInVehicle) {
      exitVehicle();
      return;
    }
    Vehicle? nearest;
    double bestDist = 50;
    for (final v in vehicles) {
      if (v.health <= 0) continue;
      final dx = v.x - playerX;
      final dy = v.y - playerY;
      final d = sqrt(dx * dx + dy * dy);
      if (d < bestDist) {
        bestDist = d;
        nearest = v;
      }
    }
    if (nearest != null) {
      playerVehicle = nearest;
      nearest.occupied = true;
      nearest.isPlayerVehicle = true;
      playerInVehicle = true;
      enterVehicleCooldown = 0.5;
      _showMessage('Entered ${nearest.info.name}');
    }
  }

  void exitVehicle() {
    if (playerVehicle != null) {
      enterVehicleCooldown = 0.5;
      playerVehicle!.occupied = false;
      playerVehicle!.isPlayerVehicle = false;
      playerVehicle!.speed *= 0.3;
      // Offset player to side
      playerX += cos(playerAngle + pi / 2) * 25;
      playerY += sin(playerAngle + pi / 2) * 25;
      playerVehicle = null;
      playerInVehicle = false;
    }
  }

  // Keyboard
  @override
  KeyEventResult onKeyEvent(KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    _keys.clear();
    _keys.addAll(keysPressed);

    if (event is KeyDownEvent) {
      audio.ensureStarted();
      if (event.logicalKey == LogicalKeyboardKey.keyF || event.logicalKey == LogicalKeyboardKey.enter) {
        tryEnterVehicle();
      }
      if (event.logicalKey == LogicalKeyboardKey.keyQ) weapons.prevWeapon();
      if (event.logicalKey == LogicalKeyboardKey.keyE) weapons.nextWeapon();
      if (event.logicalKey == LogicalKeyboardKey.keyM) showMissionMenu = !showMissionMenu;
      if (event.logicalKey == LogicalKeyboardKey.space) fireHeld = true;
    }
    return KeyEventResult.handled;
  }

  // Utility
  double _pointLineDistance(double px, double py, double x1, double y1, double x2, double y2) {
    final dx = x2 - x1;
    final dy = y2 - y1;
    final len2 = dx * dx + dy * dy;
    if (len2 == 0) return sqrt((px - x1) * (px - x1) + (py - y1) * (py - y1));
    var t = ((px - x1) * dx + (py - y1) * dy) / len2;
    t = t.clamp(0, 1);
    final cx = x1 + t * dx;
    final cy = y1 + t * dy;
    return sqrt((px - cx) * (px - cx) + (py - cy) * (py - cy));
  }

  double _projectionAlong(double px, double py, double ox, double oy, double angle) {
    return (px - ox) * cos(angle) + (py - oy) * sin(angle);
  }

  // ========== RENDERING ==========

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    canvas.save();
    canvas.translate(-camX, -camY);

    _renderGround(canvas);
    _renderBuildings(canvas);
    _renderPickups(canvas);
    _renderVehicles(canvas);
    _renderPeds(canvas);
    _renderPlayer(canvas);
    _renderMissionMarker(canvas);
    _renderProjectiles(canvas);
    _renderExplosions(canvas);

    canvas.restore();
  }

  void _renderGround(Canvas canvas) {
    // Background grass
    canvas.drawRect(
      Rect.fromLTWH(camX - 100, camY - 100, size.x + 200, size.y + 200),
      Paint()..color = kColorGrass,
    );

    // Water
    final waterPaint = Paint()..color = kColorWater;
    for (final w in cityMap.waterAreas) {
      if (_inView(w)) canvas.drawRect(w, waterPaint);
    }

    // Roads
    final roadPaint = Paint()..color = kColorRoad;
    for (final r in cityMap.roads) {
      if (_inView(r)) canvas.drawRect(r, roadPaint);
    }

    // Road markings (center lines)
    final markPaint = Paint()
      ..color = const Color(0x55FFFF00)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final stride = kBlockSize + kRoadWidth;
    final half = kRoadWidth / 2;
    for (int x = 0; x <= kCityBlocksX; x++) {
      final rx = x * stride + half;
      if (rx > camX - 50 && rx < camX + size.x + 50) {
        for (double yy = max(0, camY - 20); yy < min(kWorldH, camY + size.y + 20); yy += 20) {
          canvas.drawLine(Offset(rx, yy), Offset(rx, yy + 10), markPaint);
        }
      }
    }
    for (int y = 0; y <= kCityBlocksY; y++) {
      final ry = y * stride + half;
      if (ry > camY - 50 && ry < camY + size.y + 50) {
        for (double xx = max(0, camX - 20); xx < min(kWorldW, camX + size.x + 20); xx += 20) {
          canvas.drawLine(Offset(xx, ry), Offset(xx + 10, ry), markPaint);
        }
      }
    }

    // Sidewalks
    final swPaint = Paint()..color = kColorSidewalk;
    for (final s in cityMap.sidewalks) {
      if (_inView(s)) canvas.drawRect(s, swPaint);
    }

    // Parks
    final parkPaint = Paint()..color = const Color(0xFF3B8B3B);
    for (final p in cityMap.parks) {
      if (_inView(p)) {
        canvas.drawRect(p, parkPaint);
        // Trees
        final treePaint = Paint()..color = const Color(0xFF2A6A2A);
        final trunkPaint = Paint()..color = const Color(0xFF5A4A3A);
        for (double tx = p.left + 30; tx < p.right - 20; tx += 60) {
          for (double ty = p.top + 30; ty < p.bottom - 20; ty += 60) {
            canvas.drawCircle(Offset(tx, ty + 2), 4, trunkPaint);
            canvas.drawCircle(Offset(tx, ty), 10, treePaint);
          }
        }
      }
    }
  }

  void _renderBuildings(Canvas canvas) {
    for (final b in cityMap.buildings) {
      if (!_inView(b.rect.inflate(5))) continue;
      // Shadow
      canvas.drawRect(b.rect.shift(const Offset(3, 3)),
        Paint()..color = const Color(0x33000000));
      // Wall
      canvas.drawRect(b.rect, Paint()..color = b.color);
      // Roof edge
      canvas.drawRect(b.rect.deflate(2), Paint()..color = b.roofColor);
      // Windows
      if (b.rect.width > 25 && b.rect.height > 25) {
        final winPaint = Paint()..color = const Color(0x66FFFFAA);
        final spacing = b.height > 20 ? 8.0 : 12.0;
        for (double wx = b.rect.left + 8; wx < b.rect.right - 8; wx += spacing + 6) {
          for (double wy = b.rect.top + 8; wy < b.rect.bottom - 8; wy += spacing + 6) {
            canvas.drawRect(Rect.fromLTWH(wx, wy, 3, 3), winPaint);
          }
        }
      }
    }
  }

  void _renderVehicles(Canvas canvas) {
    for (final v in vehicles) {
      if (!_inViewPoint(v.x, v.y, 60)) continue;
      canvas.save();
      canvas.translate(v.x, v.y);
      canvas.rotate(v.angle);

      final color = v.health <= 0 ? const Color(0xFF333333) : v.bodyColor;
      // Shadow
      canvas.drawRect(
        Rect.fromCenter(center: const Offset(2, 2), width: v.length, height: v.width),
        Paint()..color = const Color(0x33000000),
      );
      // Body
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: v.length, height: v.width),
          const Radius.circular(3),
        ),
        Paint()..color = color,
      );
      // Windshield
      canvas.drawRect(
        Rect.fromCenter(center: Offset(v.length * 0.2, 0), width: v.length * 0.2, height: v.width * 0.7),
        Paint()..color = const Color(0x77AADDFF),
      );
      // Headlights
      final lightPaint = Paint()..color = const Color(0xFFFFFF88);
      canvas.drawCircle(Offset(v.length / 2, -v.width / 3), 2, lightPaint);
      canvas.drawCircle(Offset(v.length / 2, v.width / 3), 2, lightPaint);
      // Tail lights
      final tailPaint = Paint()..color = const Color(0xFFFF3333);
      canvas.drawCircle(Offset(-v.length / 2, -v.width / 3), 2, tailPaint);
      canvas.drawCircle(Offset(-v.length / 2, v.width / 3), 2, tailPaint);

      // Police markings
      if (v.type == VehicleType.policeCar) {
        canvas.drawRect(
          Rect.fromCenter(center: Offset.zero, width: v.length * 0.3, height: v.width * 0.3),
          Paint()..color = const Color(0xAAFFFFFF),
        );
        // Siren
        final sirenColor = (DateTime.now().millisecond ~/ 250) % 2 == 0
            ? const Color(0xFFFF0000) : const Color(0xFF0000FF);
        canvas.drawCircle(Offset(0, -v.width / 3), 3, Paint()..color = sirenColor);
        canvas.drawCircle(Offset(0, v.width / 3), 3, Paint()..color = sirenColor);
      }

      // Damage
      if (v.health < 50) {
        final smokePaint = Paint()..color = Color.fromARGB(((1 - v.health / 50) * 80).toInt(), 50, 50, 50);
        canvas.drawCircle(Offset(-v.length / 3, 0), 6, smokePaint);
      }

      canvas.restore();
    }
  }

  void _renderPeds(Canvas canvas) {
    for (final p in peds) {
      if (!_inViewPoint(p.x, p.y, 30)) continue;
      if (!p.alive) {
        // Blood pool + crumpled body
        canvas.drawOval(
          Rect.fromCenter(center: Offset(p.x, p.y), width: 18, height: 14),
          Paint()..color = const Color(0x66660000),
        );
        canvas.drawRect(
          Rect.fromCenter(center: Offset(p.x, p.y), width: 11, height: 7),
          Paint()..color = p.shirtColor..isAntiAlias = false,
        );
        continue;
      }
      canvas.save();
      canvas.translate(p.x, p.y);
      canvas.rotate(p.angle);
      drawTopDownChar(
        canvas,
        r: p.radius,
        skin: p.skinColor,
        hair: p.hairColor,
        shirt: p.shirtColor,
        pants: p.pantsColor,
        walkPhase: p.walkPhase,
        police: p.type == PedType.police,
        armed: p.type == PedType.police && p.chasing,
        gunColor: const Color(0xFF1A1A1A),
      );
      canvas.restore();
    }
  }

  void _renderPlayer(Canvas canvas) {
    if (playerInVehicle) return;

    canvas.save();
    canvas.translate(playerX, playerY);
    canvas.rotate(playerAngle);
    final w = weapons.current;
    drawTopDownChar(
      canvas,
      r: kPlayerRadius,
      skin: const Color(0xFFE0B98E),
      hair: const Color(0xFF3A2410),
      shirt: const Color(0xFF2E5FB0),
      pants: const Color(0xFF20242E),
      walkPhase: playerWalkPhase,
      armed: w.type != WeaponType.unarmed,
      gunColor: const Color(0xFF2A2A2A),
    );
    canvas.restore();
  }

  void _renderMissionMarker(Canvas canvas) {
    final m = missions.current;
    if (m == null || !m.active) return;
    if (m.targetX == null || m.targetY == null) return;
    final tx = m.targetX!;
    final ty = m.targetY!;
    // Pulsing circle
    final phase = (DateTime.now().millisecondsSinceEpoch % 1000) / 1000.0;
    final r = 15 + sin(phase * 3.14159 * 2) * 5;
    canvas.drawCircle(Offset(tx, ty), r,
      Paint()..color = const Color(0x88FFFF00)..style = PaintingStyle.fill);
    canvas.drawCircle(Offset(tx, ty), r,
      Paint()..color = const Color(0xFFFFFF00)..style = PaintingStyle.stroke..strokeWidth = 2);
    // Arrow pointing from player
    final dx = tx - playerX;
    final dy = ty - playerY;
    final dist = sqrt(dx * dx + dy * dy);
    if (dist > 100) {
      final a = atan2(dy, dx);
      final ax = playerX + cos(a) * 50;
      final ay = playerY + sin(a) * 50;
      canvas.drawCircle(Offset(ax, ay), 5,
        Paint()..color = const Color(0xCCFFFF00));
    }
  }

  void _renderPickups(Canvas canvas) {
    final tp = TextPainter(textDirection: TextDirection.ltr);
    for (final pk in pickups) {
      if (pk.collected || !_inViewPoint(pk.x, pk.y, 30)) continue;
      final bob = sin(pk.bobPhase) * 3;
      // Glow
      canvas.drawCircle(Offset(pk.x, pk.y + bob), 10,
        Paint()..color = const Color(0x33FFFF00));
      // Emoji
      tp.text = TextSpan(text: pk.emoji, style: const TextStyle(fontSize: 14));
      tp.layout();
      tp.paint(canvas, Offset(pk.x - tp.width / 2, pk.y + bob - tp.height / 2));
    }
  }

  void _renderProjectiles(Canvas canvas) {
    // Bullet trails
    final trailPaint = Paint()
      ..color = const Color(0xCCFFFF44)
      ..strokeWidth = 1.5;
    for (final t in trails) {
      trailPaint.color = Color.fromARGB((t.life / 0.1 * 200).toInt().clamp(0, 200), 255, 255, 68);
      canvas.drawLine(Offset(t.x1, t.y1), Offset(t.x2, t.y2), trailPaint);
    }

    // Projectiles
    for (final p in projectiles) {
      if (!p.alive) continue;
      canvas.drawCircle(Offset(p.x, p.y), 4,
        Paint()..color = const Color(0xFFFF8800));
      canvas.drawCircle(Offset(p.x, p.y), 2,
        Paint()..color = const Color(0xFFFFFF00));
    }

    // Flames
    for (final f in flames) {
      if (!f.alive) continue;
      final alpha = (f.life / 0.4 * 255).toInt().clamp(0, 255);
      canvas.drawCircle(Offset(f.x, f.y), 4 + (1 - f.life / 0.4) * 4,
        Paint()..color = Color.fromARGB(alpha, 255, 120 + (f.life * 200).toInt().clamp(0, 135), 0));
    }
  }

  void _renderExplosions(Canvas canvas) {
    for (final e in explosions) {
      if (!e.alive) continue;
      final alpha = (e.life / 0.5 * 200).toInt().clamp(0, 200);
      canvas.drawCircle(Offset(e.x, e.y), e.radius,
        Paint()..color = Color.fromARGB(alpha, 255, 150, 0));
      canvas.drawCircle(Offset(e.x, e.y), e.radius * 0.6,
        Paint()..color = Color.fromARGB(alpha, 255, 255, 100));
    }
  }

  bool _inView(Rect r) {
    return r.right > camX - 50 && r.left < camX + size.x + 50 &&
           r.bottom > camY - 50 && r.top < camY + size.y + 50;
  }

  bool _inViewPoint(double x, double y, double margin) {
    return x > camX - margin && x < camX + size.x + margin &&
           y > camY - margin && y < camY + size.y + margin;
  }
}
