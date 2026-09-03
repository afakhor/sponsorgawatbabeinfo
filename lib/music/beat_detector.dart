import 'dart:math' as math;

class BeatDetector {
  final int sampleRate;
  final int channels;

  const BeatDetector({
    required this.sampleRate,
    required this.channels,
  });

  List<double> detectBeatTimes(
    List<double> samples, {
    double? bpm,
  }) {
    if (samples.isEmpty ||
        sampleRate <= 0 ||
        channels <= 0) {
      return <double>[];
    }

    final List<double> mono = _toMono(samples);

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

        final double hann =
            0.5 -
            0.5 *
                math.cos(
                  2.0 * math.pi * phase,
                );

        final double sample =
            mono[start + i];

        final double value =
            sample * hann;

        energy += value * value;
      }

      energies.add(
        energy / windowSize,
      );
    }

    if (energies.length < 5) {
      return <double>[];
    }

    final List<double> onset =
        _calculateOnsetStrength(energies);

    final List<double> normalized =
        _normalize(onset);

    if (normalized.length < 5) {
      return <double>[];
    }

    final List<double> beats = <double>[];

    double lastBeatTime = -100.0;

    final double minimumInterval =
        _minimumBeatInterval(bpm);

    for (
      int i = 2;
      i < normalized.length - 2;
      i++
    ) {
      final double previous2 =
          normalized[i - 2];

      final double previous =
          normalized[i - 1];

      final double current =
          normalized[i];

      final double next =
          normalized[i + 1];

      final double next2 =
          normalized[i + 2];

      final bool localPeak =
          current > previous2 &&
          current >= previous &&
          current >= next &&
          current > next2;

      final bool strongEnough =
          current >= 0.48;

      final double timeSeconds =
          i * hopSize / sampleRate;

      final bool farEnough =
          timeSeconds - lastBeatTime >=
          minimumInterval;

      if (localPeak &&
          strongEnough &&
          farEnough) {
        beats.add(timeSeconds);
        lastBeatTime = timeSeconds;
      }
    }

    return beats;
  }

  List<double> _toMono(
    List<double> samples,
  ) {
    if (channels <= 1) {
      return List<double>.from(samples);
    }

    final List<double> mono = <double>[];

    for (
      int i = 0;
      i + channels <= samples.length;
      i += channels
    ) {
      double sum = 0.0;

      for (
        int channel = 0;
        channel < channels;
        channel++
      ) {
        final double value =
            samples[i + channel];

        if (value.isFinite) {
          sum += value;
        }
      }

      mono.add(sum / channels);
    }

    return mono;
  }

  List<double> _calculateOnsetStrength(
    List<double> energies,
  ) {
    final List<double> onset =
        List<double>.filled(
      energies.length,
      0.0,
    );

    for (int i = 1; i < energies.length; i++) {
      final double increase =
          energies[i] - energies[i - 1];

      onset[i] = math.max(
        increase,
        0.0,
      );
    }

    return onset;
  }

  List<double> _normalize(
    List<double> values,
  ) {
    if (values.isEmpty) {
      return <double>[];
    }

    final List<double> finiteValues =
        values
            .where(
              (double value) => value.isFinite,
            )
            .toList();

    if (finiteValues.isEmpty) {
      return List<double>.filled(
        values.length,
        0.0,
      );
    }

    final List<double> sorted =
        List<double>.from(finiteValues)
          ..sort();

    final double median =
        sorted[sorted.length ~/ 2];

    final double average =
        finiteValues.reduce(
              (double a, double b) => a + b,
            ) /
            finiteValues.length;

    final double baseline =
        math.max(
      median,
      average * 0.25,
    );

    final double safeBaseline =
        math.max(
      baseline,
      0.0000001,
    );

    return values.map((double value) {
      if (!value.isFinite || value <= 0.0) {
        return 0.0;
      }

      return (value / safeBaseline).clamp(
        0.0,
        1.0,
      );
    }).toList();
  }

  double _minimumBeatInterval(
    double? bpm,
  ) {
    if (bpm == null ||
        !bpm.isFinite ||
        bpm <= 0.0) {
      return 0.18;
    }

    final double interval =
        60.0 / bpm;

    return interval.clamp(
      0.12,
      0.70,
    );
  }
}
