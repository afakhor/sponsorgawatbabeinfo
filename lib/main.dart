import 'dart:io';
import 'package:flutter/material.dart';
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

class _GlobeLearnPageState extends State<GlobeLearnPage> {
  late FlutterGlPlugin flutterGl;
  late three.WebGLRenderer renderer;
  late three.Scene scene;
  late three.PerspectiveCamera camera;
  late three.Mesh globe;
  bool inited = false;

  // audio
  File? audioFile, bgFile, outVideo;
  final player = PlayerController();
  double total = 180, s = 0, e = 60;
  bool perm = false, load = false;

  @override
  void initState() {
    super.initState();
    flutterGl = FlutterGlPlugin();
    cekIzin();
    initGlobe();
  }

  Future<void> cekIzin() async {
    final inf = await DeviceInfoPlugin().androidInfo;
    var st = inf.version.sdkInt >= 33 ? await Permission.audio.request() : await Permission.storage.request();
    if (st.isGranted) setState(() => perm = true);
  }

  Future<void> initGlobe() async {
    await flutterGl.initialize(options: {
      "antialias": true,
      "alpha": false,
      "width": 400,
      "height": 400,
      "dpr": 1.0
    });
    await flutterGl.prepareContext();

    scene = three.Scene();
    scene.background = three.Color(0x000000);
    camera = three.PerspectiveCamera(75, 1, 0.1, 1000);
    camera.position.z = 3;

    renderer = three.WebGLRenderer({
      "gl": flutterGl.gl,
      "antialias": true,
    });
    renderer.setSize(400, 400, false);

    // LIGHT
    var light = three.DirectionalLight(0xffffff, 1);
    light.position.setValues(5, 3, 5);
    scene.add(light);
    scene.add(three.AmbientLight(0xffffff, 0.6));

    // GEOMETRY GLOBE - fix tidak nutupin tulisan
    var geo = three.SphereGeometry(1, 64, 64);
    
    var mat = three.MeshPhongMaterial();
    mat.color = three.Color(0xFFD700); // emas BABE.INFO
    mat.shininess = 150;
    mat.specular = three.Color(0xFFD700);

    globe = three.Mesh(geo, mat);
    globe.position.y = 0.8; // naik ke atas biar tidak nutupin BABE.INFO & HeruWingchun
    scene.add(globe);

    animate();
    setState(() => inited = true);
  }

  void animate() {
    if (!mounted) return;
    globe.rotation.y += 0.01;
    renderer.render(scene, camera);
    flutterGl.updateTexture(renderer.getContext());
    Future.delayed(const Duration(milliseconds: 16), animate);
  }

  Future<void> pickAudio() async {
    var r = await FilePicker.platform.pickFiles(type: FileType.audio);
    if (r == null) return;
    File f = File(r.files.single.path!);
    await player.preparePlayer(path: f.path, shouldExtractWaveform: true, noOfSamples: 200);
    final d = await player.getDuration(DurationType.max);
    setState(() {
      audioFile = f;
      total = (d / 1000).toDouble();
      s = 0;
      e = total > 60 ? 60 : total;
    });
  }

  Future<void> pickBg() async {
    var r = await FilePicker.platform.pickFiles(type: FileType.image);
    if (r == null) return;
    setState(() => bgFile = File(r.files.single.path!));
  }

  Future<void> buatMp4() async {
    if (audioFile == null) { pickAudio(); return; }
    setState(() => load = true);
    final dir = await getTemporaryDirectory();
    String trim = "${dir.path}/trim.m4a";
    String out = "${dir.path}/BABE-INFO-${DateTime.now().millisecondsSinceEpoch}.mp4";
    await FFmpegKit.execute("-y -ss $s -t ${e - s} -i \"${audioFile!.path}\" -c:a aac \"$trim\"");
    String bgPath = "";
    if (bgFile != null) bgPath = bgFile!.path;
    else {
      final data = await DefaultAssetBundle.of(context).load('assets/images/bg.jpg');
      File f = File('${dir.path}/bg.jpg');
      await f.writeAsBytes(data.buffer.asUint8List());
      bgPath = f.path;
    }
    await FFmpegKit.execute("-y -loop 1 -i \"$bgPath\" -i \"$trim\" -c:v libx264 -tune stillimage -c:a aac -pix_fmt yuv420p -shortest -t ${e - s} \"$out\"").then((st) async {
      if ((await st.getReturnCode())!.isValueSuccess()) {
        setState(() { outVideo = File(out); load = false; });
      } else {
        setState(() => load = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    double w = MediaQuery.of(context).size.width;
    Widget bg = bgFile != null ? Image.file(bgFile!, fit: BoxFit.cover) : Image.asset('assets/images/bg.jpg', fit: BoxFit.cover);
    return Scaffold(
      body: Stack(children: [
        Positioned.fill(child: bg),
        // GLOBE three_js + flutter_gl - learn by doing
        Positioned(
          top: 40,
          left: w / 2 - 150,
          child: Container(
            width: 300,
            height: 300,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(150), border: Border.all(color: Colors.amber, width: 2)),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(150),
              child: inited ? Texture(textureId: flutterGl.textureId!) : const Center(child: CircularProgressIndicator(color: Colors.amber)),
            ),
          ),
        ),
        // Tulisan BABE.INFO di bawah globe - tidak ketutup (fix)
        Positioned(
          top: 360,
          left: 0,
          right: 0,
          child: Column(children: [
            const Text("BABE.INFO", style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.amber, letterSpacing: 2)),
            const Text("HeruWingchun", style: TextStyle(fontSize: 14, color: Colors.white70)),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(8)),
              child: const Text("GLOBE BABE.INFO - TOUCHABLE", style: TextStyle(fontSize: 10, color: Colors.black, fontWeight: FontWeight.bold)),
            )
          ]),
        ),
        SafeArea(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.black.withOpacity(0.7), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.amber)),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  if (audioFile != null)
                    AudioFileWaveforms(size: Size(w - 48, 60), playerController: player, waveformType: WaveformType.long, playerWaveStyle: const PlayerWaveStyle(fixedWaveColor: Colors.white24, liveWaveColor: Colors.amber)),
                  if (audioFile != null)
                    RangeSlider(min: 0, max: total, values: RangeValues(s, e), activeColor: Colors.amber, onChanged: (v) { if (v.end - v.start <= 60) setState(() { s = v.start; e = v.end; }); }),
                  Row(children: [
                    Expanded(child: ElevatedButton.icon(onPressed: pickAudio, icon: const Icon(Icons.music_note), label: Text(audioFile == null ? "AMBIL MUSIK" : "GANTI", style: const TextStyle(fontSize: 11)), style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black))),
                    const SizedBox(width: 6),
                    Expanded(child: ElevatedButton.icon(onPressed: pickBg, icon: const Icon(Icons.image), label: const Text("BG", style: TextStyle(fontSize: 11)), style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black))),
                  ]),
                  SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: load ? null : buatMp4, icon: const Icon(Icons.video_file), label: Text(load ? "RENDER..." : "BUAT MP4", style: const TextStyle(fontSize: 11)), style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent, foregroundColor: Colors.black))),
                  if (outVideo != null)
                    ElevatedButton.icon(onPressed: () => Share.shareXFiles([XFile(outVideo!.path)], text: "BABE.INFO Globe three_js: https://afakhor.github.io/sponsorgawatbabeinfo/"), icon: const Icon(Icons.share), label: const Text("SHARE WA", style: TextStyle(fontSize: 11)), style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white)),
                ]),
              ),
            ),
          ),
        )
      ]),
    );
  }

  @override
  void dispose() {
    flutterGl.dispose();
    super.dispose();
  }
}