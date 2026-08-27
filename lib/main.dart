import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import 'globes/globe.dart';
import 'music/music.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    const SponsorBabeApp(),
  );
}

class SponsorBabeApp extends StatelessWidget {
  const SponsorBabeApp({
    super.key,
  });

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
  const SponsorBabePage({
    super.key,
  });

  @override
  State<SponsorBabePage> createState() {
    return _SponsorBabePageState();
  }
}

class _SponsorBabePageState
    extends State<SponsorBabePage>
    with SingleTickerProviderStateMixin {
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

    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
    );

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.black,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarIconBrightness:
            Brightness.light,
      ),
    );

    ticker = createTicker(
      _onTick,
    );

    ticker.start();

    _loadResources();
  }

  void _onTick(Duration elapsed) {
    if (previousElapsed == null) {
      previousElapsed = elapsed;
      return;
    }

    final Duration difference =
        elapsed - previousElapsed!;

    previousElapsed = elapsed;

    final double delta =
        difference.inMicroseconds / 1000000.0;

    if (!mounted) {
      return;
    }

    setState(() {
      time += delta.clamp(0.0, 0.05).toDouble();
    });
  }

  Future<void> _loadResources() async {
    try {
      final ui.FragmentProgram program =
          await ui.FragmentProgram.fromAsset(
        'shaders/globe.frag',
      );

      final ui.Image texture =
          await _loadTextTexture();

      if (!mounted) {
        texture.dispose();
        return;
      }

      setState(() {
        fragmentProgram = program;
        textTexture = texture;
      });
    } catch (error, stackTrace) {
      debugPrint(
        'Resource loading error: $error',
      );

      debugPrintStack(
        stackTrace: stackTrace,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        errorMessage = error.toString();
      });
    }
  }

  Future<ui.Image> _loadTextTexture() async {
    const String assetPath =
        'assets/images/babe_info.png';

    final ByteData data =
        await rootBundle.load(assetPath);

    final Uint8List bytes =
        data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );

    final ui.Codec codec =
        await ui.instantiateImageCodec(bytes);

    try {
      final ui.FrameInfo frame =
          await codec.getNextFrame();

      return frame.image;
    } finally {
      codec.dispose();
    }
  }

  @override
  void dispose() {
    ticker.dispose();
    textTexture?.dispose();
    musicController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ui.FragmentProgram? program =
        fragmentProgram;

    final ui.Image? texture =
        textTexture;

    if (errorMessage != null) {
      return _buildErrorPage();
    }

    if (program == null || texture == null) {
      return _buildLoadingPage();
    }

    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        top: true,
        bottom: false,
        child: Column(
          children: [
            // Area globe.
            Expanded(
              flex: 3,
              child: SizedBox.expand(
                child: GlobeShaderWidget(
                  program: program,
                  textTexture: texture,
                  time: time,
                ),
              ),
            ),

            // Area music.
            Expanded(
              flex: 1,
              child: Container(
                width: double.infinity,
                color: const Color(0xFF080811),
                child: SingleChildScrollView(
                  physics:
                      const ClampingScrollPhysics(),
                  child: MusicPanel(
                    controller: musicController,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingPage() {
    return const Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Center(
          child: CircularProgressIndicator(
            color: Color(0xFFFFD21F),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorPage() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Text(
              'Gagal memuat globe:\n\n$errorMessage',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.redAccent,
                fontSize: 14.0,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
