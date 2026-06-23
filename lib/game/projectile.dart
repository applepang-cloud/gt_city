import 'dart:math';
import 'weapon.dart';

class Projectile {
  double x, y, angle, speed;
  double life;
  double damage;
  double blastRadius;
  WeaponType sourceWeapon;
  bool fromPlayer;
  bool exploded = false;

  Projectile({
    required this.x, required this.y, required this.angle,
    required this.speed, required this.damage,
    this.life = 3.0, this.blastRadius = 0,
    required this.sourceWeapon, this.fromPlayer = true,
  });

  bool get alive => life > 0 && !exploded;

  void update(double dt) {
    if (!alive) return;
    x += cos(angle) * speed * dt;
    y += sin(angle) * speed * dt;
    life -= dt;
  }
}

class BulletTrail {
  double x1, y1, x2, y2;
  double life;
  BulletTrail(this.x1, this.y1, this.x2, this.y2, [this.life = 0.1]);
  bool get alive => life > 0;
  void update(double dt) => life -= dt;
}

class Explosion {
  double x, y, radius, maxRadius, life;
  Explosion(this.x, this.y, this.maxRadius) : radius = 0, life = 0.5;
  bool get alive => life > 0;
  void update(double dt) {
    life -= dt;
    radius = maxRadius * (1 - life / 0.5);
  }
}

class FlameParticle {
  double x, y, vx, vy, life;
  FlameParticle(this.x, this.y, this.vx, this.vy, [this.life = 0.4]);
  bool get alive => life > 0;
  void update(double dt) {
    x += vx * dt;
    y += vy * dt;
    life -= dt;
  }
}
