import 'dart:async';
import 'dart:io';
import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart' as ja;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class RunningText extends StatefulWidget {
  final String text;
  final Color color;
  const RunningText({super.key, required this.text, this.color = Colors.amber});
  @override State<RunningText> createState() => _RunningTextState();
}
class _RunningTextState extends State<RunningText> with SingleTickerProviderStateMixin {
  late AnimationController _c;
  @override void initState(){ super.initState(); _c=AnimationController(vsync:this, duration: const Duration(seconds:14))..repeat(); }
  @override void dispose(){ _c.dispose(); super.dispose(); }
  @override Widget build(BuildContext c){
    if(widget.text.isEmpty) return const SizedBox(height:18);
    return SizedBox(height:18, child: ClipRect(child: AnimatedBuilder(animation:_c, builder:(ctx,_){
      return Transform.translate(offset: Offset(120 - (_c.value*350),0), child: Text(widget.text, maxLines:1, style: TextStyle(color:widget.color,fontSize:14,fontWeight:FontWeight.w600,letterSpacing:0.3)));
    })));
  }
}

class MusicController extends ChangeNotifier {
  final ja.AudioPlayer audioPlayer=ja.AudioPlayer();
  final PlayerController waveformController=PlayerController();
  File? selectedMusicFile;
  String musicName='Belum ada musik';
  String editableTitle='SPONSOR BABE INFO GAWAT • TAP UNTUK EDIT JUDUL';
  String lyricText='Lyric akan muncul di sini...\nTap lyric untuk fold in/out\nGeser ke atas untuk pilih lagu & slider detik';
  Duration position=Duration.zero, duration=Duration.zero;
  bool isPlaying=false, isLoading=false;
  String? errorMessage;

  MusicController(){
    audioPlayer.positionStream.listen((v){ position=v; notifyListeners(); });
    audioPlayer.durationStream.listen((v){ if(v!=null){ duration=v; notifyListeners(); }});
    audioPlayer.playerStateStream.listen((s){
      isPlaying=s.playing;
      if(s.processingState==ja.ProcessingState.completed){ isPlaying=false; position=Duration.zero; try{waveformController.stopPlayer();}catch(_){} }
      notifyListeners();
    });
    audioPlayer.setVolume(1.0);
  }
  Future<bool> _req() async {
    if(!Platform.isAndroid) return true;
    final sdk=(await DeviceInfoPlugin().androidInfo).version.sdkInt;
    if(sdk>=33) return (await Permission.audio.request()).isGranted;
    return (await Permission.storage.request()).isGranted;
  }
  Future<void> pickMusic() async {
    try{
      if(!await _req()){ errorMessage='Izin audio ditolak'; notifyListeners(); return; }
      final res=await FilePicker.platform.pickFiles(type: FileType.audio, withData:true);
      if(res==null||res.files.isEmpty) return;
      final p=res.files.single;
      String? path=p.path;
      if(path==null && p.bytes!=null){
        final dir=await getTemporaryDirectory();
        final f=File('${dir.path}/${p.name}');
        await f.writeAsBytes(p.bytes!,flush:true);
        path=f.path;
      }
      if(path==null) return;
      selectedMusicFile=File(path);
      musicName=p.name;
      editableTitle=musicName!;
      lyricText='Memutar: $musicName\n\n[00:05] Babe info gawat jalan...\n[00:12] Lyric demo bisa panjang...';
      isLoading=true; notifyListeners();
      await audioPlayer.stop(); try{await waveformController.stopPlayer();}catch(_){}
      await audioPlayer.setAudioSource(ja.AudioSource.file(path));
      duration=audioPlayer.duration??Duration.zero;
      try{ await waveformController.preparePlayer(path:path, shouldExtractWaveform:true, noOfSamples:100); await waveformController.stopPlayer(); }catch(_){}
    }catch(e){ errorMessage='Gagal: $e'; }
    finally{ isLoading=false; notifyListeners(); }
  }
  Future<void> togglePlay() async {
    if(selectedMusicFile==null){ errorMessage='Geser atas untuk pilih lagu 📁'; notifyListeners(); return; }
    if(audioPlayer.playing){ await audioPlayer.pause(); try{await waveformController.pausePlayer();}catch(_){} }
    else { await audioPlayer.play(); try{await waveformController.startPlayer();}catch(_){} }
  }
  Future<void> stopMusic() async { try{await audioPlayer.stop();}catch(_){} try{await waveformController.stopPlayer();}catch(_){} position=Duration.zero; isPlaying=false; notifyListeners(); }
  Future<void> seekTo(Duration v) async {
    Duration safe=v; if(safe<Duration.zero) safe=Duration.zero; if(safe>duration) safe=duration;
    try{await audioPlayer.seek(safe);}catch(_){} try{await waveformController.seekTo(safe.inMilliseconds);}catch(_){}
    position=safe; notifyListeners();
  }
  String fmt(Duration v)=>'${v.inMinutes.remainder(60).toString().padLeft(2,'0')}:${v.inSeconds.remainder(60).toString().padLeft(2,'0')}';
  double max()=>duration.inMilliseconds<=0?1.0:duration.inMilliseconds.toDouble();
  double val(){ if(duration.inMilliseconds<=0) return 0; double c=position.inMilliseconds.toDouble(); double m=duration.inMilliseconds.toDouble(); if(c<0) return 0; if(c>m) return m; return c; }
  @override void dispose(){ audioPlayer.dispose(); waveformController.dispose(); super.dispose(); }
}

class MusicPanel extends StatefulWidget {
  final MusicController controller;
  final ScrollController scrollController;
  final DraggableScrollableController sheetController;
  const MusicPanel({super.key, required this.controller, required this.scrollController, required this.sheetController});
  @override State<MusicPanel> createState() => _MusicPanelState();
}

class _MusicPanelState extends State<MusicPanel> {
  bool lyricExpanded=true;
  bool get isSheetExpanded => widget.sheetController.isAttached ? widget.sheetController.size >= 0.6 : false;

  void _editTitle() async {
    final c = TextEditingController(text: widget.controller.editableTitle);
    final result = await showDialog<String>(context: context, builder: (ctx)=>AlertDialog(
      backgroundColor: const Color(0xFF1E1E24),
      title: const Text('Edit Judul Running Text', style: TextStyle(color:Colors.white,fontSize:14)),
      content: TextField(controller:c, style: const TextStyle(color:Colors.white,fontSize:14), autofocus:true, decoration: const InputDecoration(hintText:'Judul lagu', hintStyle:TextStyle(color:Colors.white38))),
      actions: [TextButton(onPressed: ()=>Navigator.pop(ctx), child: const Text('Batal')), TextButton(onPressed: ()=>Navigator.pop(ctx,c.text), child: const Text('Simpan', style:TextStyle(color:Colors.amber)))],
    ));
    if(result!=null && result.isNotEmpty){ widget.controller.editableTitle=result; widget.controller.notifyListeners(); }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context,_){
        final ctrl=widget.controller;
        final showPicker=isSheetExpanded;
        final showSlider=isSheetExpanded;
        return ListView(
          controller: widget.scrollController,
          padding: const EdgeInsets.fromLTRB(12,10,12,16),
          children: [
            Center(child: Container(width:42,height:5,decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10)))),
            const SizedBox(height:10),

            // FOLDER PICKER - AUTO HIDE, GESER BAWAH HILANG, GESER ATAS MUNCUL
            AnimatedCrossFade(
              duration: const Duration(milliseconds:250),
              firstChild: const SizedBox.shrink(),
              secondChild: Container(
                padding: const EdgeInsets.symmetric(horizontal:10,vertical:8),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.07), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.amber.withOpacity(0.3))),
                child: Row(children:[
                  const Icon(Icons.music_note,color:Colors.amber,size:20),
                  const SizedBox(width:8),
                  Expanded(child: Text(ctrl.musicName, maxLines:1, overflow:TextOverflow.ellipsis, style: const TextStyle(color:Colors.white,fontSize:13,fontWeight:FontWeight.bold))),
                  if(ctrl.isLoading) const SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2,color:Colors.amber)),
                  const SizedBox(width:8),
                  InkWell(onTap: ctrl.pickMusic, borderRadius: BorderRadius.circular(8), child: Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.folder_open,color:Colors.black,size:22))),
                ]),
              ),
              crossFadeState: showPicker ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            ),
            if(ctrl.errorMessage!=null) Padding(padding: const EdgeInsets.only(top:6), child: Text(ctrl.errorMessage!, style: const TextStyle(color:Colors.redAccent,fontSize:11))),

            const SizedBox(height:10),
            // 1 RUNNING TEXT JUDUL BISA EDIT
            InkWell(
              onTap: _editTitle,
              child: Container(width:double.infinity, padding: const EdgeInsets.symmetric(horizontal:10,vertical:6), decoration: BoxDecoration(color: Colors.amber.withOpacity(0.14), borderRadius: BorderRadius.circular(8)),
                child: Row(children:[
                  const Icon(Icons.edit,size:14,color:Colors.amber),
                  const SizedBox(width:6),
                  Expanded(child: RunningText(text: ctrl.editableTitle)),
                ]),
              ),
            ),

            const SizedBox(height:8),
            // WAVE / EQUALIZER
            Container(height:52, decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white12)), child: ctrl.selectedMusicFile==null ? const Center(child: Text('Waveform / Equalizer akan muncul di sini', style: TextStyle(color:Colors.white24,fontSize:11))) : AudioFileWaveforms(size: Size(MediaQuery.of(context).size.width-24,52), playerController: ctrl.waveformController, enableSeekGesture:true, waveformType: WaveformType.fitWidth, playerWaveStyle: const PlayerWaveStyle(fixedWaveColor:Colors.white24,liveWaveColor:Colors.amber,spacing:3,waveThickness:2))),

            const SizedBox(height:8),
            // 1 LYRIC FOLD IN/OUT
            GestureDetector(
              onTap: ()=>setState(()=>lyricExpanded=!lyricExpanded),
              child: AnimatedContainer(
                duration: const Duration(milliseconds:250),
                width: double.infinity,
                constraints: BoxConstraints(minHeight: lyricExpanded? 70 : 36, maxHeight: lyricExpanded? 140 : 36),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white12)),
                child: lyricExpanded 
                  ? SingleChildScrollView(child: Text(ctrl.lyricText, style: const TextStyle(color:Colors.white70,fontSize:14,height:1.4)))
                  : RunningText(text: ctrl.lyricText.replaceAll('\n',' • '), color: Colors.white70),
              ),
            ),
            const SizedBox(height:4),
            Center(child: Text(lyricExpanded?'Tap lyric untuk fold in':'Tap lyric untuk fold out', style: const TextStyle(color:Colors.white24,fontSize:10))),

            const SizedBox(height:12),
            // PLAY KIRI, PAUSE KANAN
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children:[
              // KIRI - PLAY
              Container(decoration: const BoxDecoration(color: Colors.amber, shape: BoxShape.circle), child: IconButton(onPressed: ctrl.togglePlay, icon: const Icon(Icons.play_arrow_rounded,color:Colors.black,size:36))),
              // TENGAH STATUS
              Column(children:[Text(ctrl.isPlaying?'PLAYING':'PAUSED', style: TextStyle(color: ctrl.isPlaying?Colors.amber:Colors.white38,fontSize:11,fontWeight:FontWeight.bold)), Text(ctrl.fmt(ctrl.position), style: const TextStyle(color:Colors.white60,fontSize:11))]),
              // KANAN - PAUSE
              Container(decoration: BoxDecoration(color: Colors.white12, shape: BoxShape.circle, border: Border.all(color: Colors.white24)), child: IconButton(onPressed: () async { if(ctrl.audioPlayer.playing){ await ctrl.audioPlayer.pause(); try{await ctrl.waveformController.pausePlayer();}catch(_){} } }, icon: const Icon(Icons.pause_rounded,color:Colors.white,size:32))),
            ]),

            const SizedBox(height:10),
            // SLIDER DETIK - AUTO HIDE GESER ATAS MUNCUL
            AnimatedCrossFade(
              duration: const Duration(milliseconds:250),
              firstChild: const SizedBox.shrink(),
              secondChild: Column(children:[
                SliderTheme(data: SliderTheme.of(context).copyWith(trackHeight:3, thumbShape: const RoundSliderThumbShape(enabledThumbRadius:8)), child: Slider(value: ctrl.val(), min:0, max:ctrl.max(), activeColor:Colors.amber, inactiveColor:Colors.white24, onChanged: ctrl.duration==Duration.zero?null:(v)=>ctrl.seekTo(Duration(milliseconds:v.toInt())))),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children:[Text(ctrl.fmt(ctrl.position),style: const TextStyle(color:Colors.white60,fontSize:11)), Text(ctrl.fmt(ctrl.duration),style: const TextStyle(color:Colors.white60,fontSize:11))]),
              ]),
              crossFadeState: showSlider ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            ),

            const SizedBox(height:10),
            Center(child: Text(showPicker?'▼ Geser bawah hide folder & slider':'▲ Geser atas untuk folder 📁 & slider detik', style: const TextStyle(color:Colors.white24,fontSize:11))),
          ],
        );
      },
    );
  }
}