import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

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

class _SponsorBabePageState extends State<SponsorBabePage>
    with SingleTickerProviderStateMixin {
  ui.FragmentProgram? fragmentProgram;
  ui.Image? textTexture;

  late final Ticker ticker;

  double time = 0.0;
  Duration? lastElapsed;

  String? errorMessage;

  @override
  void initState() {
    super.initState();

    ticker = createTicker(
      (Duration elapsed) {
        if (lastElapsed == null) {
          lastElapsed = elapsed;
          return;
        }

        final double delta =
            (elapsed - lastElapsed!).inMicroseconds / 1000000.0;

        lastElapsed = elapsed;

        if (!mounted) {
          return;
        }

        setState(() {
          // Batas delta mencegah lonjakan jika aplikasi sempat pause
          time += delta.clamp(0.0, 0.05);
        });
      },
    );

    ticker.start();
    _loadResources();
  }

  Future<void> _loadResources() async {
    try {
      final results = await Future.wait<Object>([
        ui.FragmentProgram.fromAsset(
          'shaders/globe.frag',
        ),
        _loadTextTexture(),
      ]);

      if (!mounted) {
        return;
      }

      setState(() {
        fragmentProgram = results[0] as ui.FragmentProgram;
        textTexture = results[1] as ui.Image;
      });
    } catch (error, stackTrace) {
      debugPrint('RESOURCE LOAD ERROR: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) {
        return;
      }

      setState(() {
        errorMessage = error.toString();
      });
    }
  }

  Future<ui.Image> _loadTextTexture() async {
    final ByteData data = await DefaultAssetBundle.of(context).load(
      'assets/images/babe_info.png',
    );

    final Uint8List bytes =
        data.buffer.asUint8List(
          data.offsetInBytes,
          data.lengthInBytes,
        );

    final ui.Codec codec =
        await ui.instantiateImageCodec(bytes);

    final ui.FrameInfo frame =
        await codec.getNextFrame();

    return frame.image;
  }

  @override
  void dispose() {
    ticker.dispose();

    textTexture?.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ui.FragmentProgram? program =
        fragmentProgram;

    final ui.Image? texture =
        textTexture;

    final Widget body;

    if (errorMessage != null) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text(
            'Gagal memuat shader atau texture:\n\n$errorMessage',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.redAccent,
              fontSize: 14,
            ),
          ),
        ),
      );
    } else if (program == null || texture == null) {
      body = const Center(
        child: CircularProgressIndicator(
          color: Color(0xFFFFD21F),
        ),
      );
    } else {
      body = GlobeShaderWidget(
        program: program,
        textTexture: texture,
        time: time,
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SizedBox.expand(
        child: body,
      ),
    );
  }
}
