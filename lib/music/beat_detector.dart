import 'dart:math' as math;

/// Beat detector offline untuk mencari waktu beat dari seluruh buffer audio.
class BeatDetector {
  final int sampleRate;
  final int channels;

  const BeatDetector({
    required this.sampleRate,
    required this.channels,
  });

  /// Mendeteksi posisi beat dalam satuan detik.
  ///
  /// [samples] dapat berupa:
  /// - mono:       [L, L, L, L, ...]
  /// - stereo:     [L, R, L, R, ...]
  ///
  /// Hasil:
  /// [0.52, 1.01, 1.49, ...]
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

        // Hann window.
        final double window =
            0.5 -
            0.5 *
                math.cos(
                  2.0 * math.pi * phase,
                );

        final double sample =
            mono[start + i];

        final double value =
            sample * window;

        energy += value * value;
      }

      energies.add(
        energy / windowSize,
      );
    }

    if (energies.length < 5) {
      return <double>[];
    }

    // Mengambil kenaikan energi untuk mendeteksi onset.
    final List<double> onset =
        _calculateOnsetStrength(energies);

    if (onset.isEmpty) {
      return <double>[];
    }

    final List<double> normalized =
        _normalize(onset);

    final List<double> beatTimes =
        <double>[];

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

      // Puncak lokal lima titik.
      final bool isPeak =
          current > previous2 &&
          current >= previous &&
          current >= next &&
          current > next2;

      final double timeSeconds =
          i * hopSize / sampleRate;

      final bool isStrong =
          current >= 0.48;

      final bool farEnough =
          timeSeconds - lastBeatTime >=
          minimumInterval;

      if (isPeak &&
          isStrong &&
          farEnough) {
        beatTimes.add(timeSeconds);
        lastBeatTime = timeSeconds;
      }
    }

    return beatTimes;
  }

  /// Mengubah sinyal interleaved menjadi mono.
  List<double> _toMono(
    List<double> samples,
  ) {
    if (channels <= 1) {
      return List<double>.from(samples);
    }

    final List<double> mono =
        <double>[];

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

  /// Menghitung hanya kenaikan energi.
  ///
  /// Beat biasanya terlihat sebagai lonjakan energi,
  /// bukan sebagai volume yang terus-menerus tinggi.
  List<double> _calculateOnsetStrength(
    List<double> energies,
  ) {
    if (energies.length < 2) {
      return <double>[];
    }

    final List<double> onset =
        List<double>.filled(
      energies.length,
      0.0,
    );

    for (int i = 1; i < energies.length; i++) {
      final double current =
          energies[i];

      final double previous =
          energies[i - 1];

      final double increase =
          current - previous;

      // Hanya kenaikan energi yang dihitung.
      onset[i] = math.max(
        increase,
        0.0,
      );
    }

    return onset;
  }

  /// Normalisasi onset berdasarkan median.
  List<double> _normalize(
    List<double> values,
  ) {
    if (values.isEmpty) {
      return <double>[];
    }

    final List<double> finiteValues =
        values
            .where((double value) {
              return value.isFinite;
            })
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

      final double normalized =
          value / safeBaseline;

      // Nilai lebih dari 1 tidak perlu dipertahankan
      // karena threshold bekerja pada rentang 0 sampai 1.
      return normalized.clamp(
        0.0,
        1.0,
      );
    }).toList();
  }

  /// Jarak minimum antarbeat.
  ///
  /// Tanpa BPM, 180 ms mengizinkan tempo sampai
  /// sekitar 333 BPM.
  double _minimumBeatInterval(
    double? bpm,
  ) {
    if (bpm == null ||
        !bpm.isFinite ||
        bpm <= 0.0) {
      return 0.18;
    }

    final double beatInterval =
        60.0 / bpm;

    // Jangan terlalu cepat dan jangan terlalu lambat.
    return beatInterval.clamp(
      0.12,
      0.70,
    );
  }
}

/// Beat pulse realtime untuk shader.
///
/// Class ini menerima amplitude audio setiap frame,
/// lalu menghasilkan nilai pulse dari 0.0 sampai 1.0.
class RealtimeBeatPulse {
  double _averageEnergy = 0.0;
  double _fastEnergy = 0.0;
  double _pulse = 0.0;

  int _lastBeatMilliseconds =
      -1000000;

  /// Nilai pulse terakhir.
  double get value {
    return _pulse;
  }

  /// Memperbarui pulse berdasarkan amplitude audio.
  ///
  /// [amplitude] sebaiknya sudah berada pada rentang 0.0 sampai 1.0.
  ///
  /// [timestampMilliseconds] harus terus meningkat,
  /// misalnya dari posisi audio atau stopwatch.
  ///
  /// [bpm] bersifat opsional.
  double update({
    required double amplitude,
    required int timestampMilliseconds,
    double? bpm,
  }) {
    double input =
        amplitude.abs();

    if (!input.isFinite) {
      input = 0.0;
    }

    input = input.clamp(
      0.0,
      1.0,
    );

    // Energi lambat untuk baseline.
    _averageEnergy =
        _averageEnergy * 0.94 +
        input * 0.06;

    // Energi cepat mengikuti transien atau hentakan.
    _fastEnergy =
        _fastEnergy * 0.55 +
        input * 0.45;

    final double transient =
        math.max(
      _fastEnergy - _averageEnergy,
      0.0,
    );

    final double adaptiveThreshold =
        math.max(
      0.035,
      _averageEnergy * 0.22,
    );

    final int cooldownMilliseconds =
        _cooldownMilliseconds(bpm);

    final bool strongEnough =
        input > 0.08 &&
        transient > adaptiveThreshold;

    final bool cooldownPassed =
        timestampMilliseconds -
                _lastBeatMilliseconds >=
            cooldownMilliseconds;

    if (strongEnough && cooldownPassed) {
      _lastBeatMilliseconds =
          timestampMilliseconds;

      // Beat baru menghasilkan pulse penuh.
      _pulse = 1.0;
    } else {
      // Decay halus agar animasi tidak patah.
      _pulse *= 0.885;

      if (_pulse < 0.001) {
        _pulse = 0.0;
      }
    }

    return _pulse.clamp(
      0.0,
      1.0,
    );
  }

  int _cooldownMilliseconds(
    double? bpm,
  ) {
    if (bpm == null ||
        !bpm.isFinite ||
        bpm <= 0.0) {
      return 180;
    }

    final double interval =
        60000.0 / bpm;

    final double cooldown =
        interval * 0.42;

    return cooldown.clamp(
      110.0,
      500.0,
    ).round();
  }

  void reset() {
    _averageEnergy = 0.0;
    _fastEnergy = 0.0;
    _pulse = 0.0;
    _lastBeatMilliseconds =
        -1000000;
  }
}
