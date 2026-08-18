import 'dart:io';
import 'package:flutter/material.dart';
import 'package:three_js/three_js.dart' as three;
import 'package:file_picker/file_picker.dart';
import 'package:ffmpeg_kit_flutter_new_audio/ffmpeg_kit.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hive_flutter/hive_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await Hive.initFlutter();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext c) => MaterialApp(debugShowCheckedModeBanner: false, theme: ThemeData.dark(), home: const GlobeLearnPage());
}

class GlobeLearnPage extends StatefulWidget {
  const GlobeLearnPage({super.key});
  @override
  State<GlobeLearnPage> createState() => _GlobeLearnPageState();
}

class _GlobeLearnPageState extends State<GlobeLearnPage> {
  late three.ThreeJS threeJs;
  File? audioFile, bgFile, outVideo;
  bool load=false;

  @override
  void initState() {
    threeJs = three.ThreeJS(
      onSetupComplete: (){if(mounted) setState((){});},
      setup: setup,
    );
    super.initState();
  }

  Future<void> setup() async {
    threeJs.scene = three.Scene();
    threeJs.scene.background = three.Color(0xEEEEEE);
    threeJs.camera = three.PerspectiveCamera(45, threeJs.width/threeJs.height, 0.1, 1000);
    threeJs.camera.position.z = 2.8;

    var light = three.DirectionalLight(0xffffff, 1.2);
    light.position.setValues(5,3,5);
    threeJs.scene.add(light);
    threeJs.scene.add(three.AmbientLight(0xffffff, 0.8));

    var geo = three.SphereGeometry(1, 128, 128);
    // FIX API 0.2.7: fromAsset cuma 1 argumen
    var tex = await three.TextureLoader().fromAsset("assets/images/babe_gold.jpg").loadAsync(threeJs);
    var mat = three.MeshStandardMaterial.fromMap({"map": tex, "metalness": 0.75, "roughness": 0.28});
    var globe = three.Mesh(geo, mat);
    globe.position.y = 0.3;
    threeJs.scene.add(globe);

    threeJs.addAnimationEvent((dt){ globe.rotation.y += 0.008; });
  }

  Future<void> pickAudio() async {
    var r = await FilePicker.platform.pickFiles(type: FileType.audio);
    if(r!=null) setState(()=> audioFile = File(r.files.single.path!));
  }

  Future<void> buatMp4() async {
    if(audioFile==null) return;
    setState(()=> load=true);
    final dir = await getTemporaryDirectory();
    String trim = "${dir.path}/trim.m4a";
    String out = "${dir.path}/BABE-INFO-${DateTime.now().millisecondsSinceEpoch}.mp4";
    await FFmpegKit.execute("-y -i \"${audioFile!.path}\" -c:a aac \"$trim\"");
    String bgPath = bgFile?.path ?? "";
    if(bgPath.isEmpty){
      final data = await DefaultAssetBundle.of(context).load('assets/images/bg.jpg');
      File f = File('${dir.path}/bg.jpg');
      await f.writeAsBytes(data.buffer.asUint8List());
      bgPath = f.path;
    }
    await FFmpegKit.execute("-y -loop 1 -i \"$bgPath\" -i \"$trim\" -c:v libx264 -tune stillimage -c:a aac -pix_fmt yuv420p -shortest \"$out\"").then((st) async {
      if((await st.getReturnCode())!.isValueSuccess()){
        setState((){ outVideo = File(out); load=false; });
      } else setState(()=> load=false);
    });
  }

  @override
  Widget build(BuildContext context) {
    double w = MediaQuery.of(context).size.width;
    return Scaffold(
      body: Stack(children: [
        Positioned.fill(child: bgFile!=null?Image.file(bgFile!, fit: BoxFit.cover):Image.asset('assets/images/bg.jpg', fit: BoxFit.cover)),
        Positioned(top:40, left:w/2-150, child: Container(width:300, height:300, decoration: BoxDecoration(color: Color(0xFFEEEEEE), borderRadius: BorderRadius.circular(150), border: Border.all(color: Colors.amber, width:2)), child: ClipRRect(borderRadius: BorderRadius.circular(150), child: threeJs.build()))),
        SafeArea(child: Align(alignment: Alignment.bottomCenter, child: Padding(padding: EdgeInsets.all(12), child: Container(padding: EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.black.withOpacity(0.7), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.amber)), child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [Expanded(child: ElevatedButton.icon(onPressed: pickAudio, icon: Icon(Icons.music_note), label: Text(audioFile==null?"AMBIL MUSIK":"GANTI")))]),
          SizedBox(width:double.infinity, child: ElevatedButton.icon(onPressed: load?null:buatMp4, icon: Icon(Icons.video_file), label: Text(load?"RENDER...":"BUAT MP4"))),
          if(outVideo!=null) ElevatedButton.icon(onPressed: ()=> Share.shareXFiles([XFile(outVideo!.path)]), icon: Icon(Icons.share), label: Text("SHARE WA")),
        ]))))),
      ]),
    );
  }
}