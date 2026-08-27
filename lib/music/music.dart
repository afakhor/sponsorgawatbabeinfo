import 'dart:async';
import 'dart:io';
import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart' as ja;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

// Widget running text 14px
class RunningText extends StatefulWidget {
  final String text;
  final Color color;
  const RunningText({super.key, required this.text, required this.color});
  @override State<RunningText> createState() => _RunningTextState();
}
class _RunningTextState extends State<RunningText> with SingleTickerProviderStateMixin {
  late AnimationController _c;
  @override void initState() { super.initState(); _c = AnimationController(vsync: this, duration: const Duration(seconds: 10))..repeat(); }
  @override void dispose() { _c.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) {
    return SizedBox(height: 18, child: ClipRect(child: AnimatedBuilder(animation: _c, builder: (context, _) {
      return Transform.translate(offset: Offset(-(_c.value*200)%200,0), child: Text(widget.text, maxLines:1, style: TextStyle(color:widget.color,fontSize:14,fontWeight:FontWeight.w500,letterSpacing:0.5), overflow:TextOverflow.visible));
    })));
  }
}

class MusicController extends ChangeNotifier {
  final ja.AudioPlayer audioPlayer = ja.AudioPlayer();
  final PlayerController waveformController = PlayerController();
  File? selectedMusicFile;
  String? musicName;
  String lyricText = 'Lyric akan muncul di sini... putar musik untuk melihat sinkronisasi';
  Duration position = Duration.zero;
  Duration duration = Duration.zero;
  bool isPlaying = false;
  bool isLoading = false;
  String? errorMessage;

  MusicController() {
    audioPlayer.positionStream.listen((v){ position=v; notifyListeners(); });
    audioPlayer.durationStream.listen((v){ if(v!=null){ duration=v; notifyListeners(); }});
    audioPlayer.playerStateStream.listen((s){
      isPlaying=s.playing;
      if(s.processingState==ja.ProcessingState.completed){ isPlaying=false; position=Duration.zero; try{waveformController.stopPlayer();}catch(_){} }
      notifyListeners();
    });
    audioPlayer.setVolume(1.0);
  }

  Future<bool> _reqPerm() async {
    if(!Platform.isAndroid) return true;
    final sdk=(await DeviceInfoPlugin().androidInfo).version.sdkInt;
    if(sdk>=33) return (await Permission.audio.request()).isGranted;
    return (await Permission.storage.request()).isGranted;
  }

  Future<void> pickMusic() async {
    try{
      if(!await _reqPerm()){ errorMessage='Izin audio ditolak'; notifyListeners(); return; }
      final res=await FilePicker.platform.pickFiles(type: FileType.audio, withData:true);
      if(res==null||res.files.isEmpty) return;
      final picked=res.files.single;
      String? path=picked.path;
      if(path==null && picked.bytes!=null){
        final dir=await getTemporaryDirectory();
        final f=File('${dir.path}/${picked.name}');
        await f.writeAsBytes(picked.bytes!,flush:true);
        path=f.path;
      }
      if(path==null){ errorMessage='Path null'; notifyListeners(); return; }
      selectedMusicFile=File(path);
      musicName=picked.name;
      lyricText='Memutar: $musicName\n\n[00:00] Lyric demo...\n[00:05] Babe Info Gawat jalan...';
      isLoading=true; notifyListeners();
      await audioPlayer.stop();
      try{await waveformController.stopPlayer();}catch(_){}
      await audioPlayer.setAudioSource(ja.AudioSource.file(path));
      duration=audioPlayer.duration??Duration.zero;
      try{
        await waveformController.preparePlayer(path:path, shouldExtractWaveform:true, noOfSamples:100);
        await waveformController.stopPlayer();
      }catch(_){}
    }catch(e){ errorMessage='Gagal: $e'; }
    finally{ isLoading=false; notifyListeners(); }
  }

  Future<void> togglePlay() async {
    if(selectedMusicFile==null){ errorMessage='Pilih musik dulu (icon folder)'; notifyListeners(); return; }
    try{
      if(audioPlayer.playing){ await audioPlayer.pause(); try{await waveformController.pausePlayer();}catch(_){} }
      else { await audioPlayer.play(); try{await waveformController.startPlayer();}catch(_){} }
    }catch(e){ errorMessage='Play gagal: $e'; notifyListeners(); }
  }
  Future<void> stopMusic() async { try{await audioPlayer.stop();}catch(_){} try{await waveformController.stopPlayer();}catch(_){} position=Duration.zero; isPlaying=false; notifyListeners(); }
  Future<void> seekTo(Duration v) async {
    Duration safe=v; if(safe<Duration.zero) safe=Duration.zero; if(safe>duration) safe=duration;
    try{await audioPlayer.seek(safe);}catch(_){} try{await waveformController.seekTo(safe.inMilliseconds);}catch(_){}
    position=safe; notifyListeners();
  }
  String fmt(Duration v)=>'${v.inMinutes.remainder(60).toString().padLeft(2,'0')}:${v.inSeconds.remainder(60).toString().padLeft(2,'0')}';
  double max()=>duration.inMilliseconds<=0?1.0:duration.inMilliseconds.toDouble();
  double val(){
    if(duration.inMilliseconds<=0) return 0;
    double c=position.inMilliseconds.toDouble();
    double m=duration.inMilliseconds.toDouble();
    if(c<0) return 0; if(c>m) return m; return c;
  }
  @override void dispose(){ audioPlayer.dispose(); waveformController.dispose(); super.dispose(); }
}

class MusicPanel extends StatelessWidget {
  final MusicController controller;
  const MusicPanel({super.key, required this.controller});
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context,_)=> Container(
        color: const Color(0xFF080811),
        padding: const EdgeInsets.fromLTRB(12,8,12,8),
        child: Column(
          children: [
            // HEADER + UPLOAD
            Row(children:[
              const Icon(Icons.music_note,color:Colors.amber,size:18),
              const SizedBox(width:6),
              Expanded(child: Text(controller.musicName??'Belum ada musik', maxLines:1, overflow:TextOverflow.ellipsis, style: const TextStyle(color:Colors.white,fontSize:12,fontWeight:FontWeight.bold))),
              if(controller.isLoading) const SizedBox(width:16,height:16,child:CircularProgressIndicator(strokeWidth:2,color:Colors.amber)),
              IconButton(onPressed: controller.pickMusic, icon: const Icon(Icons.folder_open,color:Colors.amber,size:26)),
            ]),
            if(controller.errorMessage!=null) Text(controller.errorMessage!, style: const TextStyle(color:Colors.redAccent,fontSize:11)),

            // RUNNING TEXT 1 - 14px
            Container(width:double.infinity, color: Colors.amber.withOpacity(0.12), padding: const EdgeInsets.symmetric(horizontal:6,vertical:2), child: RunningText(text: controller.musicName!=null ? '♫ NOW PLAYING: ${controller.musicName} ♫ SPONSOR BABE INFO GAWAT ♫ ' : 'PILIH MUSIK UNTUK MEMUTAR - SPONSOR BABE INFO GAWAT - ', color: Colors.amber)),
            
            // RUNNING TEXT 2 - 14px
            Container(width:double.infinity, color: Colors.white.withOpacity(0.06), padding: const EdgeInsets.symmetric(horizontal:6,vertical:2), child: RunningText(text: 'LIVE FROM GLOBE • INFO GAWAT • MUSIC MODE ON • EQUALIZER ACTIVE • ', color: Colors.white70)),

            const SizedBox(height:6),
            // WAVE / EQUALIZER
            Container(height: 48, width: double.infinity, decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.white12)), child: controller.selectedMusicFile==null ? const Center(child: Text('Waveform / Equalizer akan muncul di sini', style: TextStyle(color:Colors.white24,fontSize:11))) : AudioFileWaveforms(size: Size(MediaQuery.of(context).size.width-28,48), playerController: controller.waveformController, enableSeekGesture:true, waveformType: WaveformType.fitWidth, playerWaveStyle: const PlayerWaveStyle(fixedWaveColor:Colors.white24,liveWaveColor:Colors.amber,spacing:3,waveThickness:2, showSeekLine:true))),
            
            SliderTheme(data: SliderTheme.of(context).copyWith(trackHeight:2, thumbShape: const RoundSliderThumbShape(enabledThumbRadius:6)), child: Slider(value: controller.val(), min:0, max:controller.max(), activeColor:Colors.amber, inactiveColor:Colors.white24, onChanged: controller.duration==Duration.zero?null:(v)=>controller.seekTo(Duration(milliseconds:v.toInt())))),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children:[Text(controller.fmt(controller.position),style: const TextStyle(color:Colors.white60,fontSize:11)), Text(controller.fmt(controller.duration),style: const TextStyle(color:Colors.white60,fontSize:11))]),

            // LYRIC BOX 14px
            Expanded(child: Container(width:double.infinity, margin: const EdgeInsets.only(top:4), padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.white12)), child: SingleChildScrollView(child: Text(controller.lyricText, style: const TextStyle(color:Colors.white70,fontSize:14,height:1.4))))),

            const SizedBox(height:6),
            // PLAY / PAUSE GEDE - PASTI KELIHATAN
            Row(mainAxisAlignment: MainAxisAlignment.center, children:[
              Container(decoration: BoxDecoration(color: Colors.white12, shape: BoxShape.circle), child: IconButton(onPressed: controller.stopMusic, icon: const Icon(Icons.stop_rounded,color:Colors.white,size:28))),
              const SizedBox(width:16),
              Container(decoration: const BoxDecoration(color: Colors.amber, shape: BoxShape.circle), padding: const EdgeInsets.all(4), child: IconButton(onPressed: controller.togglePlay, icon: Icon(controller.isPlaying?Icons.pause_rounded:Icons.play_arrow_rounded, color:Colors.black, size:38))),
            ]),
          ],
        ),
      ),
    );
  }
}