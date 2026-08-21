import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:three_js/three_js.dart' as three;
import 'package:three_js_controls/three_js_controls.dart' as controls;
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
    theme: ThemeData.dark().copyWith(scaffoldBackgroundColor: Colors.black),
    home: const GlobeLearnPage(),
  );
}

class GlobeLearnPage extends StatefulWidget {
  const GlobeLearnPage({super.key});
  @override
  State<GlobeLearnPage> createState() => _GlobeLearnPageState();
}

class _GlobeLearnPageState extends State<GlobeLearnPage> {
  late three.ThreeJS threeJs;
  three.Mesh? globe;
  controls.OrbitControls? orbit;
  bool inited = false;

  File? audioFile, bgFile, outVideo;
  final player = PlayerController();
  double total = 180, s = 0, e = 60;
  bool load = false;
  String status = "";

  @override
  void initState() {
    super.initState();
    threeJs = three.ThreeJS(
      onSetupComplete: () { setState(() { inited = true; }); },
      setup: setupGlobe,
    );
    cekIzin();
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
    } catch (_) {}
  }

  Future<void> setupGlobe() async {
    threeJs.scene = three.Scene();
    threeJs.camera = three.PerspectiveCamera(45, threeJs.width / threeJs.height, 0.1, 1000);
    threeJs.camera.position.z = 3.2;

    threeJs.scene.add(three.AmbientLight(0xffffff, 0.9));
    var dir = three.DirectionalLight(0xffffff, 1.5);
    dir.position.setValues(5, 5, 5);
    threeJs.scene.add(dir);

    // GLOBE EMAS
    var geo = three.SphereGeometry(1, 64, 64);
    var mat = three.MeshPhongMaterial();
    mat.color = three.Color(0xFFD700); // gold fallback kalau texture gagal
    mat.shininess = 80;
    globe = three.Mesh(geo, mat);
    globe!.position.y = 0.15;
    threeJs.scene.add(globe!);

    // 3 CINCIN HITAM
    var torusGeo = three.TorusGeometry(1.08, 0.02, 12, 100);
    var torusMat = three.MeshBasicMaterial()..color = three.Color(0x222222);
    for (int i = 0; i < 3; i++) {
      var t = three.Mesh(torusGeo, torusMat.clone());
      t.rotation.x = i * 1.3;
      t.rotation.y = i * 0.7;
      t.position.y = 0.15;
      threeJs.scene.add(t);
    }

    // TEXTURE - FIX 100% ANTI GAGAL
    try {
      var loader = three.TextureLoader();
      // fromAsset = method yang benar di three_js 0.1.7
      var tex = await loader.fromAsset('assets/images/babe_gold.jpg');
      if (tex != null) {
        mat.map = tex;
        mat.needsUpdate = true;
        debugPrint("TEXTURE OK");
      }
    } catch (e) {
      debugPrint("TEXTURE FAIL - pakai warna emas $e");
    }

    // ORBIT CONTROLS = GLOBE INTERACTIVE TOUCH
    orbit = controls.OrbitControls(threeJs.camera, threeJs.renderer!.domElement);
    orbit!.enableDamping = true;
    orbit!.dampingFactor = 0.1;
    orbit!.rotateSpeed = 0.8;
    orbit!.enableZoom = true;
    orbit!.minDistance = 2.0;
    orbit!.maxDistance = 5.0;
    orbit!.target.setValues(0, 0.15, 0);

    // Auto rotate pelan
    threeJs.addAnimationEvent((dt) {
      orbit!.update();
      if (globe != null && !orbit!.isDragging) {
        globe!.rotation.y += 0.005; // muter otomatis kalau gak di-touch
      }
    });
  }

  // PICK AUDIO - FIX MP3 GAGAL
  Future<void> pickAudio() async {
    try {
      var r = await FilePicker.platform.pickFiles(type: FileType.audio);
      if (r == null) return;
      File f = File(r.files.single.path!);
      await player.preparePlayer(path: f.path, shouldExtractWaveform: true, noOfSamples: 200);
      await Future.delayed(Duration(milliseconds: 300));
      final d = await player.getDuration(DurationType.max);
      setState(() {
        audioFile = f;
        total = (d / 1000).toDouble();
        if (total <= 0) total = 180;
        s = 0;
        e = total > 60 ? 60 : total;
        outVideo = null;
        status = "Audio OK: ${f.path.split('/').last}";
      });
    } catch (e) {
      setState(() => status = "Audio gagal: $e");
    }
  }

  Future<void> pickBg() async {
    try {
      var r = await FilePicker.platform.pickFiles(type: FileType.image);
      if (r == null) return;
      setState(() {
        bgFile = File(r.files.single.path!);
        outVideo = null;
        status = "BG OK";
      });
    } catch (e) {
      setState(() => status = "BG gagal: $e");
    }
  }

  // BUAT MP4 - FIX RENDER + SHARE WA
  Future<void> buatMp4() async {
    if (audioFile == null) {
      setState(() => status = "Pilih musik dulu!");
      await pickAudio();
      return;
    }
    setState(() { load = true; status = "Render mulai..."; });

    try {
      await player.stopPlayer();
      await Future.delayed(Duration(milliseconds: 300));

      final tmp = await getTemporaryDirectory();
      final ts = DateTime.now().millisecondsSinceEpoch;
      String trim = "${tmp.path}/trim_$ts.m4a";
      String out = "${tmp.path}/BABE_$ts.mp4";
      double dur = e - s;
      if (dur <= 0 || dur > 60) dur = 60;
      if (dur < 2) dur = 5;

      setState(() => status = "Trim audio ${s.toStringAsFixed(1)}s - ${e.toStringAsFixed(1)}s");

      // FIX MP3 -> M4A AAC
      var cmdTrim = '-y -ss $s -t $dur -i "${audioFile!.path}" -c:a aac -b:a 128k "$trim"';
      var sess1 = await FFmpegKit.execute(cmdTrim);
      var code1 = await sess1.getReturnCode();
      if (!ReturnCode.isSuccess(code1)) {
        setState(() { load = false; status = "Trim gagal! Coba audio lain"; });
        var logs = await sess1.getAllLogsAsString();
        debugPrint(logs ?? "");
        return;
      }

      // FIX BG - kalau gak ada pakai bg.jpg dari assets
      String bg = bgFile?.path ?? "";
      if (bg.isEmpty) {
        try {
          final data = await DefaultAssetBundle.of(context).load('assets/images/bg.jpg');
          File f = File('${tmp.path}/bg_$ts.jpg');
          await f.writeAsBytes(data.buffer.asUint8List());
          bg = f.path;
        } catch (_) {
          // kalau bg.jpg gak ada, bikin warna hitam
          bg = "";
        }
      }

      setState(() => status = "Gabung BG + Audio jadi MP4...");

      String cmdMp4;
      if (bg.isNotEmpty) {
        cmdMp4 = '-y -loop 1 -i "$bg" -i "$trim" -c:v libx264 -preset ultrafast -pix_fmt yuv420p -c:a aac -shortest -t $dur "$out"';
      } else {
        // tanpa BG = background hitam
        cmdMp4 = '-y -f lavfi -i color=c=black:s=720x1280:d=$dur -i "$trim" -c:v libx264 -preset ultrafast -pix_fmt yuv420p -c:a aac -shortest -t $dur "$out"';
      }

      var sess2 = await FFmpegKit.execute(cmdMp4);
      var code2 = await sess2.getReturnCode();

      if (ReturnCode.isSuccess(code2)) {
        setState(() {
          outVideo = File(out);
          load = false;
          status = "MP4 JADI! Siap share WA";
        });
      } else {
        var logs = await sess2.getAllLogsAsString();
        debugPrint(logs ?? "");
        setState(() { load = false; status = "MP4 gagal: ${logs?.substring(0, 200)}"; });
      }
    } catch (e) {
      setState(() { load = false; status = "Error: $e"; });
    }
  }

  @override
  Widget build(BuildContext context) {
    double w = MediaQuery.of(context).size.width;
    Widget bgW = bgFile != null
        ? Image.file(bgFile!, fit: BoxFit.cover, width: double.infinity, height: double.infinity)
        : Image.asset('assets/images/bg.jpg', fit: BoxFit.cover, width: double.infinity, height: double.infinity, errorBuilder: (_, __, ___) => Container(color: Colors.black));

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [
        Positioned.fill(child: bgW),
        Positioned(
          top: MediaQuery.of(context).padding.top + 10,
          left: 12,
          right: 12,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(8), border: Border.all(color: Color(0xFFFFD700))),
            child: Row(children: [
              Icon(Icons.public, color: Color(0xFFFFD700), size: 16),
              SizedBox(width: 6),
              Expanded(child: Text("BABE.INFO HERU WINGCHUN ${inited ? '• GLOBE OK' : '• LOADING...'}", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFFFFD700)))),
              Text(status, style: TextStyle(fontSize: 9, color: Colors.white70), overflow: TextOverflow.ellipsis),
            ]),
          ),
        ),
        // GLOBE INTERACTIVE TOUCH AREA
        Positioned(
          top: MediaQuery.of(context).padding.top + 50,
          left: w / 2 - 150,
          child: Container(
            width: 300,
            height: 300,
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.amber, width: 2), boxShadow: [BoxShadow(color: Colors.amber.withOpacity(0.3), blurRadius: 20)]),
            child: ClipOval(child: threeJs.build()),
          ),
        ),
        Positioned(
          top: MediaQuery.of(context).padding.top + 360,
          left: 0,
          right: 0,
          child: Center(child: Text("👆 Geser globe = interactive touch", style: TextStyle(color: Colors.amber, fontSize: 11))),
        ),
        SafeArea(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: EdgeInsets.all(12),
              child: Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.black.withOpacity(0.88), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.amber.withOpacity(0.8))),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  if (audioFile != null) AudioFileWaveforms(size: Size(w - 48, 60), playerController: player, waveformType: WaveformType.long, playerWaveStyle: PlayerWaveStyle(fixedWaveColor: Colors.white24, liveWaveColor: Colors.amber)),
                  if (audioFile != null) RangeSlider(min: 0, max: total > 0 ? total : 1, values: RangeValues(s.clamp(0, total), e.clamp(s, total)), activeColor: Colors.amber, inactiveColor: Colors.white24, onChanged: (v) { if (v.end - v.start <= 60) setState(() { s = v.start; e = v.end; }); }),
                  if (audioFile != null) Text("${s.toStringAsFixed(1)}s - ${e.toStringAsFixed(1)}s = ${(e - s).toStringAsFixed(1)}s (max 60s)", style: TextStyle(fontSize: 10, color: Colors.white70)),
                  SizedBox(height: 6),
                  Row(children: [
                    Expanded(child: ElevatedButton.icon(onPressed: pickAudio, icon: Icon(Icons.music_note, size: 16), label: Text(audioFile == null ? "AMBIL MUSIK" : "GANTI", style: TextStyle(fontSize: 10)), style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black, padding: EdgeInsets.symmetric(vertical: 10)))),
                    SizedBox(width: 6),
                    Expanded(child: ElevatedButton.icon(onPressed: pickBg, icon: Icon(Icons.image, size: 16), label: Text("BG", style: TextStyle(fontSize: 10)), style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black, padding: EdgeInsets.symmetric(vertical: 10)))),
                  ]),
                  SizedBox(height: 6),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: load ? null : buatMp4,
                      icon: load ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black)) : Icon(Icons.video_file, size: 16),
                      label: Text(load ? "MERENDER..." : "BUAT MP4", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(backgroundColor: load ? Colors.grey : Colors.greenAccent, foregroundColor: Colors.black, padding: EdgeInsets.symmetric(vertical: 12)),
                    ),
                  ),
                  if (status.isNotEmpty) Padding(padding: EdgeInsets.only(top: 6), child: Text(status, style: TextStyle(fontSize: 10, color: Colors.amber), textAlign: TextAlign.center)),
                  if (outVideo != null) ...[
                    SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          // FIX SHARE WA - 100% WORK
                          await Share.shareXFiles([XFile(outVideo!.path)], text: 'BABE.INFO HERU WINGCHUN - Globe Interactive ✨\n${outVideo!.path}');
                        },
                        icon: Icon(Icons.share, size: 16),
                        label: Text("SHARE KE WA STATUS", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF25D366), foregroundColor: Colors.white, padding: EdgeInsets.symmetric(vertical: 12)),
                      ),
                    ),
                  ]
                ]),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  @override
  void dispose() {
    player.dispose();
    threeJs.dispose();
    super.dispose();
  }
}