import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart'
    as sherpa;

import 'globes/globe.dart';
import 'music/music.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Wajib sebelum menggunakan sherpa_onnx.
  sherpa.initBindings();

  runApp(
    const SponsorBabeApp(),
  );
}

class SponsorBabeApp extends StatelessWidget {
  const SponsorBabeApp({
    super.key,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Sponsor Babe',
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        scaffoldBackgroundColor:
            Colors.transparent,
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

  final DraggableScrollableController
      sheetController =
      DraggableScrollableController();

  double time = 0.0;
  Duration? previousElapsed;
  String? error;

  @override
  void initState() {
    super.initState();

    musicController =
        MusicController();

    musicController.addListener(
      _onMusicChanged,
    );

    ticker = createTicker(
      _onTick,
    )..start();

    _loadShaderAndTexture();
  }

  // ==========================================
  // LISTENER MUSIC CONTROLLER
  // ==========================================

  void _onMusicChanged() {
    if (!mounted) {
      return;
    }

    setState(() {});
  }

  // ==========================================
  // ANIMATION TIME SHADER
  // ==========================================

  void _onTick(
    Duration elapsed,
  ) {
    if (!mounted) {
      return;
    }

    if (previousElapsed == null) {
      previousElapsed = elapsed;
      return;
    }

    final Duration difference =
        elapsed -
        previousElapsed!;

    previousElapsed = elapsed;

    final double delta =
        (difference.inMicroseconds /
                Duration.microsecondsPerSecond)
            .clamp(0.0, 0.05);

    setState(() {
      time += delta;
    });
  }

  // ==========================================
  // LOAD SHADER DAN TEXTURE
  // ==========================================

  Future<void> _loadShaderAndTexture() async {
    try {
      final ui.FragmentProgram program =
          await ui.FragmentProgram.fromAsset(
        'shaders/globe.frag',
      );

      final ByteData data =
          await rootBundle.load(
        'assets/images/babe_info.png',
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

      final ui.FrameInfo frame =
          await codec.getNextFrame();

      codec.dispose();

      if (!mounted) {
        frame.image.dispose();
        return;
      }

      setState(() {
        fragmentProgram = program;
        textTexture = frame.image;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        error = e.toString();
      });
    }
  }

  // ==========================================
  // LIRIK AKTIF YANG AMAN
  // ==========================================

  String _currentLyricText() {
    final List<String> lines =
        musicController.lyricLines;

    final int index =
        musicController.currentLyricIndex;

    if (lines.isEmpty) {
      return '';
    }

    if (index < 0 ||
        index >= lines.length) {
      return '';
    }

    return lines[index];
  }

  // ==========================================
  // DISPOSE
  // ==========================================

  @override
  void dispose() {
    musicController.removeListener(
      _onMusicChanged,
    );

    ticker.dispose();

    textTexture?.dispose();

    musicController.dispose();

    sheetController.dispose();

    super.dispose();
  }

  // ==========================================
  // BUILD
  // ==========================================

  @override
  Widget build(
    BuildContext context,
  ) {
    final bool shaderReady =
        fragmentProgram != null &&
            textTexture != null;

    if (!shaderReady) {
      return _buildLoadingScreen();
    }

    final bool isRecording =
        musicController.isRecording;

    return PopScope(
      canPop: !isRecording,
      onPopInvokedWithResult: (
        bool didPop,
        Object? result,
      ) async {
        if (didPop) {
          return;
        }

        if (musicController.isRecording) {
          await musicController.cancelRecord();
        }
      },
      child: Scaffold(
        // Scaffold transparan supaya bg.png terlihat.
        backgroundColor: Colors.transparent,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // ==========================================
            // BACKGROUND PALING BELAKANG
            // ==========================================

            Positioned.fill(
              child: Image.asset(
                'assets/images/bg.png',
                fit: BoxFit.cover,
                alignment: Alignment.center,
              ),
            ),

            // ==========================================
            // GLOBE DI ATAS BACKGROUND
            // ==========================================

            Positioned.fill(
              child: GlobeShaderWidget(
                program: fragmentProgram!,
                textTexture: textTexture!,
                time: time,

                // Beat hanya memengaruhi wave,
                // atmosfer, plasma, atau buih.
                beatPulse:
                    musicController.beatPulse,
              ),
            ),

            // ==========================================
            // MODE RECORDING
            // ==========================================

            if (isRecording)
              _buildRecordingOverlay(),

            // ==========================================
            // PANEL NORMAL
            // ==========================================

            if (!isRecording)
              _buildMusicSheet(),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // LOADING / ERROR SCREEN
  // ==========================================

  Widget _buildLoadingScreen() {
    return Scaffold(
      // Fallback gelap hanya ketika shader belum selesai
      // dimuat. Tidak memengaruhi layar utama.
      backgroundColor: const Color(0xFF050509),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/bg.png',
            fit: BoxFit.cover,
          ),
          Center(
            child: error != null
                ? Padding(
                    padding:
                        const EdgeInsets.all(24),
                    child: Text(
                      'Error:\n$error',
                      textAlign:
                          TextAlign.center,
                      style:
                          const TextStyle(
                        color:
                            Colors.redAccent,
                        fontSize: 13,
                      ),
                    ),
                  )
                : const CircularProgressIndicator(
                    color:
                        Color(0xFFFFD21F),
                  ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // MUSIC SHEET
  // ==========================================

  Widget _buildMusicSheet() {
    return DraggableScrollableSheet(
      controller: sheetController,
      initialChildSize: 0.28,
      minChildSize: 0.18,
      maxChildSize: 0.85,
      snap: true,
      snapSizes: const [
        0.18,
        0.28,
        0.85,
      ],
      builder: (
        BuildContext context,
        ScrollController scrollController,
      ) {
        return Container(
          decoration: BoxDecoration(
            // Gunakan opacity agar bg/glow di belakang
            // tidak terasa tertutup warna hitam pekat.
            color: Colors.black.withOpacity(0.72),
            borderRadius:
                const BorderRadius.vertical(
              top: Radius.circular(22),
            ),
            border: const Border(
              top: BorderSide(
                color: Colors.white12,
              ),
            ),
          ),
          child: MusicPanel(
            controller: musicController,
            scrollController:
                scrollController,
            sheetController: sheetController,
          ),
        );
      },
    );
  }

  // ==========================================
  // RECORDING OVERLAY
  // ==========================================

  Widget _buildRecordingOverlay() {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Running text atas.
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              color:
                  Colors.black.withOpacity(0.70),
              child: RunningText(
                text: musicController
                    .editableTitle,
                color: Colors.amber,
                fontSize: 16,
              ),
            ),
          ),
        ),

        // Lirik aktif.
        Positioned(
          left: 12,
          right: 12,
          bottom: 130,
          child: Container(
            padding:
                const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color:
                  Colors.black.withOpacity(0.60),
              borderRadius:
                  BorderRadius.circular(14),
              border: Border.all(
                color: Colors.amber
                    .withOpacity(0.40),
              ),
            ),
            child: Text(
              _currentLyricText(),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow:
                  TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.amber,
                fontSize: 20,
                fontWeight:
                    FontWeight.w900,
                shadows: [
                  Shadow(
                    color: Colors.black,
                    blurRadius: 10,
                  ),
                ],
              ),
            ),
          ),
        ),

        // Running text bawah.
        Positioned(
          left: 0,
          right: 0,
          bottom: 90,
          child: Container(
            padding:
                const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            color:
                Colors.black.withOpacity(0.70),
            child: RunningText(
              text: musicController
                  .editableBottomTitle,
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
        ),

        // Tombol stop recording.
        Positioned(
          left: 0,
          right: 0,
          bottom: 18,
          child: Center(
            child: GestureDetector(
              onTap: () async {
                await musicController
                    .stopRecord();

                if (!mounted) {
                  return;
                }

                if (!musicController
                        .usePreTrim &&
                    musicController
                            .recordedPath !=
                        null) {
                  await musicController
                      .showPostRecordDialog(
                    context,
                  );
                }
              },
              child: Container(
                width: 78,
                height: 78,
                decoration: BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white,
                    width: 5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red
                          .withOpacity(0.70),
                      blurRadius: 25,
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    '${musicController.recordSeconds}s',
                    style:
                        const TextStyle(
                      color: Colors.white,
                      fontWeight:
                          FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),

        // Status waktu recording.
        Positioned(
          top: 56,
          right: 12,
          child: Container(
            padding:
                const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius:
                  BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize:
                  MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration:
                      const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '${musicController.recordSeconds}s / 60s',
                  style:
                      const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
