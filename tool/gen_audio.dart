// Procedural audio generator for GT City.
// Generates ORIGINAL synthesized WAV files (not from any copyrighted source)
// that evoke a top-down crime-city mood: a looping synth BGM plus SFX.
//
// Run:  dart run tool/gen_audio.dart
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

const int sr = 22050;
final Random rng = Random(1234);

void main() {
  final dir = Directory('assets/audio');
  dir.createSync(recursive: true);

  writeWav('assets/audio/shoot.wav', shoot());
  writeWav('assets/audio/punch.wav', punch());
  writeWav('assets/audio/explosion.wav', explosion());
  writeWav('assets/audio/pickup.wav', pickup());
  writeWav('assets/audio/hurt.wav', hurt());
  writeWav('assets/audio/siren.wav', siren());
  writeWav('assets/audio/engine.wav', engine());
  writeWav('assets/audio/bgm.wav', bgm());

  stdout.writeln('Audio generated in assets/audio/');
}

double sine(double f, double t) => sin(2 * pi * f * t);
double square(double f, double t) => sine(f, t) >= 0 ? 1.0 : -1.0;
double saw(double f, double t) {
  final p = f * t;
  return 2 * (p - (p + 0.5).floorToDouble());
}
double nz() => rng.nextDouble() * 2 - 1;

List<double> shoot() {
  final n = (sr * 0.13).round();
  final s = List<double>.filled(n, 0);
  for (int i = 0; i < n; i++) {
    final t = i / sr;
    final env = exp(-t * 42);
    s[i] = (nz() * 0.8 + sine(170, t) * 0.6) * env * 0.75;
  }
  return s;
}

List<double> punch() {
  final n = (sr * 0.12).round();
  final s = List<double>.filled(n, 0);
  for (int i = 0; i < n; i++) {
    final t = i / sr;
    final env = exp(-t * 32);
    s[i] = (sine(110, t) * 0.8 + nz() * 0.35) * env * 0.65;
  }
  return s;
}

List<double> explosion() {
  final n = (sr * 0.75).round();
  final s = List<double>.filled(n, 0);
  double lp = 0;
  for (int i = 0; i < n; i++) {
    final t = i / sr;
    final env = exp(-t * 5.0);
    lp += (nz() - lp) * 0.18; // one-pole lowpass for a deep rumble
    final body = sine(70 * exp(-t * 2), t) * 0.6;
    s[i] = (lp * 0.9 + body) * env * 0.85;
  }
  return s;
}

List<double> pickup() {
  final n = (sr * 0.22).round();
  final s = List<double>.filled(n, 0);
  for (int i = 0; i < n; i++) {
    final t = i / sr;
    final dur = n / sr;
    final f = 620 + 700 * (t / dur);
    final env = (t < 0.01 ? t / 0.01 : exp(-(t - 0.01) * 9));
    s[i] = sine(f, t) * env * 0.5;
  }
  return s;
}

List<double> hurt() {
  final n = (sr * 0.2).round();
  final s = List<double>.filled(n, 0);
  for (int i = 0; i < n; i++) {
    final t = i / sr;
    final dur = n / sr;
    final f = 250 - 130 * (t / dur);
    final env = exp(-t * 9);
    s[i] = (square(f, t) * 0.5 + nz() * 0.4) * env * 0.6;
  }
  return s;
}

// Seamless 1.0s loop: two alternating tones, each an integer number of cycles.
List<double> siren() {
  final half = (sr * 0.5).round();
  final s = List<double>.filled(half * 2, 0);
  for (int i = 0; i < half; i++) {
    final t = i / sr;
    // 800 Hz * 0.5s = 400 cycles exactly -> seamless
    s[i] = (sine(800, t) * 0.7 + square(800, t) * 0.15) * 0.4;
  }
  for (int i = 0; i < half; i++) {
    final t = i / sr;
    // 600 Hz * 0.5s = 300 cycles exactly -> seamless
    s[half + i] = (sine(600, t) * 0.7 + square(600, t) * 0.15) * 0.4;
  }
  return s;
}

// Seamless 0.5s engine loop (integer-cycle saws + filtered noise).
List<double> engine() {
  final n = (sr * 0.5).round();
  final s = List<double>.filled(n, 0);
  double lp = 0;
  for (int i = 0; i < n; i++) {
    final t = i / sr;
    lp += (nz() - lp) * 0.05;
    s[i] = (saw(80, t) * 0.45 + saw(160, t) * 0.2 + lp * 0.25) * 0.5;
  }
  return s;
}

// 8s looping synth groove. Original vi-IV-I-V style progression.
List<double> bgm() {
  const beat = 0.5; // 120 bpm
  const chordLen = 2.0; // 4 beats
  final total = (sr * 8.0).round();
  final s = List<double>.filled(total, 0);

  // [bass root, triad notes...]
  final chords = <List<double>>[
    [110.00, 220.00, 261.63, 329.63], // Am
    [87.31, 174.61, 220.00, 261.63], // F
    [65.41, 261.63, 329.63, 392.00], // C
    [98.00, 196.00, 246.94, 293.66], // G
  ];

  void add(int start, int len, double Function(double t) gen) {
    for (int i = 0; i < len; i++) {
      final idx = start + i;
      if (idx < 0 || idx >= total) continue;
      s[idx] += gen(i / sr);
    }
  }

  for (int c = 0; c < 4; c++) {
    final chord = chords[c];
    final cStart = (c * chordLen * sr).round();
    final cLen = (chordLen * sr).round();

    // Sustained pad (triad)
    for (int v = 1; v < chord.length; v++) {
      final f = chord[v];
      add(cStart, cLen, (t) {
        final atk = t < 0.06 ? t / 0.06 : 1.0;
        final rel = t > chordLen - 0.15 ? (chordLen - t) / 0.15 : 1.0;
        return sine(f, t) * 0.10 * atk * rel.clamp(0.0, 1.0);
      });
    }

    // Bass + kick per beat
    for (int b = 0; b < 4; b++) {
      final bStart = cStart + (b * beat * sr).round();
      final bLen = (beat * sr).round();
      final bass = chord[0];
      add(bStart, bLen, (t) {
        final env = exp(-t * 6);
        return (square(bass, t) * 0.18 + sine(bass, t) * 0.12) * env;
      });
      // kick
      add(bStart, (0.12 * sr).round(), (t) {
        final env = exp(-t * 28);
        return sine(60 * exp(-t * 8), t) * 0.5 * env;
      });
      // hat on offbeat
      add(bStart + (beat / 2 * sr).round(), (0.05 * sr).round(), (t) {
        return nz() * 0.12 * exp(-t * 60);
      });
    }

    // Arpeggio (pluck) every 1/4 beat
    final steps = 16;
    for (int a = 0; a < steps; a++) {
      final aStart = cStart + (a * (chordLen / steps) * sr).round();
      final f = chord[1 + (a % 3)] * 2; // up an octave
      add(aStart, ((chordLen / steps) * sr).round(), (t) {
        final env = exp(-t * 14);
        return sine(f, t) * 0.13 * env;
      });
    }
  }

  // Normalize
  double peak = 0;
  for (final v in s) peak = max(peak, v.abs());
  if (peak > 0) {
    final g = 0.85 / peak;
    for (int i = 0; i < total; i++) s[i] *= g;
  }
  return s;
}

void writeWav(String path, List<double> samples) {
  final n = samples.length;
  final data = ByteData(n * 2);
  for (int i = 0; i < n; i++) {
    final v = (samples[i].clamp(-1.0, 1.0) * 32767).round();
    data.setInt16(i * 2, v, Endian.little);
  }
  final dataBytes = data.buffer.asUint8List();
  final byteRate = sr * 2;
  final h = BytesBuilder();
  void str(String x) => h.add(x.codeUnits);
  void u32(int v) {
    final b = ByteData(4)..setUint32(0, v, Endian.little);
    h.add(b.buffer.asUint8List());
  }
  void u16(int v) {
    final b = ByteData(2)..setUint16(0, v, Endian.little);
    h.add(b.buffer.asUint8List());
  }
  str('RIFF'); u32(36 + dataBytes.length); str('WAVE');
  str('fmt '); u32(16); u16(1); u16(1); u32(sr); u32(byteRate); u16(2); u16(16);
  str('data'); u32(dataBytes.length);
  final out = BytesBuilder();
  out.add(h.toBytes());
  out.add(dataBytes);
  File(path).writeAsBytesSync(out.toBytes());
}
