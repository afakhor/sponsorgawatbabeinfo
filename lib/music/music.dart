import 'dart:async';
import 'dart:io';
import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart' as ja;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

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

  MusicController() {
    audioPlayer.positionStream.listen((v) { position = v; notifyListeners(); });
    audioPlayer.durationStream.listen((v) { if (v != null) { duration = v; notifyListeners(); } });
    audioPlayer.playerStateStream.listen((state) {
      isPlaying = state.playing;
      if (state.processingState == ja.ProcessingState.completed) {
        isPlaying = false;
        position = Duration.zero;
        try { waveformController.stopPlayer(); } catch (_) {}
      }
      notifyListeners();
    });
    // WAJIB: volume full
    audioPlayer.setVolume(1.0);
  }

  Future<bool> _reqPerm() async {
    if (!Platform.isAndroid) return true;
    final sdk = (await DeviceInfoPlugin().androidInfo).version.sdkInt;
    if (sdk >= 33) {
      return (await Permission.audio.request()).isGranted;
    } else {
      return (await Permission.storage.request()).isGranted;
    }
  }

  Future<void> pickMusic() async {
    try {
      errorMessage = null;
      if (!await _reqPerm()) {
        errorMessage = 'Izin audio ditolak. Buka Settings > Apps > izin Music';
        notifyListeners(); return;
      }

      final res = await FilePicker.platform.pickFiles(type: FileType.audio, withData: true);
      if (res == null || res.files.isEmpty) return;

      final picked = res.files.single;
      String? finalPath = picked.path;

      // FIX UTAMA: content:// harus di-copy
      if (finalPath == null && picked.bytes != null) {
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/${picked.name}');
        await file.writeAsBytes(picked.bytes!, flush: true);
        finalPath = file.path;
      } else if (finalPath != null && !File(finalPath).existsSync() && picked.bytes != null) {
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/${picked.name}');
        await file.writeAsBytes(picked.bytes!, flush: true);
        finalPath = file.path;
      }

      if (finalPath == null) {
        errorMessage = 'Path null. Coba file MP3 lain < 10MB';
        notifyListeners(); return;
      }

      selectedMusicFile = File(finalPath);
      musicName = picked.name;
      isLoading = true;
      notifyListeners();

      await audioPlayer.stop();
      try { await waveformController.stopPlayer(); } catch (_) {}

      // FIX UTAMA 2: pakai setAudioSource, bukan setFilePath saja
      debugPrint('LOAD AUDIO: $finalPath size: ${selectedMusicFile!.lengthSync()}');
      await audioPlayer.setAudioSource(ja.AudioSource.file(finalPath));
      
      duration = audioPlayer.duration ?? Duration.zero;
      position = Duration.zero;
      debugPrint('DURATION: $duration');

      try {
        await waveformController.preparePlayer(path: finalPath, shouldExtractWaveform: true, noOfSamples: 80);
        await waveformController.stopPlayer();
      } catch (e) {
        debugPrint('Waveform fail tapi audio tetap jalan: $e');
      }

    } catch (e, st) {
      debugPrint('PICK FAIL: $e $st');
      errorMessage = 'Gagal load: $e';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> togglePlay() async {
    if (selectedMusicFile == null) return;
    try {
      if (audioPlayer.playing) {
        await audioPlayer.pause();
        try { await waveformController.pausePlayer(); } catch (_) {}
      } else {
        if (audioPlayer.duration == null) {
          await audioPlayer.setAudioSource(ja.AudioSource.file(selectedMusicFile!.path));
        }
        await audioPlayer.play();
        try { await waveformController.startPlayer(); } catch (_) {}
      }
    } catch (e) {
      errorMessage = 'Gagal play: $e';
      debugPrint('PLAY FAIL: $e');
      notifyListeners();
    }
  }

  Future<void> stopMusic() async {
    try { await audioPlayer.stop(); } catch (_) {}
    try { await waveformController.stopPlayer(); } catch (_) {}
    position = Duration.zero; isPlaying = false; notifyListeners();
  }

  Future<void> seekTo(Duration v) async {
    final safe = v.clamp(Duration.zero, duration);
    try { await audioPlayer.seek(safe); } catch (_) {}
    try { await waveformController.seekTo(safe.inMilliseconds); } catch (_) {}
    position = safe; notifyListeners();
  }

  String formatDuration(Duration v) => '${v.inMinutes.remainder(60).toString().padLeft(2,'0')}:${v.inSeconds.remainder(60).toString().padLeft(2,'0')}';
  double sliderMaximum() => duration.inMilliseconds <= 0 ? 1.0 : duration.inMilliseconds.toDouble();
  double sliderValue() => duration.inMilliseconds <= 0 ? 0.0 : position.inMilliseconds.toDouble().clamp(0.0, duration.inMilliseconds.toDouble());

  @override
  void dispose() {
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
      builder: (context, _) => Container(
        width: double.infinity,
        color: const Color(0xFF080811),
        padding: const EdgeInsets.fromLTRB(12,8,12,20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            const Icon(Icons.music_note,color: Colors.amber,size:20),
            const SizedBox(width:6),
            Expanded(child: Text(controller.musicName ?? 'Belum ada musik', maxLines:1, overflow:TextOverflow.ellipsis, style: const TextStyle(color:Colors.white,fontSize:12,fontWeight:FontWeight.bold))),
            if (controller.isLoading) const SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2,color:Colors.amber)),
            IconButton(onPressed: controller.isLoading ? null : controller.pickMusic, icon: const Icon(Icons.upload_file,color:Colors.amber)),
          ]),
          if (controller.errorMessage != null)
            Container(width:double.infinity, color: Colors.red.withOpacity(0.2), padding: const EdgeInsets.all(6), child: Text(controller.errorMessage!, style: const TextStyle(color:Colors.redAccent,fontSize:10))),
          const SizedBox(height:4),
          SizedBox(height:38, child: controller.selectedMusicFile == null ? const Center(child: Text('Pilih MP3 untuk test', style: TextStyle(color:Colors.white38,fontSize:10))) : AudioFileWaveforms(size: Size(MediaQuery.of(context).size.width-24,38), playerController: controller.waveformController, enableSeekGesture:true, waveformType: WaveformType.fitWidth, playerWaveStyle: const PlayerWaveStyle(fixedWaveColor:Colors.white24,liveWaveColor:Colors.amber,spacing:3,waveThickness:2))),
          SliderTheme(data: SliderTheme.of(context).copyWith(trackHeight:2,thumbShape: const RoundSliderThumbShape(enabledThumbRadius:6)), child: Slider(value: controller.sliderValue(), min:0, max:controller.sliderMaximum(), activeColor:Colors.amber, inactiveColor:Colors.white24, onChanged: controller.duration==Duration.zero ? null : (v)=>controller.seekTo(Duration(milliseconds:v.toInt())))),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(controller.formatDuration(controller.position),style: const TextStyle(color:Colors.white60,fontSize:10)), Text(controller.formatDuration(controller.duration),style: const TextStyle(color:Colors.white60,fontSize:10))]),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            IconButton(onPressed: controller.selectedMusicFile==null?null:controller.stopMusic, icon: const Icon(Icons.stop_circle,color:Colors.white70,size:28)),
            IconButton(onPressed: controller.selectedMusicFile==null?null:controller.togglePlay, icon: Icon(controller.isPlaying?Icons.pause_circle:Icons.play_circle,color:Colors.amber,size:44)),
          ]),
          Text('debug duration: ${controller.duration.inSeconds}s', style: const TextStyle(color:Colors.white24,fontSize:8)),
        ]),
      ),
    );
  }
}