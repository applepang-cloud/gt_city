import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../game/gt_city_game.dart';
import '../game/constants.dart';
import '../game/vehicle.dart';
import '../game/ped.dart';
import '../game/weapon.dart';

class GameHud extends StatefulWidget {
  final GtCityGame game;
  const GameHud({super.key, required this.game});

  @override
  State<GameHud> createState() => _GameHudState();
}

class _GameHudState extends State<GameHud> {
  GtCityGame get g => widget.game;

  // Touch joystick
  Offset? _joyStart;
  Offset? _joyCurrent;
  int? _joyPointer;

  @override
  void initState() {
    super.initState();
    g.hudNotifier.addListener(_onUpdate);
  }

  @override
  void dispose() {
    g.hudNotifier.removeListener(_onUpdate);
    super.dispose();
  }

  void _onUpdate() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: _onPointerUp,
      onPointerCancel: _onPointerUp,
      child: Stack(
        children: [
          // Minimap
          Positioned(left: 10, bottom: 10, child: _buildMinimap()),
          // Health/Armor bars
          Positioned(left: 10, top: 10, child: _buildStatusBars()),
          // Money + Wanted
          Positioned(right: 10, top: 10, child: _buildTopRight()),
          // Weapon info
          Positioned(right: 10, bottom: 10, child: _buildWeaponInfo()),
          // Action buttons
          Positioned(right: 10, bottom: 80, child: _buildActionButtons()),
          // Message
          if (g.messageText != null)
            Positioned(
              top: 60, left: 0, right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xCC000000),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(g.messageText!,
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          // Vehicle indicator
          if (g.playerInVehicle)
            Positioned(
              left: 160, bottom: 10,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xAA000000),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${g.playerVehicle?.info.name ?? "Vehicle"} | ${g.playerVehicle?.speed.abs().toInt() ?? 0} km/h',
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
              ),
            ),
          // Active mission HUD
          if (g.missions.current != null && g.missions.current!.active)
            Positioned(top: 10, left: 0, right: 0, child: _buildActiveMission()),
          // Mission menu overlay
          if (g.showMissionMenu)
            Positioned.fill(child: _buildMissionMenu()),
          // Mission button
          Positioned(
            left: 160, top: 10,
            child: GestureDetector(
              onTap: () => setState(() => g.showMissionMenu = !g.showMissionMenu),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xAA000000),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: const Color(0xFF888800)),
                ),
                child: const Text('M:Missions', style: TextStyle(color: Color(0xFFFFFF00), fontSize: 11)),
              ),
            ),
          ),
          // Audio mute toggle
          Positioned(
            left: 255, top: 10,
            child: GestureDetector(
              onTap: () async {
                await g.audio.toggle();
                if (mounted) setState(() {});
              },
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xAA000000),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: const Color(0xFF888888)),
                ),
                child: Text(g.audio.enabled ? '🔊' : '🔇', style: const TextStyle(fontSize: 14)),
              ),
            ),
          ),
          // On-screen control keys
          Positioned(
            bottom: 8, left: 0, right: 0,
            child: Center(
              child: FittedBox(fit: BoxFit.scaleDown, child: _buildControlKeys()),
            ),
          ),
          // Joystick visual
          if (_joyStart != null && _joyCurrent != null)
            Positioned.fill(child: CustomPaint(painter: _JoystickPainter(_joyStart!, _joyCurrent!))),
        ],
      ),
    );
  }

  Widget _buildStatusBars() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _bar('HP', g.playerHealth, kPlayerMaxHealth, Colors.red),
        const SizedBox(height: 4),
        _bar('AR', g.playerArmor, kPlayerMaxArmor, Colors.blue),
      ],
    );
  }

  Widget _bar(String label, double value, double maxVal, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 24, alignment: Alignment.center,
          child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
        ),
        Container(
          width: 100, height: 12,
          decoration: BoxDecoration(
            color: const Color(0x55000000),
            borderRadius: BorderRadius.circular(2),
            border: Border.all(color: Colors.white24),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: (value / maxVal).clamp(0, 1),
            child: Container(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTopRight() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Money
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xAA000000),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            '\$${g.playerMoney}',
            style: const TextStyle(color: Color(0xFF44DD44), fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 6),
        // Wanted stars
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xAA000000),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(6, (i) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1),
              child: Icon(
                Icons.star,
                size: 16,
                color: i < g.wanted.level ? const Color(0xFFFFCC00) : const Color(0xFF444444),
              ),
            )),
          ),
        ),
      ],
    );
  }

  Widget _buildWeaponInfo() {
    final w = g.weapons.current;
    final info = w.info;
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xAA000000),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(info.emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(info.name, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
              Text(
                w.ammo < 0 ? '---' : '${w.ammo}',
                style: TextStyle(
                  color: w.ammo == 0 ? Colors.red : Colors.white70,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        _actionBtn('🔫', () => g.fireHeld = true, Colors.red),
        const SizedBox(height: 8),
        _actionBtn(g.playerInVehicle ? '🚪' : '🚗', () => g.tryEnterVehicle(), Colors.blue),
        const SizedBox(height: 8),
        _actionBtn('🔄', () => g.weapons.nextWeapon(), Colors.orange),
      ],
    );
  }

  Widget _actionBtn(String emoji, VoidCallback onTap, Color color) {
    return GestureDetector(
      onTapDown: (_) => onTap(),
      child: Container(
        width: 50, height: 50,
        decoration: BoxDecoration(
          color: color.withOpacity(0.3),
          shape: BoxShape.circle,
          border: Border.all(color: color.withOpacity(0.6), width: 2),
        ),
        alignment: Alignment.center,
        child: Text(emoji, style: const TextStyle(fontSize: 22)),
      ),
    );
  }

  Widget _buildActiveMission() {
    final m = g.missions.current!;
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xCC000000),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFF888800)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(m.title, style: const TextStyle(color: Color(0xFFFFFF00), fontSize: 13, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text('${m.description}  ${m.progress}/${m.targetCount}',
                  style: const TextStyle(color: Colors.white70, fontSize: 11)),
              ],
            ),
            if (m.hasTimeLimit) ...[
              const SizedBox(width: 12),
              Text('${m.timeRemaining.toInt()}s',
                style: TextStyle(
                  color: m.timeRemaining < 10 ? Colors.red : Colors.white,
                  fontSize: 15, fontWeight: FontWeight.bold,
                )),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMissionMenu() {
    return GestureDetector(
      onTap: () => setState(() => g.showMissionMenu = false),
      child: Container(
        color: const Color(0x88000000),
        child: Center(
          child: Container(
            width: 320, padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xEE111111),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF888800), width: 2),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('MISSIONS', style: TextStyle(color: Color(0xFFFFFF00), fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('Completed: ${g.missions.completedCount}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                const SizedBox(height: 12),
                if (g.missions.current != null && g.missions.current!.active)
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: const Color(0x44FFFF00), borderRadius: BorderRadius.circular(6)),
                    child: Text('Active: ${g.missions.current!.title}',
                      style: const TextStyle(color: Colors.white, fontSize: 13)),
                  )
                else
                  ...g.missions.available.asMap().entries.map((e) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: GestureDetector(
                      onTap: () {
                        g.missions.startMission(e.key);
                        g.showMissionMenu = false;
                        g.messageText = 'Mission: ${e.value.title}';
                        g.messageTimer = 3;
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF222222),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(e.value.title, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                                  Text(e.value.description, style: const TextStyle(color: Colors.white54, fontSize: 11)),
                                ],
                              ),
                            ),
                            Text('\$${e.value.reward}', style: const TextStyle(color: Color(0xFF44DD44), fontSize: 13, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  )),
                const SizedBox(height: 8),
                const Text('Press M or tap outside to close', style: TextStyle(color: Colors.white38, fontSize: 10)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildControlKeys() {
    final k = g.heldKeys;
    bool h(LogicalKeyboardKey a, [LogicalKeyboardKey? b]) =>
        k.contains(a) || (b != null && k.contains(b));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0x66000000),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // WASD diamond
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _key('W', active: h(LogicalKeyboardKey.keyW, LogicalKeyboardKey.arrowUp)),
              Row(mainAxisSize: MainAxisSize.min, children: [
                _key('A', active: h(LogicalKeyboardKey.keyA, LogicalKeyboardKey.arrowLeft)),
                _key('S', active: h(LogicalKeyboardKey.keyS, LogicalKeyboardKey.arrowDown)),
                _key('D', active: h(LogicalKeyboardKey.keyD, LogicalKeyboardKey.arrowRight)),
              ]),
            ],
          ),
          const SizedBox(width: 12),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(mainAxisSize: MainAxisSize.min, children: [
                _key('Space', active: h(LogicalKeyboardKey.space), w: 50),
                _lbl('Shoot'),
                _key('Shift', active: h(LogicalKeyboardKey.shiftLeft, LogicalKeyboardKey.shiftRight), w: 46),
                _lbl('Run'),
              ]),
              const SizedBox(height: 4),
              Row(mainAxisSize: MainAxisSize.min, children: [
                _key('F', active: h(LogicalKeyboardKey.keyF)),
                _lbl('Car'),
                _key('Q', active: h(LogicalKeyboardKey.keyQ)),
                _key('E', active: h(LogicalKeyboardKey.keyE)),
                _lbl('Weapon'),
                _key('M', active: h(LogicalKeyboardKey.keyM)),
                _lbl('Mission'),
              ]),
            ],
          ),
        ],
      ),
    );
  }

  Widget _key(String label, {bool active = false, double w = 26}) {
    return Container(
      margin: const EdgeInsets.all(2),
      width: w, height: 26,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: active ? const Color(0xDDFFCC00) : const Color(0x99202020),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: active ? const Color(0xFFFFEE88) : Colors.white30,
          width: 1.5,
        ),
      ),
      child: Text(label,
          style: TextStyle(
            color: active ? Colors.black : Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          )),
    );
  }

  Widget _lbl(String s) => Padding(
        padding: const EdgeInsets.only(right: 8, left: 2),
        child: Text(s, style: const TextStyle(color: Colors.white70, fontSize: 9)),
      );

  Widget _buildMinimap() {
    return Container(
      width: kMinimapSize, height: kMinimapSize,
      decoration: BoxDecoration(
        color: const Color(0xCC000000),
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFF44AA44), width: 2),
      ),
      child: ClipOval(
        child: CustomPaint(
          size: const Size(kMinimapSize, kMinimapSize),
          painter: _MinimapPainter(g),
        ),
      ),
    );
  }

  // Touch joystick handling
  void _onPointerDown(PointerDownEvent e) {
    if (e.position.dx < MediaQuery.of(context).size.width * 0.4) {
      _joyPointer = e.pointer;
      g.joyPointer = e.pointer;
      _joyStart = e.position;
      _joyCurrent = e.position;
    }
  }

  void _onPointerMove(PointerMoveEvent e) {
    if (e.pointer == _joyPointer && _joyStart != null) {
      _joyCurrent = e.position;
      final dx = _joyCurrent!.dx - _joyStart!.dx;
      final dy = _joyCurrent!.dy - _joyStart!.dy;
      final dist = sqrt(dx * dx + dy * dy);
      final maxR = 60.0;
      if (dist > 5) {
        final clamped = dist.clamp(0, maxR);
        g.joyX = dx / dist * (clamped / maxR);
        g.joyY = dy / dist * (clamped / maxR);
      } else {
        g.joyX = 0;
        g.joyY = 0;
      }
    }
  }

  void _onPointerUp(PointerEvent e) {
    if (e.pointer == _joyPointer) {
      _joyPointer = null;
      g.joyPointer = null;
      _joyStart = null;
      _joyCurrent = null;
      g.joyX = 0;
      g.joyY = 0;
    }
  }
}

class _JoystickPainter extends CustomPainter {
  final Offset start, current;
  _JoystickPainter(this.start, this.current);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawCircle(start, 50,
      Paint()..color = const Color(0x22FFFFFF)..style = PaintingStyle.fill);
    canvas.drawCircle(start, 50,
      Paint()..color = const Color(0x44FFFFFF)..style = PaintingStyle.stroke..strokeWidth = 2);
    final dx = current.dx - start.dx;
    final dy = current.dy - start.dy;
    final dist = sqrt(dx * dx + dy * dy);
    final maxR = 50.0;
    final cx = dist > maxR ? start.dx + dx / dist * maxR : current.dx;
    final cy = dist > maxR ? start.dy + dy / dist * maxR : current.dy;
    canvas.drawCircle(Offset(cx, cy), 20,
      Paint()..color = const Color(0x66FFFFFF));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _MinimapPainter extends CustomPainter {
  final GtCityGame g;
  _MinimapPainter(this.g);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final scale = size.width / (kMinimapRange * 2);

    // Roads
    final roadPaint = Paint()..color = const Color(0xFF555555);
    final stride = kBlockSize + kRoadWidth;
    for (int i = 0; i <= kCityBlocksX; i++) {
      final rx = i * stride + kRoadWidth / 2;
      final sx = cx + (rx - g.playerX) * scale;
      canvas.drawLine(
        Offset(sx, cy + (0 - g.playerY) * scale),
        Offset(sx, cy + (kWorldH - g.playerY) * scale),
        roadPaint..strokeWidth = kRoadWidth * scale,
      );
    }
    for (int i = 0; i <= kCityBlocksY; i++) {
      final ry = i * stride + kRoadWidth / 2;
      final sy = cy + (ry - g.playerY) * scale;
      canvas.drawLine(
        Offset(cx + (0 - g.playerX) * scale, sy),
        Offset(cx + (kWorldW - g.playerX) * scale, sy),
        roadPaint..strokeWidth = kRoadWidth * scale,
      );
    }

    // Buildings as dark blocks
    final bldgPaint = Paint()..color = const Color(0xFF333333);
    for (final b in g.cityMap.buildings) {
      final bx = cx + (b.rect.center.dx - g.playerX) * scale;
      final by = cy + (b.rect.center.dy - g.playerY) * scale;
      if ((bx - cx).abs() > size.width && (by - cy).abs() > size.height) continue;
      canvas.drawRect(
        Rect.fromCenter(center: Offset(bx, by),
          width: b.rect.width * scale, height: b.rect.height * scale),
        bldgPaint,
      );
    }

    // Vehicles as colored dots
    for (final v in g.vehicles) {
      final vx = cx + (v.x - g.playerX) * scale;
      final vy = cy + (v.y - g.playerY) * scale;
      if ((vx - cx).abs() > size.width / 2 || (vy - cy).abs() > size.height / 2) continue;
      final color = v.type == VehicleType.policeCar ? const Color(0xFF4444FF) : const Color(0xFFAAAAAA);
      canvas.drawCircle(Offset(vx, vy), 2, Paint()..color = color);
    }

    // Peds as tiny dots
    for (final p in g.peds) {
      if (!p.alive) continue;
      final px = cx + (p.x - g.playerX) * scale;
      final py = cy + (p.y - g.playerY) * scale;
      if ((px - cx).abs() > size.width / 2 || (py - cy).abs() > size.height / 2) continue;
      final color = p.type == PedType.police ? const Color(0xFF6666FF) : const Color(0xFF888888);
      canvas.drawCircle(Offset(px, py), 1.5, Paint()..color = color);
    }

    // Player arrow
    final pp = Paint()..color = const Color(0xFFFFFFFF);
    final pa = g.playerAngle;
    final ps = 6.0;
    final path = ui.Path();
    path.moveTo(cx + cos(pa) * ps, cy + sin(pa) * ps);
    path.lineTo(cx + cos(pa + 2.5) * ps * 0.6, cy + sin(pa + 2.5) * ps * 0.6);
    path.lineTo(cx + cos(pa - 2.5) * ps * 0.6, cy + sin(pa - 2.5) * ps * 0.6);
    path.close();
    canvas.drawPath(path, pp);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
