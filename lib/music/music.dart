import 'dart:async';
import 'dart:io';

import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart' as ja;

class MusicController extends ChangeNotifier {
  final ja.AudioPlayer audioPlayer = ja.AudioPlayer();
  final PlayerController waveformController = PlayerController();

  File? selectedMusicFile;
  String? musicName;

  Duration position = Duration.zero;
  Duration duration = Duration.zero;

  bool isPlaying = false;
  bool isLoading = false;
  String? errorMessage;

  StreamSubscription<Duration>? positionSubscription;
  StreamSubscription<Duration?>? durationSubscription;
  StreamSubscription<ja.PlayerState>? playerStateSubscription;

  MusicController() {
    positionSubscription = audioPlayer.positionStream.listen((value) {
      position = value;
      notifyListeners();
    });

    durationSubscription = audioPlayer.durationStream.listen((value) {
      if (value != null) {
        duration = value;
        notifyListeners();
      }
    });

    playerStateSubscription = audioPlayer.playerStateStream.listen((state) {
      isPlaying = state.playing;
      if (state.processingState == ja.ProcessingState.completed) {
        isPlaying = false;
        position = Duration.zero;
        try {
          waveformController.stopPlayer();
        } catch (_) {}
      }
      notifyListeners();
    });
  }

  Future<void> pickMusic() async {
    try {
      errorMessage = null;
      final result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: false,
        withData: false,
      );

      if (result == null || result.files.single.path == null) return;

      final path = result.files.single.path!;
      selectedMusicFile = File(path);
      musicName = result.files.single.name;

      isLoading = true;
      position = Duration.zero;
      duration = Duration.zero;
      isPlaying = false;
      notifyListeners();

      await audioPlayer.stop();
      await audioPlayer.setFilePath(path);
      duration = audioPlayer.duration ?? Duration.zero;

      try {
        await waveformController.preparePlayer(
          path: path,
          shouldExtractWaveform: true,
          noOfSamples: 120,
        );
        await waveformController.stopPlayer();
      } catch (e) {
        debugPrint('Waveform gagal: $e');
      }
    } catch (e) {
      errorMessage = e.toString();
      debugPrint('Pick music error: $e');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> togglePlay() async {
    if (selectedMusicFile == null) return;
    try {
      errorMessage = null;
      if (audioPlayer.playing) {
        await audioPlayer.pause();
        try { await waveformController.pausePlayer(); } catch (_) {}
      } else {
        await audioPlayer.play();
        try { await waveformController.startPlayer(); } catch (_) {}
      }
    } catch (e) {
      errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<void> seekTo(Duration value) async {
    if (duration == Duration.zero) return;
    Duration safe = value;
    if (value < Duration.zero) safe = Duration.zero;
    if (value > duration) safe = duration;

    try { await audioPlayer.seek(safe); } catch (_) {}
    try { await waveformController.seekTo(safe.inMilliseconds); } catch (_) {}

    position = safe;
    notifyListeners();
  }

  Future<void> stopMusic() async {
    try { await audioPlayer.stop(); } catch (_) {}
    try { await waveformController.stopPlayer(); } catch (_) {}
    position = Duration.zero;
    isPlaying = false;
    notifyListeners();
  }

  String formatDuration(Duration v) {
    final m = v.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = v.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  double sliderMaximum() {
    if (duration.inMilliseconds <= 0) return 1.0;
    return duration.inMilliseconds.toDouble();
  }

  double sliderValue() {
    if (duration.inMilliseconds <= 0) return 0.0;
    return position.inMilliseconds.toDouble().clamp(0.0, duration.inMilliseconds.toDouble());
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
  const MusicPanel({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Container(
          width: double.infinity,
          color: const Color(0xFF080811),
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(),
              _buildErrorMessage(),
              _buildWaveform(context),
              _buildSlider(context), // FIX: pakai context asli
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
        const Icon(Icons.music_note, color: Colors.amber, size: 20),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            controller.musicName ?? 'Belum ada musik',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ),
        if (controller.isLoading)
          const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.amber)),
        IconButton(
          onPressed: controller.isLoading ? null : controller.pickMusic,
          icon: const Icon(Icons.upload_file, color: Colors.amber),
          tooltip: 'Pilih musik',
        ),
      ],
    );
  }

  Widget _buildErrorMessage() {
    if (controller.errorMessage == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(controller.errorMessage!, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.redAccent, fontSize: 10)),
    );
  }

  Widget _buildWaveform(BuildContext context) {
    return SizedBox(
      height: 38,
      width: double.infinity,
      child: controller.selectedMusicFile == null
          ? const Center(child: Text('Pilih file musik untuk membuat waveform', style: TextStyle(color: Colors.white38, fontSize: 10)))
          : AudioFileWaveforms(
              size: Size(MediaQuery.of(context).size.width, 38),
              playerController: controller.waveformController,
              enableSeekGesture: true,
              waveformType: WaveformType.fitWidth,
              playerWaveStyle: const PlayerWaveStyle(fixedWaveColor: Colors.white24, liveWaveColor: Colors.amber, spacing: 3, waveThickness: 2),
            ),
    );
  }

  Widget _buildSlider(BuildContext context) {
    return SliderTheme(
      data: SliderTheme.of(context).copyWith( // FIX UTAMA
        trackHeight: 2.0,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5.0),
      ),
      child: Slider(
        value: controller.sliderValue(),
        min: 0.0,
        max: controller.sliderMaximum(),
        activeColor: Colors.amber,
        inactiveColor: Colors.white24,
        onChanged: controller.duration == Duration.zero
            ? null
            : (v) => controller.seekTo(Duration(milliseconds: v.toInt())),
      ),
    );
  }

  Widget _buildTimeLabels() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(controller.formatDuration(controller.position), style: const TextStyle(color: Colors.white60, fontSize: 10)),
        Text(controller.formatDuration(controller.duration), style: const TextStyle(color: Colors.white60, fontSize: 10)),
      ],
    );
  }

  Widget _buildControlButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          onPressed: controller.selectedMusicFile == null ? null : controller.stopMusic,
          icon: const Icon(Icons.stop_circle, color: Colors.white70, size: 28),
        ),
        IconButton(
          onPressed: controller.selectedMusicFile == null ? null : controller.togglePlay,
          icon: Icon(controller.isPlaying ? Icons.pause_circle : Icons.play_circle, color: Colors.amber, size: 44),
        ),
      ],
    );
  }
}