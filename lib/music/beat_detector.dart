import 'dart:math' as math;

class BeatDetector {
  final int sampleRate;
  final int channels;

  const BeatDetector({
    required this.sampleRate,
    required this.channels,
  });

  List<double> detectBeatTimes(
    List<double> samples,
  ) {
    if (samples.isEmpty) {
      return <double>[];
    }

    // Jika audio stereo, ubah interleaved stereo menjadi mono.
    final List<double> mono =
        _toMono(samples);

    // 1024 sampel dan lompatan 512 sampel
    // memberi resolusi waktu yang cukup baik.
    const int windowSize = 1024;
    const int hopSize = 512;

    if (mono.length < windowSize) {
      return <double>[];
    }

    final List<double> energies = <double>[];

    for (
      int start = 0;
      start + windowSize <= mono.length;
      start += hopSize
    ) {
      double energy = 0.0;

      for (int i = 0; i < windowSize; i++) {
        final double phase =
            i / (windowSize - 1);

        // Hann window.
        final double window =
            0.5 -
            0.5 *
                math.cos(
                  2.0 *
                      math.pi *
                      phase,
                );

        final double value =
            mono[start + i] *
            window;

        energy += value * value;
      }

      energies.add(
        energy / windowSize,
      );
    }

    if (energies.length < 3) {
      return <double>[];
    }

    final List<double> normalized =
        _normalize(energies);

    final List<double> beatTimes = <double>[];

    double lastBeat =
        -10.0;

    for (
      int i = 1;
      i < normalized.length - 1;
      i++
    ) {
      final double previous =
          normalized[i - 1];

      final double current =
          normalized[i];

      final double next =
          normalized[i + 1];

      final bool isPeak =
          current > previous &&
          current >= next;

      // Ambang sensitivitas deteksi beat.
      final bool isStrong =
          current >= 0.58;

      final double timeSeconds =
          i *
              hopSize /
              sampleRate;

      // Minimal jarak antarbeat 220 ms.
      // Ini membatasi sekitar maksimal 272 BPM.
      final bool farEnough =
          timeSeconds - lastBeat >= 0.22;

      if (isPeak &&
          isStrong &&
          farEnough) {
        beatTimes.add(timeSeconds);
        lastBeat = timeSeconds;
      }
    }

    return beatTimes;
  }

  List<double> _toMono(
    List<double> samples,
  ) {
    if (channels <= 1) {
      return samples;
    }

    final List<double> mono =
        <double>[];

    for (
      int i = 0;
      i + channels <= samples.length;
      i += channels
    ) {
      double sum = 0.0;

      for (int c = 0; c < channels; c++) {
        sum += samples[i + c];
      }

      mono.add(
        sum / channels,
      );
    }

    return mono;
  }

  List<double> _normalize(
  List<double> energies,
) {
  if (energies.isEmpty) {
    return <double>[];
  }

  final List<double> sorted =
      List<double>.from(energies)..sort();

  final double median =
      sorted[sorted.length ~/ 2];

  final double average =
      energies.reduce(
            (double a, double b) => a + b,
          ) /
          energies.length;

  final double baseline =
      math.max(
        median,
        average * 0.35,
      );

  return energies.map((double energy) {
    final double value =
        energy /
        (baseline + 0.0000001);

    // Jangan langsung clamp ke 1.0 sebelum
    // dibandingkan dengan energi sekitar.
    return value;
  }).toList();
}}
