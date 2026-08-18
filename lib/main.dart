import 'dart:io';
import 'package:flutter/material.dart';
import 'package:three_js/three_js.dart' as three;
import 'package:file_picker/file_picker.dart';
import 'package:ffmpeg_kit_flutter_new_audio/ffmpeg_kit.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

void main() => runApp(const MyApp());

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
  three.Mesh? globe;
  File? audioFile, bgFile, outVideo;
  double total = 180, s = 0, e = 60;
  bool load = false;

  @override
  void initState() {
    threeJs = three.ThreeJS(
      onSetupComplete: (){setState((){});},
      setup: setup,
    );
    super.initState();
  }

  Future<void> setup() async {
    threeJs.scene = three.Scene();
    threeJs.scene.background = three.Color(0xEEEEEE);
    threeJs.camera = three.PerspectiveCamera(45, threeJs.width/threeJs.height, 0.1, 1000);
    threeJs.camera.position.z = 2.8;

    // LIGHT
    var light = three.DirectionalLight(0xffffff, 1.2);
    light.position.setValues(5,3,5);
    threeJs.scene.add(light);
    threeJs.scene.add(three.AmbientLight(0xffffff, 0.8));

    // TEXTURE babe_gold.jpg
    var geo = three.SphereGeometry(1, 128, 128);
    var tex = await three.TextureLoader().fromAsset("assets/images/babe_gold.jpg");
    var mat = three.MeshStandardMaterial.fromMap({
      "map": tex,
      "metalness": 0.75,
      "roughness": 0.28,
    });
    globe = three.Mesh(geo, mat);
    globe!.position.y = 0.3;
    threeJs.scene.add(globe!);

    // AKAR
    var rootGeo = three.TorusGeometry(1.05, 0.02, 8, 100);
    var rootMat = three.MeshBasicMaterial.fromMap({"color": 0x111111});
    for(int i=0;i<3;i++){
      var torus = three.Mesh(rootGeo, rootMat);
      torus.rotation.x = i*1.2;
      torus.rotation.y = i*0.8;
      threeJs.scene.add(torus);
    }
  }

  @override
  Widget build(BuildContext context) {
    double w = MediaQuery.of(context).size.width;
    Widget bgWidget = bgFile != null ? Image.file(bgFile!, fit: BoxFit.cover) : Image.asset('assets/images/bg.jpg', fit: BoxFit.cover);
    return Scaffold(
      body: Stack(children: [
        Positioned.fill(child: bgWidget),
        // GLOBE ANTI BLINK - PAKAI three_js WIDGET BAWAAN
        Positioned(
          top: 40, left: w/2 - 150,
          child: Container(
            width: 300, height: 300,
            decoration: BoxDecoration(color: Color(0xFFEEEEEE), borderRadius: BorderRadius.circular(150), border: Border.all(color: Colors.amber, width: 2)),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(150),
              child: threeJs.build(),
            ),
          ),
        ),
        Positioned(top: 360, left:0, right:0, child: Column(children: [
          const Text("BABE.INFO", style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.amber)),
          const Text("HeruWingchun", style: TextStyle(fontSize: 14, color: Colors.white70)),
        ])),
        SafeArea(child: Align(alignment: Alignment.bottomCenter, child: Padding(padding: EdgeInsets.all(12), child: Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.black.withOpacity(0.7), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.amber)),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              Expanded(child: ElevatedButton.icon(onPressed: () async {
                var r = await FilePicker.platform.pickFiles(type: FileType.audio);
                if(r!=null) setState(()=> audioFile = File(r.files.single.path!));
              }, icon: Icon(Icons.music_note), label: Text(audioFile==null?"AMBIL MUSIK":"GANTI"))),
              SizedBox(width:6),
              Expanded(child: ElevatedButton.icon(onPressed: () async {
                var r = await FilePicker.platform.pickFiles(type: FileType.image);
                if(r!=null) setState(()=> bgFile = File(r.files.single.path!));
              }, icon: Icon(Icons.image), label: Text("BG"))),
            ]),
            SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: load?null:() async {
              if(audioFile==null) return;
              setState(()=> load=true);
              final dir = await getTemporaryDirectory();
              String trim = "${dir.path}/trim.m4a";
              String out = "${dir.path}/BABE-INFO-${DateTime.now().millisecondsSinceEpoch}.mp4";
              await FFmpegKit.execute("-y -ss $s -t ${e - s} -i \"${audioFile!.path}\" -c:a aac \"$trim\"");
              String bgPath = bgFile?.path ?? "";
              if(bgPath.isEmpty){
                final data = await DefaultAssetBundle.of(context).load('assets/images/bg.jpg');
                File f = File('${dir.path}/bg.jpg');
                await f.writeAsBytes(data.buffer.asUint8List());
                bgPath = f.path;
              }
              await FFmpegKit.execute("-y -loop 1 -i \"$bgPath\" -i \"$trim\" -c:v libx264 -tune stillimage -c:a aac -pix_fmt yuv420p -shortest -t ${e - s} \"$out\"").then((st) async {
                if((await st.getReturnCode())!.isValueSuccess()){
                  setState((){ outVideo = File(out); load=false; });
                } else setState(()=> load=false);
              });
            }, icon: Icon(Icons.video_file), label: Text(load?"RENDER...":"BUAT MP4"))),
            if(outVideo!=null) ElevatedButton.icon(onPressed: ()=> Share.shareXFiles([XFile(outVideo!.path)], text: "BABE.INFO Globe: https://afakhor.github.io/sponsorgawatbabeinfo/"), icon: Icon(Icons.share), label: Text("SHARE WA")),
          ]),
        )))),
      ]),
    );
  }
}