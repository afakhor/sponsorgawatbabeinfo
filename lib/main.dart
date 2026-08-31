import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'globes/globe.dart';
import 'music/music.dart';

void main() { 
  WidgetsFlutterBinding.ensureInitialized(); 
  runApp(const SponsorBabeApp()); 
}

class SponsorBabeApp extends StatelessWidget {
  const SponsorBabeApp({super.key});
  
  @override 
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false, 
      title: 'Sponsor Babe', 
      theme: ThemeData(
        brightness: Brightness.dark, 
        scaffoldBackgroundColor: Colors.black, 
        useMaterial3: true,
      ), 
      home: const SponsorBabePage(),
    );
  }
}

class SponsorBabePage extends StatefulWidget {
  const SponsorBabePage({super.key});
  
  @override 
  State<SponsorBabePage> createState() => _SponsorBabePageState();
}

class _SponsorBabePageState extends State<SponsorBabePage> with SingleTickerProviderStateMixin {
  ui.FragmentProgram? fragmentProgram;
  ui.Image? textTexture;
  late final Ticker ticker;
  late final MusicController musicController;
  final DraggableScrollableController sheetController = DraggableScrollableController();
  double time = 0.0;
  Duration? prev;
  String? error;

  @override 
  void initState() {
    super.initState();
    musicController = MusicController();
    musicController.addListener(() => setState(() {}));
    ticker = createTicker((elapsed) {
      if (prev == null) { prev = elapsed; return; }
      final diff = elapsed - prev!;
      prev = elapsed;
      final delta = (diff.inMicroseconds / 1000000.0).clamp(0.0, 0.05);
      if (mounted) setState(() => time += delta);
    })..start();
    _load();
  }

  Future<void> _load() async {
    try {
      final prog = await ui.FragmentProgram.fromAsset('shaders/globe.frag');
      final data = await rootBundle.load('assets/images/babe_info.png');
      final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      codec.dispose();
      if (!mounted) { frame.image.dispose(); return; }
      setState(() { fragmentProgram = prog; textTexture = frame.image; });
    } catch (e) { 
      setState(() => error = e.toString()); 
    }
  }

  @override 
  void dispose() { 
    ticker.dispose(); 
    textTexture?.dispose(); 
    musicController.dispose(); 
    sheetController.dispose(); 
    super.dispose(); 
  }

  @override 
  Widget build(BuildContext context) {
    if (error != null) {
      return Scaffold(
        backgroundColor: Colors.black, 
        body: Center(
          child: Text('Error:\n$error', style: const TextStyle(color: Colors.redAccent)),
        ),
      );
    }
    
    if (fragmentProgram == null || textTexture == null) {
      return const Scaffold(
        backgroundColor: Colors.black, 
        body: Center(child: CircularProgressIndicator(color: Color(0xFFFFD21F))),
      );
    }

    final isRec = musicController.isRecording;
    
    return PopScope(
      canPop: !isRec,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (isRec) await musicController.cancelRecord();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // GLOBE - RASIO 3:1 KETIKA NORMAL, FULL KETIKA REC
            Positioned.fill(
              child: GlobeShaderWidget(
                program: fragmentProgram!, 
                textTexture: textTexture!, 
                time: time,
              ),
            ),

            // RECORDING OVERLAY - CUMA GLOBE + 2 RUNNING + LIRIK
            if (isRec) ...[
              Positioned(
                top: 0, left: 0, right: 0, 
                child: SafeArea(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), 
                    color: Colors.black.withOpacity(0.7), 
                    child: RunningText(
                      text: musicController.editableTitle, 
                      color: Colors.amber, 
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 12, right: 12, bottom: 130, 
                child: Container(
                  padding: const EdgeInsets.all(14), 
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6), 
                    borderRadius: BorderRadius.circular(14), 
                    border: Border.all(color: Colors.amber.withOpacity(0.4)),
                  ), 
                  child: Text(
                    musicController.lyricLines.isNotEmpty ? musicController.lyricLines[musicController.currentLyricIndex] : '', 
                    textAlign: TextAlign.center, 
                    style: const TextStyle(
                      color: Colors.amber, 
                      fontSize: 20, 
                      fontWeight: FontWeight.w900, 
                      shadows: [Shadow(color: Colors.black, blurRadius: 10)],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0, right: 0, bottom: 90, 
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), 
                  color: Colors.black.withOpacity(0.7), 
                  child: RunningText(
                    text: musicController.editableBottomTitle, 
                    color: Colors.white70, 
                    fontSize: 14,
                  ),
                ),
              ),
              Positioned(
                left: 0, right: 0, bottom: 18, 
                child: Center(
                  child: GestureDetector(
                    onTap: () async {
                      await musicController.stopRecord();
                      if (!mounted) return;
                      if (!musicController.usePreTrim && musicController.recordedPath != null) {
                        await musicController.showPostRecordDialog(context);
                      }
                    },
                    child: Container(
                      width: 78, height: 78, 
                      decoration: BoxDecoration(
                        color: Colors.red, 
                        shape: BoxShape.circle, 
                        border: Border.all(color: Colors.white, width: 5), 
                        boxShadow: [BoxShadow(color: Colors.red.withOpacity(0.7), blurRadius: 25)],
                      ), 
                      child: Center(
                        child: Text(
                          '${musicController.recordSeconds}s', 
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 56, right: 12, 
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), 
                  decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(20)), 
                  child: Row(
                    children: [
                      Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)), 
                      const SizedBox(width: 6), 
                      Text(
                        '${musicController.recordSeconds}s / 60s', 
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            // NORMAL PANEL - 3:1 RATIO
            if (!isRec) 
              DraggableScrollableSheet(
                controller: sheetController,
                initialChildSize: 0.28,
                minChildSize: 0.18,
                maxChildSize: 0.85,
                snap: true,
                snapSizes: const [0.18, 0.28, 0.85],
                builder: (ctx, scrollCtrl) => Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFF0F0F14), 
                    borderRadius: BorderRadius.vertical(top: Radius.circular(22)), 
                    border: Border(top: BorderSide(color: Colors.white12)),
                  ),
                  child: MusicPanel(
                    controller: musicController, 
                    scrollController: scrollCtrl, 
                    sheetController: sheetController,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
