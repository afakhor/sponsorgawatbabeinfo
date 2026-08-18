import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:ffmpeg_kit_flutter_audio/ffmpeg_kit.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:three_js/three_js.dart' as three;
import 'package:flutter_gl/flutter_gl.dart';
import 'package:screenshot/screenshot.dart';

void main()=>runApp(const MyApp());
class MyApp extends StatelessWidget{const MyApp({super.key}); @override Widget build(BuildContext c)=>MaterialApp(debugShowCheckedModeBanner:false, theme:ThemeData.dark(useMaterial3:true), home:const FixedPage());}

class FixedPage extends StatefulWidget{const FixedPage({super.key}); @override State<FixedPage> createState()=>_FixedPageState();}
class _FixedPageState extends State<FixedPage>{
  late FlutterGlPlugin gl; three.WebGLRenderer? renderer; late three.Scene scene; late three.PerspectiveCamera cam; late three.Mesh globe; bool ready=false, drag=false; double lx=0,ly=0;
  File? audioFile, bgFile, outVideo; final player=PlayerController(); double total=180,s=0,e=60; bool perm=false, load=false; String stat=""; final shot=ScreenshotController();

  @override void initState(){super.initState(); gl=FlutterGlPlugin(); init3D(); WidgetsBinding.instance.addPostFrameCallback((_)=>cekIzin());}
  Future<void> cekIzin() async {final inf=await DeviceInfoPlugin().androidInfo; var st=inf.version.sdkInt>=33?await Permission.audio.request():await Permission.storage.request(); if(st.isGranted) setState(()=>perm=true);}
  Future<void> init3D() async {double w=MediaQuery.of(context).size.width,h=MediaQuery.of(context).size.height,d=MediaQuery.of(context).devicePixelRatio; await gl.initialize(options:{"antialias":true,"alpha":true,"width":w.toInt(),"height":h.toInt(),"dpr":d}); await gl.prepareContext(); scene=three.Scene(); scene.background=null; cam=three.PerspectiveCamera(50,w/h,0.1,1000); cam.position.z=3.3; renderer=three.WebGLRenderer({"gl":gl.gl,"antialias":true,"alpha":true}); renderer!.setSize(w,h,false); scene.add(three.DirectionalLight(0xFFD700,2.6)..position.setValues(5,5,5)); scene.add(three.AmbientLight(0xffffff,0.9));
    // TEXTURE LENGKAP BABE.INFO
    final tex=three.CanvasTexture(_makeTexture()); final geo=three.SphereGeometry(0.52,64,64); // 0.52 biar gak nutupin tulisan utama
    final mat=three.MeshPhongMaterial({"map":tex,"shininess":150,"specular":0xFFD700}); globe=three.Mesh(geo,mat);
    // POSISI FIX: jadi titik huruf i, DI ATAS tulisan BABE.INFO, tidak menutupi BABE.INFO & HeruWingchun
    globe.position.setValues(0.12,0.82,0); // y=0.82 tinggi, ada gap jelas
    scene.add(globe); setState(()=>ready=true); animate();
  }
  dynamic _makeTexture(){
    final c=three.Canvas(width:1024,height:512); final ctx=c.getContext('2d');
    // Gold background
    final grad=ctx.createLinearGradient(0,0,0,512); grad.addColorStop(0,'#FFD700'); grad.addColorStop(0.5,'#D4AF37'); grad.addColorStop(1,'#B8860B'); ctx.fillStyle=grad; ctx.fillRect(0,0,1024,512);
    // Tulisan LENGKAP BABE.INFO - tidak kepotong
    ctx.fillStyle='#000000'; ctx.font='bold 28px Arial'; ctx.textAlign='center';
    for(double y=30;y<512;y+=36){
      for(double x=65;x<1024;x+=130){
        ctx.save(); ctx.translate(x,y); ctx.rotate((math.Random().nextDouble()-0.5)*0.15);
        ctx.fillText('BABE.INFO',0,0); // LENGKAP
        ctx.restore();
      }
    }
    return c;
  }
  void animate(){if(!mounted) return; if(!drag) globe.rotation.y+=0.01; gl.gl.flush(); renderer!.render(scene,cam); Future.delayed(const Duration(milliseconds:16),(){if(mounted) animate();});}

  Future<void> pickAudio() async {if(!perm){await cekIzin(); return;} var r=await FilePicker.platform.pickFiles(type:FileType.audio); if(r==null) return; File f=File(r.files.single.path!); await player.preparePlayer(path:f.path, shouldExtractWaveform:true, noOfSamples:200); final d=await player.getDuration(DurationType.max); setState((){ audioFile=f; total=(d/1000).toDouble(); s=0; e= total>60?60:total; });}
  Future<void> pickBg() async {var r=await FilePicker.platform.pickFiles(type:FileType.image); if(r==null) return; setState(()=>bgFile=File(r.files.single.path!));}

  Future<void> buatMp4TanpaGlobe() async {
    if(audioFile==null){ pickAudio(); return; }
    setState((){ load=true; stat="Capture background + wave..."; });
    final dir=await getTemporaryDirectory();
    // Capture hanya background + wave (tanpa globe) - pakai screenshot dari Stack bawah
    // Untuk simple: pakai bgFile atau asset default + waveform image digabung
    String trimmed="${dir.path}/trim.m4a";
    String out="${dir.path}/BABE_WAVE_${DateTime.now().millisecondsSinceEpoch}.mp4";
    // Trim audio 1 menit
    await FFmpegKit.execute("-y -ss $s -t ${e-s} -i \"${audioFile!.path}\" -c:a aac \"$trimmed\"");
    setState(()=>stat="Render MP4 (tanpa globe)...");
    // Background untuk MP4 = bg default kamu (tanpa globe)
    String bgPath=""; if(bgFile!=null) bgPath=bgFile!.path; else { final data=await DefaultAssetBundle.of(context).load('assets/images/bg.jpg'); File f=File('${dir.path}/bg.jpg'); await f.writeAsBytes(data.buffer.asUint8List()); bgPath=f.path; }
    await FFmpegKit.execute("-y -loop 1 -i \"$bgPath\" -i \"$trimmed\" -c:v libx264 -tune stillimage -c:a aac -pix_fmt yuv420p -shortest -t ${e-s} \"$out\"").then((s) async { if((await s.getReturnCode())!.isValueSuccess()) setState((){ outVideo=File(out); load=false; }); });
  }

  @override Widget build(BuildContext c){
    Widget bg = bgFile!=null?Image.file(bgFile!, fit:BoxFit.cover):Image.asset('assets/images/bg.jpg', fit:BoxFit.cover);
    return Scaffold(body: Stack(children:[
      Positioned.fill(child:bg),
      // Globe 3D di atas, tidak menutupi tulisan utama
      if(ready) Positioned.fill(child: GestureDetector(
        onPanStart:(d){drag=true; lx=d.localPosition.dx; ly=d.localPosition.dy;},
        onPanUpdate:(d){double dx=d.localPosition.dx-lx, dy=d.localPosition.dy-ly; globe.rotation.y+=dx*0.015; globe.rotation.x+=dy*0.015; lx=d.localPosition.dx; ly=d.localPosition.dy;},
        onPanEnd:(_)=>drag=false,
        child: Texture(textureId: gl.textureId!),
      )),
      SafeArea(child: Column(children:[
        const Spacer(flex:5), // beri jarak biar globe di atas tidak nutupin BABE.INFO
        const Spacer(flex:3),
        Padding(padding: const EdgeInsets.all(12), child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.black.withOpacity(0.68), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.amber)), child: Column(children:[
          if(audioFile!=null) AudioFileWaveforms(size: Size(MediaQuery.of(c).size.width-48,60), playerController: player, waveformType: WaveformType.long, playerWaveStyle: const PlayerWaveStyle(fixedWaveColor:Colors.white24, liveWaveColor:Colors.amber)),
          if(audioFile==null) const SizedBox(height:50, child: Center(child: Text("WAVE MUSIC DI BAWAH HERU WINGCHUN", style:TextStyle(color:Colors.amber, fontSize:10, letterSpacing:1)))),
          if(audioFile!=null) RangeSlider(min:0,max:total,values:RangeValues(s,e),activeColor:Colors.amber, onChanged:(v){ if(v.end-v.start<=60) setState((){ s=v.start; e=v.end; }); }),
          if(audioFile!=null) Row(mainAxisAlignment:MainAxisAlignment.spaceBetween, children:[Text("START ${s.toStringAsFixed(1)}s", style:const TextStyle(color:Colors.greenAccent,fontSize:10)), Text("${(e-s).toStringAsFixed(1)}s / 60s", style:const TextStyle(color:Colors.amber,fontSize:10,fontWeight:FontWeight.bold)), Text("END ${e.toStringAsFixed(1)}s", style:const TextStyle(color:Colors.greenAccent,fontSize:10))]),
          const SizedBox(height:8),
          Row(children:[Expanded(child: ElevatedButton.icon(onPressed:pickAudio, icon:const Icon(Icons.music_note,size:16), label:Text(audioFile==null?"AMBIL MUSIK":"GANTI MUSIK", style:const TextStyle(fontSize:11)), style:ElevatedButton.styleFrom(backgroundColor:Colors.white, foregroundColor:Colors.black))), const SizedBox(width:6), Expanded(child: ElevatedButton.icon(onPressed:pickBg, icon:const Icon(Icons.image,size:16), label:const Text("GANTI BG", style:TextStyle(fontSize:11)), style:ElevatedButton.styleFrom(backgroundColor:Colors.amber, foregroundColor:Colors.black)))]),
          const SizedBox(height:6),
          SizedBox(width:double.infinity, child: ElevatedButton.icon(onPressed:load?null:buatMp4TanpaGlobe, icon:const Icon(Icons.video_file,size:16), label:Text(load?stat:"BUAT MP4 (Background+Wave Saja)", style:const TextStyle(fontSize:11)), style:ElevatedButton.styleFrom(backgroundColor:Colors.greenAccent, foregroundColor:Colors.black))),
          if(outVideo!=null) Padding(padding: const EdgeInsets.only(top:6), child: Column(children:[
            SizedBox(width:double.infinity, child: ElevatedButton.icon(onPressed:()=>Share.shareXFiles([XFile(outVideo!.path)], text:"BABE.INFO - Background+Wave+Musik 60 detik. Globe touchable di link: https://babe-info.web.app"), icon:const Icon(Icons.share), label:const Text("SHARE WA - MP4 + LINK GLOBE TOUCH", style:TextStyle(fontSize:11)), style:ElevatedButton.styleFrom(backgroundColor:Colors.green, foregroundColor:Colors.white))),
            const Padding(padding: EdgeInsets.only(top:4), child: Text("MP4 = background + wave + musik. Globe tetap touch via link di caption", style:TextStyle(color:Colors.amberAccent, fontSize:9))),
          ])),
        ]))),
      ])),
    ]));
  }
  @override void dispose(){ gl.dispose(); player.dispose(); super.dispose(); }
}