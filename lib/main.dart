import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import 'globes/globe.dart';

void main() {
  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: SponsorBabePage(),
    ),
  );
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

  double time = 0.0;
  Duration? previousElapsed;
  String? errorMessage;

  @override
  void initState() {
    super.initState();

    // Membuat area aplikasi dapat menggunakan seluruh layar,
    // tetapi SafeArea di bawah akan melindungi globe dari status bar.
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
    );

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.black,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );

    ticker = createTicker(
      (Duration elapsed) {
        if (previousElapsed == null) {
          previousElapsed = elapsed;
          return;
        }

        final double delta =
            (elapsed - previousElapsed!).inMicroseconds /
            1000000.0;

        previousElapsed = elapsed;

        if (!mounted) {
          return;
        }

        setState(() {
          time += delta.clamp(
            0.0,
            0.05,
          );
        });
      },
    );

    ticker.start();
    _loadResources();
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
    } catch (error) {
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
        await DefaultAssetBundle.of(context).load(
      assetPath,
    );

    final Uint8List bytes =
        data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );

    final ui.Codec codec =
        await ui.instantiateImageCodec(
      bytes,
    );

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
    super.dispose();
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    final ui.FragmentProgram? program =
        fragmentProgram;

    final ui.Image? texture =
        textTexture;

    // Tampilan jika shader atau texture gagal dimuat.
    if (errorMessage != null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(
                24.0,
              ),
              child: Text(
                'Gagal memuat shader atau texture:\n\n'
                '$errorMessage',
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

    // Tampilan loading.
    if (program == null || texture == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Center(
            child: CircularProgressIndicator(
              color: Color(
                0xFFFFD21F,
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,

      // SafeArea membuat isi dimulai di bawah status bar.
      body: SafeArea(
        top: true,
        bottom: false,
        child: Column(
          children: [
            // =========================================
            // AREA GLOBE
            // =========================================
            Expanded(
              flex: 4,
              child: SizedBox(
                width: double.infinity,
                child: Align(
                  alignment: Alignment.topCenter,
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

            // =========================================
            // AREA BAWAH
            // =========================================
            const Expanded(
              flex: 1,
              child: SizedBox(),
            ),
          ],
        ),
      ),
    );
  }
}
