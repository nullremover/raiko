
import 'dart:math' as math;
import 'dart:typed_data';

/// Audio spectrum helpers for Raiko.
///
/// Converts signed 16-bit PCM samples into normalized frequency bands.
/// This class does not capture audio or connect to a music player by itself.
abstract final class RaikoSpectrumDecoder {
  /// Decode little-endian, signed 16-bit PCM audio.
  ///
  /// [bytes] contains interleaved samples when using multiple channels.
  /// [channels] is typically 1 (mono) or 2 (stereo).
  /// [barCount] controls the number of output frequency bands.
  ///
  /// Returns values between 0.0 and 1.0.
  static List<double> decodePcm16(
    Uint8List bytes, {
    int channels = 2,
    int barCount = 48,
  }) {
    if (barCount <= 0) return const [];
    if (channels <= 0 || bytes.length < 4) {
      return List<double>.filled(barCount, 0.0);
    }

    final sampleCount = bytes.length ~/ 2;
    final frameCount = sampleCount ~/ channels;

    if (frameCount < 8) {
      return List<double>.filled(barCount, 0.0);
    }

    // Convert interleaved PCM samples into mono floating-point audio.
    final samples = List<double>.filled(frameCount, 0.0);

    for (var frame = 0; frame < frameCount; frame++) {
      var sum = 0.0;

      for (var channel = 0; channel < channels; channel++) {
        final offset = (frame * channels + channel) * 2;

        final unsigned =
            bytes[offset] | (bytes[offset + 1] << 8);

        final signed = unsigned >= 0x8000
            ? unsigned - 0x10000
            : unsigned;

        sum += signed / 32768.0;
      }

      samples[frame] = sum / channels;
    }

    // Hann window reduces spectral leakage.
    for (var i = 0; i < frameCount; i++) {
      final window =
          0.5 *
          (1 - math.cos(2 * math.pi * i / (frameCount - 1)));

      samples[i] *= window;
    }

    final nyquistBin = frameCount ~/ 2;

    if (nyquistBin < 2) {
      return List<double>.filled(barCount, 0.0);
    }

    final result = List<double>.filled(barCount, 0.0);

    // Group frequency bins into logarithmically spaced bands.
    for (var band = 0; band < barCount; band++) {
    final start = math
          .pow(
            nyquistBin.toDouble(),
            band / barCount,
          )
          .toDouble()
          .floor()
          .clamp(1, nyquistBin - 1);


      final end = math
          .pow(
            nyquistBin.toDouble(),
            (band + 1) / barCount,
          )
          .ceil()
          .clamp(start + 1, nyquistBin)
          .toInt();

      var energy = 0.0;
      var count = 0;

      for (var bin = start; bin < end; bin++) {
        var real = 0.0;
        var imaginary = 0.0;

        for (var sample = 0; sample < frameCount; sample++) {
          final angle =
              2 * math.pi * bin * sample / frameCount;

          real += samples[sample] * math.cos(angle);
          imaginary -= samples[sample] * math.sin(angle);
        }

        final magnitude =
            math.sqrt(real * real + imaginary * imaginary) /
            frameCount;

        energy += magnitude;
        count++;
      }

      final magnitude = count == 0 ? 0.0 : energy / count;

      // Logarithmic compression makes quieter bands more visible.
      result[band] = (
        math.log(1 + magnitude * 90) / math.log(91)
      ).clamp(0.0, 1.0).toDouble();
    }

    return result;
  }

  /// Creates deterministic, animated preview bars for the UI.
  ///
  /// Use this while developing the visualizer before connecting real audio.
  static List<double> previewBars(
    int count, {
    double phase = 0.0,
  }) {
    if (count <= 0) return const [];

    return List<double>.generate(count, (index) {
      final x = index / count;

      final bass = math.exp(-x * 4.0) *
          (0.36 + 0.28 * math.sin(phase * 0.8 + index * 0.16));

      final mids = math.exp(-math.pow((x - 0.43) * 3.1, 2)) *
          (0.16 +
              0.3 *
                  (0.5 +
                      0.5 *
                          math.sin(phase * 1.25 + index * 0.37)));

      final highs =
          (0.04 +
                  0.13 *
                      (0.5 +
                          0.5 *
                              math.sin(
                                phase * 1.8 + index * 0.63,
                              ))) *
              math.pow(x, 0.7);

      return (0.08 + bass + mids + highs)
          .clamp(0.06, 0.95)
          .toDouble();
    });
  }
}
