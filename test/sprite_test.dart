import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:gt_city/game/sprites.dart';

void main() {
  test('drawTopDownChar renders without error for all variants', () {
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);

    for (final police in [false, true]) {
      for (final armed in [false, true]) {
        for (final phase in [0.0, 1.2, 3.1]) {
          canvas.save();
          canvas.translate(100, 100);
          canvas.rotate(phase);
          drawTopDownChar(
            canvas,
            r: 8,
            skin: const Color(0xFFE0B98E),
            hair: const Color(0xFF3A2410),
            shirt: const Color(0xFF2E5FB0),
            pants: const Color(0xFF20242E),
            walkPhase: phase,
            armed: armed,
            police: police,
            gunColor: const Color(0xFF1A1A1A),
          );
          canvas.restore();
        }
      }
    }

    final picture = recorder.endRecording();
    expect(picture, isNotNull);
    picture.dispose();
  });
}
