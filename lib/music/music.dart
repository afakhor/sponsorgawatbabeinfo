import 'dart:async';
import 'dart:io';
import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screen_recording/flutter_screen_recording.dart';
import 'package:just_audio/just_audio.dart' as ja;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';

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
      return Transform.translate(offset: Offset(120 - (_c.value*350),0), child: Text(widget.text, maxLines:1, style: TextStyle(color:widget.color,fontSize:14,fontWeight:FontWeight.w600)));
    })));
  }
}

class MusicController extends ChangeNotifier {
  final ja.AudioPlayer audioPlayer=ja.AudioPlayer();
  final PlayerController waveformController=PlayerController();

  File? selectedMusicFile;
  String musicName='Belum ada musik';
  String editableTitle='SPONSOR BABE INFO GAWAT • TAP UNTUK EDIT JUDUL';
  List<String> lyricLines=['Tap lyric untuk fold in/out','Geser atas untuk pilih lagu 📁','Putar musik untuk lyric per kalimat muncul'];
  int currentLyricIndex=0;
  Duration position=Duration.zero, duration=Duration.zero;
  bool isPlaying=false, isLoading=false, isRecording=false;
  String? errorMessage;
  String? recordedPath;
  Timer? recordTimer;
  int recordSeconds=0;

  MusicController(){
    audioPlayer.positionStream.listen((v){
      position=v;
      if(lyricLines.isNotEmpty && duration.inSeconds>2){
        int idx = ((v.inSeconds / duration.inSeconds) * lyricLines.length).floor();
        if(idx<0) idx=0;
        if(idx>=lyricLines.length) idx=lyricLines.length-1;
        if(idx!=currentLyricIndex) currentLyricIndex=idx;
      }
      notifyListeners();
    });
    audioPlayer.durationStream.listen((v){ if(v!=null){ duration=v; notifyListeners(); }});
    audioPlayer.playerStateStream.listen((s){
      isPlaying=s.playing;
      if(s.processingState==ja.ProcessingState.completed){ isPlaying=false; position=Duration.zero; try{waveformController.stopPlayer();}catch(_){} }
      notifyListeners();
    });
    audioPlayer.setVolume(1.0);
  }

  Future<void> _req() async {
    if(!Platform.isAndroid) return;
    await Permission.storage.request();
    await Permission.audio.request();
    await Permission.microphone.request();
  }

  Future<void> pickMusic() async {
    try{
      await _req();
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
      lyricLines=['Memutar: $musicName','Babe Info Gawat di angkasa','Globe berputar musik berdentum','Wave naik turun ikuti beat','Share ke WhatsApp Status sekarang'];
      currentLyricIndex=0;
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

  Future<void> seekTo(Duration v) async {
    Duration safe=v;
    if(safe<Duration.zero) safe=Duration.zero;
    if(safe>duration) safe=duration;
    try{await audioPlayer.seek(safe);}catch(_){}
    try{await waveformController.seekTo(safe.inMilliseconds);}catch(_){}
    position=safe; notifyListeners();
  }

  Future<void> startRecord() async {
    try{
      await _req();
      // FIX UTAMA: SEMBUNYIKAN JAM,SINYAL,BATERAI BIAR GAK KE-RECORD
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      
      final dir=await getTemporaryDirectory();
      isRecording=true; recordSeconds=0; recordedPath=null; notifyListeners();
      final fileName='babe_${DateTime.now().millisecondsSinceEpoch}';
      await FlutterScreenRecording.startRecordScreen(fileName, dirPath: dir.path, audioEnable: true);
      recordTimer?.cancel();
      recordTimer=Timer.periodic(const Duration(seconds:1), (t){
        recordSeconds++; notifyListeners();
        if(recordSeconds>=60) stopRecord();
      });
    }catch(e){
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      isRecording=false; errorMessage='Record gagal: $e'; notifyListeners();
    }
  }

  Future<void> stopRecord() async {
    try{
      recordTimer?.cancel();
      recordedPath = await FlutterScreenRecording.stopRecordScreen;
      isRecording=false;
      // BALIKIN SYSTEM UI BIAR JAM MUNCUL LAGI
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.black,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarIconBrightness: Brightness.light,
      ));
      notifyListeners();
    }catch(e){
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      isRecording=false; errorMessage='Stop gagal: $e'; notifyListeners();
    }
  }

  Future<void> shareToWhatsApp() async {
    if(recordedPath==null || !File(recordedPath!).existsSync()){ errorMessage='Belum ada video record'; notifyListeners(); return; }
    await Share.shareXFiles([XFile(recordedPath!)], text: editableTitle);
  }

  String fmt(Duration v)=>'${v.inMinutes.remainder(60).toString().padLeft(2,'0')}:${v.inSeconds.remainder(60).toString().padLeft(2,'0')}';
  double max()=>duration.inMilliseconds<=0?1.0:duration.inMilliseconds.toDouble();
  double val(){
    if(duration.inMilliseconds<=0) return 0;
    double c=position.inMilliseconds.toDouble();
    double m=duration.inMilliseconds.toDouble();
    if(c<0) return 0; if(c>m) return m; return c;
  }
  @override void dispose(){ recordTimer?.cancel(); audioPlayer.dispose(); waveformController.dispose(); super.dispose(); }
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
    final c=TextEditingController(text: widget.controller.editableTitle);
    final result=await showDialog<String>(context: context, builder: (ctx)=>AlertDialog(
      backgroundColor: const Color(0xFF1E1E24),
      title: const Text('Edit Judul Running Text', style: TextStyle(color:Colors.white,fontSize:14)),
      content: TextField(controller:c, style: const TextStyle(color:Colors.white,fontSize:14), autofocus:true),
      actions: [TextButton(onPressed: ()=>Navigator.pop(ctx), child: const Text('Batal')), TextButton(onPressed: ()=>Navigator.pop(ctx,c.text), child: const Text('Simpan', style:TextStyle(color:Colors.amber)))],
    ));
    if(result!=null && result.isNotEmpty){ widget.controller.editableTitle=result; widget.controller.notifyListeners(); }
  }

  @override Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context,_){
        final ctrl=widget.controller;
        final showPicker=isSheetExpanded;
        return ListView(
          controller: widget.scrollController,
          padding: const EdgeInsets.fromLTRB(12,10,12,16),
          children: [
            Center(child: Container(width:42,height:5,decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10)))),
            const SizedBox(height:10),
            AnimatedCrossFade(duration: const Duration(milliseconds:250), firstChild: const SizedBox.shrink(), secondChild: Container(padding: const EdgeInsets.symmetric(horizontal:10,vertical:8), decoration: BoxDecoration(color: Colors.white.withOpacity(0.07), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.amber.withOpacity(0.3))), child: Row(children:[const Icon(Icons.music_note,color:Colors.amber,size:20), const SizedBox(width:8), Expanded(child: Text(ctrl.musicName, maxLines:1, overflow:TextOverflow.ellipsis, style: const TextStyle(color:Colors.white,fontSize:13,fontWeight:FontWeight.bold))), if(ctrl.isLoading) const SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2,color:Colors.amber)), const SizedBox(width:8), InkWell(onTap: ctrl.pickMusic, child: Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.folder_open,color:Colors.black,size:22)))]),), crossFadeState: showPicker ? CrossFadeState.showSecond : CrossFadeState.showFirst),
            if(ctrl.errorMessage!=null) Padding(padding: const EdgeInsets.only(top:6), child: Text(ctrl.errorMessage!, style: const TextStyle(color:Colors.redAccent,fontSize:11))),
            const SizedBox(height:10),
            InkWell(onTap: _editTitle, child: Container(width:double.infinity, padding: const EdgeInsets.symmetric(horizontal:10,vertical:6), decoration: BoxDecoration(color: Colors.amber.withOpacity(0.14), borderRadius: BorderRadius.circular(8)), child: Row(children:[const Icon(Icons.edit,size:14,color:Colors.amber), const SizedBox(width:6), Expanded(child: RunningText(text: ctrl.editableTitle))]))),
            const SizedBox(height:8),
            Container(height:52, decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white12)), child: ctrl.selectedMusicFile==null ? const Center(child: Text('Waveform / Equalizer', style: TextStyle(color:Colors.white24,fontSize:11))) : AudioFileWaveforms(size: Size(MediaQuery.of(context).size.width-24,52), playerController: ctrl.waveformController, enableSeekGesture:true, waveformType: WaveformType.fitWidth, playerWaveStyle: const PlayerWaveStyle(fixedWaveColor:Colors.white24,liveWaveColor:Colors.amber,spacing:3,waveThickness:2))),
            const SizedBox(height:8),
            GestureDetector(onTap: ()=>setState(()=>lyricExpanded=!lyricExpanded), child: AnimatedContainer(duration: const Duration(milliseconds:250), width: double.infinity, padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white12)), child: lyricExpanded ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: ctrl.lyricLines.asMap().entries.map((e){ final isActive = e.key==ctrl.currentLyricIndex; return AnimatedContainer(duration: const Duration(milliseconds:200), padding: const EdgeInsets.symmetric(vertical:2), child: Text(e.value, style: TextStyle(color: isActive?Colors.amber:Colors.white54, fontSize: isActive?14:12, fontWeight: isActive?FontWeight.bold:FontWeight.normal))); }).toList()) : RunningText(text: ctrl.lyricLines.isNotEmpty ? ctrl.lyricLines[ctrl.currentLyricIndex] : '', color: Colors.white70),)),
            const SizedBox(height:12),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children:[
              Container(decoration: const BoxDecoration(color: Colors.amber, shape: BoxShape.circle), child: IconButton(onPressed: ctrl.togglePlay, icon: const Icon(Icons.play_arrow_rounded,color:Colors.black,size:36))),
              GestureDetector(onTap: ctrl.isRecording ? ctrl.stopRecord : ctrl.startRecord, child: Container(padding: const EdgeInsets.symmetric(horizontal:14,vertical:8), decoration: BoxDecoration(color: ctrl.isRecording?Colors.red:Colors.white12, borderRadius: BorderRadius.circular(20)), child: Row(children:[Icon(ctrl.isRecording?Icons.stop:Icons.fiber_manual_record, color: ctrl.isRecording?Colors.white:Colors.red, size:16), const SizedBox(width:6), Text(ctrl.isRecording?'${ctrl.recordSeconds}s / 60s':'REC', style: TextStyle(color: ctrl.isRecording?Colors.white:Colors.white70,fontSize:12,fontWeight:FontWeight.bold))])),
              ),
              Container(decoration: BoxDecoration(color: Colors.white12, shape: BoxShape.circle, border: Border.all(color: Colors.white24)), child: IconButton(onPressed: () async { if(ctrl.audioPlayer.playing){ await ctrl.audioPlayer.pause(); try{await ctrl.waveformController.pausePlayer();}catch(_){} } }, icon: const Icon(Icons.pause_rounded,color:Colors.white,size:32))),
            ]),
            const SizedBox(height:10),
            AnimatedCrossFade(duration: const Duration(milliseconds:250), firstChild: const SizedBox.shrink(), secondChild: Column(children:[SliderTheme(data: SliderTheme.of(context).copyWith(trackHeight:3, thumbShape: const RoundSliderThumbShape(enabledThumbRadius:8)), child: Slider(value: ctrl.val(), min:0, max:ctrl.max(), activeColor:Colors.amber, inactiveColor:Colors.white24, onChanged: ctrl.duration==Duration.zero?null:(v)=>ctrl.seekTo(Duration(milliseconds:v.toInt())))), Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children:[Text(ctrl.fmt(ctrl.position),style: const TextStyle(color:Colors.white60,fontSize:11)), Text(ctrl.fmt(ctrl.duration),style: const TextStyle(color:Colors.white60,fontSize:11))]),]), crossFadeState: showPicker ? CrossFadeState.showSecond : CrossFadeState.showFirst),
            const SizedBox(height:12),
            if(ctrl.recordedPath!=null) Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.green.withOpacity(0.12), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.green.withOpacity(0.3))), child: Column(children:[Row(children:[const Icon(Icons.check_circle,color:Colors.green,size:18), const SizedBox(width:6), Expanded(child: Text('Video: ${ctrl.recordedPath!.split('/').last}', maxLines:1, overflow:TextOverflow.ellipsis, style: const TextStyle(color:Colors.white,fontSize:11)))]), const SizedBox(height:8), SizedBox(width:double.infinity, child: ElevatedButton.icon(onPressed: ctrl.shareToWhatsApp, icon: const Icon(Icons.share,color:Colors.white,size:18), label: const Text('Preview & Share ke WhatsApp 1 menit', style: TextStyle(fontSize:13)), style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))))),]),),
            const SizedBox(height:10),
            Center(child: Text(showPicker?'▼ Geser bawah hide':'▲ Geser atas untuk 📁 & slider & REC', style: const TextStyle(color:Colors.white24,fontSize:11))),
          ],
        );
      },
    );
  }
}