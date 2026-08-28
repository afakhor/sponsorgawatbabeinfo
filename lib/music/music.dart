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
import 'package:http/http.dart' as http;
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

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
    if(widget.text.isEmpty) return const SizedBox(height:18);
    return SizedBox(height:18, child: ClipRect(child: AnimatedBuilder(animation:_c, builder:(ctx,_){
      return Transform.translate(offset: Offset(120 - (_c.value*350),0), child: Text(widget.text, maxLines:1, style: TextStyle(color:widget.color,fontSize:widget.fontSize,fontWeight:FontWeight.w600)));
    })));
  }
}

class LyricKaraoke extends StatelessWidget {
  final String sentence;
  final int sentenceIndex;
  final int currentSentenceIndex;
  final Duration position;
  final Duration sentenceDuration;
  final Duration sentenceStart;
  const LyricKaraoke({super.key, required this.sentence, required this.sentenceIndex, required this.currentSentenceIndex, required this.position, required this.sentenceDuration, required this.sentenceStart});
  @override Widget build(BuildContext context) {
    final isActive = sentenceIndex == currentSentenceIndex;
    if (!isActive) return const SizedBox.shrink();
    final words = sentence.split(' ').where((w)=>w.isNotEmpty).toList();
    if(words.isEmpty) return const SizedBox.shrink();
    final elapsed = position - sentenceStart;
    double progress = sentenceDuration.inMilliseconds>0? (elapsed.inMilliseconds / sentenceDuration.inMilliseconds).clamp(0.0, 1.0) : 0;
    int activeWord = (progress * words.length).floor().clamp(0, words.length-1);
    return TweenAnimationBuilder<double>(
      key: ValueKey(sentenceIndex),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutBack,
      builder: (ctx, val, child) {
        return Opacity(opacity: val, child: Transform.translate(offset: Offset(0, (1-val)*14), child: Transform.scale(scale: 0.85 + val*0.15, child: child)));
      },
      child: Wrap(spacing: 6, runSpacing: 6, children: List.generate(words.length, (i){
        final passed = i < activeWord;
        final current = i == activeWord;
        Color col = passed? Colors.greenAccent : current? Colors.green : Colors.white;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: EdgeInsets.symmetric(horizontal: current?8:0, vertical: current?4:2),
          decoration: current? BoxDecoration(color: Colors.green.withOpacity(0.22), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.greenAccent.withOpacity(0.8))) : null,
          child: Text(words[i], style: TextStyle(color: col, fontSize: current?16:13.5, fontWeight: passed||current?FontWeight.bold:FontWeight.w500)),
        );
      })),
    );
  }
}

class MusicController extends ChangeNotifier {
  final ja.AudioPlayer audioPlayer=ja.AudioPlayer();
  final PlayerController waveformController=PlayerController();
  File? selectedMusicFile;
  String musicName='Belum ada musik';
  String editableTitle='SPONSOR BABE INFO GAWAT • TAP UNTUK EDIT JUDUL';
  String editableBottomTitle='Babe Info Gawat - Tap untuk edit bawah';
  bool usePreTrim=false;
  List<String> lyricLines=['Tap 📁 pilih lagu untuk auto lirik','Lirik asli auto transcribe Whisper','Putih fold in -> hijau per kata -> fold out'];
  int currentLyricIndex=0;
  Duration position=Duration.zero, duration=Duration.zero;
  bool isPlaying=false, isLoading=false, isRecording=false, isTranscribing=false;
  String? errorMessage;
  String? recordedPath;
  Timer? recordTimer;
  int recordSeconds=0;
  Duration trimStart=Duration.zero;
  Duration trimEnd=const Duration(seconds:60);

  Duration get sentenceDuration {
    if(lyricLines.isEmpty || duration.inMilliseconds==0) return const Duration(seconds:4);
    return Duration(milliseconds: (duration.inMilliseconds / lyricLines.length).floor());
  }
  Duration get currentSentenceStart => Duration(milliseconds: currentLyricIndex * sentenceDuration.inMilliseconds);

  MusicController(){
    audioPlayer.positionStream.listen((v){
      position=v;
      if(lyricLines.isNotEmpty && duration.inSeconds>1){
        int idx = ((v.inMilliseconds / duration.inMilliseconds) * lyricLines.length).floor();
        idx = idx.clamp(0, lyricLines.length-1);
        if(idx!=currentLyricIndex){ currentLyricIndex=idx; }
      }
      notifyListeners();
    });
    audioPlayer.durationStream.listen((v){ if(v!=null){ duration=v; if(trimEnd>v) trimEnd=v; notifyListeners(); }});
    audioPlayer.playerStateStream.listen((s){
      isPlaying=s.playing;
      if(s.processingState==ja.ProcessingState.completed){ isPlaying=false; position=Duration.zero; currentLyricIndex=0; try{waveformController.stopPlayer();}catch(_){} }
      notifyListeners();
    });
    audioPlayer.setVolume(1.0);
    sherpa.initBindings();
  }

  Future<void> _req() async {
    if(!Platform.isAndroid) return;
    await Permission.storage.request();
    await Permission.audio.request();
    await Permission.microphone.request();
    await Permission.notification.request();
  }

  Future<String> _ensureModel() async {
    final dir = await getApplicationDocumentsDirectory();
    final modelDir = Directory('${dir.path}/sherpa-small');
    if(!await modelDir.exists()) await modelDir.create(recursive:true);
    final enc = '${modelDir.path}/encoder.onnx';
    final dec = '${modelDir.path}/decoder.onnx';
    final tok = '${modelDir.path}/tokens.txt';
    if(File(enc).existsSync() && File(dec).existsSync() && File(tok).existsSync()){
      return modelDir.path;
    }
    const base = 'https://huggingface.co/csukuangfj/sherpa-onnx-whisper-base/resolve/main';
    errorMessage='⬇️ Download model 70MB pertama kali...';
    notifyListeners();
    await _dl('$base/base-encoder.int8.onnx', enc);
    await _dl('$base/base-decoder.int8.onnx', dec);
    await _dl('$base/base-tokens.txt', tok);
    return modelDir.path;
  }

  Future<void> _dl(String url, String save) async {
    final r = await http.get(Uri.parse(url));
    if(r.statusCode==200){
      await File(save).writeAsBytes(r.bodyBytes);
    } else {
      throw Exception('Gagal $url');
    }
  }

  Future<void> transcribeLyric() async {
    if(selectedMusicFile==null) return;
    isTranscribing=true;
    errorMessage='🌐 Auto detect Indo/Barat...';
    notifyListeners();
    try{
      final mp = await _ensureModel();
      final whisperCfg = sherpa.OfflineWhisperModelConfig(
        encoder: '${mp}/encoder.onnx',
        decoder: '${mp}/decoder.onnx',
        language: '',
        task: 'transcribe',
      );
      final modelCfg = sherpa.OfflineModelConfig(
        whisper: whisperCfg,
        tokens: '${mp}/tokens.txt',
      );
      final recogCfg = sherpa.OfflineRecognizerConfig(model: modelCfg);
      final recog = sherpa.OfflineRecognizer(recogCfg);
      final stream = recog.createStream();
      final wave = sherpa.readWave(selectedMusicFile!.path);
      stream.acceptWaveform(sampleRate: wave.sampleRate, samples: wave.samples);
      recog.decode(stream);
      final result = recog.getResult(stream);
      String raw = result.text.trim();
      stream.free();
      recog.free();
      if(raw.length>5){
        List<String> sentences = [];
        final wordsAll = raw.split(RegExp(r'\s+'));
        for(int i=0;i<wordsAll.length;i+=7){
          int end = (i+7<wordsAll.length)? i+7 : wordsAll.length;
          sentences.add(wordsAll.sublist(i,end).join(' '));
        }
        lyricLines = sentences;
        currentLyricIndex=0;
        errorMessage='✅ Lirik asli ${sentences.length} baris';
        notifyListeners();
        return;
      }
      throw Exception('Hasil kosong');
    }catch(e){
      String base = musicName.replaceAll('.mp3','').replaceAll('.m4a','').replaceAll('.wav','').replaceAll('_',' ').trim();
      if(base.length<4) base = 'Babe Info Gawat Globe Berputar Musik Berdentum';
      List<String> parts = base.split(RegExp(r'[-|]')).map((e)=>e.trim()).where((e)=>e.isNotEmpty).toList();
      if(parts.length<3) parts = ['Memutar: $musicName','Babe Info Gawat di angkasa','Globe berputar musik berdentum','Wave naik turun ikuti beat','Share ke WhatsApp Status'];
      lyricLines = parts;
      currentLyricIndex=0;
      errorMessage='⚠️ Pakai judul: $e';
    }finally{
      isTranscribing=false;
      notifyListeners();
    }
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
      editableTitle=musicName;
      currentLyricIndex=0;
      isLoading=true; notifyListeners();
      await audioPlayer.stop(); try{await waveformController.stopPlayer();}catch(_){}
      await audioPlayer.setAudioSource(ja.AudioSource.file(path));
      duration=audioPlayer.duration??Duration.zero;
      trimStart=Duration.zero;
      trimEnd= duration.inSeconds>60? const Duration(seconds:60) : duration;
      try{ await waveformController.preparePlayer(path:path, shouldExtractWaveform:true, noOfSamples:100); await waveformController.stopPlayer(); }catch(_){}
      isLoading=false; notifyListeners();
      await transcribeLyric();
    }catch(e){ errorMessage='Gagal: $e'; isLoading=false; notifyListeners(); }
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

  Future<void> startRecord({Duration? startFrom, Duration? endAt}) async {
    try{
      await _req();
      if(selectedMusicFile!=null){
        if(startFrom!=null) await seekTo(startFrom); else await seekTo(Duration.zero);
        await audioPlayer.play();
        try{await waveformController.startPlayer();}catch(_){}
      }
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      isRecording=true; recordSeconds=0; recordedPath=null; notifyListeners();
      final fileName='babe_${DateTime.now().millisecondsSinceEpoch}';
      await FlutterScreenRecording.startRecordScreenAndAudio(fileName, titleNotification: "Babe Info GAWAT REC HD", messageNotification: "Globe + running + karaoke hijau 60s");
      Duration targetEnd = endAt?? (duration.inSeconds>0? (duration.inSeconds>60? const Duration(seconds:60) : duration) : const Duration(seconds:60));
      if(startFrom!=null){
        Duration maxDur = targetEnd - startFrom;
        if(maxDur.inSeconds>60) targetEnd = startFrom + const Duration(seconds:60);
      }
      recordTimer?.cancel();
      recordTimer=Timer.periodic(const Duration(seconds:1), (t){
        recordSeconds++; notifyListeners();
        if(startFrom!=null && position >= targetEnd){ stopRecord(); }
        else if(recordSeconds>=60 || (startFrom==null && recordSeconds>=targetEnd.inSeconds)){ stopRecord(); }
      });
    }catch(e){
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      isRecording=false; errorMessage='Record gagal: $e'; notifyListeners();
    }
  }

  Future<void> stopRecord() async {
    try{
      recordTimer?.cancel();
      try{ await audioPlayer.pause(); await waveformController.pausePlayer(); }catch(_){}
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
      await FlutterScreenRecording.stopRecordScreen;
      try{ await audioPlayer.pause(); await waveformController.pausePlayer(); }catch(_){}
      isRecording=false; recordedPath=null; recordSeconds=0;
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      notifyListeners();
    }catch(_){}
  }

  Future<void> showPostRecordDialog(BuildContext context) async {
    if(recordedPath==null) return;
    await showDialog(context: context, barrierDismissible:false, builder: (ctx)=>AlertDialog(
      backgroundColor: const Color(0xFF1E1E24),
      title: const Text('Rekaman Selesai 0-60s HD', style: TextStyle(color:Colors.white)),
      content: Text('File: ${recordedPath!.split('/').last}\nDurasi: ${recordSeconds}s / 60s\n${editableTitle}', style: const TextStyle(color:Colors.white70, fontSize:12)),
      actions: [
        TextButton(onPressed: () async { Navigator.pop(ctx); await cancelRecord(); }, child: const Text('Hapus', style: TextStyle(color:Colors.redAccent))),
        ElevatedButton(onPressed: (){ Navigator.pop(ctx); shareToWhatsApp(); }, style: ElevatedButton.styleFrom(backgroundColor: Colors.green), child: const Text('Share WA HD')),
      ],
    ));
  }

  Future<void> showTrimDialog(BuildContext context) async {
    if(selectedMusicFile==null || duration==Duration.zero){ errorMessage='Pilih lagu dulu 📁'; notifyListeners(); return; }
    Duration tempStart=Duration.zero;
    Duration tempEnd= duration.inSeconds>60? const Duration(seconds:60) : duration;
    await showDialog(context: context, builder: (ctx){
      return StatefulBuilder(builder: (ctx,setSt){
        double maxSec = duration.inSeconds.toDouble();
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E24),
          title: const Text('TRIM REC 60s MAX', style: TextStyle(color:Colors.amber, fontSize:14, fontWeight: FontWeight.bold)),
          content: Column(mainAxisSize: MainAxisSize.min, children:[
            Text('${fmt(tempStart)} - ${fmt(tempEnd)} (${(tempEnd-tempStart).inSeconds}s)', style: const TextStyle(color:Colors.white70, fontSize:12)),
            const SizedBox(height:12),
            RangeSlider(min: 0, max: maxSec, values: RangeValues(tempStart.inSeconds.toDouble(), tempEnd.inSeconds.toDouble()), activeColor: Colors.amber, inactiveColor: Colors.white24, labels: RangeLabels(fmt(tempStart), fmt(tempEnd)), onChanged: (v){
              Duration ns = Duration(seconds: v.start.toInt());
              Duration ne = Duration(seconds: v.end.toInt());
              if((ne-ns).inSeconds>60) ne = ns + const Duration(seconds:60);
              setSt((){ tempStart=ns; tempEnd=ne; });
            }),
          ]),
          actions: [
            TextButton(onPressed: ()=>Navigator.pop(ctx), child: const Text('Batal')),
            ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black), onPressed: () async { Navigator.pop(ctx); trimStart=tempStart; trimEnd=tempEnd; await startRecord(startFrom: trimStart, endAt: trimEnd); }, child: const Text('TRIM REC & SHARE')),
          ],
        );
      });
    });
  }

  Future<void> editLyricsDialog(BuildContext context) async {
    final controller = TextEditingController(text: lyricLines.join('\n'));
    final res = await showDialog<String>(context: context, builder: (ctx)=>AlertDialog(
      backgroundColor: const Color(0xFF1E1E24),
      title: const Text('Edit Lirik Asli', style: TextStyle(color:Colors.white, fontSize:12)),
      content: SizedBox(width: double.maxFinite, height: 320, child: TextField(controller: controller, maxLines: 20, style: const TextStyle(color:Colors.white, fontSize:12))),
      actions: [
        TextButton(onPressed: ()=>Navigator.pop(ctx), child: const Text('Batal')),
        ElevatedButton(onPressed: ()=>Navigator.pop(ctx, controller.text), style: ElevatedButton.styleFrom(backgroundColor: Colors.green), child: const Text('Simpan Lirik')),
      ],
    ));
    if(res!=null){
      lyricLines = res.split('\n').map((e)=>e.trim()).where((e)=>e.isNotEmpty).toList();
      if(lyricLines.isEmpty) lyricLines=['Lirik kosong'];
      currentLyricIndex=0;
      notifyListeners();
    }
  }

  Future<void> shareToWhatsApp() async {
    if(recordedPath==null ||!File(recordedPath!).existsSync()){ errorMessage='Belum ada video record'; notifyListeners(); return; }
    await Share.shareXFiles([XFile(recordedPath!)], text: "$editableTitle - HD 1080p - ${recordSeconds}s");
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
  bool get isSheetExpanded => widget.sheetController.isAttached? widget.sheetController.size >= 0.6 : false;
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
    return PopScope(
      canPop:!widget.controller.isRecording,
      onPopInvokedWithResult: (didPop, result) async { if(!didPop && widget.controller.isRecording){ await widget.controller.cancelRecord(); }},
      child: AnimatedBuilder(animation: widget.controller, builder: (context,_){
        final ctrl=widget.controller;
        final showPicker=isSheetExpanded;
        return ListView(controller: widget.scrollController, padding: const EdgeInsets.fromLTRB(12,10,12,16), children: [
          Center(child: Container(width:42,height:5,decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10)))),
          const SizedBox(height:10),
          AnimatedCrossFade(duration: const Duration(milliseconds:250), firstChild: const SizedBox.shrink(), secondChild: Container(padding: const EdgeInsets.symmetric(horizontal:10,vertical:8), decoration: BoxDecoration(color: Colors.white.withOpacity(0.07), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.amber.withOpacity(0.3))), child: Row(children:[const Icon(Icons.music_note,color:Colors.amber,size:20), const SizedBox(width:8), Expanded(child: Text(ctrl.musicName, maxLines:1, overflow:TextOverflow.ellipsis, style: const TextStyle(color:Colors.white,fontSize:13,fontWeight:FontWeight.bold))), if(ctrl.isLoading||ctrl.isTranscribing) const SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2,color:Colors.amber)), const SizedBox(width:8), InkWell(onTap: ctrl.pickMusic, child: Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.folder_open,color:Colors.black,size:22)))])), crossFadeState: showPicker? CrossFadeState.showSecond : CrossFadeState.showFirst),
          if(ctrl.errorMessage!=null) Padding(padding: const EdgeInsets.only(top:6), child: Text(ctrl.errorMessage!, style: const TextStyle(color:Colors.amber,fontSize:11))),
          const SizedBox(height:10),
          InkWell(onTap: _editTitle, child: Container(width:double.infinity, padding: const EdgeInsets.symmetric(horizontal:10,vertical:6), decoration: BoxDecoration(color: Colors.amber.withOpacity(0.14), borderRadius: BorderRadius.circular(8)), child: Row(children:[const Icon(Icons.edit,size:14,color:Colors.amber), const SizedBox(width:6), Expanded(child: RunningText(text: ctrl.editableTitle))]))),
          const SizedBox(height:8),
          Container(height:52, decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white12)), child: ctrl.selectedMusicFile==null? const Center(child: Text('Waveform / Equalizer', style: TextStyle(color:Colors.white24,fontSize:11))) : AudioFileWaveforms(size: Size(MediaQuery.of(context).size.width-24,52), playerController: ctrl.waveformController, enableSeekGesture:true, waveformType: WaveformType.fitWidth, playerWaveStyle: const PlayerWaveStyle(fixedWaveColor:Colors.white24,liveWaveColor:Colors.amber,spacing:3,waveThickness:2))),
          const SizedBox(height:8),
          Row(children:[
            Expanded(child: ElevatedButton.icon(onPressed: ctrl.isTranscribing?null:()=>ctrl.transcribeLyric(), style: ElevatedButton.styleFrom(backgroundColor: Colors.white12, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical:10)), icon: Icon(ctrl.isTranscribing?Icons.hourglass_top:Icons.auto_awesome, size:16), label: Text(ctrl.isTranscribing?'Transcribing...':'Auto Lirik Asli', style: const TextStyle(fontSize:11)))),
            const SizedBox(width:8),
            Expanded(child: ElevatedButton.icon(onPressed: ()=>ctrl.editLyricsDialog(context), style: ElevatedButton.styleFrom(backgroundColor: Colors.amber.withOpacity(0.2), foregroundColor: Colors.amber, padding: const EdgeInsets.symmetric(vertical:10)), icon: const Icon(Icons.edit_note, size:16), label: const Text('Edit Lirik', style: TextStyle(fontSize:11)))),
          ]),
          const SizedBox(height:8),
          GestureDetector(onTap: ()=>setState(()=>lyricExpanded=!lyricExpanded), child: AnimatedContainer(duration: const Duration(milliseconds:250), width: double.infinity, padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.amber.withOpacity(0.2))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[
            Row(children:[const Icon(Icons.lyrics, size:14, color: Colors.amber), const SizedBox(width:6), Expanded(child: Text(lyricExpanded? 'LIRIK KARAOKE AUTO - TAP FOLD': 'KARAOKE: ${ctrl.lyricLines.isNotEmpty? ctrl.lyricLines[ctrl.currentLyricIndex] : ''}', style: const TextStyle(color:Colors.amber, fontSize:11, fontWeight: FontWeight.bold), maxLines:1, overflow: TextOverflow.ellipsis))]),
            const SizedBox(height:8),
            if(lyricExpanded) Column(crossAxisAlignment: CrossAxisAlignment.start, children:[
              Container(width: double.infinity, padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.white.withOpacity(0.06), borderRadius: BorderRadius.circular(10)), child: ctrl.lyricLines.isEmpty? const Text('Belum ada lirik', style: TextStyle(color:Colors.white24, fontSize:11)) : LyricKaraoke(sentence: ctrl.lyricLines[ctrl.currentLyricIndex], sentenceIndex: ctrl.currentLyricIndex, currentSentenceIndex: ctrl.currentLyricIndex, position: ctrl.position, sentenceStart: ctrl.currentSentenceStart, sentenceDuration: ctrl.sentenceDuration)),
              const SizedBox(height:8),
           ...ctrl.lyricLines.asMap().entries.map((e){
                final isActive = e.key==ctrl.currentLyricIndex;
                return AnimatedContainer(duration: const Duration(milliseconds:200), padding: const EdgeInsets.symmetric(vertical:3, horizontal:6), margin: const EdgeInsets.only(bottom:2), decoration: isActive? BoxDecoration(color: Colors.amber.withOpacity(0.12), borderRadius: BorderRadius.circular(6)) : null, child: Row(children:[Text('${e.key+1}. ', style: TextStyle(color: isActive?Colors.amber:Colors.white24, fontSize:10)), Expanded(child: Text(e.value, style: TextStyle(color: isActive?Colors.white:Colors.white38, fontSize: isActive?13:11, fontWeight: isActive?FontWeight.bold:FontWeight.normal)))]));
              }),
            ]) else LyricKaraoke(sentence: ctrl.lyricLines.isNotEmpty? ctrl.lyricLines[ctrl.currentLyricIndex] : '', sentenceIndex: ctrl.currentLyricIndex, currentSentenceIndex: ctrl.currentLyricIndex, position: ctrl.position, sentenceStart: ctrl.currentSentenceStart, sentenceDuration: ctrl.sentenceDuration),
          ]))),
          const SizedBox(height:12),
          Row(children:[
            Expanded(child: ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical:12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), onPressed: ctrl.isRecording? ctrl.stopRecord : () => ctrl.startRecord(), icon: Icon(ctrl.isRecording? Icons.stop : Icons.fiber_manual_record, size:18), label: Text(ctrl.isRecording? '${ctrl.recordSeconds}s STOP' : 'REC MERAH', style: const TextStyle(fontWeight: FontWeight.bold, fontSize:12)))),
            const SizedBox(width:8),
            Expanded(child: ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical:12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), onPressed: ctrl.isRecording? null : () => ctrl.showTrimDialog(context), icon: const Icon(Icons.content_cut, size:18), label: const Text('TRIM REC KUNING', style: TextStyle(fontWeight: FontWeight.bold, fontSize:11)))),
          ]),
          const SizedBox(height:8),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children:[
            Container(decoration: const BoxDecoration(color: Colors.amber, shape: BoxShape.circle), child: IconButton(onPressed: ctrl.togglePlay, icon: const Icon(Icons.play_arrow_rounded,color:Colors.black,size:32))),
            Text(ctrl.isRecording?'Globe Full + Running + Karaoke':'BACK=cancel | O merah=stop', style: const TextStyle(color:Colors.white24,fontSize:10)),
            Container(decoration: BoxDecoration(color: Colors.white12, shape: BoxShape.circle, border: Border.all(color: Colors.white24)), child: IconButton(onPressed: () async { if(ctrl.audioPlayer.playing){ await ctrl.audioPlayer.pause(); try{await ctrl.waveformController.pausePlayer();}catch(_){} } }, icon: const Icon(Icons.pause_rounded,color:Colors.white,size:28))),
          ]),
          const SizedBox(height:10),
          AnimatedCrossFade(duration: const Duration(milliseconds:250), firstChild: const SizedBox.shrink(), secondChild: Column(children:[SliderTheme(data: SliderTheme.of(context).copyWith(trackHeight:3, thumbShape: const RoundSliderThumbShape(enabledThumbRadius:8)), child: Slider(value: ctrl.val(), min:0.0, max:ctrl.max(), activeColor:Colors.amber, inactiveColor:Colors.white24, onChanged: ctrl.duration==Duration.zero?null:(v)=>ctrl.seekTo(Duration(milliseconds:v.toInt())))), Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children:[Text(ctrl.fmt(ctrl.position),style: const TextStyle(color:Colors.white60,fontSize:11)), Text(ctrl.fmt(ctrl.duration),style: const TextStyle(color:Colors.white60,fontSize:11))])]), crossFadeState: showPicker? CrossFadeState.showSecond : CrossFadeState.showFirst),
          const SizedBox(height:12),
          if(ctrl.recordedPath!=null)
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.green.withOpacity(0.12), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.green.withOpacity(0.3))),
              child: Column(children:[
                Row(children:[const Icon(Icons.check_circle,color:Colors.green,size:18), const SizedBox(width:6), Expanded(child: Text('Video: ${ctrl.recordedPath!.split('/').last} ${ctrl.recordSeconds}s', maxLines:1, overflow:TextOverflow.ellipsis, style: const TextStyle(color:Colors.white,fontSize:11)))]),
                const SizedBox(height:8),
                Row(children:[
                  Expanded(child: ElevatedButton(onPressed: () => ctrl.showPostRecordDialog(context), style: ElevatedButton.styleFrom(backgroundColor: Colors.white12), child: const Text('Lihat 0-60s', style:TextStyle(fontSize:11)))),
                  const SizedBox(width:8),
                  Expanded(child: ElevatedButton.icon(onPressed: ctrl.shareToWhatsApp, icon: const Icon(Icons.share,color:Colors.white,size:18), label: const Text('Share WA', style: TextStyle(fontSize:11)), style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))))),
                ]),
              ]),
            ),
          const SizedBox(height:10),
          Center(child: Text(showPicker?'▼ Geser bawah hide':'▲ Geser atas untuk 📁', style: const TextStyle(color:Colors.white24,fontSize:11))),
        ]);
      }),
    );
  }
}