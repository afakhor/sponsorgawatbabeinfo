import 'dart:async';
import 'dart:io';

import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart' as ja;

class MusicController extends ChangeNotifier {
  final ja.AudioPlayer audioPlayer = ja.AudioPlayer();

  final PlayerController waveformController =
      PlayerController();

  File? selectedMusicFile;
  String? musicName;

  Duration position = Duration.zero;
  Duration duration = Duration.zero;

  bool isPlaying = false;
  bool isLoading = false;
  String? errorMessage;

  StreamSubscription<Duration>? positionSubscription;
  StreamSubscription<Duration?>? durationSubscription;
  StreamSubscription<ja.PlayerState>?
      playerStateSubscription;

  MusicController() {
    positionSubscription =
        audioPlayer.positionStream.listen(
      (Duration value) {
        position = value;
        notifyListeners();
      },
    );

    durationSubscription =
        audioPlayer.durationStream.listen(
      (Duration? value) {
        if (value != null) {
          duration = value;
          notifyListeners();
        }
      },
    );

    playerStateSubscription =
        audioPlayer.playerStateStream.listen(
      (ja.PlayerState state) {
        isPlaying = state.playing;

        if (state.processingState ==
            ja.ProcessingState.completed) {
          isPlaying = false;
          position = Duration.zero;
        }

        notifyListeners();
      },
    );
  }

  Future<void> pickMusic() async {
    try {
      errorMessage = null;

      final FilePickerResult? result =
          await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: false,
        withData: false,
      );

      if (result == null ||
          result.files.single.path == null) {
        return;
      }

      final String path =
          result.files.single.path!;

      selectedMusicFile = File(path);
      musicName = result.files.single.name;

      isLoading = true;
      position = Duration.zero;
      duration = Duration.zero;
      isPlaying = false;
      notifyListeners();

      // Hentikan audio sebelumnya.
      await audioPlayer.stop();

      // Muat audio lokal.
      await audioPlayer.setFilePath(path);

      duration =
          audioPlayer.duration ?? Duration.zero;

      // Buat waveform.
      try {
        await waveformController.preparePlayer(
          path: path,
          shouldExtractWaveform: true,
          noOfSamples: 120,
        );

        await waveformController.stopPlayer();
      } catch (error) {
        debugPrint(
          'Waveform gagal dibuat: $error',
        );

        // Musik tetap dapat diputar meskipun
        // waveform gagal dibuat.
      }
    } catch (error) {
      errorMessage = error.toString();
      debugPrint('Pick music error: $error');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> togglePlay() async {
    if (selectedMusicFile == null) {
      return;
    }

    try {
      errorMessage = null;

      if (audioPlayer.playing) {
        await audioPlayer.pause();

        try {
          await waveformController.pausePlayer();
        } catch (error) {
          debugPrint(
            'Waveform pause gagal: $error',
          );
        }
      } else {
        await audioPlayer.play();

        try {
          await waveformController.startPlayer();
        } catch (error) {
          debugPrint(
            'Waveform start gagal: $error',
          );
        }
      }
    } catch (error) {
      errorMessage = error.toString();
      debugPrint('Toggle play error: $error');
      notifyListeners();
    }
  }

  Future<void> seekTo(Duration value) async {
    if (duration == Duration.zero) {
      return;
    }

    Duration safeValue;

    if (value < Duration.zero) {
      safeValue = Duration.zero;
    } else if (value > duration) {
      safeValue = duration;
    } else {
      safeValue = value;
    }

    try {
      // Seek audio utama.
      await audioPlayer.seek(safeValue);
    } catch (error) {
      debugPrint(
        'Audio seek gagal: $error',
      );
    }

    try {
      // audio_waveforms 2.0.2 membutuhkan int,
      // bukan double progress.
      await waveformController.seekTo(
        safeValue.inMilliseconds,
      );
    } catch (error) {
      debugPrint(
        'Waveform seek gagal: $error',
      );
    }

    position = safeValue;
    notifyListeners();
  }

  Future<void> stopMusic() async {
    try {
      await audioPlayer.stop();
    } catch (error) {
      debugPrint(
        'Audio stop gagal: $error',
      );
    }

    try {
      await waveformController.stopPlayer();
    } catch (error) {
      debugPrint(
        'Waveform stop gagal: $error',
      );
    }

    position = Duration.zero;
    isPlaying = false;

    notifyListeners();
  }

  String formatDuration(Duration value) {
    final String minutes = value.inMinutes
        .remainder(60)
        .toString()
        .padLeft(2, '0');

    final String seconds = value.inSeconds
        .remainder(60)
        .toString()
        .padLeft(2, '0');

    return '$minutes:$seconds';
  }

  double sliderMaximum() {
    if (duration.inMilliseconds <= 0) {
      return 1.0;
    }

    return duration.inMilliseconds.toDouble();
  }

  double sliderValue() {
    if (duration.inMilliseconds <= 0) {
      return 0.0;
    }

    final double currentValue =
        position.inMilliseconds.toDouble();

    return currentValue
        .clamp(
          0.0,
          duration.inMilliseconds.toDouble(),
        )
        .toDouble();
  }

  @override
  void dispose() {
    positionSubscription?.cancel();
    durationSubscription?.cancel();
    playerStateSubscription?.cancel();

    audioPlayer.dispose();
    waveformController.dispose();

    super.dispose();
  }
}

class MusicPanel extends StatelessWidget {
  final MusicController controller;

  const MusicPanel({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (
        BuildContext context,
        Widget? child,
      ) {
        return Container(
          width: double.infinity,
          color: const Color(0xFF080811),
          padding: const EdgeInsets.fromLTRB(
            12.0,
            8.0,
            12.0,
            8.0,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(),
              _buildErrorMessage(),
              _buildWaveform(context),
              _buildSlider(),
              _buildTimeLabels(),
              _buildControlButtons(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        const Icon(
          Icons.music_note,
          color: Colors.amber,
          size: 20.0,
        ),
        const SizedBox(width: 6.0),
        Expanded(
          child: Text(
            controller.musicName ??
                'Belum ada musik',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12.0,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        if (controller.isLoading)
          const SizedBox(
            width: 18.0,
            height: 18.0,
            child: CircularProgressIndicator(
              strokeWidth: 2.0,
              color: Colors.amber,
            ),
          ),
        IconButton(
          onPressed: controller.isLoading
              ? null
              : controller.pickMusic,
          icon: const Icon(
            Icons.upload_file,
            color: Colors.amber,
          ),
          tooltip: 'Pilih musik',
        ),
      ],
    );
  }

  Widget _buildErrorMessage() {
    if (controller.errorMessage == null) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(
        bottom: 4.0,
      ),
      child: Text(
        controller.errorMessage!,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.redAccent,
          fontSize: 10.0,
        ),
      ),
    );
  }

  Widget _buildWaveform(BuildContext context) {
    return SizedBox(
      height: 38.0,
      width: double.infinity,
      child: controller.selectedMusicFile == null
          ? const Center(
              child: Text(
                'Pilih file musik untuk membuat waveform',
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 10.0,
                ),
              ),
            )
          : AudioFileWaveforms(
              size: Size(
                MediaQuery.of(context).size.width,
                38.0,
              ),
              playerController:
                  controller.waveformController,
              enableSeekGesture: true,
              waveformType:
                  WaveformType.fitWidth,
              playerWaveStyle:
                  const PlayerWaveStyle(
                fixedWaveColor: Colors.white24,
                liveWaveColor: Colors.amber,
                spacing: 3.0,
                waveThickness: 2.0,
              ),
            ),
    );
  }

  Widget _buildSlider() {
    return SliderTheme(
      data: SliderTheme.of(_dummyContext()).copyWith(
        trackHeight: 2.0,
        thumbShape:
            const RoundSliderThumbShape(
          enabledThumbRadius: 5.0,
        ),
      ),
      child: Slider(
        value: controller.sliderValue(),
        min: 0.0,
        max: controller.sliderMaximum(),
        activeColor: Colors.amber,
        inactiveColor: Colors.white24,
        onChanged: controller.duration ==
                Duration.zero
            ? null
            : (double value) {
                controller.seekTo(
                  Duration(
                    milliseconds: value.toInt(),
                  ),
                );
              },
      ),
    );
  }

  Widget _buildTimeLabels() {
    return Row(
      mainAxisAlignment:
          MainAxisAlignment.spaceBetween,
      children: [
        Text(
          controller.formatDuration(
            controller.position,
          ),
          style: const TextStyle(
            color: Colors.white60,
            fontSize: 10.0,
          ),
        ),
        Text(
          controller.formatDuration(
            controller.duration,
          ),
          style: const TextStyle(
            color: Colors.white60,
            fontSize: 10.0,
          ),
        ),
      ],
    );
  }

  Widget _buildControlButtons() {
    return Row(
      mainAxisAlignment:
          MainAxisAlignment.center,
      children: [
        IconButton(
          onPressed:
              controller.selectedMusicFile == null
                  ? null
                  : controller.stopMusic,
          icon: const Icon(
            Icons.stop_circle,
            color: Colors.white70,
            size: 28.0,
          ),
        ),
        IconButton(
          onPressed:
              controller.selectedMusicFile == null
                  ? null
                  : controller.togglePlay,
          icon: Icon(
            controller.isPlaying
                ? Icons.pause_circle
                : Icons.play_circle,
            color: Colors.amber,
            size: 44.0,
          ),
        ),
      ],
    );
  }

  // Context sederhana untuk SliderTheme.
  // Tidak digunakan untuk membangun widget visual.
  BuildContext _dummyContext() {
    throw UnimplementedError();
  }
}
