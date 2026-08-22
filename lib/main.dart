import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:three_js/three_js.dart' as three;
import 'package:file_picker/file_picker.dart';
import 'package:ffmpeg_kit_flutter_new_audio/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_audio/return_code.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cross_file/cross_file.dart';
import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:device_info_plus/device_info_plus.dart';

class AppTheme { final String name; final int globe; final int bg; final int accent; AppTheme(this.name,this.globe,this.bg,this.accent); }
final List<AppTheme> themes = [
  AppTheme("Luxurious Gold",0xFFD700,0x000000,0xFFD700),
  AppTheme("Royal Platinum",0xE5E4E2,0x111111,0xE5E4E2),
  AppTheme("Rose Gold",0xB76E79,0x1A0F10,0xB76E79),
  AppTheme("Deep Emerald",0x00A86B,0x0A1A0F,0x00A86B),
  AppTheme("Midnight Sapphire",0x0F52BA,0x080E1E,0x0F52BA),
  AppTheme("Ruby Velvet",0x9B111E,0x1A0A0A,0x9B111E),
  AppTheme("Obsidian Onyx",0x444444,0x000000,0x444444),
  AppTheme("Nordic Frost",0xADD8E6,0x101820,0xADD8E6),
  AppTheme("Desert Dune",0xC19A6B,0x1A1510,0xC19A6B),
  AppTheme("Champagne Glow",0xF7E7CE,0x151510,0xF7E7CE),
  AppTheme("Cyber Turquoise",0x40E0D0,0x0A1515,0x40E0D0),
  AppTheme("Sunset Magenta",0xFF4F8B,0x1A101A,0xFF4F8B),
  AppTheme("Amethyst Violet",0x9966CC,0x12101A,0x9966CC),
  AppTheme("Coffee Mocha",0x6F4E37,0x15100A,0x6F4E37),
  AppTheme("Sage Green",0x9CAF88,0x10150F,0x9CAF88),
  AppTheme("Copper Bronze",0xB87333,0x1A120A,0xB87333),
  AppTheme("Slate Monochrome",0x708090,0x101010,0x708090),
  AppTheme("Pearl White",0xF8F6F0,0x111111,0xF8F6F0),
  AppTheme("Ocean Trench",0x0A3D62,0x061020,0x0A3D62),
  AppTheme("Terracotta Warm",0xE2725B,0x1A100A,0xE2725B),
  AppTheme("Celestial Galaxy",0x9D4EDD,0x080410,0x9D4EDD),
];

void main()=>runApp(const MyApp());
class MyApp extends StatelessWidget{ const MyApp({super.key}); @override Widget build(BuildContext c)=>MaterialApp(debugShowCheckedModeBanner:false,theme:ThemeData.dark(),home:const GlobePage());}

class GlobePage extends StatefulWidget{const GlobePage({super.key});@override State<GlobePage> createState()=>_GlobePageState();}
class _GlobePageState extends State<GlobePage>{
  late three.ThreeJS threeJs;
  three.Mesh? globe; three.Mesh? glow; List<three.Mesh> rings=[]; three.Mesh? cube; three.Mesh? textLogo;
  bool inited=false; bool gpuSiap=false; Timer? rotTimer;
  int temaIdx=0; int modelIdx=0;
  File? audioFile,bgFile,outVideo; String? customTexPath;
  final player=PlayerController(); final recorder=RecorderController();
  double total=180,s=0,e=60; bool load=false, isRec=false;
  String status="GPU napas 4 detik..."; String runText="BABE.INFO HERU WINGCHUN";
  List<String> history=[]; double speed=1.0,pitch=1.0;

  @override void initState(){
    super.initState();
    threeJs=three.ThreeJS(
      setup: () {},
      onSetupComplete:(){ setup(); },
      settings: three.Settings(renderOptions:{"antialias":false,"alpha":true})
    );
    izin();
    Future.delayed(Duration(seconds:6),(){ if(!inited && mounted) setup(); });
  }
  Future<void> izin() async{ try{ var i=await DeviceInfoPlugin().androidInfo; if(i.version.sdkInt>=33){await Permission.audio.request();await Permission.photos.request();await Permission.microphone.request();} else{await Permission.storage.request();await Permission.microphone.request();} }catch(_){} loadHistory(); }
  void loadHistory() async{ var d=await getTemporaryDirectory(); var files=d.listSync().where((f)=>f.path.endsWith(".mp4")).map((e)=>e.path).toList(); setState(()=>history=files.reversed.take(20).toList()); }

    Future<void> setup() async{
    if(gpuSiap) return;
    if(mounted) setState(()=>status="GPU napas 4 detik...");
    await Future.delayed(Duration(seconds:4));
    if(threeJs.scene!=null) return;
    threeJs.scene=three.Scene();
    threeJs.scene.background=three.Color(0x000000.toDouble()); // Color pakai double
    double aspect = threeJs.width>0 && threeJs.height>0? threeJs.width/threeJs.height : 0.5625;
    threeJs.camera=three.PerspectiveCamera(45,aspect,0.1,1000); 
    threeJs.camera.position.z=3.2;
    threeJs.scene.add(three.AmbientLight(0xffffff,0.9)); // Light pakai INT!
    var l=three.DirectionalLight(0xffffff,1.2); // Light pakai INT!
    l.position.setValues(5,5,5); 
    threeJs.scene.add(l);
    buildModel();
    rotTimer?.cancel();
    rotTimer=Timer.periodic(Duration(milliseconds:16),(_){
      if(globe!=null){ globe!.rotation.y+=0.005; for(var r in rings) r.rotation.z+=0.003; }
      if(cube!=null){ cube!.rotation.y+=0.01; }
    });
    gpuSiap=true; 
    await Future.delayed(Duration(milliseconds:500)); 
    if(mounted) setState((){ inited=true; status="GLOBE OK"; });
  }

  void buildModel(){
    if(threeJs.scene==null) return;
    try{
      if(globe!=null) threeJs.scene.remove(globe!); if(glow!=null) threeJs.scene.remove(glow!); for(var r in rings) threeJs.scene.remove(r); if(cube!=null) threeJs.scene.remove(cube!); if(textLogo!=null) threeJs.scene.remove(textLogo!); rings.clear();
      var t=themes[temaIdx];
      if(modelIdx==0){
        var geo=three.SphereGeometry(0.9,40,40); var mat=three.MeshPhongMaterial(); mat.color=three.Color(t.globe.toDouble()); mat.shininess=60; // FIX toDouble
        globe=three.Mesh(geo,mat); globe!.position.y=0.1; threeJs.scene.add(globe!);
        var glowGeo=three.SphereGeometry(1.05,24,24); var glowMat=three.MeshBasicMaterial(); glowMat.color=three.Color(t.accent.toDouble()); glowMat.transparent=true; glowMat.opacity=0.12;
        glow=three.Mesh(glowGeo,glowMat); glow!.position.y=0.1; threeJs.scene.add(glow!);
        var torusGeo=three.TorusGeometry(1.0,0.018,10,70);
        for(int i=0;i<2;i++){ var m=three.MeshBasicMaterial(); m.color=three.Color(t.accent.toDouble()); m.transparent=true; m.opacity=0.5; var ring=three.Mesh(torusGeo,m.clone()); ring.rotation.x=i==0?0.6:1.3; ring.rotation.y=i==0?0:0.7; ring.position.y=0.1; rings.add(ring); threeJs.scene.add(ring); }
      } else if(modelIdx==1){ var geo=three.BoxGeometry(1.2,1.2,1.2); var mat=three.MeshPhongMaterial(); mat.color=three.Color(t.globe.toDouble()); cube=three.Mesh(geo,mat); cube!.position.y=0.1; threeJs.scene.add(cube!); globe=cube; }
      else { var geo=three.SphereGeometry(0.9,32,32); var mat=three.MeshPhongMaterial(); mat.color=three.Color(t.globe.toDouble()); globe=three.Mesh(geo,mat); globe!.position.y=0.1; threeJs.scene.add(globe!); }
      loadTex();
    }catch(e){ debugPrint("buildModel ERROR $e"); }
  }

  Future<void> loadTex() async{ try{ await Future.delayed(Duration(seconds:2)); var loader=three.TextureLoader(); three.Texture? tex; if(customTexPath!=null){ tex=await loader.fromAsset(customTexPath!); } else { try{ tex=await loader.fromAsset('assets/images/babe_gold.jpg'); }catch(_){}} if(tex!=null && globe!=null){ var m = globe!.material as three.MeshPhongMaterial; m.map=tex; m.needsUpdate=true; } }catch(e){debugPrint("tex fail $e");} }
  Future<void> pickCustomTex() async{ var r=await FilePicker.platform.pickFiles(type: FileType.image); if(r==null) return; customTexPath=r.files.single.path; await loadTex(); setState(()=>status="Skin custom OK"); }
  Future<void> pickAudio() async{ var r=await FilePicker.platform.pickFiles(type: FileType.any); if(r==null) return; var p=r.files.single.path!; if(p.endsWith(".mp4")||p.endsWith(".mov")){ setState(()=>status="Ekstrak audio..."); var tmp=await getTemporaryDirectory(); var out="${tmp.path}/ext_${DateTime.now().millisecondsSinceEpoch}.m4a"; await FFmpegKit.execute('-y -i "$p" -vn -c:a aac "$out"'); p=out; } File f=File(p); await player.preparePlayer(path:f.path,shouldExtractWaveform:true,noOfSamples:200); await Future.delayed(Duration(milliseconds:400)); var d=await player.getDuration(DurationType.max); setState((){audioFile=f; total=(d/1000).toDouble(); if(total<=0) total=180; s=0; e=total>60?60:total; status="Audio OK";}); }
  Future<void> pickBg() async{ var r=await FilePicker.platform.pickFiles(type: FileType.image); if(r==null) return; setState(()=>bgFile=File(r.files.single.path!)); }
  Future<void> toggleRec() async{ if(isRec){ var p=await recorder.stop(); if(p!=null){ File f=File(p); await player.preparePlayer(path:f.path,shouldExtractWaveform:true,noOfSamples:200); await Future.delayed(Duration(milliseconds:400)); var d=await player.getDuration(DurationType.max); setState((){audioFile=f; total=(d/1000).toDouble(); if(total<=0) total=180; s=0; e=total>60?60:total; isRec=false; status="Rekaman OK";}); } else { setState(()=>isRec=false); } }else{ var tmp=await getTemporaryDirectory(); var path="${tmp.path}/rec_${DateTime.now().millisecondsSinceEpoch}.m4a"; await recorder.record(path: path); setState(()=>isRec=true); } }
  Future<void> buatMp4() async{
    if(audioFile==null){setState(()=>status="Pilih musik dulu!"); return;}
    setState((){load=true; status="Render...";});
    try{
      await player.stopPlayer(); var tmp=await getTemporaryDirectory(); var ts=DateTime.now().millisecondsSinceEpoch; String trim="${tmp.path}/trim_$ts.m4a"; String out="${tmp.path}/BABE_${ts}.mp4"; double dur=e-s; if(dur<=0||dur>60) dur=60; if(dur<2) dur=5; String filter="atempo=$speed"; if(pitch!=1.0) filter+=",asetrate=44100*$pitch,aresample=44100"; var cmdTrim='-y -ss $s -t $dur -i "${audioFile!.path}" -filter:a "$filter" -c:a aac -b:a 128k "$trim"'; var s1=await FFmpegKit.execute(cmdTrim); if(!ReturnCode.isSuccess(await s1.getReturnCode())){ setState((){load=false; status="Trim gagal";}); return;} String bg=bgFile?.path??""; if(bg.isEmpty){ try{ var data=await DefaultAssetBundle.of(context).load('assets/images/bg.jpg'); File f=File('${tmp.path}/bg_$ts.jpg'); await f.writeAsBytes(data.buffer.asUint8List()); bg=f.path; }catch(_){bg="";} } String txtFilter=""; if(runText.isNotEmpty){ txtFilter=",drawtext=text='$runText':fontcolor=white:fontsize=32:x=w-mod(t*200\\,w+tw):y=h-th-20:box=1:boxcolor=black@0.5"; } String cmd; if(bg.isNotEmpty){ cmd='-y -loop 1 -i "$bg" -i "$trim" -c:v libx264 -preset ultrafast -pix_fmt yuv420p -vf "scale=720:1280:force_original_aspect_ratio=increase,crop=720:1280${txtFilter}" -c:a aac -shortest -t $dur "$out"'; }else{ cmd='-y -f lavfi -i color=c=black:s=720x1280:d=$dur -i "$trim" -c:v libx264 -preset ultrafast -pix_fmt yuv420p -vf "scale=720:1280${txtFilter}" -c:a aac -shortest -t $dur "$out"'; } var s2=await FFmpegKit.execute(cmd); if(ReturnCode.isSuccess(await s2.getReturnCode())){ setState((){outVideo=File(out); load=false; status="MP4 JADI!"; history.insert(0,out);}); }else{ setState((){load=false; status="MP4 gagal";}); } }catch(e){setState((){load=false; status="Error $e";});}
  }

  @override Widget build(BuildContext context){
    var w=MediaQuery.of(context).size.width; var th=themes[temaIdx];
    Widget bgW=bgFile!=null?Image.file(bgFile!,fit:BoxFit.cover,width:double.infinity,height:double.infinity):Image.asset('assets/images/bg.jpg',fit:BoxFit.cover,width:double.infinity,height:double.infinity,errorBuilder:(_,__,___)=>Container(color:Color(th.bg)));
    return Scaffold(backgroundColor:Color(th.bg),body:Stack(children:[
      Positioned.fill(child:bgW),
      Positioned(top:MediaQuery.of(context).padding.top+8,left:8,right:8,child:Container(padding:EdgeInsets.all(8),decoration:BoxDecoration(color:Colors.black87,borderRadius:BorderRadius.circular(10),border:Border.all(color:Color(th.accent))),child:Column(children:[
        Row(children:[Icon(Icons.public,color:Color(th.accent),size:16),SizedBox(width:6),Expanded(child:Text("${th.name} • ${['Globe','Cube','Ring','Logo'][modelIdx]}",style:TextStyle(fontSize:11,fontWeight:FontWeight.w900,color:Color(th.accent)))),Text(inited?"GLOBE OK":"LOADING...",style:TextStyle(fontSize:8,color:Colors.white70))]),
        SizedBox(height:6), SizedBox(height:30,child:ListView.builder(scrollDirection:Axis.horizontal,itemCount:themes.length,itemBuilder:(c,i)=>GestureDetector(onTap:(){setState(()=>temaIdx=i); buildModel();},child:Container(margin:EdgeInsets.only(right:6),padding:EdgeInsets.symmetric(horizontal:10,vertical:4),decoration:BoxDecoration(color:i==temaIdx?Color(th.accent):Colors.white12,borderRadius:BorderRadius.circular(20),border:Border.all(color:Color(themes[i].accent))),child:Text(themes[i].name.split(" ").first,style:TextStyle(fontSize:9,color:i==temaIdx?Colors.black:Colors.white)))))),
      ]))),
      Positioned(top:110,left:w/2-110,child:GestureDetector(onPanUpdate:(d){ if(globe!=null){ globe!.rotation.y+=d.delta.dx*0.015; globe!.rotation.x+=d.delta.dy*0.015; } }, onDoubleTap:(){ setState((){modelIdx=(modelIdx+1)%4;}); buildModel(); }, child:Container(width:220,height:220,decoration:BoxDecoration(shape:BoxShape.circle,border:Border.all(color:Color(th.accent),width:2)),child:ClipOval(child:threeJs.build())))),
      SafeArea(child:Align(alignment:Alignment.bottomCenter,child:SingleChildScrollView(child:Container(margin:EdgeInsets.all(10),padding:EdgeInsets.all(10),decoration:BoxDecoration(color:Colors.black.withOpacity(0.9),borderRadius:BorderRadius.circular(16),border:Border.all(color:Color(th.accent))),child:Column(mainAxisSize:MainAxisSize.min,children:[
        if(audioFile!=null) RangeSlider(min:0,max:total>0?total:1,values:RangeValues(s.clamp(0,total),e.clamp(s,total)),activeColor:Color(th.accent),inactiveColor:Colors.white24,onChanged:(v){ if(v.end-v.start<=60) setState((){s=v.start; e=v.end;}); }),
        Row(children:[
          Expanded(child:ElevatedButton.icon(onPressed:pickAudio,icon:Icon(Icons.music_note,size:14),label:Text("MUSIK",style:TextStyle(fontSize:9)),style:ElevatedButton.styleFrom(backgroundColor:Colors.white,foregroundColor:Colors.black))),
          SizedBox(width:4), Expanded(child:ElevatedButton.icon(onPressed:toggleRec,icon:Icon(isRec?Icons.stop:Icons.mic,size:14),label:Text(isRec?"STOP":"REC",style:TextStyle(fontSize:9)),style:ElevatedButton.styleFrom(backgroundColor:isRec?Colors.red:Color(th.accent),foregroundColor:Colors.black))),
          SizedBox(width:4), Expanded(child:ElevatedButton.icon(onPressed:pickBg,icon:Icon(Icons.image,size:14),label:Text("BG",style:TextStyle(fontSize:9)),style:ElevatedButton.styleFrom(backgroundColor:Color(th.accent),foregroundColor:Colors.black))),
          SizedBox(width:4), Expanded(child:ElevatedButton.icon(onPressed:pickCustomTex,icon:Icon(Icons.public,size:14),label:Text("SKIN",style:TextStyle(fontSize:9)),style:ElevatedButton.styleFrom(backgroundColor:Colors.amber,foregroundColor:Colors.black))),
        ]),
        SizedBox(height:6), SizedBox(width:double.infinity,child:ElevatedButton.icon(onPressed:load?null:buatMp4,icon:load?SizedBox(width:14,height:14,child:CircularProgressIndicator(strokeWidth:2)):Icon(Icons.video_file,size:14),label:Text(load?"RENDER...":"BUAT MP4",style:TextStyle(fontSize:11,fontWeight:FontWeight.bold)),style:ElevatedButton.styleFrom(backgroundColor:Colors.greenAccent,foregroundColor:Colors.black))),
        if(status.isNotEmpty) Padding(padding:EdgeInsets.only(top:4),child:Text(status,style:TextStyle(fontSize:9,color:Color(th.accent)))),
        if(outVideo!=null) SizedBox(width:double.infinity,child:ElevatedButton.icon(onPressed:() async{ await Share.shareXFiles([XFile(outVideo!.path)],text:runText); },icon:Icon(Icons.share,size:14),label:Text("SHARE WA STATUS",style:TextStyle(fontSize:11)),style:ElevatedButton.styleFrom(backgroundColor:Color(0xFF25D366),foregroundColor:Colors.white))),
      ]))))),
    ]));
  }
  @override void dispose(){ rotTimer?.cancel(); player.dispose(); recorder.dispose(); threeJs.dispose(); super.dispose(); }
}