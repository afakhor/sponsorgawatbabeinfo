import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screen_recording/flutter_screen_recording.dart';
import 'package:just_audio/just_audio.dart' as ja;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

// ==========================================
// RUNNING TEXT WIDGET
// ==========================================
class RunningText extends StatefulWidget {
  final String text;
  final Color color;
  final double fontSize;
  const RunningText({super.key, required this.text, this.color = Colors.amber, this.fontSize = 14});

  @override
  State<RunningText> createState() => _RunningTextState();
}

class _RunningTextState extends State<RunningText> with SingleTickerProviderStateMixin {
  late AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 14))..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) {
    if (widget.text.isEmpty) return const SizedBox(height: 18);
    return SizedBox(
      height: 18,
      child: ClipRect(
        child: AnimatedBuilder(
          animation: _c,
          builder: (ctx, _) {
            return Transform.translate(
              offset: Offset(120 - (_c.value * 350), 0),
              child: Text(
                widget.text,
                maxLines: 1,
                style: TextStyle(color: widget.color, fontSize: widget.fontSize, fontWeight: FontWeight.w600),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ==========================================
// DATA MODELS FOR LYRICS
// ==========================================
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
  TimedSentence(this.words, this.start, this.end);
  String get text => words.map((w) => w.word).join(' ');
}

// ==========================================
// SAFE WAV DECODER WITH MP3 VALIDATION
// ==========================================
sherpa.WaveData _decodeWavSafe(Uint8List bytes) {
  if (bytes.length < 44 ||
      bytes[0] != 0x52 || bytes[1] != 0x49 || bytes[2] != 0x46 || bytes[3] != 0x46 ||
      bytes[8] != 0x57 || bytes[9] != 0x41 || bytes[10] != 0x56 || bytes[11] != 0x45) {
    throw Exception('Auto Lirik AI memerlukan file WAV (16-bit PCM). Untuk MP3, gunakan menu "Edit Lirik".');
  }

  int dataPos = -1;
  int sampleRate = 16000;
  int numChannels = 1;
  int bitsPerSample = 16;

  for (int i = 0; i < bytes.length - 12; i++) {
    if (bytes[i] == 0x66 && bytes[i + 1] == 0x6D && bytes[i + 2] == 0x74 && bytes[i + 3] == 0x20) {
      numChannels = bytes[i + 10] | (bytes[i + 11] << 8);
      sampleRate = bytes[i + 12] | (bytes[i + 13] << 8) | (bytes[i + 14] << 16) | (bytes[i + 15] << 24);
      bitsPerSample = bytes[i + 22] | (bytes[i + 23] << 8);
    }
    if (bytes[i] == 0x64 && bytes[i + 1] == 0x61 && bytes[i + 2] == 0x72 && bytes[i + 3] == 0x61) {
      dataPos = i + 8;
      break;
    }
  }

  if (dataPos == -1 || dataPos >= bytes.length) dataPos = 44;

  int bytesPerSample = bitsPerSample ~/ 8;
  if (bytesPerSample <= 0) bytesPerSample = 2;

  int availableBytes = bytes.length - dataPos;
  if (availableBytes <= 0) throw Exception('Header WAV rusak atau sampel tidak ditemukan.');

  int blockAlign = bytesPerSample * numChannels;
  int totalSamples = availableBytes ~/ blockAlign;
  int safeLength = totalSamples * blockAlign;

  final Float32List floatSamples = Float32List(totalSamples);
  final ByteData byteData = ByteData.sublistView(bytes, dataPos, dataPos + safeLength);

  int offset = 0;
  for (int i = 0; i < totalSamples; i++) {
    int sampleValue = 0;
    if (bitsPerSample == 16) {
      sampleValue = byteData.getInt16(offset, Endian.little);
    } else if (bitsPerSample == 8) {
      sampleValue = (byteData.getUint8(offset) - 128) << 8;
    }
    floatSamples[i] = sampleValue / 32768.0;
    offset += blockAlign;
  }

  return sherpa.WaveData(samples: floatSamples, sampleRate: sampleRate);
}

// ==========================================
// LYRIC KARAOKE WIDGET
// ==========================================
class LyricKaraoke extends StatelessWidget {
  final TimedSentence sentence;
  final Duration position;
  const LyricKaraoke({super.key, required this.sentence, required this.position});

  @override
  Widget build(BuildContext context) {
    int activeWord = -1;
    for (int i = 0; i < sentence.words.length; i++) {
      if (position >= sentence.words[i].start && position < sentence.words[i].end) {
        activeWord = i;
        break;
      }
      if (position >= sentence.words[i].end && i == sentence.words.length - 1 && position < sentence.end + const Duration(milliseconds: 600)) {
        activeWord = i;
      }
    }
    if (position > sentence.end) activeWord = sentence.words.length;

    return TweenAnimationBuilder<double>(
      key: ValueKey(sentence.start),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutBack,
      builder: (ctx, val, child) {
        return Opacity(
          opacity: val,
          child: Transform.translate(
            offset: Offset(0, (1 - val) * 18),
            child: Transform.scale(scale: 0.85 + val * 0.15, child: child),
          ),
        );
      },
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: List.generate(sentence.words.length, (i) {
          final passed = activeWord > i;
          final current = i == activeWord;
          Color col = passed ? Colors.greenAccent : current ? Colors.green : Colors.white;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: EdgeInsets.symmetric(horizontal: current ? 10 : 0, vertical: current ? 4 : 2),
            decoration: current
                ? BoxDecoration(
                    color: Colors.green.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.greenAccent.withOpacity(0.9)),
                  )
                : null,
            child: Text(
              sentence.words[i].word,
              style: TextStyle(
                color: col,
                fontSize: current ? 17 : 13.5,
                fontWeight: passed || current ? FontWeight.bold : FontWeight.w500,
                shadows: current ? [const Shadow(color: Colors.black, blurRadius: 8)] : null,
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ==========================================
// MUSIC CONTROLLER LOGIC
// ==========================================
class MusicController extends ChangeNotifier {
  final ja.AudioPlayer audioPlayer = ja.AudioPlayer();
  final PlayerController waveformController = PlayerController();
// Tambahkan di dalam class MusicController
bool get usePreTrim => trimStart > Duration.zero || trimEnd < duration;

  File? selectedMusicFile;
  String musicName = 'Belum ada musik';
  String editableTitle = 'SPONSOR BABE INFO GAWAT • TAP UNTUK EDIT JUDUL';
  String editableBottomTitle = 'Babe Info Gawat - Tap untuk edit bawah';

  List<TimedSentence> lyricSentences = [];
  List<String> get lyricLines => lyricSentences.map((e) => e.text).toList();
  int currentLyricIndex = 0;
  Duration position = Duration.zero, duration = Duration.zero;

  bool isPlaying = false, isLoading = false, isRecording = false, isTranscribing = false;
  String? errorMessage;
  String? recordedPath;
  Timer? recordTimer;
  int recordSeconds = 0;
  Duration trimStart = Duration.zero;
  Duration trimEnd = const Duration(seconds: 60);

  MusicController() {
    audioPlayer.positionStream.listen((p) {
      position = p;
      _updateLyricIndex();
      notifyListeners();
    });
    audioPlayer.playerStateStream.listen((s) {
      isPlaying = s.playing;
      notifyListeners();
    });
  }

  void _updateLyricIndex() {
    if (lyricSentences.isEmpty) return;
    for (int i = 0; i < lyricSentences.length; i++) {
      if (position >= lyricSentences[i].start && position <= lyricSentences[i].end) {
        currentLyricIndex = i;
        break;
      }
    }
  }

  String fmt(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    return "${twoDigits(d.inMinutes.remainder(60))}:${twoDigits(d.inSeconds.remainder(60))}";
  }

  Future<void> _req() async {
    await [Permission.storage, Permission.microphone, Permission.photos].request();
  }

  // UPLOAD MUSIK BIASA (OPSI TANPA LIRIK)
  Future<void> pickMusic(BuildContext context) async {
    try {
      await _req();
      final res = await FilePicker.platform.pickFiles(type: FileType.audio, withData: false);
      if (res == null || res.files.isEmpty) return;
      final p = res.files.single;
      String? path = p.path;
      if (path == null) return;

      selectedMusicFile = File(path);
      musicName = p.name;
      editableTitle = musicName;
      lyricSentences = []; // Reset lirik menjadi kosong
      currentLyricIndex = 0;
      errorMessage = null;
      isLoading = true;
      notifyListeners();

      await audioPlayer.stop();
      try { await waveformController.stopPlayer(); } catch (_) {}

      await audioPlayer.setAudioSource(ja.AudioSource.file(path));
      duration = audioPlayer.duration ?? Duration.zero;
      trimStart = Duration.zero;
      trimEnd = duration.inSeconds > 60 ? const Duration(seconds: 60) : duration;

      try {
        await waveformController.preparePlayer(path: path, shouldExtractWaveform: true, noOfSamples: 100);
        await waveformController.stopPlayer();
      } catch (_) {}

      isLoading = false;
      errorMessage = '✅ Musik siap diputar (Tanpa Lirik)';
      notifyListeners();

      // CATATAN: Panggilan auto-transcribe telah DIBUANG di sini agar pengguna
      // bisa bebas memilih memutar lagu offline tanpa lirik otomatis.
    } catch (e) {
      errorMessage = 'Gagal pilih file: $e';
      isLoading = false;
      notifyListeners();
    }
  }

  // AUTO LIRIK HANYA BERJALAN JIKA DITEKAN MANUAL
  Future<void> transcribeLyric(BuildContext context) async {
    if (selectedMusicFile == null) {
      errorMessage = 'Pilih musik terlebih dahulu!';
      notifyListeners();
      return;
    }
    isTranscribing = true;
    String currentStep = 'START';
    double progress = 0;
    late StateSetter diagSet;

    if (context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setSt) {
            diagSet = setSt;
            return AlertDialog(
              backgroundColor: const Color(0xFF1E1E24),
              title: const Text('🔍 AI TRANSCRIBE LIRIK', style: TextStyle(color: Colors.amber, fontSize: 13)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('PROSES: $currentStep', style: const TextStyle(color: Colors.cyan, fontSize: 12)),
                  const SizedBox(height: 10),
                  LinearProgressIndicator(value: progress == 0 ? null : progress, color: Colors.amber),
                ],
              ),
            );
          },
        ),
      );
    }

    void updateStep(String step, {double prog = 0, String? msg}) {
      currentStep = step;
      progress = prog;
      if (msg != null) errorMessage = msg;
      try { diagSet(() {}); } catch (_) {}
      notifyListeners();
    }

    try {
      updateStep('1/5 CEK MODEL SHERPA', prog: 0.1);
      final mp = await _ensureModelWithDialog(context);

      updateStep('2/5 MENYIAPKAN DATA AUDIO', prog: 0.3);
      final rawBytes = await selectedMusicFile!.readAsBytes();

      updateStep('3/5 MEMBACA SAMPEL AUDIO', prog: 0.5);
      sherpa.WaveData wave = _decodeWavSafe(rawBytes);

      updateStep('4/5 INIT ENGINE WHISPER', prog: 0.7);

      final whisperCfg = sherpa.OfflineWhisperModelConfig(
        encoder: '$mp/encoder.onnx',
        decoder: '$mp/decoder.onnx',
        language: 'en',
        task: 'transcribe',
      );

      final modelCfg = sherpa.OfflineModelConfig(
        whisper: whisperCfg,
        tokens: '$mp/tokens.txt',
        numThreads: 1,
        provider: 'cpu',
      );

      final recog = sherpa.OfflineRecognizer(
        sherpa.OfflineRecognizerConfig(
          model: modelCfg,
          decodingMethod: 'greedy',
          maxActivePaths: 1,
        ),
      );

      List<TimedSentence> allSentences = [];
      final samples = wave.samples;
      int chunkSize = wave.sampleRate * 10;
      int totalChunks = (samples.length / chunkSize).ceil();

      for (int c = 0; c < totalChunks; c++) {
        updateStep('5/5 DECODE TIMING ${c + 1}/$totalChunks', prog: 0.7 + (0.3 * c / totalChunks));

        int start = c * chunkSize;
        int end = (start + chunkSize > samples.length) ? samples.length : start + chunkSize;
        final chunk = samples.sublist(start, end);

        try {
          final stream = recog.createStream();
          stream.acceptWaveform(sampleRate: wave.sampleRate, samples: chunk);
          recog.decode(stream);
          final result = recog.getResult(stream);
          String rawText = result.text.trim();
          stream.free();

          double offsetSec = start / wave.sampleRate.toDouble();
          if (rawText.isNotEmpty) {
            var words = rawText.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
            double durationSec = (end - start) / wave.sampleRate.toDouble();
            double timePerWord = durationSec / (words.isEmpty ? 1 : words.length);

            for (int i = 0; i < words.length; i += 6) {
              int en = (i + 6 < words.length) ? i + 6 : words.length;
              var slice = words.sublist(i, en);
              List<TimedWord> wds = [];
              for (int j = 0; j < slice.length; j++) {
                double s = offsetSec + ((i + j) * timePerWord);
                wds.add(TimedWord(
                  slice[j],
                  Duration(milliseconds: (s * 1000).floor()),
                  Duration(milliseconds: ((s + timePerWord) * 1000).floor()),
                ));
              }
              if (wds.isNotEmpty) allSentences.add(TimedSentence(wds, wds.first.start, wds.last.end));
            }
          }
        } catch (_) {}
        await Future.delayed(const Duration(milliseconds: 50));
      }

      lyricSentences = allSentences;
      currentLyricIndex = 0;
      recog.free();

      if (context.mounted) Navigator.pop(context);
      errorMessage = '✅ ${allSentences.length} baris - Auto Transcribe OK';
    } catch (e) {
      if (context.mounted) Navigator.pop(context);
      errorMessage = '⚠️ ${e.toString().replaceAll('Exception: ', '')}';
    } finally {
      isTranscribing = false;
      notifyListeners();
    }
  }

  Future<String> _ensureModelWithDialog(BuildContext context) async {
    final dir = await getApplicationDocumentsDirectory();
    final modelDir = Directory('${dir.path}/sherpa-tiny');
    if (!await modelDir.exists()) await modelDir.create(recursive: true);

    final enc = '${modelDir.path}/encoder.onnx';
    final dec = '${modelDir.path}/decoder.onnx';
    final tok = '${modelDir.path}/tokens.txt';

    if (File(enc).existsSync() && File(dec).existsSync() && File(tok).existsSync() && File(enc).lengthSync() > 3 * 1024 * 1024) {
      return modelDir.path;
    }

    double progress = 0;
    bool success = false;
    late StateSetter dialogSetState;
    if (context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          return StatefulBuilder(
            builder: (ctx, setSt) {
              dialogSetState = setSt;
              return AlertDialog(
                backgroundColor: const Color(0xFF1E1E24),
                title: Text(
                  success ? '✅ Download Sukses' : '⬇️ Download Model 39MB',
                  style: const TextStyle(color: Colors.amber, fontSize: 14, fontWeight: FontWeight.bold),
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    LinearProgressIndicator(value: success ? 1 : (progress == 0 ? null : progress), color: Colors.amber),
                    const SizedBox(height: 12),
                    Text(success ? 'Model siap!' : '${(progress * 100).toStringAsFixed(0)}%', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                ),
              );
            },
          );
        },
      );
    }

    const base = 'https://huggingface.co/csukuangfj/sherpa-onnx-whisper-tiny/resolve/main';
    try {
      await _dlWithProgress('$base/tiny-encoder.int8.onnx', enc, (p) { progress = p * 0.5; try { dialogSetState(() {}); } catch (_) {} });
      await _dlWithProgress('$base/tiny-decoder.int8.onnx', dec, (p) { progress = 0.5 + p * 0.4; try { dialogSetState(() {}); } catch (_) {} });
      await _dlWithProgress('$base/tiny-tokens.txt', tok, (p) { progress = 0.9 + p * 0.1; try { dialogSetState(() {}); } catch (_) {} });
      success = true;
      try { dialogSetState(() {}); } catch (_) {}
      await Future.delayed(const Duration(milliseconds: 800));
      if (context.mounted) Navigator.pop(context);
    } catch (e) {
      if (context.mounted) Navigator.pop(context);
      rethrow;
    }
    return modelDir.path;
  }

  Future<void> _dlWithProgress(String url, String path, Function(double) onProg) async {
    final client = HttpClient();
    final req = await client.getUrl(Uri.parse(url));
    final res = await req.close();
    final total = res.contentLength;
    int rx = 0;
    final f = File(path);
    final sink = f.openWrite();
    await res.forEach((chunk) {
      rx += chunk.length;
      sink.add(chunk);
      if (total > 0) onProg(rx / total);
    });
    await sink.close();
  }

  Future<void> togglePlay() async {
    if (selectedMusicFile == null) {
      errorMessage = 'Pilih lagu terlebih dahulu 📁';
      notifyListeners();
      return;
    }
    if (audioPlayer.playing) {
      await audioPlayer.pause();
      try { await waveformController.pausePlayer(); } catch (_) {}
    } else {
      await audioPlayer.play();
      try { await waveformController.startPlayer(); } catch (_) {}
    }
  }

  Future<void> seekTo(Duration v) async {
    Duration safe = v;
    if (safe < Duration.zero) safe = Duration.zero;
    if (safe > duration) safe = duration;
    try { await audioPlayer.seek(safe); } catch (_) {}
    try { await waveformController.seekTo(safe.inMilliseconds); } catch (_) {}
    position = safe;
    notifyListeners();
  }

  Future<void> startRecord({Duration? startFrom, Duration? endAt}) async {
    try {
      await _req();
      if (selectedMusicFile != null) {
        await seekTo(startFrom ?? Duration.zero);
        await audioPlayer.play();
        try { await waveformController.startPlayer(); } catch (_) {}
      }
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      isRecording = true;
      recordSeconds = 0;
      recordedPath = null;
      notifyListeners();

      final fileName = 'babe_${DateTime.now().millisecondsSinceEpoch}';
      await FlutterScreenRecording.startRecordScreenAndAudio(
        fileName,
        titleNotification: "Babe Info GAWAT REC HD",
        messageNotification: "Recording screen and audio HD 1080p",
      );

      Duration targetEnd = endAt ?? (duration.inSeconds > 0 ? (duration.inSeconds > 60 ? const Duration(seconds: 60) : duration) : const Duration(seconds: 60));

      recordTimer?.cancel();
      recordTimer = Timer.periodic(const Duration(seconds: 1), (t) {
        recordSeconds++;
        notifyListeners();
        if (startFrom != null && position >= targetEnd) {
          stopRecord();
        } else if (recordSeconds >= 60 || (startFrom == null && recordSeconds >= targetEnd.inSeconds)) {
          stopRecord();
        }
      });
    } catch (e) {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      isRecording = false;
      errorMessage = 'Record gagal: $e';
      notifyListeners();
    }
  }

  Future<void> stopRecord() async {
    try {
      recordTimer?.cancel();
      try {
        await audioPlayer.pause();
        await waveformController.pausePlayer();
      } catch (_) {}
      recordedPath = await FlutterScreenRecording.stopRecordScreen;
    } catch (e) {
      errorMessage = 'Stop gagal: $e';
    } finally {
      isRecording = false;
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      notifyListeners();
    }
  }

  Future<void> cancelRecord() async {
    try {
      recordTimer?.cancel();
      await FlutterScreenRecording.stopRecordScreen;
      try {
        await audioPlayer.pause();
        await waveformController.pausePlayer();
      } catch (_) {}
    } catch (_) {} finally {
      isRecording = false;
      recordedPath = null;
      recordSeconds = 0;
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      notifyListeners();
    }
  }

  Future<void> showPostRecordDialog(BuildContext context) async {
    if (recordedPath == null || !File(recordedPath!).existsSync()) {
      errorMessage = 'Belum ada hasil rekaman';
      notifyListeners();
      return;
    }

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E24),
        title: const Text('🎬 Rekaman Selesai', style: TextStyle(color: Colors.amber, fontSize: 14, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Video berhasil direkam!', style: TextStyle(color: Colors.white70, fontSize: 12)),
            const SizedBox(height: 8),
            Text('Durasi: ${recordSeconds}s', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Tutup', style: TextStyle(color: Colors.white54))),
        ],
      ),
    );
  }

  Future<void> showTrimDialog(BuildContext context) async {
    if (selectedMusicFile == null || duration == Duration.zero) {
      errorMessage = 'Pilih lagu dulu 📁';
      notifyListeners();
      return;
    }
    Duration tempStart = Duration.zero;
    Duration tempEnd = duration.inSeconds > 60 ? const Duration(seconds: 60) : duration;

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSt) {
            double maxSec = duration.inSeconds.toDouble();
            if (!maxSec.isFinite || maxSec == 0) maxSec = 60;
            return AlertDialog(
              backgroundColor: const Color(0xFF1E1E24),
              title: const Text('TRIM REC 60s MAX', style: TextStyle(color: Colors.amber, fontSize: 14, fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${fmt(tempStart)} - ${fmt(tempEnd)} (${(tempEnd - tempStart).inSeconds}s)', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  const SizedBox(height: 12),
                  RangeSlider(
                    min: 0,
                    max: maxSec,
                    values: RangeValues(tempStart.inSeconds.toDouble().clamp(0, maxSec), tempEnd.inSeconds.toDouble().clamp(0, maxSec)),
                    activeColor: Colors.amber,
                    inactiveColor: Colors.white24,
                    labels: RangeLabels(fmt(tempStart), fmt(tempEnd)),
                    onChanged: (v) {
                      Duration ns = Duration(seconds: v.start.floor());
                      Duration ne = Duration(seconds: v.end.floor());
                      if ((ne - ns).inSeconds > 60) ne = ns + const Duration(seconds: 60);
                      setSt(() {
                        tempStart = ns;
                        tempEnd = ne;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black),
                  onPressed: () async {
                    Navigator.pop(ctx);
                    trimStart = tempStart;
                    trimEnd = tempEnd;
                    await startRecord(startFrom: trimStart, endAt: trimEnd);
                  },
                  child: const Text('TRIM REC'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> editLyricsDialog(BuildContext context) async {
    final txt = lyricSentences.map((s) => s.text).join('\n');
    final controller = TextEditingController(text: txt);

    final res = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E24),
        title: const Text('Edit Lirik Manual (Simpan Selesai)', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: double.maxFinite,
          height: 320,
          child: TextField(
            controller: controller,
            maxLines: 20,
            style: const TextStyle(color: Colors.white, fontSize: 12),
            decoration: const InputDecoration(
              hintText: 'Ketik atau tempel lirik lagu di sini...\nSatu baris per kalimat.',
              hintStyle: TextStyle(color: Colors.white24, fontSize: 11),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black),
            child: const Text('Simpan & Gunakan Lirik'),
          ),
        ],
      ),
    );

    if (res != null) {
      var lines = res.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      if (lines.isEmpty) {
        lyricSentences = [];
        notifyListeners();
        return;
      }

      List<TimedWord> words = [];
      int totalMs = duration.inMilliseconds > 0 ? duration.inMilliseconds : lines.length * 3000;
      int idx = 0;
      int totalWords = lines.join(' ').split(' ').where((w) => w.isNotEmpty).length;
      if (totalWords == 0) totalWords = 1;

      for (var line in lines) {
        var ws = line.split(' ').where((w) => w.isNotEmpty).toList();
        for (var w in ws) {
          int s = (idx * totalMs ~/ totalWords);
          words.add(TimedWord(w, Duration(milliseconds: s), Duration(milliseconds: s + 400)));
          idx++;
        }
      }

      List<TimedSentence> newSent = [];
      for (int i = 0; i < words.length; i += 6) {
        int e = (i + 6 < words.length) ? i + 6 : words.length;
        var sl = words.sublist(i, e);
        newSent.add(TimedSentence(sl, sl.first.start, sl.last.end));
      }
      lyricSentences = newSent;
      currentLyricIndex = 0;
      errorMessage = '✅ Lirik berhasil diperbarui secara manual';
      notifyListeners();
    }
  }

  @override
  void dispose() {
    recordTimer?.cancel();
    audioPlayer.dispose();
    waveformController.dispose();
    super.dispose();
  }
}

// ==========================================
// FLOATING PLAYER CONTROL BAR (PLAY/PAUSE & SEEK)
// ==========================================
class MusicPlayerBar extends StatelessWidget {
  final MusicController controller;
  const MusicPlayerBar({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        if (controller.selectedMusicFile == null) return const SizedBox.shrink();

        final pos = controller.position;
        final dur = controller.duration;
        double maxSec = dur.inSeconds.toDouble();
        if (maxSec <= 0) maxSec = 1.0;
        double curSec = pos.inSeconds.toDouble().clamp(0.0, maxSec);

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E24),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.amber.withOpacity(0.4)),
          ),
          child: Row(
            children: [
              IconButton(
                onPressed: controller.isLoading ? null : () => controller.togglePlay(),
                icon: Icon(
                  controller.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill,
                  color: Colors.amber,
                  size: 36,
                ),
              ),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 3,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                        overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
                        activeTrackColor: Colors.amber,
                        inactiveTrackColor: Colors.white24,
                        thumbColor: Colors.amber,
                      ),
                      child: Slider(
                        min: 0,
                        max: maxSec,
                        value: curSec,
                        onChanged: (v) => controller.seekTo(Duration(seconds: v.floor())),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(controller.fmt(pos), style: const TextStyle(color: Colors.white70, fontSize: 10)),
                          Text(controller.fmt(dur), style: const TextStyle(color: Colors.white38, fontSize: 10)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ==========================================
// MUSIC PANEL UI COMPONENT
// ==========================================
class MusicPanel extends StatefulWidget {
  final MusicController controller;
  final ScrollController scrollController;
  final DraggableScrollableController sheetController;

  const MusicPanel({
    super.key,
    required this.controller,
    required this.scrollController,
    required this.sheetController,
  });

  @override
  State<MusicPanel> createState() => _MusicPanelState();
}

class _MusicPanelState extends State<MusicPanel> {
  bool lyricExpanded = true;
  bool get isSheetExpanded => widget.sheetController.isAttached ? widget.sheetController.size >= 0.6 : false;

  void _editTitle() async {
    final c = TextEditingController(text: widget.controller.editableTitle);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E24),
        title: const Text('Edit Judul Running Text', style: TextStyle(color: Colors.white, fontSize: 14)),
        content: TextField(controller: c, style: const TextStyle(color: Colors.white, fontSize: 14), autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          TextButton(onPressed: () => Navigator.pop(ctx, c.text), child: const Text('Simpan', style: TextStyle(color: Colors.amber))),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      widget.controller.editableTitle = result;
      widget.controller.notifyListeners();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !widget.controller.isRecording,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop && widget.controller.isRecording) {
          await widget.controller.cancelRecord();
        }
      },
      child: AnimatedBuilder(
        animation: widget.controller,
        builder: (context, _) {
          final ctrl = widget.controller;
          final showPicker = isSheetExpanded;
          final currentSentence = ctrl.lyricSentences.isNotEmpty && ctrl.currentLyricIndex < ctrl.lyricSentences.length
              ? ctrl.lyricSentences[ctrl.currentLyricIndex]
              : null;

          return ListView(
            controller: widget.scrollController,
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
            children: [
              Center(child: Container(width: 42, height: 5, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10)))),
              const SizedBox(height: 10),
              AnimatedCrossFade(
                duration: const Duration(milliseconds: 250),
                firstChild: const SizedBox.shrink(),
                secondChild: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amber.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.music_note, color: Colors.amber, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          ctrl.musicName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      ),
                      if (ctrl.isLoading || ctrl.isTranscribing)
                        const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.amber)),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: () => ctrl.pickMusic(context),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(8)),
                          child: const Icon(Icons.folder_open, color: Colors.black, size: 22),
                        ),
                      )
                    ],
                  ),
                ),
                crossFadeState: showPicker ? CrossFadeState.showSecond : CrossFadeState.showFirst,
              ),
              if (ctrl.errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(ctrl.errorMessage!, style: const TextStyle(color: Colors.amber, fontSize: 11)),
                ),
              const SizedBox(height: 10),
              InkWell(
                onTap: _editTitle,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: Colors.amber.withOpacity(0.14), borderRadius: BorderRadius.circular(8)),
                  child: Row(
                    children: [
                      const Icon(Icons.edit, size: 14, color: Colors.amber),
                      const SizedBox(width: 6),
                      Expanded(child: RunningText(text: ctrl.editableTitle)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              
              // FLOATING CONTROLLER (PLAY/PAUSE BAR)
              MusicPlayerBar(controller: ctrl),

              Container(
                height: 52,
                decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white12)),
                child: ctrl.selectedMusicFile == null
                    ? const Center(child: Text('Waveform Audio', style: TextStyle(color: Colors.white24, fontSize: 11)))
                    : AudioFileWaveforms(
                        size: Size(MediaQuery.of(context).size.width - 24, 52),
                        playerController: ctrl.waveformController,
                        enableSeekGesture: true,
                        waveformType: WaveformType.fitWidth,
                        playerWaveStyle: const PlayerWaveStyle(
                          fixedWaveColor: Colors.white24,
                          liveWaveColor: Colors.amber,
                          spacing: 3,
                          waveThickness: 2,
                        ),
                      ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: ctrl.isTranscribing ? null : () => ctrl.transcribeLyric(context),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.white12, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 10)),
                      icon: Icon(ctrl.isTranscribing ? Icons.hourglass_top : Icons.auto_awesome, size: 16),
                      label: Text(ctrl.isTranscribing ? 'Transcribing...' : 'Auto Lirik AI', style: const TextStyle(fontSize: 11)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => ctrl.editLyricsDialog(context),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.amber.withOpacity(0.2), foregroundColor: Colors.amber, padding: const EdgeInsets.symmetric(vertical: 10)),
                      icon: const Icon(Icons.edit_note, size: 16),
                      label: const Text('Edit Lirik', style: TextStyle(fontSize: 11)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () => setState(() => lyricExpanded = !lyricExpanded),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amber.withOpacity(0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.lyrics, size: 14, color: Colors.amber),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              lyricExpanded ? 'LIRIK KARAOKE - TAP UNTUK LIPAT' : 'KARAOKE: ${currentSentence?.text ?? ''}',
                              style: const TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (lyricExpanded)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(color: Colors.white.withOpacity(0.06), borderRadius: BorderRadius.circular(10)),
                              child: currentSentence == null
                                  ? const Text('Belum ada lirik', style: TextStyle(color: Colors.white24, fontSize: 11))
                                  : LyricKaraoke(sentence: currentSentence, position: ctrl.position),
                            ),
                            const SizedBox(height: 8),
                            ...ctrl.lyricSentences.asMap().entries.map((e) {
                              final isActive = e.key == ctrl.currentLyricIndex;
                              return Container(
                                padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 6),
                                margin: const EdgeInsets.only(bottom: 2),
                                decoration: isActive ? BoxDecoration(color: Colors.amber.withOpacity(0.12), borderRadius: BorderRadius.circular(6)) : null,
                                child: Row(
                                  children: [
                                    Text('${e.key + 1}. ', style: TextStyle(color: isActive ? Colors.amber : Colors.white24, fontSize: 10)),
                                    Expanded(
                                      child: Text(
                                        e.value.text,
                                        style: TextStyle(color: isActive ? Colors.white : Colors.white38, fontSize: isActive ? 13 : 11),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        )
                      else
                        currentSentence == null ? const SizedBox.shrink() : LyricKaraoke(sentence: currentSentence, position: ctrl.position),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: ctrl.isRecording
                          ? () async {
                              await ctrl.stopRecord();
                              if (context.mounted) {
                                await ctrl.showPostRecordDialog(context);
                              }
                            }
                          : () => ctrl.startRecord(),
                      icon: Icon(ctrl.isRecording ? Icons.stop : Icons.fiber_manual_record, size: 18),
                      label: Text(
                        ctrl.isRecording ? '${ctrl.recordSeconds}s STOP' : 'REC MERAH',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: ctrl.isRecording ? null : () => ctrl.showTrimDialog(context),
                      icon: const Icon(Icons.content_cut, size: 18),
                      label: const Text('TRIM REC KUNING', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Center(
                child: Text(
                  showPicker ? '▼ Geser bawah untuk sembunyikan' : '▲ Geser atas untuk pilih lagu 📁',
                  style: const TextStyle(color: Colors.white24, fontSize: 11),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
