import 'dart:io';
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:ffmpeg_kit_flutter_new_audio/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_audio/return_code.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cross_file/cross_file.dart';
import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/rendering.dart';

class AppTheme { final String name; final int accent; AppTheme(this.name,this.accent); }
final themes = [
  AppTheme("Luxurious Gold",0xFFD4AF37),
  AppTheme("Royal Platinum",0xFFC0C0C0),
  AppTheme("Midnight Sapphire",0xFF4FC3F7),
  AppTheme("Rose Gold",0xFFE8B4B8),
];

void main()=>runApp(const MyApp());
class MyApp extends StatelessWidget{ const MyApp({super.key}); @override Widget build(BuildContext c)=>MaterialApp(debugShowCheckedModeBanner:false,theme:ThemeData.dark(),home:const GlobePage());}

class GlobePage extends StatefulWidget{const GlobePage({super.key});@override State<GlobePage> createState()=>_GlobePageState();}
class _GlobePageState extends State<GlobePage> with SingleTickerProviderStateMixin{
  int temaIdx=0;
  double rotX=0.2, rotY=0.0, scale=1.0; bool dragging=false;
  late AnimationController ctrl;
  File? audioFile, bgFile, outVideo; String? customGlobePath;
  final player=PlayerController(); final recorder=RecorderController();
  double total=30,s=0,e=10; bool load=false, isRec=false;
  String status="Geser globe kiri kanan atas bawah!"; String runText="BABE.INFO (n/) By Heru Wingchun";
  double speed=1.0; double pitch=1.0;
  GlobalKey globeKey=GlobalKey();

  @override void initState(){
    super.initState();
    ctrl=AnimationController(vsync:this,duration:Duration(milliseconds:16))..addListener((){
      if(!dragging){ setState(()=> rotY+=0.006); }
    })..repeat();
    izin();
  }
  Future<void> izin() async{ try{ var i=await DeviceInfoPlugin().androidInfo; if(i.version.sdkInt>=33){await Permission.audio.request();await Permission.photos.request();await Permission.microphone.request();} else{await Permission.storage.request();await Permission.microphone.request();} }catch(_){} }

  // 1. UPLOAD MUSIK
  Future<void> pickAudio() async{
    var r=await FilePicker.platform.pickFiles(type: FileType.any); if(r==null) return;
    var p=r.files.single.path!; 
    if(p.endsWith(".mp4")||p.endsWith(".mov")){ setState(()=>status="Ekstrak audio..."); var tmp=await getTemporaryDirectory(); var out="${tmp.path}/ext_${DateTime.now().millisecondsSinceEpoch}.m4a"; await FFmpegKit.execute('-y -i "$p" -vn -c:a aac "$out"'); p=out; }
    File f=File(p); await player.preparePlayer(path:f.path,shouldExtractWaveform:true,noOfSamples:200);
    var d=await player.getDuration(DurationType.max);
    setState((){audioFile=f; total=(d/1000).toDouble(); if(total<=0) total=20; s=0; e=total>60?60:total; status="Upload Musik OK - ${f.path.split('/').last}";});
  }
  // 2. CREATE MUSIK (Generate tone)
  Future<void> createMusic() async{
    setState(()=>status="Create musik 8 detik...");
    var tmp=await getTemporaryDirectory(); var out="${tmp.path}/create_${DateTime.now().millisecondsSinceEpoch}.m4a";
    await FFmpegKit.execute('-y -f lavfi -i "sine=frequency=220:duration=8,afade=t=in:st=0:d=1,afade=t=out:st=7:d=1" -c:a aac "$out"');
    File f=File(out); await player.preparePlayer(path:f.path,shouldExtractWaveform:true,noOfSamples:100);
    var d=await player.getDuration(DurationType.max);
    setState((){audioFile=f; total=(d/1000).toDouble(); s=0; e=total; status="CREATE MUSIK OK!";});
  }
  Future<void> pickBg() async{ var r=await FilePicker.platform.pickFiles(type: FileType.image); if(r==null) return; setState(()=>bgFile=File(r.files.single.path!)); }
  Future<void> pickGlobe() async{ var r=await FilePicker.platform.pickFiles(type: FileType.image); if(r==null) return; setState(()=>customGlobePath=r.files.single.path!); }

  // 3. CREATE MUSIK VIA REC - FIX SYNTAX ERROR!
  Future<void> toggleRec() async{
    if(isRec){
      var p=await recorder.stop();
      if(p!=null){
        File f=File(p);
        await player.preparePlayer(path:f.path,shouldExtractWaveform:true,noOfSamples:200);
        var d=await player.getDuration(DurationType.max);
        setState((){
          audioFile=f; total=(d/1000).toDouble(); if(total<=0) total=10;
          s=0; e=total>60?60:total; isRec=false; status="REC OK - Bisa buat MP4";
        });
      }else{
        setState((){
          isRec=false;
        });
      }
    }else{
      var tmp=await getTemporaryDirectory();
      var path="${tmp.path}/rec_${DateTime.now().millisecondsSinceEpoch}.m4a";
      await recorder.record(path: path);
      setState((){
        isRec=true; status="Recording... ngomong!";
      });
    }
  }

  // 4. BUST VIDEO + GLOBE INTERAKTIF (Screenshot posisi globe terakhir)
  Future<void> bustVideo() async{
    if(audioFile==null){ setState(()=>status="Pilih CREATE / UPLOAD / REC dulu!"); return; }
    setState((){load=true; status="RENDER VIDEO + GLOBE...";});
    try{
      await player.stopPlayer();
      var tmp=await getTemporaryDirectory(); var ts=DateTime.now().millisecondsSinceEpoch;
      String trim="${tmp.path}/trim_$ts.m4a"; String globeImg="${tmp.path}/globe_$ts.png"; String out="${tmp.path}/BABE_$ts.mp4";
      double dur=e-s; if(dur<=0||dur>60) dur=10; if(dur<3) dur=3;

      // Screenshot globe sesuai geseran user
      try{
        RenderRepaintBoundary? b = globeKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
        if(b!=null){ var img=await b.toImage(pixelRatio:3); var bytes=await img.toByteData(format: ui.ImageByteFormat.png); await File(globeImg).writeAsBytes(bytes!.buffer.asUint8List()); }
      }catch(e){ debugPrint("screenshot $e"); }

      String filter="atempo=$speed"; if(pitch!=1.0) filter+=",asetrate=44100*$pitch,aresample=44100";
      await FFmpegKit.execute('-y -ss $s -t $dur -i "${audioFile!.path}" -filter:a "$filter" -c:a aac -b:a 128k "$trim"');

      String bg=bgFile?.path??""; 
      if(bg.isEmpty){ try{ var data=await DefaultAssetBundle.of(context).load('assets/images/bg.jpg'); File f=File('${tmp.path}/bg_$ts.jpg'); await f.writeAsBytes(data.buffer.asUint8List()); bg=f.path; }catch(_){} }

      String cmd;
      if(File(globeImg).existsSync() && bg.isNotEmpty){
        cmd='-y -loop 1 -i "$bg" -i "$globeImg" -i "$trim" -filter_complex "[0][1]overlay=(W-w)/2:(H-h)/2-120:format=auto,drawtext=text=\'$runText\':fontcolor=gold:fontsize=44:x=w-mod(t*180\\,w+tw):y=h-th-40:box=1:boxcolor=black@0.6" -c:v libx264 -preset ultrafast -pix_fmt yuv420p -c:a aac -shortest -t $dur "$out"';
      }else if(bg.isNotEmpty){
        cmd='-y -loop 1 -i "$bg" -i "$trim" -c:v libx264 -preset ultrafast -pix_fmt yuv420p -vf "scale=720:1280:force_original_aspect_ratio=increase,crop=720:1280,drawtext=text=\'$runText\':fontcolor=gold:fontsize=52:x=(w-text_w)/2:y=h-th-120:box=1:boxcolor=black@0.7" -c:a aac -shortest -t $dur "$out"';
      }else{
        cmd='-y -f lavfi -i color=c=black:s=720x1280:d=$dur -i "$trim" -c:v libx264 -preset ultrafast -vf "drawtext=text=\'$runText\':fontcolor=gold:fontsize=52:x=(w-text_w)/2:y=h-th-120" -c:a aac -shortest -t $dur "$out"';
      }
      var sess=await FFmpegKit.execute(cmd);
      if(ReturnCode.isSuccess(await sess.getReturnCode())){
        setState((){outVideo=File(out); load=false; status="VIDEO JADI! Globe interactive masuk!";});
      }else{ setState((){load=false; status="Video gagal";}); }
    }catch(e){ setState((){load=false; status="Error $e";}); }
  }

  @override Widget build(BuildContext context){
    var th=themes[temaIdx];
    Widget bgWidget = bgFile!=null? Image.file(bgFile!,fit:BoxFit.cover,width:double.infinity,height:double.infinity) : Image.asset('assets/images/bg.jpg',fit:BoxFit.cover,width:double.infinity,height:double.infinity,errorBuilder:(_,__,___)=>Container(color:Colors.black));

    Widget globeImage;
    if(customGlobePath!=null) globeImage=Image.file(File(customGlobePath!),fit:BoxFit.cover);
    else globeImage=Image.asset('assets/images/babe_gold.jpg',fit:BoxFit.cover,errorBuilder:(_,__,___)=>Container(color:Color(0xFFD4AF37)));

    return Scaffold(backgroundColor:Colors.black,body:Stack(children:[
      Positioned.fill(child:bgWidget),

      // HEADER - BACKGROUND HILANG FIX
      Positioned(top:MediaQuery.of(context).padding.top+8,left:10,right:10,child:Container(padding:EdgeInsets.all(10),decoration:BoxDecoration(color:Colors.black.withOpacity(0.75),borderRadius:BorderRadius.circular(12),border:Border.all(color:Color(th.accent))),child:Row(children:[
        Icon(Icons.public,color:Color(th.accent)), SizedBox(width:8),
        Expanded(child:Text("BABE.INFO • ${th.name} • Geser Globe!",style:TextStyle(color:Color(th.accent),fontWeight:FontWeight.bold,fontSize:12))),
        Container(padding:EdgeInsets.symmetric(horizontal:8,vertical:4),decoration:BoxDecoration(color:Colors.green,borderRadius:BorderRadius.circular(20)),child:Text("GLOBE INTERAKTIF OK",style:TextStyle(fontSize:9,color:Colors.white))),
      ])))),

      // GLOBE HILANG FIX + INTERAKTIF
      Positioned(top:120,left:0,right:0,child:Center(child:Column(children:[
        RepaintBoundary(key:globeKey, child:GestureDetector(
          onScaleStart:(_){ dragging=true; },
          onScaleUpdate:(d){
            setState((){
              rotY+=d.focalPointDelta.dx*0.01;
              rotX+=d.focalPointDelta.dy*0.01;
              rotX=rotX.clamp(-1.2,1.2);
              scale=(scale*d.scale).clamp(0.7,1.8);
            });
          },
          onScaleEnd:(_){ dragging=false; },
          child:Transform(
            alignment:Alignment.center,
            transform: Matrix4.identity()..setEntry(3,2,0.001)..rotateX(rotX)..rotateY(rotY)..scale(scale),
            child:Container(width:270,height:270,decoration:BoxDecoration(shape:BoxShape.circle,boxShadow:[BoxShadow(color:Color(th.accent).withOpacity(0.7),blurRadius:40,spreadRadius:8)],border:Border.all(color:Color(th.accent),width:2)),child:ClipOval(child:Stack(fit:StackFit.expand,children:[
              globeImage,
              Container(decoration:BoxDecoration(gradient:RadialGradient(colors:[Colors.white.withOpacity(0.35),Colors.transparent],center:Alignment(-0.3,-0.3),radius:0.7))),
            ]))),
          ),
        )),
        SizedBox(height:10),
        Text("👆 Geser Kiri Kanan Atas Bawah • Pinch Zoom • Background Ada!",style:TextStyle(color:Color(th.accent),fontSize:11,fontWeight:FontWeight.bold)),
        if(audioFile!=null) Container(margin:EdgeInsets.only(top:10),height:42,padding:EdgeInsets.symmetric(horizontal:20),child:AudioFileWaveforms(size:Size(MediaQuery.of(context).size.width-40,42),playerController:player,waveformType:WaveformType.long,playerWaveStyle:PlayerWaveStyle(fixedWaveColor:Colors.white30,liveWaveColor:Color(th.accent)))),
      ]))),

      // ALL POINT MASUK
      SafeArea(child:Align(alignment:Alignment.bottomCenter,child:Container(margin:EdgeInsets.all(10),padding:EdgeInsets.all(12),decoration:BoxDecoration(color:Colors.black.withOpacity(0.88),borderRadius:BorderRadius.circular(18),border:Border.all(color:Color(th.accent))),child:Column(mainAxisSize:MainAxisSize.min,children:[
        if(audioFile!=null) RangeSlider(min:0,max:total>0?total:1,values:RangeValues(s.clamp(0,total),e.clamp(s,total)),activeColor:Color(th.accent),inactiveColor:Colors.white24, onChanged:(v){ if(v.end-v.start<=60) setState((){s=v.start; e=v.end;}); }),
        Row(children:[
          Expanded(child:ElevatedButton.icon(onPressed:pickAudio,icon:Icon(Icons.upload,size:16),label:Text("UPLOAD",style:TextStyle(fontSize:10,fontWeight:FontWeight.bold)),style:ElevatedButton.styleFrom(backgroundColor:Colors.white,foregroundColor:Colors.black))),
          SizedBox(width:6),
          Expanded(child:ElevatedButton.icon(onPressed:createMusic,icon:Icon(Icons.auto_awesome,size:16),label:Text("CREATE",style:TextStyle(fontSize:10,fontWeight:FontWeight.bold)),style:ElevatedButton.styleFrom(backgroundColor:Color(th.accent),foregroundColor:Colors.black))),
          SizedBox(width:6),
          Expanded(child:ElevatedButton.icon(onPressed:toggleRec,icon:Icon(isRec?Icons.stop:Icons.mic,size:16),label:Text(isRec?"STOP":"REC",style:TextStyle(fontSize:10,fontWeight:FontWeight.bold)),style:ElevatedButton.styleFrom(backgroundColor:isRec?Colors.red:Colors.orange,foregroundColor:Colors.white))),
          SizedBox(width:6),
          Expanded(child:ElevatedButton.icon(onPressed:pickBg,icon:Icon(Icons.image,size:16),label:Text("BG",style:TextStyle(fontSize:10,fontWeight:FontWeight.bold)),style:ElevatedButton.styleFrom(backgroundColor:Colors.white12,foregroundColor:Colors.white))),
        ]),
        SizedBox(height:8),
        Row(children:[
          Expanded(child:ElevatedButton.icon(onPressed:pickGlobe,icon:Icon(Icons.public,size:16),label:Text("GLOBE IMG",style:TextStyle(fontSize:10)),style:ElevatedButton.styleFrom(backgroundColor:Colors.amber,foregroundColor:Colors.black))),
          SizedBox(width:8),
          Expanded(flex:2,child:ElevatedButton.icon(onPressed:load?null:bustVideo,icon:load?SizedBox(width:14,height:14,child:CircularProgressIndicator(strokeWidth:2,color:Colors.black)):Icon(Icons.videocam,size:18),label:Text(load?"RENDER...":"BUST VIDEO + GLOBE",style:TextStyle(fontSize:12,fontWeight:FontWeight.bold)),style:ElevatedButton.styleFrom(backgroundColor:Colors.greenAccent,foregroundColor:Colors.black,padding:EdgeInsets.symmetric(vertical:14)))),
        ]),
        SizedBox(height:6),
        Text(status,style:TextStyle(fontSize:10,color:Color(th.accent)),textAlign:TextAlign.center),
        if(outVideo!=null) Padding(padding:EdgeInsets.only(top:8),child:SizedBox(width:double.infinity,child:ElevatedButton.icon(onPressed:() async{ await Share.shareXFiles([XFile(outVideo!.path)],text:'$runText'); },icon:Icon(Icons.share),label:Text("SHARE VIDEO (Globe Geser Ikut)",style:TextStyle(fontSize:11,fontWeight:FontWeight.bold)),style:ElevatedButton.styleFrom(backgroundColor:Color(0xFF25D366),foregroundColor:Colors.white,padding:EdgeInsets.symmetric(vertical:12))))),
      ])))),
    ]));
  }
  @override void dispose(){ ctrl.dispose(); player.dispose(); recorder.dispose(); super.dispose(); }
}