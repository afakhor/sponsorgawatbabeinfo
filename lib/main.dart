import 'dart:io';
import 'package:flutter/material.dart';
import 'package:three_js/three_js.dart' as three;
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
  @override Widget build(BuildContext c) => MaterialApp(debugShowCheckedModeBanner: false, theme: ThemeData.dark().copyWith(scaffoldBackgroundColor: Colors.transparent), home: const GlobeLearnPage());
}
class GlobeLearnPage extends StatefulWidget { const GlobeLearnPage({super.key}); @override State<GlobeLearnPage> createState()=>_GlobeLearnPageState(); }
class _GlobeLearnPageState extends State<GlobeLearnPage> {
  late three.ThreeJS threeJs;
  three.Mesh? globe;
  bool inited=false;
  File? audioFile, bgFile, outVideo;
  final player = PlayerController();
  double total=180,s=0,e=60; bool load=false;

  @override void initState(){
    super.initState();
    threeJs = three.ThreeJS(onSetupComplete: (){ setState((){}); }, setup: setupGlobe);
    cekIzin();
  }
  Future<void> cekIzin() async {
    try{
      final inf=await DeviceInfoPlugin().androidInfo;
      if(inf.version.sdkInt>=33){ await Permission.audio.request(); await Permission.photos.request(); }
      else { await Permission.storage.request(); }
    }catch(_){}
  }
  Future<void> setupGlobe() async {
    threeJs.scene = three.Scene();
    threeJs.camera = three.PerspectiveCamera(45, threeJs.width/threeJs.height, 0.1, 1000);
    threeJs.camera.position.z = 2.8;
    threeJs.scene.add(three.AmbientLight(0xffffff, 0.8));
    var dir = three.DirectionalLight(0xffffff, 1.2); dir.position.setValues(5,3,5); threeJs.scene.add(dir);
    
    var geo = three.SphereGeometry(1, 64, 64);
    var mat = three.MeshPhongMaterial(); // Phong lebih kompatibel dari Standard
    mat.color = three.Color(0xFFD700);
    globe = three.Mesh(geo, mat);
    globe!.position.y=0.1;
    threeJs.scene.add(globe!);

    var torusGeo = three.TorusGeometry(1.05, 0.02, 12, 100);
    var torusMat = three.MeshBasicMaterial(); torusMat.color = three.Color(0x111111);
    for(int i=0;i<3;i++){
      var t = three.Mesh(torusGeo, torusMat);
      t.rotation.x = i*1.2; t.rotation.y = i*0.8; t.position.y=0.1;
      threeJs.scene.add(t);
    }
    // texture - coba load kalau ada
    try{
      final tex = await three.TextureLoader().loadAsync('assets/images/babe_gold.jpg', threeJs);
      if(tex!=null){ mat.map = tex; mat.needsUpdate=true; }
    }catch(e){ debugPrint("tex fail $e"); }
    
    inited=true;
    threeJs.addAnimationEvent((dt){ globe?.rotation.y = (globe?.rotation.y ?? 0) + 0.008; });
  }

  Future<void> pickAudio() async {
    try{
      var r=await FilePicker.platform.pickFiles(type: FileType.audio); if(r==null) return;
      File f=File(r.files.single.path!); await player.preparePlayer(path: f.path, shouldExtractWaveform: true, noOfSamples: 200);
      final d=await player.getDuration(DurationType.max);
      setState((){ audioFile=f; total=(d/1000).toDouble(); s=0; e= total>60?60:total; outVideo=null; });
    }catch(e){ debugPrint("$e"); }
  }
  Future<void> pickBg() async {
    try{
      var r=await FilePicker.platform.pickFiles(type: FileType.image); if(r==null) return;
      setState((){ bgFile=File(r.files.single.path!); outVideo=null; });
    }catch(e){ debugPrint("$e"); }
  }
  Future<void> buatMp4() async {
    if(audioFile==null){ pickAudio(); return; }
    setState(()=>load=true);
    try{
      await player.stopPlayer(); await Future.delayed(Duration(milliseconds:200));
      final tmp=await getTemporaryDirectory(); final ts=DateTime.now().millisecondsSinceEpoch;
      String trim="${tmp.path}/trim_$ts.m4a"; String out="${tmp.path}/BABE_$ts.mp4";
      double dur=e-s; if(dur<=0) dur=5;
      var s1=await FFmpegKit.execute("-y -ss $s -t $dur -i \"${audioFile!.path}\" -c:a aac \"$trim\"");
      if(!ReturnCode.isSuccess(await s1.getReturnCode())){ setState(()=>load=false); return; }
      String bg=bgFile?.path ?? "";
      if(bg.isEmpty){ final data=await DefaultAssetBundle.of(context).load('assets/images/bg.jpg'); File f=File('${tmp.path}/bg_$ts.jpg'); await f.writeAsBytes(data.buffer.asUint8List()); bg=f.path; }
      String cmd="-y -loop 1 -i \"$bg\" -i \"$trim\" -c:v libx264 -preset ultrafast -pix_fmt yuv420p -c:a aac -shortest -t $dur \"$out\"";
      var s2=await FFmpegKit.execute(cmd);
      if(ReturnCode.isSuccess(await s2.getReturnCode())){ setState((){ outVideo=File(out); load=false; }); } else { setState(()=>load=false); }
    }catch(e){ setState(()=>load=false); }
  }

  @override Widget build(BuildContext context){
    double w=MediaQuery.of(context).size.width;
    Widget bgW = bgFile!=null ? Image.file(bgFile!, fit: BoxFit.cover, width: double.infinity, height: double.infinity) : Image.asset('assets/images/bg.jpg', fit: BoxFit.cover, width: double.infinity, height: double.infinity, errorBuilder: (_,__,___)=>Container(color: Colors.black));
    return Scaffold(backgroundColor: Colors.transparent, body: Stack(children:[
      Positioned.fill(child: bgW),
      Positioned(top: MediaQuery.of(context).padding.top+12, left:16, child: Container(padding: EdgeInsets.symmetric(horizontal:10, vertical:4), decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(6), border: Border.all(color: Color(0xFFFFD700).withOpacity(0.6))), child: Text("BABE.INFO HERU WINGCHUN", style: TextStyle(fontSize:14, fontWeight: FontWeight.w900, color: Color(0xFFFFD700))))),
      Positioned(top: MediaQuery.of(context).padding.top+60, left: w/2-140, child: Container(width:280, height:280, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.amber, width:2)), child: ClipOval(child: threeJs.build()))),
      SafeArea(child: Align(alignment: Alignment.bottomCenter, child: Padding(padding: EdgeInsets.all(12), child: Container(padding: EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.black.withOpacity(0.85), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.amber.withOpacity(0.8))), child: Column(mainAxisSize: MainAxisSize.min, children:[
        if(audioFile!=null) AudioFileWaveforms(size: Size(w-48,60), playerController: player, waveformType: WaveformType.long, playerWaveStyle: PlayerWaveStyle(fixedWaveColor: Colors.white24, liveWaveColor: Colors.amber)),
        if(audioFile!=null) RangeSlider(min:0, max: total>0?total:1, values: RangeValues(s.clamp(0,total), e.clamp(s,total)), activeColor: Colors.amber, onChanged: (v){ if(v.end-v.start<=60) setState((){ s=v.start; e=v.end; }); }),
        Row(children:[
          Expanded(child: ElevatedButton.icon(onPressed: pickAudio, icon: Icon(Icons.music_note), label: Text(audioFile==null?"AMBIL MUSIK":"GANTI", style: TextStyle(fontSize:11)), style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black))),
          SizedBox(width:6),
          Expanded(child: ElevatedButton.icon(onPressed: pickBg, icon: Icon(Icons.image), label: Text("BG", style: TextStyle(fontSize:11)), style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black))),
        ]),
        SizedBox(height:6),
        SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: load?null:buatMp4, icon: load?SizedBox(width:16,height:16,child:CircularProgressIndicator(strokeWidth:2)):Icon(Icons.video_file), label: Text(load?"MERENDER...":"BUAT MP4", style: TextStyle(fontSize:11, fontWeight: FontWeight.bold)), style: ElevatedButton.styleFrom(backgroundColor: load?Colors.grey:Colors.greenAccent, foregroundColor: Colors.black))),
        if(outVideo!=null) ...[SizedBox(height:8), SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: (){ Share.shareXFiles([XFile(outVideo!.path)], text: 'BABE.INFO HERU WINGCHUN'); }, icon: Icon(Icons.share), label: Text("SHARE KE WA STATUS", style: TextStyle(fontSize:12, fontWeight: FontWeight.bold)), style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white)))]
      ]))))),
    ]));
  }
  @override void dispose(){ player.dispose(); threeJs.dispose(); super.dispose(); }
}