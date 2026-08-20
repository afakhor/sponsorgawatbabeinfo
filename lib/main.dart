import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:three_js/three_js.dart' as three;
import 'package:flutter_gl/flutter_gl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:ffmpeg_kit_flutter_new_audio/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_audio/return_code.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:device_info_plus/device_info_plus.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext c) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark(),
        home: const GlobeLearnPage(),
      );
}

class GlobeLearnPage extends StatefulWidget {
  const GlobeLearnPage({super.key});
  @override
  State<GlobeLearnPage> createState() => _GlobeLearnPageState();
}

class _GlobeLearnPageState extends State<GlobeLearnPage> with SingleTickerProviderStateMixin {
  late FlutterGlPlugin flutterGl;
  late three.WebGLRenderer renderer;
  late three.Scene scene;
  late three.PerspectiveCamera camera;
  three.Mesh? globe;
  bool inited = false;

  Ticker? _ticker;

  File? audioFile, bgFile, outVideo;
  final player = PlayerController();
  double total = 180, s = 0, e = 60;
  bool perm = false, load = false;

  @override
  void initState() {
    super.initState();
    flutterGl = FlutterGlPlugin();
    cekIzin();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        initGlobe();
      }
    });
  }

  Future<void> cekIzin() async {
    try {
      final inf = await DeviceInfoPlugin().androidInfo;
      if (inf.version.sdkInt >= 33) {
        await Permission.audio.request();
        await Permission.photos.request();
      } else {
        await Permission.storage.request();
      }
      if (mounted) setState(() => perm = true);
    } catch (_) {}
  }

  Future<void> initGlobe() async {
    await Future.delayed(const Duration(milliseconds: 600));

    try {
      if (!mounted) return;

      double dpr = MediaQuery.of(context).devicePixelRatio;
      int renderWidth = (280 * dpr).toInt();
      int renderHeight = (280 * dpr).toInt();

      Map<String, dynamic> options = {
        "antialias": true,
        "alpha": true,
        "width": renderWidth,
        "height": renderHeight,
        "dpr": dpr,
        "preserveDrawingBuffer": true,
      };

      await flutterGl.initialize(options: options);

      int retryCount = 0;
      while (flutterGl.gl == null && retryCount < 10) {
        await Future.delayed(const Duration(milliseconds: 100));
        await flutterGl.prepareContext();
        retryCount++;
      }

      if (flutterGl.textureId == null) {
        await Future.delayed(const Duration(milliseconds: 300));
      }

      if (flutterGl.textureId == null) {
        if (mounted && !inited) {
          Future.delayed(const Duration(milliseconds: 500), () => initGlobe());
        }
        return;
      }

      scene = three.Scene();
      camera = three.PerspectiveCamera(45, 1, 0.1, 1000);
      camera.position.z = 2.8;

      renderer = three.WebGLRenderer({
        "gl": flutterGl.gl,
        "antialias": true,
        "alpha": true,
        "preserveDrawingBuffer": true,
      });

      renderer.setSize(renderWidth.toDouble(), renderHeight.toDouble(), false);
      renderer.setClearColor(three.Color(0x000000), 0);

      var light = three.DirectionalLight(0xffffff, 1.2);
      light.position.setValues(5, 3, 5);
      scene.add(light);
      scene.add(three.AmbientLight(0xffffff, 0.8));

      var pointLight = three.PointLight(0xFFD700, 0.8, 10);
      pointLight.position.setValues(-3, -2, 3);
      scene.add(pointLight);

      var geo = three.SphereGeometry(1, 64, 64);
      var mat = three.MeshStandardMaterial()
        ..color = three.Color(0xFFD700)
        ..metalness = 0.75
        ..roughness = 0.28;

      globe = three.Mesh(geo, mat);
      globe!.position.y = 0.3;
      scene.add(globe!);

      var rootGeo = three.TorusGeometry(1.05, 0.02, 8, 80);
      var rootMat = three.MeshBasicMaterial()..color = three.Color(0x111111);

      for (int i = 0; i < 3; i++) {
        var torus = three.Mesh(rootGeo, rootMat);
        torus.rotation.x = i * 1.2;
        torus.rotation.y = i * 0.8;
        torus.position.y = 0.3;
        scene.add(torus);
      }

      if (mounted) {
        setState(() {
          inited = true;
        });
        startAnimation();
      }

      loadTextureSafe(mat);

    } catch (e) {
      if (mounted && !inited) {
        Future.delayed(const Duration(seconds: 1), () => initGlobe());
      }
    }
  }

  Future<void> loadTextureSafe(three.MeshStandardMaterial mat) async {
    try {
      final loader = three.TextureLoader();
      var tex = await loader.fromAsset('assets/images/babe_gold.jpg');
      if (tex != null && mounted) {
        tex.wrapS = three.RepeatWrapping;
        tex.wrapT = three.RepeatWrapping;
        tex.flipY = false;
        mat.map = tex;
        mat.needsUpdate = true;
      }
    } catch (_) {}
  }

  void startAnimation() {
    _ticker?.stop();
    _ticker?.dispose();
    _ticker = createTicker((elapsed) {
      if (!mounted || globe == null || !inited) return;
      globe!.rotation.y += 0.008;
      renderer.render(scene, camera);
      flutterGl.updateTexture(renderer.getContext());
    });
    _ticker!.start();
  }

  Future<void> pickAudio() async {
    try {
      var r = await FilePicker.platform.pickFiles(type: FileType.audio);
      if (r == null || r.files.single.path == null) return;
      File f = File(r.files.single.path!);
      await player.preparePlayer(path: f.path, shouldExtractWaveform: true, noOfSamples: 200);
      final d = await player.getDuration(DurationType.max);
      if (mounted) {
        setState(() {
          audioFile = f;
          total = (d / 1000).toDouble();
          s = 0;
          e = total > 60 ? 60 : total;
          outVideo = null;
        });
      }
    } catch (e) {
      debugPrint("Audio Pick Error: $e");
    }
  }

  Future<void> pickBg() async {
    try {
      var r = await FilePicker.platform.pickFiles(type: FileType.image);
      if (r == null || r.files.single.path == null) return;
      if (mounted) {
        setState(() {
          bgFile = File(r.files.single.path!);
          outVideo = null;
        });
      }
    } catch (e) {
      debugPrint("BG Pick Error: $e");
    }
  }

  Future<void> buatMp4() async {
    if (audioFile == null) {
      pickAudio();
      return;
    }

    setState(() {
      load = true;
      outVideo = null;
    });

    try {
      final tempDir = await getTemporaryDirectory();
      final timeStamp = DateTime.now().millisecondsSinceEpoch;

      // Copy file audio ke direktori lokal internal agar tidak kena batasan akses/izin file eksternal
      File tempAudioInput = File("${tempDir.path}/in_audio_$timeStamp.mp3");
      await tempAudioInput.writeAsBytes(await audioFile!.readAsBytes());

      String trimAudioPath = "${tempDir.path}/trim_$timeStamp.m4a";
      String outputPath = "${tempDir.path}/BABE_INFO_$timeStamp.mp4";

      double durasi = e - s;
      if (durasi <= 0) durasi = 5;

      // 1. Potong Audio
      var trimSession = await FFmpegKit.execute(
        "-y -ss $s -t $durasi -i \"${tempAudioInput.path}\" -c:a aac \"$trimAudioPath\""
      );
      
      var trimCode = await trimSession.getReturnCode();
      if (!ReturnCode.isSuccess(trimCode)) {
        if (mounted) {
          setState(() => load = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Gagal memotong audio. Silakan coba audio lain.")),
          );
        }
        return;
      }

      // 2. Siapkan Gambar Background
      String bgPath = "";
      if (bgFile != null) {
        File tempBgInput = File("${tempDir.path}/in_bg_$timeStamp.jpg");
        await tempBgInput.writeAsBytes(await bgFile!.readAsBytes());
        bgPath = tempBgInput.path;
      } else {
        final data = await DefaultAssetBundle.of(context).load('assets/images/bg.jpg');
        File f = File('${tempDir.path}/default_bg.jpg');
        await f.writeAsBytes(data.buffer.asUint8List());
        bgPath = f.path;
      }

      // 3. Render Video MP4
      String cmd = "-y -loop 1 -i \"$bgPath\" -i \"$trimAudioPath\" -c:v libx264 -preset ultrafast -pix_fmt yuv420p -c:a copy -shortest -t $durasi \"$outputPath\"";

      var videoSession = await FFmpegKit.execute(cmd);
      var videoCode = await videoSession.getReturnCode();

      if (mounted) {
        if (ReturnCode.isSuccess(videoCode)) {
          File resFile = File(outputPath);
          if (await resFile.exists()) {
            setState(() {
              outVideo = resFile;
              load = false;
            });
            return;
          }
        }

        // Jika Gagal
        setState(() => load = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Gagal memproses video, silakan coba lagi.")),
        );
      }

    } catch (e) {
      if (mounted) {
        setState(() => load = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Terjadi kesalahan: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    double w = MediaQuery.of(context).size.width;
    Widget bgWidget = bgFile != null 
        ? Image.file(bgFile!, fit: BoxFit.cover) 
        : Image.asset(
            'assets/images/bg.jpg', 
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Container(color: Colors.black),
          );

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(child: bgWidget),

          // WATERMARK TOP LEFT - LUXURIOUS GOLD 16PX
          SafeArea(
            child: Positioned(
              top: 12,
              left: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.5), width: 1),
                ),
                child: const Text(
                  "BABE.INFO HERU WINGCHUN",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFFFFD700),
                    letterSpacing: 1.5,
                    shadows: [
                      Shadow(
                        blurRadius: 4,
                        color: Colors.black,
                        offset: Offset(1, 1),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // GLOBE CONTAINER
          Positioned(
            top: 70,
            left: w / 2 - 150,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                color: Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.amber, width: 2),
              ),
              child: ClipOval(
                child: inited && flutterGl.textureId != null
                    ? RepaintBoundary(child: Texture(textureId: flutterGl.textureId!))
                    : const Center(child: CircularProgressIndicator(color: Colors.amber)),
              ),
            ),
          ),

          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.amber),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (audioFile != null)
                        AudioFileWaveforms(
                          size: Size(w - 48, 60),
                          playerController: player,
                          waveformType: WaveformType.long,
                          playerWaveStyle: const PlayerWaveStyle(fixedWaveColor: Colors.white24, liveWaveColor: Colors.amber),
                        ),
                      if (audioFile != null)
                        RangeSlider(
                          min: 0,
                          max: total > 0 ? total : 1,
                          values: RangeValues(s.clamp(0, total), e.clamp(s, total)),
                          activeColor: Colors.amber,
                          onChanged: (v) {
                            if (v.end - v.start <= 60) {
                              setState(() { s = v.start; e = v.end; });
                            }
                          },
                        ),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: pickAudio,
                              icon: const Icon(Icons.music_note),
                              label: Text(audioFile == null ? "AMBIL MUSIK" : "GANTI", style: const TextStyle(fontSize: 11)),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: pickBg,
                              icon: const Icon(Icons.image),
                              label: const Text("BG", style: TextStyle(fontSize: 11)),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: load ? null : buatMp4,
                          icon: load 
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                              : const Icon(Icons.video_file),
                          label: Text(load ? "SEDANG MERENDER MP4..." : "BUAT MP4", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: load ? Colors.grey : Colors.greenAccent, 
                            foregroundColor: Colors.black
                          ),
                        ),
                      ),
                      if (outVideo != null) ...[
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Share.shareXFiles(
                                [XFile(outVideo!.path)],
                                text: 'BABE.INFO HERU WINGCHUN',
                              );
                            },
                            icon: const Icon(Icons.share),
                            label: const Text("SHARE KE WA STATUS", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                          ),
                        ),
                      ]
                    ],
                  ),
                ),
              ),
            ),
          )
        ],
      ),
    );
  }

  @override
  void dispose() {
    _ticker?.stop();
    _ticker?.dispose();
    player.dispose();
    try {
      renderer.dispose();
      flutterGl.dispose();
    } catch (_) {}
    super.dispose();
  }
}
