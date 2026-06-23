import 'dart:math';

enum MissionType {
  killTarget,
  reachLocation,
  destroyVehicles,
  collectMoney,
  survive,
}

class Mission {
  final String title;
  final String description;
  final MissionType type;
  final int targetCount;
  int progress = 0;
  final int reward;
  final double timeLimit;
  double elapsed = 0;
  bool active = false;
  bool completed = false;
  bool failed = false;

  // Location missions
  double? targetX, targetY;

  Mission({
    required this.title,
    required this.description,
    required this.type,
    required this.targetCount,
    required this.reward,
    this.timeLimit = 0,
    this.targetX,
    this.targetY,
  });

  bool get hasTimeLimit => timeLimit > 0;
  double get timeRemaining => max(0, timeLimit - elapsed);
  double get progressFraction => (progress / targetCount).clamp(0.0, 1.0);

  void start() {
    active = true;
    progress = 0;
    elapsed = 0;
    completed = false;
    failed = false;
  }

  void update(double dt) {
    if (!active || completed || failed) return;
    elapsed += dt;
    if (hasTimeLimit && elapsed >= timeLimit) {
      failed = true;
      active = false;
    }
    if (progress >= targetCount) {
      completed = true;
      active = false;
    }
  }

  void addProgress([int amount = 1]) {
    if (!active || completed || failed) return;
    progress += amount;
  }
}

class MissionSystem {
  final List<Mission> available = [];
  Mission? current;
  int completedCount = 0;

  void generate(Random rng, double worldW, double worldH) {
    available.clear();

    available.add(Mission(
      title: 'Street Cleaner',
      description: 'Take out 5 pedestrians',
      type: MissionType.killTarget,
      targetCount: 5,
      reward: 500,
      timeLimit: 60,
    ));

    available.add(Mission(
      title: 'Demolition Man',
      description: 'Destroy 3 vehicles',
      type: MissionType.destroyVehicles,
      targetCount: 3,
      reward: 800,
      timeLimit: 90,
    ));

    available.add(Mission(
      title: 'Money Maker',
      description: 'Collect \$1000',
      type: MissionType.collectMoney,
      targetCount: 1000,
      reward: 500,
    ));

    available.add(Mission(
      title: 'Survivor',
      description: 'Survive 60 seconds at 3+ stars',
      type: MissionType.survive,
      targetCount: 60,
      reward: 2000,
    ));

    final tx = 200 + rng.nextDouble() * (worldW - 400);
    final ty = 200 + rng.nextDouble() * (worldH - 400);
    available.add(Mission(
      title: 'Courier',
      description: 'Reach the marker',
      type: MissionType.reachLocation,
      targetCount: 1,
      reward: 300,
      timeLimit: 45,
      targetX: tx,
      targetY: ty,
    ));
  }

  void startMission(int index) {
    if (index < 0 || index >= available.length) return;
    current = available[index];
    current!.start();
  }

  void update(double dt) {
    current?.update(dt);
    if (current != null && current!.completed) {
      completedCount++;
    }
  }

  void onPedKilled() {
    if (current?.type == MissionType.killTarget && current!.active) {
      current!.addProgress();
    }
  }

  void onVehicleDestroyed() {
    if (current?.type == MissionType.destroyVehicles && current!.active) {
      current!.addProgress();
    }
  }

  void onMoneyCollected(int amount) {
    if (current?.type == MissionType.collectMoney && current!.active) {
      current!.addProgress(amount);
    }
  }

  void onSurviveTick(double dt, int wantedLevel) {
    if (current?.type == MissionType.survive && current!.active && wantedLevel >= 3) {
      current!.addProgress(dt.ceil());
    }
  }

  void checkReachLocation(double px, double py) {
    if (current?.type == MissionType.reachLocation && current!.active) {
      final dx = px - (current!.targetX ?? 0);
      final dy = py - (current!.targetY ?? 0);
      if (dx * dx + dy * dy < 40 * 40) {
        current!.addProgress();
      }
    }
  }
}
