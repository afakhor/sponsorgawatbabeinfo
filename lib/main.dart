import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'globes/globe.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 1. SET EDGE TO EDGE SEBELUM RUNAPP - INI WAJIB
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent, // biar bawah juga tembus
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: SponsorBabePage(),
    ),
  );
}

class SponsorBabePage extends StatefulWidget {
  const SponsorBabePage({super.key});
  @override
  State<SponsorBabePage> createState() => _SponsorBabePageState();
}

class _SponsorBabePageState extends State<SponsorBabePage>
    with SingleTickerProviderStateMixin {
  ui.FragmentProgram? fragmentProgram;
  ui.Image? textTexture;
  late final Ticker ticker;
  double time = 0.0;
  Duration? previousElapsed;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    ticker = createTicker((elapsed) {
      if (previousElapsed == null) {
        previousElapsed = elapsed;
        return;
      }
      final delta = (elapsed - previousElapsed!).inMicroseconds / 1000000.0;
      previousElapsed = elapsed;
      if (!mounted) return;
      setState(() => time += delta.clamp(0.0, 0.05));
    });
    ticker.start();
    _loadResources();
  }

  Future<void> _loadResources() async {
    try {
      final program = await ui.FragmentProgram.fromAsset('shaders/globe.frag');
      final texture = await _loadTextTexture();
      if (!mounted) {
        texture.dispose();
        return;
      }
      setState(() {
        fragmentProgram = program;
        textTexture = texture;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => errorMessage = e.toString());
    }
  }

  Future<ui.Image> _loadTextTexture() async {
    const assetPath = 'assets/images/babe_info.png';
    final data = await DefaultAssetBundle.of(context).load(assetPath);
    final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    final codec = await ui.instantiateImageCodec(bytes);
    try {
      final frame = await codec.getNextFrame();
      return frame.image;
    } finally {
      codec.dispose();
    }
  }

  @override
  void dispose() {
    ticker.dispose();
    textTexture?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final program = fragmentProgram;
    final texture = textTexture;

    if (errorMessage != null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Text(
                'Gagal memuat shader atau texture:\n\n$errorMessage',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.redAccent),
              ),
            ),
          ),
        ),
      );
    }

    if (program == null || texture == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Color(0xFFFFD21F))),
      );
    }

    // 2. MODE LENGKAPNYA DISINI
    return Scaffold(
      backgroundColor: Colors.black,
      extendBody: true,
      extendBodyBehindAppBar: true,
      body: Column(
        children: [
          // 3/5 ATAS - DIJAGA SAFE AREA BIAR GAK KETUTUP STATUS BAR
          Expanded(
            flex: 3,
            child: SafeArea(
              bottom: false, // bawahnya jangan di-safe-in biar nyambung
              child: Center(
                child: AspectRatio(
                  aspectRatio: 1.0,
                  child: GlobeShaderWidget(
                    program: program,
                    textTexture: texture,
                    time: time,
                  ),
                ),
              ),
            ),
          ),
          // 2/5 BAWAH KOSONG - TAPI DIJAGA BIAR GAK KETUTUP NAV BAR
          Expanded(
            flex: 2,
            child: SafeArea(
              top: false,
              left: false,
              right: false,
              bottom: true, // cuma bawah yang dijaga
              child: const SizedBox.expand(),
            ),
          ),
        ],
      ),
    );
  }
}