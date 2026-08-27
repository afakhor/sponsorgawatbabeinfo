import 'dart:async';
import 'dart:io';
import 'package:audio_waveforms/audio_waveforms.dart';
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
  final double fontSize;
  const RunningText({super.key, required this.text, this.color = Colors.amber, this.fontSize = 14});
  @override State<RunningText> createState() => _RunningTextState();
}
class _RunningTextState extends State<RunningText> with SingleTickerProviderStateMixin {
  late AnimationController _c;
  @override void initState(){ super.initState(); _c=AnimationController(vsync:this, duration: const Duration(seconds:14))..repeat(); }
  @override void dispose(){ _c.dispose(); super.dispose(); }
  @override Widget build(BuildContext c){
    if(widget.text.isEmpty) return const SizedBox(height:20);
    return SizedBox(height:20, child: ClipRect(child: AnimatedBuilder(animation:_c, builder:(ctx,_){
      return Transform.translate(offset: Offset(200 - (_c.value*400),0), child: Text(widget.text, maxLines:1, style: TextStyle(color:widget.color,fontSize:widget.fontSize,fontWeight:FontWeight.w800)));
    })));
  }
}

class MusicController extends ChangeNotifier {
  final ja.AudioPlayer audioPlayer=ja.AudioPlayer();
  final PlayerController waveformController=PlayerController();

  File? selectedMusicFile;
  String musicName='Belum ada musik';
  String editableTitle='SPONSOR BABE INFO GAWAT • TAP UNTUK EDIT JUDUL';
  String editableBottomTitle='BABE INFO GAWAT • SHARE KE WA STATUS';
  List<String> lyricLines=['Tap lyric untuk fold in/out','Geser atas untuk pilih lagu 📁','Putar musik untuk lyric per kalimat muncul'];
  int currentLyricIndex=0;
  Duration position=Duration.zero, duration=Duration.zero;
  bool isPlaying=false, isLoading=false, isRecording=false;
  String? errorMessage;
  String? recordedPath;
  Timer? recordTimer;
  int recordSeconds=0;
  double trimStartSec=0;
  double trimEndSec=60;
  bool usePreTrim=false;

  MusicController(){
    audioPlayer.positionStream.listen((v){
      position=v;
      if(lyricLines.isNotEmpty && duration.inSeconds>2){
        int idx = ((v.inSeconds / duration.inSeconds) * lyricLines.length).floor();
        idx = idx.clamp(0, lyricLines.length-1);
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

  // OPSI 1: REC LANGSUNG - PANEL HILANG - STOP O -> DIALOG TRIM -> AUTO SHARE
  Future<void> startRecord() async {
    try{
      await _req();
      usePreTrim=false;
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      isRecording=true; recordSeconds=0; recordedPath=null; notifyListeners();
      final fileName='babe_${DateTime.now().millisecondsSinceEpoch}';
      await FlutterScreenRecording.startRecordScreen(fileName, titleNotification: "Babe REC", messageNotification: "60s tanpa UI");
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

  // OPSI 2: PILIH START-END DULU -> REC -> AUTO SHARE
  Future<void> startRecordWithTrim(BuildContext context) async {
    double tempStart=trimStartSec;
    double tempEnd=trimEndSec;
        final maxDur = duration.inSeconds>0 ? duration.inSeconds.toDouble() : 120.0;

    final result = await showDialog<Map<String,double>>(
      context: context,
      builder: (ctx)=>StatefulBuilder(builder: (ctx,setD)=>AlertDialog(
        backgroundColor: const Color(0xFF1E1E24),
        title: const Text('OPSI 2: Pilih Start-End', style: TextStyle(color: Colors.amber, fontSize: 14, fontWeight: FontWeight.bold)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Durasi: ${(tempEnd-tempStart).toInt()}s (max 60s)', style: const TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 12),
          RangeSlider(
            min: 0.0, max: maxDur,
            divisions: maxDur.toInt(),
            labels: RangeLabels('${tempStart.toInt()}s','${tempEnd.toInt()}s'),
            values: RangeValues(tempStart, tempEnd.clamp(tempStart+1, tempStart+60)),
            activeColor: Colors.amber,
            onChanged: (v){
              if(v.end - v.start >60) return;
              setD((){ tempStart=v.start; tempEnd=v.end; });
            },
          ),
          Row(children: [
            Text('${tempStart.toInt()}s', style: const TextStyle(color: Colors.white54, fontSize: 11)),
            const Spacer(),
            Text('${tempEnd.toInt()}s', style: const TextStyle(color: Colors.white54, fontSize: 11)),
          ]),
        ]),
        actions: [
          TextButton(onPressed: ()=>Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black),
            onPressed: ()=>Navigator.pop(ctx, {'start':tempStart,'end':tempEnd}),
            child: const Text('REC 60s'),
          ),
        ],
      )),
    );
    if(result==null) return;
    trimStartSec=result['start']!;
    trimEndSec=result['end']!;
    usePreTrim=true;
    final dur = (trimEndSec - trimStartSec).toInt().clamp(1,60);

    try{
      await _req();
      await seekTo(Duration(seconds: trimStartSec.toInt()));
      await Future.delayed(const Duration(milliseconds:200));
      await audioPlayer.play(); try{await waveformController.startPlayer();}catch(_){}
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      isRecording=true; recordSeconds=0; recordedPath=null; notifyListeners();
      final fileName='babe_trim_${DateTime.now().millisecondsSinceEpoch}';
      await FlutterScreenRecording.startRecordScreen(fileName, titleNotification: "Babe REC ${dur}s", messageNotification: "Dari ${trimStartSec.toInt()}s");
      recordTimer?.cancel();
      recordTimer=Timer.periodic(const Duration(seconds:1), (t) async {
        recordSeconds++; notifyListeners();
        if(recordSeconds>=dur){
          await stopRecord();
          await shareToWhatsApp();
        }
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
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      notifyListeners();
    }catch(e){
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      isRecording=false; errorMessage='Stop gagal: $e'; notifyListeners();
    }
  }

  Future<void> cancelRecord() async {
    try{
      recordTimer?.cancel();
      final p = await FlutterScreenRecording.stopRecordScreen;
      if(p!=null && File(p).existsSync()){ try{ await File(p).delete(); }catch(_){} }
    }catch(_){}
    recordedPath=null; isRecording=false;
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    notifyListeners();
  }

  Future<void> showPostRecordDialog(BuildContext context) async {
    if(recordedPath==null) return;
    double tempStart=0;
    double tempEnd=recordSeconds.toDouble().clamp(1,60);
    final res = await showDialog<Map<String,double>>(
      context: context,
      builder: (ctx)=>StatefulBuilder(builder: (ctx,setD)=>AlertDialog(
        backgroundColor: const Color(0xFF1E1E24),
        title: const Text('OPSI 1: Potong & Share?', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Video ${recordSeconds}s - Pilih ${tempStart.toInt()}s ke ${tempEnd.toInt()}s (max 60s)', style: const TextStyle(color: Colors.white70, fontSize: 11)),
          RangeSlider(
            min: 0, max: recordSeconds.toDouble(),
            divisions: recordSeconds,
            labels: RangeLabels('${tempStart.toInt()}s','${tempEnd.toInt()}s'),
            values: RangeValues(tempStart, tempEnd),
            activeColor: Colors.green,
            onChanged: (v){
              if(v.end - v.start >60) return;
              setD((){ tempStart=v.start; tempEnd=v.end; });
            },
          ),
        ]),
        actions: [
          TextButton(onPressed: ()=>Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: ()=>Navigator.pop(ctx, {'start':tempStart,'end':tempEnd}),
            child: const Text('Share WA', style: TextStyle(color: Colors.white)),
          ),
        ],
      )),
    );
    if(res!=null){
      trimStartSec=res['start']!; trimEndSec=res['end']!;
      await shareToWhatsApp();
    }
  }

  Future<void> shareToWhatsApp() async {
    if(recordedPath==null || !File(recordedPath!).existsSync()){ errorMessage='Belum ada video'; notifyListeners(); return; }
    final txt = "$editableTitle\n$editableBottomTitle\n[${trimStartSec.toInt()}s-${trimEndSec.toInt()}s]";
    await Share.shareXFiles([XFile(recordedPath!)], text: txt);
  }

  String fmt(Duration v)=>'${v.inMinutes.remainder(60).toString().padLeft(2,'0')}:${v.inSeconds.remainder(60).toString().padLeft(2,'0')}';
  double max()=>duration.inMilliseconds<=0?1.0:duration.inMilliseconds.toDouble();
  double val(){ if(duration.inMilliseconds<=0) return 0; return position.inMilliseconds.toDouble().clamp(0, duration.inMilliseconds.toDouble()); }
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
  void _editTitle(bool isTop) async {
    final c=TextEditingController(text: isTop ? widget.controller.editableTitle : widget.controller.editableBottomTitle);
    final result=await showDialog<String>(context: context, builder: (ctx)=>AlertDialog(
      backgroundColor: const Color(0xFF1E1E24),
      title: Text(isTop ? 'Edit Atas' : 'Edit Bawah', style: const TextStyle(color:Colors.white,fontSize:14)),
      content: TextField(controller:c, style: const TextStyle(color:Colors.white,fontSize:14), autofocus:true),
      actions: [TextButton(onPressed: ()=>Navigator.pop(ctx), child: const Text('Batal')), TextButton(onPressed: ()=>Navigator.pop(ctx,c.text), child: const Text('Simpan', style:TextStyle(color:Colors.amber)))],
    ));
    if(result!=null && result.isNotEmpty){ if(isTop) widget.controller.editableTitle=result; else widget.controller.editableBottomTitle=result; widget.controller.notifyListeners(); }
  }
  @override Widget build(BuildContext context) {
    return AnimatedBuilder(animation: widget.controller, builder: (context,_){
      final ctrl=widget.controller;
      final showPicker=isSheetExpanded;
      return ListView(controller: widget.scrollController, padding: const EdgeInsets.fromLTRB(12,10,12,16), children: [
        Center(child: Container(width:42,height:5,decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10)))),
        const SizedBox(height:10),
        AnimatedCrossFade(duration: const Duration(milliseconds:250), firstChild: const SizedBox.shrink(), secondChild: Container(padding: const EdgeInsets.symmetric(horizontal:10,vertical:8), decoration: BoxDecoration(color: Colors.white.withOpacity(0.07), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.amber.withOpacity(0.3))), child: Row(children:[const Icon(Icons.music_note,color:Colors.amber,size:20), const SizedBox(width:8), Expanded(child: Text(ctrl.musicName, maxLines:1, overflow:TextOverflow.ellipsis, style: const TextStyle(color:Colors.white,fontSize:13,fontWeight:FontWeight.bold))), const SizedBox(width:8), InkWell(onTap: ctrl.pickMusic, child: Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.folder_open,color:Colors.black,size:22)))]),), crossFadeState: showPicker ? CrossFadeState.showSecond : CrossFadeState.showFirst),
        const SizedBox(height:10),
        Row(children: [
          Expanded(child: InkWell(onTap: ()=>_editTitle(true), child: Container(padding: const EdgeInsets.symmetric(horizontal:10,vertical:6), decoration: BoxDecoration(color: Colors.amber.withOpacity(0.14), borderRadius: BorderRadius.circular(8)), child: RunningText(text: ctrl.editableTitle, fontSize: 12)))),
          const SizedBox(width:6),
          Expanded(child: InkWell(onTap: ()=>_editTitle(false), child: Container(padding: const EdgeInsets.symmetric(horizontal:10,vertical:6), decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: RunningText(text: ctrl.editableBottomTitle, color: Colors.white70, fontSize: 12)))),
        ]),
        const SizedBox(height:8),
        Container(height:52, decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white12)), child: ctrl.selectedMusicFile==null ? const Center(child: Text('Waveform', style: TextStyle(color:Colors.white24,fontSize:11))) : AudioFileWaveforms(size: Size(MediaQuery.of(context).size.width-24,52), playerController: ctrl.waveformController, enableSeekGesture:true, waveformType: WaveformType.fitWidth, playerWaveStyle: const PlayerWaveStyle(fixedWaveColor:Colors.white24,liveWaveColor:Colors.amber,spacing:3,waveThickness:2))),
        const SizedBox(height:8),
        GestureDetector(onTap: ()=>setState(()=>lyricExpanded=!lyricExpanded), child: Container(width: double.infinity, padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white12)), child: lyricExpanded ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: ctrl.lyricLines.asMap().entries.map((e){ final isActive = e.key==ctrl.currentLyricIndex; return Text(e.value, style: TextStyle(color: isActive?Colors.amber:Colors.white54, fontSize: isActive?14:12, fontWeight: isActive?FontWeight.bold:FontWeight.normal)); }).toList()) : RunningText(text: ctrl.lyricLines.isNotEmpty ? ctrl.lyricLines[ctrl.currentLyricIndex] : '', color: Colors.white70),)),
        const SizedBox(height:12),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children:[
          Container(decoration: const BoxDecoration(color: Colors.amber, shape: BoxShape.circle), child: IconButton(onPressed: ctrl.togglePlay, icon: const Icon(Icons.play_arrow_rounded,color:Colors.black,size:36))),
          Row(children: [
            GestureDetector(onTap: ctrl.isRecording ? ctrl.stopRecord : ctrl.startRecord, child: Container(padding: const EdgeInsets.symmetric(horizontal:14,vertical:8), decoration: BoxDecoration(color: ctrl.isRecording?Colors.red:Colors.red.withOpacity(0.8), borderRadius: BorderRadius.circular(20)), child: Row(children:[Icon(ctrl.isRecording?Icons.stop:Icons.fiber_manual_record, color: Colors.white, size:16), const SizedBox(width:6), Text(ctrl.isRecording?'${ctrl.recordSeconds}s':'REC', style: const TextStyle(color: Colors.white,fontSize:12,fontWeight:FontWeight.bold))]))),
            const SizedBox(width:8),
            GestureDetector(onTap: ()=>ctrl.startRecordWithTrim(context), child: Container(padding: const EdgeInsets.symmetric(horizontal:12,vertical:8), decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.amber)), child: const Row(children:[Icon(Icons.content_cut,color: Colors.amber, size:14), SizedBox(width:4), Text('TRIM REC', style: TextStyle(color: Colors.amber,fontSize:11,fontWeight:FontWeight.bold))]))),
          ]),
          Container(decoration: BoxDecoration(color: Colors.white12, shape: BoxShape.circle, border: Border.all(color: Colors.white24)), child: IconButton(onPressed: () async { if(ctrl.audioPlayer.playing){ await ctrl.audioPlayer.pause(); try{await ctrl.waveformController.pausePlayer();}catch(_){} } }, icon: const Icon(Icons.pause_rounded,color:Colors.white,size:32))),
        ]),
        const SizedBox(height:10),
        if(showPicker) SliderTheme(data: SliderTheme.of(context).copyWith(trackHeight:3, thumbShape: const RoundSliderThumbShape(enabledThumbRadius:8)), child: Slider(value: ctrl.val(), min:0, max:ctrl.max(), activeColor:Colors.amber, inactiveColor:Colors.white24, onChanged: ctrl.duration==Duration.zero?null:(v)=>ctrl.seekTo(Duration(milliseconds:v.toInt())))),
        if(ctrl.recordedPath!=null) Container(margin: const EdgeInsets.only(top:10), padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.green.withOpacity(0.12), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.green.withOpacity(0.3))), child: Column(children:[Text('Video: ${ctrl.recordedPath!.split('/').last}', maxLines:1, style: const TextStyle(color:Colors.white,fontSize:11)), const SizedBox(height:8), SizedBox(width:double.infinity, child: ElevatedButton.icon(onPressed: ctrl.shareToWhatsApp, icon: const Icon(Icons.share,color:Colors.white,size:18), label: const Text('Share WA', style: TextStyle(fontSize:13)), style: ElevatedButton.styleFrom(backgroundColor: Colors.green)))])),
        const SizedBox(height:10),
        Center(child: Text(showPicker?'▼ hide':'▲ Geser atas | REC=langsung TRIM REC=pilih detik dulu', style: const TextStyle(color:Colors.white24,fontSize:10))),
      ]);
    });
  }
}