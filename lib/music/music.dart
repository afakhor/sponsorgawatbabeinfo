import 'dart:async';
import 'dart:io';

import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screen_recording/flutter_screen_recording.dart';
import 'package:just_audio/just_audio.dart' as ja;
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';

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
// DATA MODELS FOR LYRICS & SYNC
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
// LYRIC KARAOKE WIDGET (FADE IN/OUT & WORD SYNC)
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
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
      builder: (ctx, val, child) {
        return Opacity(
          opacity: val,
          child: Transform.scale(
            scale: 0.92 + (val * 0.08),
            child: child,
          ),
        );
      },
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: List.generate(sentence.words.length, (i) {
          final passed = activeWord > i;
          final current = i == activeWord;
          Color col = passed ? Colors.greenAccent : (current ? Colors.green : Colors.white70);
          return AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: EdgeInsets.symmetric(horizontal: current ? 8 : 2, vertical: current ? 4 : 2),
            decoration: current
                ? BoxDecoration(
                    color: Colors.green.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.greenAccent),
                  )
                : null,
            child: Text(
              sentence.words[i].word,
              style: TextStyle(
                color: col,
                fontSize: current ? 17 : 14,
                fontWeight: passed || current ? FontWeight.bold : FontWeight.w500,
                shadows: current ? [const Shadow(color: Colors.black, blurRadius: 6)] : null,
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ==========================================
// MUSIC CONTROLLER
// ==========================================
class MusicController extends ChangeNotifier {
  final ja.AudioPlayer audioPlayer = ja.AudioPlayer();
  final PlayerController waveformController = PlayerController();

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

  bool get usePreTrim => trimStart > Duration.zero || trimEnd < duration;

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

  // UPLOAD MUSIK (MP3 ATAU WAV)
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
      lyricSentences = []; // Reset lirik saat ganti lagu
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
      errorMessage = '✅ Musik siap diputar';
      notifyListeners();
    } catch (e) {
      errorMessage = 'Gagal upload file: $e';
      isLoading = false;
      notifyListeners();
    }
  }

  // DIALOG PASTE LIRIK & SYNC OTOMATIS (CACHED)
    // DIALOG PASTE LIRIK (SUPPORT TEKS BIASA & FORMAT TIMESTAMP LRC)
  Future<void> openTranscribeDialog(BuildContext context) async {
    if (selectedMusicFile == null) {
      errorMessage = 'Upload musik (MP3/WAV) terlebih dahulu!';
      notifyListeners();
      return;
    }

    final controller = TextEditingController();
    final res = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E24),
        title: const Text(
          '📝 Transcribe / Upload LRC Timestamp',
          style: TextStyle(color: Colors.amber, fontSize: 13, fontWeight: FontWeight.bold),
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 280,
          child: TextField(
            controller: controller,
            maxLines: 15,
            style: const TextStyle(color: Colors.white, fontSize: 12),
            decoration: const InputDecoration(
              hintText: 'Tempel lirik biasa ATAU format .lrc bertimestamp:\n\nContoh LRC:\n[00:12.50] Biar saja ku tak sehebat matahari\n[00:18.20] Tapi slaluku coba tuk menghangatkanmu',
              hintStyle: TextStyle(color: Colors.white24, fontSize: 11),
              border: OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black),
            child: const Text('Simpan & Sync Lirik'),
          ),
        ],
      ),
    );

    if (res != null && res.trim().isNotEmpty) {
      _processLyricsWithLrcSupport(res.trim());
    }
  }

  // PARSER OTOMATIS: MEMBEDAKAN LRC TIMESTAMP DAN TEKS BIASA
  void _processLyricsWithLrcSupport(String rawText) {
    var rawLines = rawText.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    if (rawLines.isEmpty) return;

    final lrcRegExp = RegExp(r'^\[(\d{2}):(\d{2})\.(\d{2,3})\]\s*(.*)');
    bool isLrcFormat = rawLines.any((line) => lrcRegExp.hasMatch(line));

    if (isLrcFormat) {
      // 1. PROSES FORMAT LRC (TIMESTAMP MANUAL PRESISI)
      List<TimedSentence> generatedSentences = [];
      for (int i = 0; i < rawLines.length; i++) {
        var match = lrcRegExp.firstMatch(rawLines[i]);
        if (match != null) {
          int min = int.parse(match.group(1)!);
          int sec = int.parse(match.group(2)!);
          int ms = int.parse(match.group(3)!.padRight(3, '0'));
          
          Duration start = Duration(minutes: min, seconds: sec, milliseconds: ms);
          String text = match.group(4)!.trim();

          if (text.isEmpty) continue;

          // Estimasi waktu selesai baris berdasarkan waktu mulai baris berikutnya
          Duration end = start + const Duration(seconds: 4);
          if (i + 1 < rawLines.length) {
            var nextMatch = lrcRegExp.firstMatch(rawLines[i + 1]);
            if (nextMatch != null) {
              int nMin = int.parse(nextMatch.group(1)!);
              int nSec = int.parse(nextMatch.group(2)!);
              int nMs = int.parse(nextMatch.group(3)!.padRight(3, '0'));
              end = Duration(minutes: nMin, seconds: nSec, milliseconds: nMs);
            }
          }

          var words = text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
          int wordDurationMs = (end.inMilliseconds - start.inMilliseconds) ~/ (words.length > 0 ? words.length : 1);

          List<TimedWord> timedWords = [];
          for (int j = 0; j < words.length; j++) {
            Duration wStart = start + Duration(milliseconds: j * wordDurationMs);
            Duration wEnd = wStart + Duration(milliseconds: wordDurationMs);
            timedWords.add(TimedWord(words[j], wStart, wEnd));
          }

          generatedSentences.add(TimedSentence(timedWords, start, end));
        }
      }
      lyricSentences = generatedSentences;
      errorMessage = '✅ Sync LRC presisi berhasil (${lyricSentences.length} baris tersimpan)';
    } else {
      // 2. FALLBACK KE ESTIMASI OTOMATIS JIKA HANYA TEKS BIASA
      _processAndCacheLyricsSmart(rawText);
    }

    currentLyricIndex = 0;
    notifyListeners();
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

  // OPSI 1: REC MERAH (REKAM LANGSUNG MAX 60 DETIK)
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
        titleNotification: "Babe Info REC 60s",
        messageNotification: "Recording music video...",
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

  // OPSI 2: TRIM REC KUNING (DURASI 60s MAX TERPILIH)
  Future<void> showTrimDialog(BuildContext context) async {
    if (selectedMusicFile == null || duration == Duration.zero) {
      errorMessage = 'Upload lagu dulu 📁';
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
              title: const Text('TRIM REC KUNING (MAX 1 MENIT)', style: TextStyle(color: Colors.amber, fontSize: 13, fontWeight: FontWeight.bold)),
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
                  child: const Text('Mulai Trim REC'),
                ),
              ],
            );
          },
        );
      },
    );
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

  // SHARE HASIL REKAMAN KE WHATSAPP
  Future<void> shareToWhatsApp(BuildContext context) async {
    if (recordedPath == null || !File(recordedPath!).existsSync()) {
      errorMessage = 'Belum ada rekaman untuk dibagikan!';
      notifyListeners();
      return;
    }
    try {
      await Share.shareXFiles(
        [XFile(recordedPath!)],
        text: 'Sponsor Babe Info Gawat - ${lyricSentences.isNotEmpty ? "Lagu + Sync Lirik" : "Video Musik 1 Menit"}',
      );
    } catch (e) {
      errorMessage = 'Gagal share WhatsApp: $e';
      notifyListeners();
    }
  }

  Future<void> showPostRecordDialog(BuildContext context) async {
    if (recordedPath == null || !File(recordedPath!).existsSync()) return;

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E24),
        title: const Text('🎬 Rekaman Selesai', style: TextStyle(color: Colors.amber, fontSize: 14, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              lyricSentences.isNotEmpty ? 'Video Sync Lirik 1 Menit Berhasil Direkam!' : 'Video Musik Tanpa Lirik Berhasil Direkam!',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(height: 10),
            Text('Durasi: ${recordSeconds} detik', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Tutup', style: TextStyle(color: Colors.white54))),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF25D366), foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              shareToWhatsApp(context);
            },
            icon: const Icon(Icons.share, size: 16),
            label: const Text('Share WhatsApp'),
          ),
        ],
      ),
    );
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
// MUSIC PLAYER BAR
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
// MUSIC PANEL UI
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
                      onPressed: () => ctrl.openTranscribeDialog(context),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 10)),
                      icon: const Icon(Icons.subtitles, size: 16),
                      label: const Text('Transcribe + Sync Lirik', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
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
                              lyricExpanded ? 'SYNC LIRIK KARAOKE - TAP UNTUK LIPAT' : 'KARAOKE: ${currentSentence?.text ?? ''}',
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
                                  ? const Text('Belum ada sync lirik (Klik Transcribe)', style: TextStyle(color: Colors.white24, fontSize: 11))
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
            ],
          );
        },
      ),
    );
  }
}
