import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:three_js/three_js.dart' as three;
import 'package:flutter_gl/flutter_gl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:ffmpeg_kit_flutter_new_audio/ffmpeg_kit.dart';
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
      var st = inf.version.sdkInt >= 33 
          ? await Permission.audio.request() 
          : await Permission.storage.request();
      if (st.isGranted && mounted) {
        setState(() => perm = true);
      }
    } catch (_) {}
  }

  Future<void> initGlobe() async {
    // FIX 1: Beri waktu jeda 300ms agar EGL Native Surface benar-benar siap
    await Future.delayed(const Duration(milliseconds: 300));

    try {
      double dpr = MediaQuery.of(context).devicePixelRatio;
      int renderWidth = (300 * dpr).toInt();
      int renderHeight = (300 * dpr).toInt();

      await flutterGl.initialize(options: {
        "antialias": true,
        "alpha": false,
        "width": renderWidth,
        "height": renderHeight,
        "dpr": dpr,
        "preserveDrawingBuffer": true,
      });

      await flutterGl.prepareContext();

      if (flutterGl.textureId == null) {
        debugPrint("EGL Texture ID gagal didapatkan!");
        return;
      }

      scene = three.Scene();
      scene.background = three.Color(0xEEEEEE);

      camera = three.PerspectiveCamera(45, 1, 0.1, 1000);
      camera.position.z = 2.8;

      renderer = three.WebGLRenderer({
        "gl": flutterGl.gl,
        "antialias": true,
        "alpha": false,
        "preserveDrawingBuffer": true,
      });

      renderer.setSize(renderWidth.toDouble(), renderHeight.toDouble(), false);
      renderer.setClearColor(three.Color(0xEEEEEE), 1);

      // Setup Lighting
      var light = three.DirectionalLight(0xffffff, 1.2);
      light.position.setValues(5, 3, 5);
      scene.add(light);
      scene.add(three.AmbientLight(0xffffff, 0.8));
      var pointLight = three.PointLight(0xFFD700, 0.8, 10);
      pointLight.position.setValues(-3, -2, 3);
      scene.add(pointLight);

      // Geometri & Material Emas Standar
      var geo = three.SphereGeometry(1, 64, 64);
      var mat = three.MeshStandardMaterial()
        ..color = three.Color(0xFFD700)
        ..metalness = 0.75
        ..roughness = 0.28;

      globe = three.Mesh(geo, mat);
      globe!.position.y = 0.3;
      scene.add(globe!);

      // Akar Hitam 3D
      var rootGeo = three.TorusGeometry(1.05, 0.02, 8, 80);
      var rootMat = three.MeshBasicMaterial()..color = three.Color(0x111111);

      for (int i = 0; i < 3; i++) {
        var torus = three.Mesh(rootGeo, rootMat);
        torus.rotation.x = i * 1.2;
        torus.rotation.y = i * 0.8;
        torus.position.y = 0.3;
        scene.add(torus);
      }

      // FIX 2: Langsung aktifkan tampilan UI begitu Geometri 3D siap di memori EGL
      if (mounted) {
        setState(() => inited = true);
        startAnimation();
      }

      // FIX 3: Muat tekstur via ByteData secara aman tanpa memblokir siklus utama
      loadTextureSafe(mat);

    } catch (e) {
      debugPrint("Init Globe Fatal Error: $e");
    }
  }

  Future<void> loadTextureSafe(three.MeshStandardMaterial mat) async {
    try {
      final ByteData data = await rootBundle.load('assets/images/babe_gold.jpg');
      final Uint8List bytes = data.buffer.asUint8List();
      
      final loader = three.TextureLoader();
      var tex = await loader.fromList(bytes);
      if (tex != null && mounted) {
        tex.wrapS = three.RepeatWrapping;
        tex.wrapT = three.RepeatWrapping;
        tex.flipY = false;
        mat.map = tex;
        mat.needsUpdate = true;
      }
    } catch (e) {
      debugPrint("Asset babe_gold.jpg tidak ditemukan/gagal dimuat. Menggunakan warna Emas default. Error: $e");
    }
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
        setState(() => bgFile = File(r.files.single.path!));
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
    setState(() => load = true);
    try {
      final dir = await getTemporaryDirectory();
      String trim = "${dir.path}/trim.m4a";
      String out = "${dir.path}/BABE-INFO-${DateTime.now().millisecondsSinceEpoch}.mp4";

      await FFmpegKit.execute("-y -ss $s -t ${e - s} -i \"${audioFile!.path}\" -c:a aac \"$trim\"");

      String bgPath = "";
      if (bgFile != null) {
        bgPath = bgFile!.path;
      } else {
        final data = await DefaultAssetBundle.of(context).load('assets/images/bg.jpg');
        File f = File('${dir.path}/bg.jpg');
        await f.writeAsBytes(data.buffer.asUint8List());
        bgPath = f.path;
      }

      var st = await FFmpegKit.execute(
        "-y -loop 1 -i \"$bgPath\" -i \"$trim\" -c:v libx264 -tune stillimage -c:a aac -pix_fmt yuv420p -shortest -t ${e - s} \"$out\""
      );

      var returnCode = await st.getReturnCode();
      if (mounted) {
        if (returnCode != null && returnCode.isValueSuccess()) {
          setState(() {
            outVideo = File(out);
            load = false;
          });
        } else {
          setState(() => load = false);
        }
      }
    } catch (e) {
      if (mounted) setState(() => load = false);
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

          Positioned(
            top: 70,
            left: w / 2 - 150,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                color: const Color(0xFFEEEEEE),
                borderRadius: BorderRadius.circular(150),
                border: Border.all(color: Colors.amber, width: 2),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(150),
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
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: load ? null : buatMp4,
                          icon: const Icon(Icons.video_file),
                          label: Text(load ? "RENDER..." : "BUAT MP4", style: const TextStyle(fontSize: 11)),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent, foregroundColor: Colors.black),
                        ),
                      ),
                      if (outVideo != null)
                        ElevatedButton.icon(
                          onPressed: () {
                            Share.shareXFiles(
                              [XFile(outVideo!.path)],
                            );
                          },
                          icon: const Icon(Icons.share),
                          label: const Text("SHARE KE WA STATUS", style: TextStyle(fontSize: 11)),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                        ),
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
