import 'dart:async';
import 'dart:io';

import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

class MusicController extends ChangeNotifier {
  final AudioPlayer audioPlayer = AudioPlayer();

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
  StreamSubscription<PlayerState>? playerStateSubscription;

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
      (PlayerState state) {
        isPlaying = state.playing;

        // Jika lagu selesai, kembalikan status ke awal.
        if (state.processingState ==
            ProcessingState.completed) {
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
      notifyListeners();

      // Hentikan lagu sebelumnya.
      await audioPlayer.stop();

      // Muat file musik lokal ke just_audio.
      await audioPlayer.setFilePath(path);

      // Buat waveform dari file audio.
      try {
        await waveformController.preparePlayer(
          path: path,
          shouldExtractWaveform: true,
          noOfSamples: 120,
        );

        await waveformController.stopPlayer();
      } catch (waveformError) {
        // Jika waveform gagal, musik tetap bisa diputar.
        debugPrint(
          'Waveform gagal dibuat: $waveformError',
        );
      }

      position = Duration.zero;
      duration =
          audioPlayer.duration ?? Duration.zero;
    } catch (error) {
      errorMessage = error.toString();
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
        } catch (_) {}
      } else {
        await audioPlayer.play();

        try {
          await waveformController.startPlayer();
        } catch (_) {}
      }
    } catch (error) {
      errorMessage = error.toString();
      notifyListeners();
    }
  }

  Future<void> seekTo(Duration value) async {
    if (duration == Duration.zero) {
      return;
    }

    final Duration safeValue;

    if (value < Duration.zero) {
      safeValue = Duration.zero;
    } else if (value > duration) {
      safeValue = duration;
    } else {
      safeValue = value;
    }

    await audioPlayer.seek(safeValue);

    // audio_waveforms menggunakan nilai progres 0 sampai 1.
    if (duration.inMilliseconds > 0) {
      final double progress =
          safeValue.inMilliseconds /
          duration.inMilliseconds;

      try {
        await waveformController.seekTo(
          progress.clamp(0.0, 1.0),
        );
      } catch (_) {}
    }

    notifyListeners();
  }

  Future<void> stopMusic() async {
    await audioPlayer.stop();

    try {
      await waveformController.stopPlayer();
    } catch (_) {}

    position = Duration.zero;
    isPlaying = false;

    notifyListeners();
  }

  String formatDuration(Duration value) {
    final String minutes =
        value.inMinutes
            .remainder(60)
            .toString()
            .padLeft(2, '0');

    final String seconds =
        value.inSeconds
            .remainder(60)
            .toString()
            .padLeft(2, '0');

    return '$minutes:$seconds';
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
              Row(
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
              ),

              if (controller.errorMessage != null)
                Padding(
                  padding:
                      const EdgeInsets.only(bottom: 4.0),
                  child: Text(
                    controller.errorMessage!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontSize: 10.0,
                    ),
                  ),
                ),

              // Waveform musik.
              SizedBox(
                height: 38.0,
                width: double.infinity,
                child: controller.selectedMusicFile ==
                        null
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
                          fixedWaveColor:
                              Colors.white24,
                          liveWaveColor:
                              Colors.amber,
                          spacing: 3.0,
                          waveThickness: 2.0,
                        ),
                      ),
              ),

              const SizedBox(height: 2.0),

              // Slider posisi musik.
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 2.0,
                  thumbShape:
                      const RoundSliderThumbShape(
                    enabledThumbRadius: 5.0,
                  ),
                ),
                child: Slider(
                  value: _sliderValue(controller),
                  min: 0.0,
                  max: _sliderMax(controller),
                  activeColor: Colors.amber,
                  inactiveColor: Colors.white24,
                  onChanged:
                      controller.duration ==
                              Duration.zero
                          ? null
                          : (double value) {
                              controller.seekTo(
                                Duration(
                                  milliseconds:
                                      value.toInt(),
                                ),
                              );
                            },
                ),
              ),

              Row(
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
              ),

              // Tombol kontrol.
              Row(
                mainAxisAlignment:
                    MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed:
                        controller.selectedMusicFile ==
                                null
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
                        controller.selectedMusicFile ==
                                null
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
              ),
            ],
          ),
        );
      },
    );
  }

  double _sliderMax(
    MusicController controller,
  ) {
    if (controller.duration.inMilliseconds <= 0) {
      return 1.0;
    }

    return controller.duration.inMilliseconds
        .toDouble();
  }

  double _sliderValue(
    MusicController controller,
  ) {
    if (controller.duration.inMilliseconds <= 0) {
      return 0.0;
    }

    final double value =
        controller.position.inMilliseconds.toDouble();

    return value.clamp(
      0.0,
      controller.duration.inMilliseconds.toDouble(),
    );
  }
}
