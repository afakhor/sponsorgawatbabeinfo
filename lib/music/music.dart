import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
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
// HAPUS FFMPEG BIAR BUILD GAK GAGAL LAGI
// import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';

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

class TimedWord {
  final String word;
  final Duration start;
  final Duration end;
  TimedWord(this.word, this.start, this.end);
}
class TimedSentence {
  final List<TimedWord> words;
  final Duration start;
  final Duration end;
  String get text => words.map((w)=>w.word).join(' ');
  TimedSentence(this.words, this.start, this.end);
}

class LyricKaraoke extends StatelessWidget {
  final TimedSentence sentence;
  final Duration position;
  const LyricKaraoke({super.key, required this.sentence, required this.position});
  @override Widget build(BuildContext context) {
    int activeWord = -1;
    for(int i=0;i<sentence.words.length;i++){
      if(position >= sentence.words[i].start && position < sentence.words[i].end){
        activeWord = i; break;
      }
      if(position >= sentence.words[i].end && i==sentence.words.length-1 && position < sentence.end + const Duration(milliseconds:300)){
        activeWord = i;
      }
    }
    if(position > sentence.end) activeWord = sentence.words.length;
    return TweenAnimationBuilder<double>(
      key: ValueKey(sentence.start),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutBack,
      builder: (ctx, val, child) {
        return Opacity(opacity: val, child: Transform.translate(offset: Offset(0, (1-val)*14), child: Transform.scale(scale: 0.85 + val*0.15, child: child)));
      },
      child: Wrap(spacing: 6, runSpacing: 6, children: List.generate(sentence.words.length, (i){
        final passed = activeWord>i;
        final current = i == activeWord;
        Color col = passed? Colors.greenAccent : current? Colors.green : Colors.white;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: EdgeInsets.symmetric(horizontal: current?8:0, vertical: current?4:2),
          decoration: current? BoxDecoration(color: Colors.green.withOpacity(0.22), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.greenAccent.withOpacity(0.8))) : null,
          child: Text(sentence.words[i].word, style: TextStyle(color: col, fontSize: current?16:13.5, fontWeight: passed||current?FontWeight.bold:FontWeight.w500)),
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
  List<TimedSentence> lyricSentences=[];
  List<String> get lyricLines => lyricSentences.map((e)=>e.text).toList();
  int currentLyricIndex=0;
  Duration position=Duration.zero, duration=Duration.zero;
  bool isPlaying=false, isLoading=false, isRecording=false, isTranscribing=false;
  String? errorMessage;
  String? recordedPath;
  Timer? recordTimer;
  int recordSeconds=0;
  Duration trimStart=Duration.zero;
  Duration trimEnd=const Duration(seconds:60);
  Duration get sentenceDuration => lyricSentences.isEmpty? const Duration(seconds:4) : lyricSentences[currentLyricIndex].end - lyricSentences[currentLyricIndex].start;
  Duration get currentSentenceStart => lyricSentences.isEmpty? Duration.zero : lyricSentences[currentLyricIndex].start;

  MusicController(){
    audioPlayer.positionStream.listen((v){
      position=v;
      if(lyricSentences.isNotEmpty){
        for(int i=0;i<lyricSentences.length;i++){
          if(v >= lyricSentences[i].start && v < lyricSentences[i].end + const Duration(milliseconds:500)){
            if(i!=currentLyricIndex) currentLyricIndex=i;
            break;
          }
          if(i < lyricSentences.length-1 && v >= lyricSentences[i].end && v < lyricSentences[i+1].start){
            if(i!=currentLyricIndex) currentLyricIndex=i+1;
            break;
          }
        }
        if(v > lyricSentences.last.end) currentLyricIndex = lyricSentences.length-1;
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

  Future<void> _dlWithProgress(String url, String save, Function(double) onProgress) async {
    final client = http.Client();
    final req = http.Request('GET', Uri.parse(url));
    final res = await client.send(req);
    final total = res.contentLength?? 0;
    int received = 0;
    final file = File(save).openWrite();
    await for(var chunk in res.stream){
      received += chunk.length;
      file.add(chunk);
      if(total>0) onProgress(received/total);
    }
    await file.close();
    client.close();
  }

  Future<String> _ensureModelWithDialog(BuildContext context) async {
    final dir = await getApplicationDocumentsDirectory();
    try{
      final old = Directory('${dir.path}/sherpa-small');
      if(await old.exists()) await old.delete(recursive:true);
    }catch(_){}
    final modelDir = Directory('${dir.path}/sherpa-tiny');
    if(!await modelDir.exists()) await modelDir.create(recursive:true);
    final enc = '${modelDir.path}/encoder.onnx';
    final dec = '${modelDir.path}/decoder.onnx';
    final tok = '${modelDir.path}/tokens.txt';
    if(File(enc).existsSync() && File(dec).existsSync() && File(tok).existsSync() && File(enc).lengthSync() > 3*1024*1024){
      return modelDir.path;
    }
    try{ if(File(enc).existsSync()) await File(enc).delete(); if(File(dec).existsSync()) await File(dec).delete(); if(File(tok).existsSync()) await File(tok).delete(); }catch(_){}
    double progress = 0;
    bool success = false;
    late StateSetter dialogSetState;
    if(context.mounted){
      showDialog(context: context, barrierDismissible: false, builder: (ctx){
        return StatefulBuilder(builder: (ctx,setSt){
          dialogSetState = setSt;
          return AlertDialog(
            backgroundColor: const Color(0xFF1E1E24),
            title: Text(success? '✅ Download Sukses' : '⬇️ Download Tiny 39MB', style: const TextStyle(color: Colors.amber, fontSize: 14, fontWeight: FontWeight.bold)),
            content: Column(mainAxisSize: MainAxisSize.min, children:[
              LinearProgressIndicator(value: success?1: (progress==0?null:progress), color: Colors.amber, backgroundColor: Colors.white12),
              const SizedBox(height:12),
              Text(success? 'Model siap! Anti-crash.' : '${(progress*100).toStringAsFixed(0)}% - Model kecil...', style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ]),
          );
        });
      });
    }
    const base = 'https://huggingface.co/csukuangfj/sherpa-onnx-whisper-tiny/resolve/main';
    try{
      await _dlWithProgress('$base/tiny-encoder.int8.onnx', enc, (p){ progress = p*0.5; try{dialogSetState((){});}catch(_){} });
      await _dlWithProgress('$base/tiny-decoder.int8.onnx', dec, (p){ progress = 0.5 + p*0.4; try{dialogSetState((){});}catch(_){} });
      await _dlWithProgress('$base/tiny-tokens.txt', tok, (p){ progress = 0.9 + p*0.1; try{dialogSetState((){});}catch(_){} });
      success = true;
      try{dialogSetState((){});}catch(_){}
      await Future.delayed(const Duration(milliseconds: 800));
      if(context.mounted) Navigator.pop(context);
      if(context.mounted){
        await showDialog(context: context, builder: (ctx)=>AlertDialog(
          backgroundColor: const Color(0xFF1E1E24),
          title: Row(children:[const Icon(Icons.check_circle, color: Colors.green), const SizedBox(width:8), const Text('Download Sukses!', style: TextStyle(color: Colors.white))]),
          content: const Text('Tiny 39MB terpasang.\nAnti crash untuk MP3 11MB.', style: TextStyle(color: Colors.white70, fontSize: 12)),
          actions: [ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black), onPressed: ()=>Navigator.pop(ctx), child: const Text('OK Siap'))],
        ));
      }
    }catch(e){
      if(context.mounted) Navigator.pop(context);
      rethrow;
    }
    return modelDir.path;
  }

  // FIX UTAMA - GAK PAKAI FFMPEG
  Future<String> _convertToWav(String inputPath, {int maxSeconds = 180}) async => inputPath;

  Future<void> transcribeLyric(BuildContext context) async {
    if(selectedMusicFile==null) return;
    isTranscribing=true;
    String currentStep = 'START';
    double progress = 0;
    late StateSetter diagSet;
    if(context.mounted){
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => StatefulBuilder(builder: (ctx,setSt){
          diagSet = setSt;
          return AlertDialog(
            backgroundColor: const Color(0xFF1E1E24),
            title: const Text('🔍 TRANSCRIBE 3 MENIT', style: TextStyle(color: Colors.amber, fontSize:13, fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('File: $musicName (${selectedMusicFile!.lengthSync()~/1024}KB)', style: const TextStyle(color: Colors.white70, fontSize:11)),
                const SizedBox(height:8),
                Text('STEP: $currentStep', style: const TextStyle(color: Colors.cyan, fontSize:12, fontWeight: FontWeight.bold)),
                const SizedBox(height:8),
                LinearProgressIndicator(value: progress==0?null:progress, color: Colors.amber),
                const SizedBox(height:12),
                Text(errorMessage??'', style: const TextStyle(color: Colors.white54, fontSize:10)),
              ],
            ),
          );
        }),
      );
    }
    void updateStep(String step, {double prog = 0, String? msg}){
      currentStep = step;
      progress = prog;
      if(msg!=null) errorMessage = msg;
      try{ diagSet((){}); }catch(_){}
      notifyListeners();
    }
    try{
      updateStep('1/5 CEK MODEL', prog:0.1);
      final mp = await _ensureModelWithDialog(context);

      updateStep('2/5 SKIP CONVERT', prog:0.3, msg:'MP3 11MB langsung baca tanpa FFmpeg');
      String wavPath = selectedMusicFile!.path;

      updateStep('3/5 BACA MP3', prog:0.5, msg:'readWave MP3 3 menit...');
      late sherpa.WaveData wave;
      try{
        wave = sherpa.readWave(wavPath);
      }catch(e){
        throw Exception('readWave gagal baca MP3: $e - coba MP3 lain');
      }

      if(wave.sampleRate==0 || wave.samples.isEmpty){
        throw Exception('readWave sampleRate 0 / kosong');
      }

      // ANTI NaN / Infinity - INI FIX ERROR LU DI FOTO
      List<double> raw = wave.samples.map((e)=> e.isFinite? e : 0.0).where((e)=> e.isFinite).toList();
      if(raw.isEmpty) throw Exception('Semua samples NaN');

      int targetSr = 16000;
      List<double> samples = raw;

      if(wave.sampleRate!= targetSr && wave.sampleRate > 0 && wave.sampleRate.isFinite){
        double ratio = wave.sampleRate / targetSr;
        if(ratio.isFinite && ratio>0){
          int newLen = (samples.length / ratio).floor(); // floor anti Infinity
          if(newLen > targetSr * 180) newLen = targetSr * 180;
          if(newLen>0){
            var resampled = List<double>.filled(newLen, 0.0);
            for(int i=0;i<newLen;i++){
              int srcIdx = (i * ratio).floor();
              if(srcIdx>=0 && srcIdx < samples.length){
                double v = samples[srcIdx];
                resampled[i] = v.isFinite? v : 0.0;
              }
            }
            samples = resampled;
          }
        }
      } else {
        if(samples.length > targetSr * 180) samples = samples.sublist(0, targetSr * 180);
      }

      // pastikan final gak ada NaN lagi
      samples = samples.map((e)=> e.isFinite? e : 0.0).toList();
      Float32List finalSamples = Float32List.fromList(samples);

      updateStep('3/5 SIAP ${finalSamples.length~/16000}s', prog:0.6, msg:'${finalSamples.length} samples valid');

      updateStep('4/5 INIT TINY', prog:0.7);
      final whisperCfg = sherpa.OfflineWhisperModelConfig(encoder: '$mp/encoder.onnx', decoder: '$mp/decoder.onnx', language: '', task: 'transcribe');
      final modelCfg = sherpa.OfflineModelConfig(whisper: whisperCfg, tokens: '$mp/tokens.txt', numThreads: 1);
      final recog = sherpa.OfflineRecognizer(sherpa.OfflineRecognizerConfig(model: modelCfg, decodingMethod: 'greedy', maxActivePaths: 1));

      int chunkSec = 30;
      int chunkSamples = 16000 * chunkSec;
      int totalChunks = (finalSamples.length / chunkSamples).ceil();
      if(totalChunks==0) totalChunks=1;
      List<TimedSentence> allSentences = [];

      for(int c=0;c<totalChunks;c++){
        int start = c * chunkSamples;
        int end = start + chunkSamples;
        if(end > finalSamples.length) end = finalSamples.length;
        if(start>=end) break;
        var chunk = finalSamples.sublist(start, end);

        updateStep('5/5 DECODE ${c+1}/$totalChunks', prog:0.7 + 0.3*c/totalChunks, msg:'${(start/16000).toInt()}s-${(end/16000).toInt()}s / ${finalSamples.length~/16000}s');

        final stream = recog.createStream();
        stream.acceptWaveform(sampleRate: 16000, samples: chunk);
        recog.decode(stream);
        final result = recog.getResult(stream);
        String rawText = result.text.trim();

        double offsetSec = start / 16000.0;
        if(offsetSec.isNaN ||!offsetSec.isFinite) offsetSec = 0;

        if(rawText.isNotEmpty){
          var words = rawText.split(RegExp(r'\s+')).where((w)=>w.isNotEmpty).toList();
          for(int i=0;i<words.length;i+=6){
            int en = (i+6<words.length)? i+6 : words.length;
            var slice = words.sublist(i,en);
            List<TimedWord> wds = [];
            for(int j=0;j<slice.length;j++){
              double s = offsetSec + (i+j)*0.5;
              double e = s + 0.5;
              if(!s.isFinite) s = offsetSec;
              if(!e.isFinite) e = s + 0.5;
              wds.add(TimedWord(slice[j], Duration(milliseconds:(s*1000).floor()), Duration(milliseconds:(e*1000).floor())));
            }
            if(wds.isNotEmpty) allSentences.add(TimedSentence(wds, wds.first.start, wds.last.end));
          }
        }
        stream.free();
        await Future.delayed(const Duration(milliseconds:150));
      }

      lyricSentences = allSentences;
      currentLyricIndex=0;
      recog.free();

      if(context.mounted) Navigator.pop(context);
      errorMessage='✅ ${allSentences.length} baris - 3 menit sukses';
      if(allSentences.isEmpty) errorMessage='⚠️ Lirik kosong - model tidak deteksi vokal, coba edit manual';

    }catch(e){
      if(context.mounted) Navigator.pop(context);
      errorMessage='❌ GAGAL DI $currentStep: $e';
      if(context.mounted){
        showDialog(context: context, builder: (ctx)=>AlertDialog(
          backgroundColor: const Color(0xFF1E1E24),
          title: Text('❌ $currentStep', style: const TextStyle(color: Colors.redAccent)),
          content: Text('$e', style: const TextStyle(color: Colors.white70, fontSize:11)),
          actions: [ElevatedButton(onPressed: ()=>Navigator.pop(ctx), child: const Text('OK'))],
        ));
      }
    }finally{
      isTranscribing=false;
      notifyListeners();
    }
  }

  Future<void> pickMusic(BuildContext context) async {
    try{
      await _req();
      final res=await FilePicker.platform.pickFiles(type: FileType.audio, withData:false);
      if(res==null||res.files.isEmpty) return;
      final p=res.files.single;
      String? path=p.path;
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
      await transcribeLyric(context);
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
      content: Text('File: ${recordedPath!.split('/').last}\nDurasi: ${recordSeconds}s / 60s\n${editableTitle}\nLirik: ${lyricSentences.length} baris', style: const TextStyle(color:Colors.white70, fontSize:12)),
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
        if(!maxSec.isFinite) maxSec=60;
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E24),
          title: const Text('TRIM REC 60s MAX', style: TextStyle(color:Colors.amber, fontSize:14, fontWeight: FontWeight.bold)),
          content: Column(mainAxisSize: MainAxisSize.min, children:[
            Text('${fmt(tempStart)} - ${fmt(tempEnd)} (${(tempEnd-tempStart).inSeconds}s)', style: const TextStyle(color:Colors.white70, fontSize:12)),
            const SizedBox(height:12),
            RangeSlider(min: 0, max: maxSec, values: RangeValues(tempStart.inSeconds.toDouble(), tempEnd.inSeconds.toDouble()), activeColor: Colors.amber, inactiveColor: Colors.white24, labels: RangeLabels(fmt(tempStart), fmt(tempEnd)), onChanged: (v){
              Duration ns = Duration(seconds: v.start.floor());
              Duration ne = Duration(seconds: v.end.floor());
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
    final txt = lyricSentences.map((s)=>s.text).join('\n');
    final controller = TextEditingController(text: txt);
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
      var lines = res.split('\n').map((e)=>e.trim()).where((e)=>e.isNotEmpty).toList();
      if(lines.isEmpty) lines=['Lirik kosong'];
      List<TimedWord> words = [];
      int totalMs = duration.inMilliseconds>0? duration.inMilliseconds : lines.length*3000;
      if(!totalMs.isFinite) totalMs = lines.length*3000;
      int idx=0;
      int totalWords = lines.join(' ').split(' ').where((w)=>w.isNotEmpty).length;
      if(totalWords==0) totalWords=1;
      for(var line in lines){
        var ws = line.split(' ').where((w)=>w.isNotEmpty).toList();
        for(var w in ws){
          int s = (idx*totalMs ~/ totalWords);
          if(!s.isFinite) s=0;
          words.add(TimedWord(w, Duration(milliseconds:s), Duration(milliseconds:s+400)));
          idx++;
        }
      }
      List<TimedSentence> newSent = [];
      for(int i=0;i<words.length;i+=6){
        int e = (i+6<words.length)? i+6 : words.length;
        var sl = words.sublist(i,e);
        newSent.add(TimedSentence(sl, sl.first.start, sl.last.end));
      }
      lyricSentences = newSent;
      currentLyricIndex=0;
      notifyListeners();
    }
  }

  Future<void> shareToWhatsApp() async {
    if(recordedPath==null ||!File(recordedPath!).existsSync()){ errorMessage='Belum ada video record'; notifyListeners(); return; }
    await Share.shareXFiles([XFile(recordedPath!)], text: "$editableTitle - HD 1080p - ${recordSeconds}s");
  }

  String fmt(Duration v){
    if(!v.inMilliseconds.isFinite) return "00:00";
    return '${v.inMinutes.remainder(60).toString().padLeft(2,'0')}:${v.inSeconds.remainder(60).toString().padLeft(2,'0')}';
  }
  double max(){
    if(duration.inMilliseconds<=0) return 1.0;
    double m = duration.inMilliseconds.toDouble();
    if(!m.isFinite) return 1.0;
    return m;
  }
  double val(){
    if(duration.inMilliseconds<=0) return 0;
    double c=position.inMilliseconds.toDouble();
    double m=duration.inMilliseconds.toDouble();
    if(!c.isFinite ||!m.isFinite) return 0;
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
        final currentSentence = ctrl.lyricSentences.isNotEmpty && ctrl.currentLyricIndex < ctrl.lyricSentences.length? ctrl.lyricSentences[ctrl.currentLyricIndex] : null;
        return ListView(controller: widget.scrollController, padding: const EdgeInsets.fromLTRB(12,10,12,16), children: [
          Center(child: Container(width:42,height:5,decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10)))),
          const SizedBox(height:10),
          AnimatedCrossFade(duration: const Duration(milliseconds:250), firstChild: const SizedBox.shrink(), secondChild: Container(padding: const EdgeInsets.symmetric(horizontal:10,vertical:8), decoration: BoxDecoration(color: Colors.white.withOpacity(0.07), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.amber.withOpacity(0.3))), child: Row(children:[const Icon(Icons.music_note,color:Colors.amber,size:20), const SizedBox(width:8), Expanded(child: Text(ctrl.musicName, maxLines:1, overflow:TextOverflow.ellipsis, style: const TextStyle(color:Colors.white,fontSize:13,fontWeight:FontWeight.bold))), if(ctrl.isLoading||ctrl.isTranscribing) const SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2,color:Colors.amber)), const SizedBox(width:8), InkWell(onTap: ()=>ctrl.pickMusic(context), child: Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.folder_open,color:Colors.black,size:22)))])), crossFadeState: showPicker? CrossFadeState.showSecond : CrossFadeState.showFirst),
          if(ctrl.errorMessage!=null) Padding(padding: const EdgeInsets.only(top:6), child: Text(ctrl.errorMessage!, style: const TextStyle(color:Colors.amber,fontSize:11))),
          const SizedBox(height:10),
          InkWell(onTap: _editTitle, child: Container(width:double.infinity, padding: const EdgeInsets.symmetric(horizontal:10,vertical:6), decoration: BoxDecoration(color: Colors.amber.withOpacity(0.14), borderRadius: BorderRadius.circular(8)), child: Row(children:[const Icon(Icons.edit,size:14,color:Colors.amber), const SizedBox(width:6), Expanded(child: RunningText(text: ctrl.editableTitle))]))),
          const SizedBox(height:8),
          Container(height:52, decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white12)), child: ctrl.selectedMusicFile==null? const Center(child: Text('Waveform / Equalizer', style: TextStyle(color:Colors.white24,fontSize:11))) : AudioFileWaveforms(size: Size(MediaQuery.of(context).size.width-24,52), playerController: ctrl.waveformController, enableSeekGesture:true, waveformType: WaveformType.fitWidth, playerWaveStyle: const PlayerWaveStyle(fixedWaveColor:Colors.white24,liveWaveColor:Colors.amber,spacing:3,waveThickness:2))),
          const SizedBox(height:8),
          Row(children:[
            Expanded(child: ElevatedButton.icon(onPressed: ctrl.isTranscribing?null:()=>ctrl.transcribeLyric(context), style: ElevatedButton.styleFrom(backgroundColor: Colors.white12, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical:10)), icon: Icon(ctrl.isTranscribing?Icons.hourglass_top:Icons.auto_awesome, size:16), label: Text(ctrl.isTranscribing?'Transcribing...':'Auto Lirik Asli', style: const TextStyle(fontSize:11)))),
            const SizedBox(width:8),
            Expanded(child: ElevatedButton.icon(onPressed: ()=>ctrl.editLyricsDialog(context), style: ElevatedButton.styleFrom(backgroundColor: Colors.amber.withOpacity(0.2), foregroundColor: Colors.amber, padding: const EdgeInsets.symmetric(vertical:10)), icon: const Icon(Icons.edit_note, size:16), label: const Text('Edit Lirik', style: TextStyle(fontSize:11)))),
          ]),
          const SizedBox(height:8),
          GestureDetector(onTap: ()=>setState(()=>lyricExpanded=!lyricExpanded), child: AnimatedContainer(duration: const Duration(milliseconds:250), width: double.infinity, padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.amber.withOpacity(0.2))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[
            Row(children:[const Icon(Icons.lyrics, size:14, color: Colors.amber), const SizedBox(width:6), Expanded(child: Text(lyricExpanded? 'LIRIK KARAOKE TIMESTAMP AKURAT - TAP FOLD' : 'KARAOKE: ${currentSentence?.text?? ''}', style: const TextStyle(color:Colors.amber, fontSize:11, fontWeight: FontWeight.bold), maxLines:1, overflow: TextOverflow.ellipsis))]),
            const SizedBox(height:8),
            if(lyricExpanded) Column(crossAxisAlignment: CrossAxisAlignment.start, children:[
              Container(width: double.infinity, padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.white.withOpacity(0.06), borderRadius: BorderRadius.circular(10)), child: currentSentence==null? const Text('Belum ada lirik - Transcribe dulu', style: TextStyle(color:Colors.white24, fontSize:11)) : LyricKaraoke(sentence: currentSentence, position: ctrl.position)),
              const SizedBox(height:8),
            ...ctrl.lyricSentences.asMap().entries.map((e){
                final isActive = e.key==ctrl.currentLyricIndex;
                return AnimatedContainer(duration: const Duration(milliseconds:200), padding: const EdgeInsets.symmetric(vertical:3, horizontal:6), margin: const EdgeInsets.only(bottom:2), decoration: isActive? BoxDecoration(color: Colors.amber.withOpacity(0.12), borderRadius: BorderRadius.circular(6)) : null, child: Row(children:[Text('${e.key+1}. ', style: TextStyle(color: isActive?Colors.amber:Colors.white24, fontSize:10)), Expanded(child: Text(e.value.text, style: TextStyle(color: isActive?Colors.white:Colors.white38, fontSize: isActive?13:11, fontWeight: isActive?FontWeight.bold:FontWeight.normal)))]));
              }),
            ]) else currentSentence==null? const SizedBox.shrink() : LyricKaraoke(sentence: currentSentence, position: ctrl.position),
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
          AnimatedCrossFade(duration: const Duration(milliseconds:250), firstChild: const SizedBox.shrink(), secondChild: Column(children:[SliderTheme(data: SliderTheme.of(context).copyWith(trackHeight:3, thumbShape: const RoundSliderThumbShape(enabledThumbRadius:8)), child: Slider(value: ctrl.val(), min:0.0, max:ctrl.max(), activeColor:Colors.amber, inactiveColor:Colors.white24, onChanged: ctrl.duration==Duration.zero?null:(v)=>ctrl.seekTo(Duration(milliseconds:v.floor())))), Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children:[Text(ctrl.fmt(ctrl.position),style: const TextStyle(color:Colors.white60,fontSize:11)), Text(ctrl.fmt(ctrl.duration),style: const TextStyle(color:Colors.white60,fontSize:11))])]), crossFadeState: showPicker? CrossFadeState.showSecond : CrossFadeState.showFirst),
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