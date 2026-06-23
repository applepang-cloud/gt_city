import 'dart:math';

enum WeaponType {
  unarmed,
  baseballBat,
  colt45,
  uzi,
  shotgun,
  ak47,
  m16,
  sniperRifle,
  rocketLauncher,
  flamethrower,
  molotov,
  grenade,
}

enum WeaponFire { melee, instantHit, projectile, areaEffect }

class WeaponInfo {
  final String name;
  final String emoji;
  final WeaponFire fireType;
  final double damage;
  final double range;
  final double fireRate;
  final int magSize;
  final double spread;
  final double projectileSpeed;
  final double blastRadius;

  const WeaponInfo({
    required this.name,
    required this.emoji,
    required this.fireType,
    required this.damage,
    required this.range,
    required this.fireRate,
    this.magSize = 0,
    this.spread = 0,
    this.projectileSpeed = 600,
    this.blastRadius = 0,
  });
}

const Map<WeaponType, WeaponInfo> weaponData = {
  WeaponType.unarmed: WeaponInfo(
    name: 'Fists', emoji: '👊', fireType: WeaponFire.melee,
    damage: 8, range: 28, fireRate: 0.4,
  ),
  WeaponType.baseballBat: WeaponInfo(
    name: 'Bat', emoji: '🏏', fireType: WeaponFire.melee,
    damage: 25, range: 35, fireRate: 0.5,
  ),
  WeaponType.colt45: WeaponInfo(
    name: 'Pistol', emoji: '🔫', fireType: WeaponFire.instantHit,
    damage: 15, range: 300, fireRate: 0.35, magSize: 17, spread: 0.04,
  ),
  WeaponType.uzi: WeaponInfo(
    name: 'Uzi', emoji: '🔫', fireType: WeaponFire.instantHit,
    damage: 10, range: 250, fireRate: 0.08, magSize: 30, spread: 0.08,
  ),
  WeaponType.shotgun: WeaponInfo(
    name: 'Shotgun', emoji: '🔫', fireType: WeaponFire.instantHit,
    damage: 40, range: 200, fireRate: 0.7, magSize: 8, spread: 0.15,
  ),
  WeaponType.ak47: WeaponInfo(
    name: 'AK-47', emoji: '🔫', fireType: WeaponFire.instantHit,
    damage: 18, range: 350, fireRate: 0.1, magSize: 30, spread: 0.06,
  ),
  WeaponType.m16: WeaponInfo(
    name: 'M16', emoji: '🔫', fireType: WeaponFire.instantHit,
    damage: 20, range: 400, fireRate: 0.07, magSize: 60, spread: 0.03,
  ),
  WeaponType.sniperRifle: WeaponInfo(
    name: 'Sniper', emoji: '🎯', fireType: WeaponFire.instantHit,
    damage: 100, range: 600, fireRate: 1.2, magSize: 5, spread: 0.01,
  ),
  WeaponType.rocketLauncher: WeaponInfo(
    name: 'RPG', emoji: '🚀', fireType: WeaponFire.projectile,
    damage: 150, range: 500, fireRate: 1.5, magSize: 1,
    projectileSpeed: 350, blastRadius: 60,
  ),
  WeaponType.flamethrower: WeaponInfo(
    name: 'Flame', emoji: '🔥', fireType: WeaponFire.areaEffect,
    damage: 5, range: 100, fireRate: 0.05, magSize: 200, spread: 0.2,
  ),
  WeaponType.molotov: WeaponInfo(
    name: 'Molotov', emoji: '🍾', fireType: WeaponFire.projectile,
    damage: 50, range: 200, fireRate: 1.0, magSize: 1,
    projectileSpeed: 250, blastRadius: 50,
  ),
  WeaponType.grenade: WeaponInfo(
    name: 'Grenade', emoji: '💣', fireType: WeaponFire.projectile,
    damage: 100, range: 250, fireRate: 1.0, magSize: 1,
    projectileSpeed: 300, blastRadius: 70,
  ),
};

class Weapon {
  WeaponType type;
  int ammo;
  double cooldown = 0;

  Weapon(this.type, [this.ammo = -1]);

  WeaponInfo get info => weaponData[type]!;
  bool get hasAmmo => ammo < 0 || ammo > 0;

  bool tryFire() {
    if (cooldown > 0 || !hasAmmo) return false;
    cooldown = info.fireRate;
    if (ammo > 0) ammo--;
    return true;
  }

  void update(double dt) {
    if (cooldown > 0) cooldown = max(0, cooldown - dt);
  }
}

class WeaponInventory {
  final List<Weapon> slots = [Weapon(WeaponType.unarmed)];
  int currentIndex = 0;

  Weapon get current => slots[currentIndex];

  void add(WeaponType type, int ammo) {
    final idx = slots.indexWhere((w) => w.type == type);
    if (idx >= 0) {
      if (slots[idx].ammo >= 0) slots[idx].ammo += ammo;
      currentIndex = idx;
    } else {
      slots.add(Weapon(type, ammo));
      currentIndex = slots.length - 1;
    }
  }

  void nextWeapon() {
    currentIndex = (currentIndex + 1) % slots.length;
  }

  void prevWeapon() {
    currentIndex = (currentIndex - 1 + slots.length) % slots.length;
  }

  void update(double dt) {
    for (final w in slots) w.update(dt);
  }
}
