import 'dart:math';
import 'dart:ui';

/// Blocky top-down pixel-art humanoid. Caller has already translated the canvas
/// to the entity centre and rotated so the character faces +x.
void drawTopDownChar(
  Canvas canvas, {
  required double r,
  required Color skin,
  required Color hair,
  required Color shirt,
  required Color pants,
  double walkPhase = 0,
  bool armed = false,
  bool police = false,
  Color? gunColor,
}) {
  final pix = Paint()..isAntiAlias = false;

  // Soft drop shadow under the feet
  canvas.drawOval(
    Rect.fromCenter(center: Offset(-r * 0.1, 0), width: r * 2.3, height: r * 1.7),
    Paint()..color = const Color(0x33000000)..isAntiAlias = false,
  );

  final swing = sin(walkPhase) * r * 0.5;

  // Legs (animate fore/aft)
  final pantsPaint = pix..color = pants;
  canvas.drawRect(
    Rect.fromCenter(center: Offset(-r * 0.25 + swing, -r * 0.42), width: r * 0.95, height: r * 0.55),
    pantsPaint,
  );
  canvas.drawRect(
    Rect.fromCenter(center: Offset(-r * 0.25 - swing, r * 0.42), width: r * 0.95, height: r * 0.55),
    Paint()..color = pants..isAntiAlias = false,
  );

  // Torso (shirt)
  final shirtPaint = Paint()..color = shirt..isAntiAlias = false;
  canvas.drawRect(
    Rect.fromCenter(center: Offset(-r * 0.05, 0), width: r * 1.25, height: r * 1.5),
    shirtPaint,
  );
  // Shoulder shading line
  canvas.drawRect(
    Rect.fromCenter(center: Offset(r * 0.45, 0), width: r * 0.25, height: r * 1.5),
    Paint()..color = _shade(shirt, 0.85)..isAntiAlias = false,
  );

  // Arms
  final armY = r * 0.85;
  if (armed) {
    // Right arm extended forward holding a gun
    canvas.drawRect(
      Rect.fromCenter(center: Offset(r * 0.35, armY), width: r * 1.4, height: r * 0.42),
      shirtPaint,
    );
    canvas.drawRect(
      Rect.fromCenter(center: Offset(r * 1.05, armY), width: r * 0.45, height: r * 0.45),
      Paint()..color = skin..isAntiAlias = false,
    );
    canvas.drawRect(
      Rect.fromCenter(center: Offset(r * 1.55, armY), width: r * 0.9, height: r * 0.28),
      Paint()..color = gunColor ?? const Color(0xFF2A2A2A)..isAntiAlias = false,
    );
    // Left arm resting
    canvas.drawRect(
      Rect.fromCenter(center: Offset(-r * 0.05, -armY), width: r * 0.4, height: r * 0.42),
      shirtPaint,
    );
  } else {
    for (final sy in [armY, -armY]) {
      canvas.drawRect(
        Rect.fromCenter(center: Offset(swing * (sy > 0 ? 1 : -1) * 0.6, sy), width: r * 0.42, height: r * 0.42),
        shirtPaint,
      );
      canvas.drawRect(
        Rect.fromCenter(center: Offset(r * 0.2 + swing * (sy > 0 ? 1 : -1) * 0.6, sy), width: r * 0.32, height: r * 0.36),
        Paint()..color = skin..isAntiAlias = false,
      );
    }
  }

  // Head: top-down so we mostly see hair, with a forward-facing face wedge
  canvas.drawRect(
    Rect.fromCenter(center: Offset(r * 0.5, 0), width: r * 1.05, height: r * 1.05),
    Paint()..color = hair..isAntiAlias = false,
  );
  // Face (skin) at the front
  canvas.drawRect(
    Rect.fromCenter(center: Offset(r * 0.92, 0), width: r * 0.4, height: r * 0.7),
    Paint()..color = skin..isAntiAlias = false,
  );

  if (police) {
    // Cap covering the head + a peaked brim
    canvas.drawRect(
      Rect.fromCenter(center: Offset(r * 0.45, 0), width: r * 1.1, height: r * 1.1),
      Paint()..color = const Color(0xFF15183A)..isAntiAlias = false,
    );
    canvas.drawRect(
      Rect.fromCenter(center: Offset(r * 1.05, 0), width: r * 0.35, height: r * 0.75),
      Paint()..color = const Color(0xFF0B0D24)..isAntiAlias = false,
    );
    // Badge dot
    canvas.drawRect(
      Rect.fromCenter(center: Offset(r * 0.45, 0), width: r * 0.25, height: r * 0.25),
      Paint()..color = const Color(0xFFFFD24A)..isAntiAlias = false,
    );
  }
}

Color _shade(Color c, double f) => Color.fromARGB(
      c.alpha,
      (c.red * f).round().clamp(0, 255),
      (c.green * f).round().clamp(0, 255),
      (c.blue * f).round().clamp(0, 255),
    );
