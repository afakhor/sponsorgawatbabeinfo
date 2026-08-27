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
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Sponsor Babe',
      theme: ThemeData(brightness: Brightness.dark, scaffoldBackgroundColor: Colors.black, useMaterial3: true),
      home: const SponsorBabePage(),
    );
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
  double time = 0.0;
  Duration? previousElapsed;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    musicController = MusicController();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(statusBarColor: Colors.transparent, systemNavigationBarColor: Colors.black, statusBarIconBrightness: Brightness.light, systemNavigationBarIconBrightness: Brightness.light));
    ticker = createTicker(_onTick);
    ticker.start();
    _loadResources();
  }

  void _onTick(Duration elapsed) {
    if (previousElapsed == null) { previousElapsed = elapsed; return; }
    final diff = elapsed - previousElapsed!;
    previousElapsed = elapsed;
    final delta = diff.inMicroseconds / 1000000.0;
    if (!mounted) return;
    setState(() { time += delta.clamp(0.0, 0.05).toDouble(); });
  }

  Future<void> _loadResources() async {
    try {
      final program = await ui.FragmentProgram.fromAsset('shaders/globe.frag');
      final texture = await _loadTextTexture();
      if (!mounted) { texture.dispose(); return; }
      setState(() { fragmentProgram = program; textTexture = texture; });
    } catch (e, st) {
      debugPrint('Resource error: $e'); debugPrintStack(stackTrace: st);
      if (!mounted) return;
      setState(() { errorMessage = e.toString(); });
    }
  }

  Future<ui.Image> _loadTextTexture() async {
    final data = await rootBundle.load('assets/images/babe_info.png');
    final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    final codec = await ui.instantiateImageCodec(bytes);
    try { final frame = await codec.getNextFrame(); return frame.image; } finally { codec.dispose(); }
  }

  @override
  void dispose() { ticker.dispose(); textTexture?.dispose(); musicController.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final program = fragmentProgram;
    final texture = textTexture;
    if (errorMessage != null) return _buildErrorPage();
    if (program == null || texture == null) return _buildLoadingPage();

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        top: true,
        bottom: false,
        child: Column(
          children: [
            // GLOBE - sekarang cuma 40% layar
            Expanded(
              flex: 5,
              child: SizedBox.expand(
                child: GlobeShaderWidget(program: program, textTexture: texture, time: time),
              ),
            ),
            // MUSIC - sekarang 60% layar, cukup untuk semua kontrol
            Expanded(
              flex: 2,
              child: Container(
                width: double.infinity,
                color: const Color(0xFF080811),
                child: MusicPanel(controller: musicController),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingPage() => const Scaffold(backgroundColor: Colors.black, body: Center(child: CircularProgressIndicator(color: Color(0xFFFFD21F))));
  Widget _buildErrorPage() => Scaffold(backgroundColor: Colors.black, body: Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('Gagal memuat globe:\n\n$errorMessage', textAlign: TextAlign.center, style: const TextStyle(color: Colors.redAccent, fontSize: 14)))));
}