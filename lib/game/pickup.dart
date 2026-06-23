import 'dart:math';
import 'weapon.dart';

enum PickupType { health, armor, weapon, money }

class Pickup {
  double x, y;
  PickupType type;
  WeaponType? weaponType;
  int amount;
  double respawnTimer = 0;
  bool collected = false;
  double bobPhase;

  Pickup(this.x, this.y, this.type, {this.weaponType, this.amount = 0})
      : bobPhase = Random().nextDouble() * 6.28;

  String get emoji {
    switch (type) {
      case PickupType.health: return '❤️';
      case PickupType.armor: return '🛡️';
      case PickupType.money: return '💰';
      case PickupType.weapon:
        return weaponType != null ? weaponData[weaponType]!.emoji : '📦';
    }
  }

  void update(double dt) {
    bobPhase += dt * 3;
    if (collected) {
      respawnTimer -= dt;
      if (respawnTimer <= 0) collected = false;
    }
  }
}
