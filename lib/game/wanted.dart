import 'dart:math';

class WantedSystem {
  int level = 0;
  double heat = 0;
  double decayTimer = 0;
  double policeSpawnTimer = 0;
  int killCount = 0;
  int vehicleDestroyCount = 0;

  static const _thresholds = [0, 20, 60, 120, 200, 320, 500];

  void addHeat(double amount) {
    heat += amount;
    _updateLevel();
    decayTimer = 8.0;
  }

  void onPedKilled() {
    killCount++;
    addHeat(15);
  }

  void onCopKilled() {
    killCount++;
    addHeat(40);
  }

  void onVehicleDestroyed() {
    vehicleDestroyCount++;
    addHeat(10);
  }

  void onCopCarDestroyed() {
    vehicleDestroyCount++;
    addHeat(30);
  }

  void _updateLevel() {
    for (int i = _thresholds.length - 1; i >= 0; i--) {
      if (heat >= _thresholds[i]) {
        level = i;
        return;
      }
    }
    level = 0;
  }

  void update(double dt) {
    if (level > 0) {
      decayTimer -= dt;
      if (decayTimer <= 0) {
        heat = max(0, heat - 3.0 * dt);
        _updateLevel();
      }
      policeSpawnTimer -= dt;
    } else {
      heat = max(0, heat - 5.0 * dt);
    }
  }

  int get maxPolice => level * 2;
  double get policeAggression => level / 6.0;

  bool shouldSpawnPolice() {
    if (level <= 0) return false;
    if (policeSpawnTimer > 0) return false;
    policeSpawnTimer = max(1.0, 6.0 - level);
    return true;
  }
}
