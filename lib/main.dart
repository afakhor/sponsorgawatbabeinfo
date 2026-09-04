import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

import 'globes/globe.dart';
import 'music/music.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Wajib dipanggil sebelum menggunakan sherpa_onnx.
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
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Sponsor Babe',
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.transparent,
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

class _SponsorBabePageState extends State<SponsorBabePage>
    with SingleTickerProviderStateMixin {
  ui.FragmentProgram? _fragmentProgram;
  ui.Image? _textTexture;
  ui.Image? _backgroundTexture;


  late final Ticker _ticker;
  late final MusicController _musicController;

  final DraggableScrollableController _sheetController =
      DraggableScrollableController();

  Duration? _previousElapsed;
  double _time = 0.0;

  String? _error;

// Mencegah dialog share tampil dua kali.
bool _postRecordDialogShowing = false;

// Menyimpan status rekaman sebelumnya.
// Dialog hanya muncul ketika status berubah
// dari true menjadi false.
bool _wasRecording = false;


  @override
void initState() {
  super.initState();

  _musicController = MusicController();

  _musicController.addListener(
    _handleRecordingFinished,
  );

  _ticker = createTicker(
    _onTick,
  )..start();

  _loadShaderAndTexture();
}


  // ==================================================
  // DETEKSI REKAMAN SELESAI
  // ==================================================

  void _handleRecordingFinished() {
  if (!mounted) {
    return;
  }

  final bool currentlyRecording =
      _musicController.isRecording;

  // Selama masih merekam, simpan status true.
  if (currentlyRecording) {
    _wasRecording = true;
    return;
  }

  // Tidak ada perubahan true -> false.
  // Mencegah dialog muncul berulang kali
  // setiap notifyListeners().
  if (!_wasRecording) {
    return;
  }

  _wasRecording = false;

  final String? path =
      _musicController.recordedPath;

  if (path == null ||
      path.isEmpty ||
      !File(path).existsSync()) {
    return;
  }

  if (_postRecordDialogShowing) {
    return;
  }

  _postRecordDialogShowing = true;

  WidgetsBinding.instance.addPostFrameCallback(
    (_) async {
      if (!mounted) {
        _postRecordDialogShowing = false;
        return;
      }

      try {
        await _musicController.showPostRecordDialog(
          context,
        );
      } finally {
        _postRecordDialogShowing = false;
      }
    },
  );
}

  // ==================================================
  // TICKER
  // ==================================================

  void _onTick(Duration elapsed) {
    if (!mounted) {
      return;
    }

    if (_previousElapsed == null) {
      _previousElapsed = elapsed;
      return;
    }

    final Duration difference =
        elapsed - _previousElapsed!;

    _previousElapsed = elapsed;

    double delta =
        difference.inMicroseconds /
        Duration.microsecondsPerSecond;

    if (!delta.isFinite || delta < 0.0) {
      delta = 0.0;
    }

    // Membatasi lonjakan waktu setelah aplikasi kembali
    // dari background.
    delta = delta.clamp(
      0.0,
      0.05,
    );

    setState(() {
      _time += delta;
    });
  }

// ==================================================
  // HELPER LOAD GAMBAR
  // ==================================================
Future<ui.Image> _loadAssetImage(
  String assetPath,
) async {
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


  // ==================================================
  // LOAD SHADER DAN TEXTURE
  // ==================================================

  Future<void> _loadShaderAndTexture() async {
    ui.Image? loadedImage;

    try {
      final ui.FragmentProgram loadedProgram =
          await ui.FragmentProgram.fromAsset(
        'shaders/globe.frag',
      );

      final ByteData data = await rootBundle.load(
        'assets/images/babe_info.png',
      );

      final Uint8List bytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );

      final ui.Codec codec =
          await ui.instantiateImageCodec(bytes);

      try {
        final ui.FrameInfo frame =
            await codec.getNextFrame();

        loadedImage = frame.image;
      } finally {
        codec.dispose();
      }

      if (!mounted) {
        loadedImage?.dispose();
        return;
      }

      setState(() {
        _fragmentProgram = loadedProgram;
        _textTexture = loadedImage;
        loadedImage = null;
      });
    } catch (e) {
      loadedImage?.dispose();

      if (!mounted) {
        return;
      }

      setState(() {
        _error = e.toString();
      });
    }
  }

  // ==================================================
  // LIRIK AKTIF
  // ==================================================

  String _currentLyricText() {
    final List<String> lines =
        _musicController.lyricLines;

    final int index =
        _musicController.currentLyricIndex;

    if (lines.isEmpty ||
        index < 0 ||
        index >= lines.length) {
      return '';
    }

    return lines[index];
  }

  // ==================================================
  // DISPOSE
  // ==================================================

  @override
void dispose() {
  _ticker.dispose();

  _musicController.removeListener(
    _handleRecordingFinished,
  );

  _textTexture?.dispose();

  _musicController.dispose();

  _sheetController.dispose();

  super.dispose();
}


  // ==================================================
  // BUILD
  // ==================================================

  @override
  Widget build(BuildContext context) {
    final ui.FragmentProgram? program =
        _fragmentProgram;

    final ui.Image? texture =
        _textTexture;

    if (program == null || texture == null) {
      return _buildLoadingScreen();
    }

    return AnimatedBuilder(
      animation: _musicController,
      builder: (
        BuildContext context,
        Widget? child,
      ) {
        final bool isRecording =
            _musicController.isRecording;

        return PopScope(
          canPop: !isRecording,
          onPopInvokedWithResult: (
            bool didPop,
            Object? result,
          ) async {
            if (!didPop &&
                _musicController.isRecording) {
              await _musicController.cancelRecord();
            }
          },
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: Stack(
              fit: StackFit.expand,
              children: [
                // ==================================================
                // BACKGROUND PALING BAWAH
                // ==================================================

                Positioned.fill(
                  child: Image.asset(
                    'assets/images/bg.png',
                    fit: BoxFit.cover,
                    alignment: Alignment.center,
                    filterQuality: FilterQuality.high,
                  ),
                ),

                // ==================================================
                // SHADER GLOBE DI ATAS BACKGROUND
                // ==================================================

                Positioned.fill(
                  child: GlobeShaderWidget(
                    program: program,
                    textTexture: texture,
                    time: _time,
                    beatPulse:
                        _musicController.beatPulse,
                  ),
                ),

                // ==================================================
                // OVERLAY RECORDING ATAU MUSIC SHEET
                // ==================================================

                if (isRecording)
                  _buildRecordingOverlay()
                else
                  _buildMusicSheet(),
              ],
            ),
          ),
        );
      },
    );
  }

  // ==================================================
  // LOADING SCREEN
  // ==================================================

  Widget _buildLoadingScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFF050509),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/bg.png',
            fit: BoxFit.cover,
            filterQuality: FilterQuality.high,
          ),
          Center(
            child: _error != null
                ? Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Shader gagal dimuat:\n\n$_error',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 13,
                      ),
                    ),
                  )
                : const CircularProgressIndicator(
                    color: Color(0xFFFFD21F),
                  ),
          ),
        ],
      ),
    );
  }

  // ==================================================
  // MUSIC SHEET
  // ==================================================

  Widget _buildMusicSheet() {
    return DraggableScrollableSheet(
      controller: _sheetController,
      initialChildSize: 0.28,
      minChildSize: 0.18,
      maxChildSize: 0.85,
      snap: true,
      snapSizes: const <double>[
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
            color: Colors.black.withOpacity(0.72),
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(22),
            ),
            border: const Border(
              top: BorderSide(
                color: Colors.white12,
              ),
            ),
          ),
          child: MusicPanel(
            controller: _musicController,
            scrollController: scrollController,
            sheetController: _sheetController,
          ),
        );
      },
    );
  }

  // ==================================================
  // RECORDING OVERLAY
  // ==================================================

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
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            color: Colors.black.withOpacity(0.70),
            child: RunningText(
              text: _musicController.editableTitle,
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
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.60),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Colors.amber.withOpacity(0.40),
            ),
          ),
          child: Text(
            _currentLyricText(),
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.amber,
              fontSize: 20,
              fontWeight: FontWeight.w900,
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
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
          color: Colors.black.withOpacity(0.70),
          child: RunningText(
            text: _musicController.editableBottomTitle,
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
            onTap: _musicController.isRecording
                ? () async {
                    await _musicController.stopRecord();
                  }
                : null,
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
                    color: Colors.red.withOpacity(0.70),
                    blurRadius: 25,
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  '${_musicController.recordSeconds}s',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),

      // Status rekaman.
      Positioned(
        top: 56,
        right: 12,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            color: Colors.red,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '${_musicController.recordSeconds}s / 60s',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
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
