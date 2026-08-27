import 'dart:typed_data';
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
  @override Widget build(BuildContext context) {
    return MaterialApp(debugShowCheckedModeBanner: false, title: 'Sponsor Babe', theme: ThemeData(brightness: Brightness.dark, scaffoldBackgroundColor: Colors.black, useMaterial3: true), home: const SponsorBabePage());
  }
}

class SponsorBabePage extends StatefulWidget {
  const SponsorBabePage({super.key});
  @override State<SponsorBabePage> createState() => _SponsorBabePageState();
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

  @override void initState() {
    super.initState();
    musicController = MusicController();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    ticker = createTicker((elapsed) {
      if (prev == null) { prev = elapsed; return; }
      final d = (elapsed - prev!).inMicroseconds / 1000000.0;
      prev = elapsed;
      if (mounted) setState(() => time += d.clamp(0.0, 0.05));
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
    } catch (e) { setState(() => error = e.toString()); }
  }

  @override void dispose() { ticker.dispose(); textTexture?.dispose(); musicController.dispose(); sheetController.dispose(); super.dispose(); }

  @override Widget build(BuildContext context) {
    if (error != null) return Scaffold(backgroundColor: Colors.black, body: Center(child: Text(error!, style: const TextStyle(color: Colors.redAccent))));
    if (fragmentProgram == null || textTexture == null) return const Scaffold(backgroundColor: Colors.black, body: Center(child: CircularProgressIndicator(color: Color(0xFFFFD21F))));
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [
        Positioned.fill(child: GlobeShaderWidget(program: fragmentProgram!, textTexture: textTexture!, time: time)),
        DraggableScrollableSheet(
          controller: sheetController,
          initialChildSize: 0.34,
          minChildSize: 0.22,
          maxChildSize: 0.82,
          snap: true,
          snapSizes: const [0.22, 0.34, 0.82],
          builder: (ctx, scrollCtrl) => Container(
            decoration: const BoxDecoration(color: Color(0xFF0F0F14), borderRadius: BorderRadius.vertical(top: Radius.circular(22)), border: Border(top: BorderSide(color: Colors.white12))),
            child: MusicPanel(controller: musicController, scrollController: scrollCtrl, sheetController: sheetController),
          ),
        ),
      ]),
    );
  }
}