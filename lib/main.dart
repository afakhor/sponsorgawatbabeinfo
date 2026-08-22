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

class AppTheme { final String name; final int globe; final int bg; final int accent; AppTheme(this.name,this.globe,this.bg,this.accent); }
final List<AppTheme> themes = [
  AppTheme("Luxurious Gold",0xFFD4AF37,0x000000,0xFFD700),
  AppTheme("Royal Platinum",0xE5E4E2,0x111111,0xC0C0C0),
  AppTheme("Rose Gold",0xB76E79,0x1A0F10,0xE8B4B8),
  AppTheme("Midnight",0x0F52BA,0x080E1E,0x4FC3F7),
];

void main()=>runApp(const MyApp());
class MyApp extends StatelessWidget{ const MyApp({super.key}); @override Widget build(BuildContext c)=>MaterialApp(debugShowCheckedModeBanner:false,theme:ThemeData.dark(),home:const GlobePage());}

class GlobePage extends StatefulWidget{const GlobePage({super.key});@override State<GlobePage> createState()=>_GlobePageState();}
class _GlobePageState extends State<GlobePage> with SingleTickerProviderStateMixin{
  int temaIdx=0;
  double rotX=0.2, rotY=0.5; double velX=0.008, velY=0;
  bool dragging=false;
  late AnimationController ctrl;
  File? audioFile,bgFile,outVideo; String? customGlobePath;
  final player=PlayerController(); final recorder=RecorderController();
  double total=180,s=0,e=60; bool load=false, isRec=false;
  String status="Globe Interaktif OK - Geser!"; String runText="BABE.INFO (n/) By Heru Wingchun";
  double speed=1.0,pitch=1.0;
  GlobalKey globeKey=GlobalKey();

  @override void initState(){
    super.initState();
    ctrl=AnimationController(vsync:this,duration:Duration(milliseconds:16))..addListener((){
      if(!dragging){ setState(()=> rotY+=velX); }
    })..repeat();
    izin();
  }
  Future<void> izin() async{ try{ var i=await DeviceInfoPlugin().androidInfo; if(i.version.sdkInt>=33){await Permission.audio.request();await Permission.photos.request();await Permission.microphone.request();} else{await Permission.storage.request();await Permission.microphone.request();} }catch(_){} }

  Future<void> pickAudio() async{ var r=await FilePicker.platform.pickFiles(type: FileType.any); if(r==null) return; var p=r.files.single.path!; if(p.endsWith(".mp4")||p.endsWith(".mov")){ setState(()=>status="Ekstrak audio..."); var tmp=await getTemporaryDirectory(); var out="${tmp.path}/ext_${DateTime.now().millisecondsSinceEpoch}.m4a"; await FFmpegKit.execute('-y -i "$p" -vn -c:a aac "$out"'); p=out; } File f=File(p); await player.preparePlayer(path:f.path,shouldExtractWaveform:true,noOfSamples:200); var d=await player.getDuration(DurationType.max); setState((){audioFile=f; total=(d/1000).toDouble(); if(total<=0) total=30; s=0; e=total>60?60:total; status="Musik OK";}); }
  Future<void> pickBg() async{ var r=await FilePicker.platform.pickFiles(type: FileType.image); if(r==null) return; setState(()=>bgFile=File(r.files.single.path!)); }
  Future<void> pickGlobeTex() async{ var r=await FilePicker.platform.pickFiles(type: FileType.image); if(r==null) return; setState(()=>customGlobePath=r.files.single.path!); }

  Future<void> createMusicTone() async{
    setState(()=>status="Create musik tone 5 detik...");
    var tmp=await getTemporaryDirectory(); var out="${tmp.path}/tone_${DateTime.now().millisecondsSinceEpoch}.m4a";
    await FFmpegKit.execute('-y -f lavfi -i "sine=frequency=440:duration=5" -c:a aac "$out"');
    File f=File(out); await player.preparePlayer(path:f.path,shouldExtractWaveform:true,noOfSamples:100); var d=await player.getDuration(DurationType.max); setState((){audioFile=f; total=(d/1000).toDouble(); s=0; e=total; status="Musik Tone Created!";});
  }

  Future<void> toggleRec() async{
    if(isRec){ var p=await recorder.stop(); if(p!=null){ File f=File(p); await player.preparePlayer(path:f.path,shouldExtractWaveform:true,noOfSamples:200); var d=await player.getDuration(DurationType.max); setState((){audioFile=f; total=(d/1000).toDouble(); if(total<=0) total=10; s=0; e=total>60?60:total; isRec=false; status="Rekaman OK - Bisa buat video";}); } else { setState(()=>isRec=false); } }
    else{ var tmp=await getTemporaryDirectory(); var path="${tmp.path}/rec_${DateTime.now().millisecondsSinceEpoch}.m4a"; await recorder.record(path: path); setState(()=>isRec=true; status="Recording..."); }
  }

  Future<void> buatVideo() async{
    if(audioFile==null){ setState(()=>status="Pilih/CREATE musik dulu! Pakai CREATE TONE atau REC"); return; }
    setState((){load=true; status="RENDER VIDEO + GLOBE...";});
    try{
      await player.stopPlayer();
      var tmp=await getTemporaryDirectory(); var ts=DateTime.now().millisecondsSinceEpoch;
      String trim="${tmp.path}/trim_$ts.m4a"; String globeImg="${tmp.path}/globe_$ts.png"; String out="${tmp.path}/BABE_${ts}.mp4";
      double dur=e-s; if(dur<=0||dur>60) dur=10; if(dur<3) dur=3;

      // 1. Screenshot globe yang lagi dirotasi user
      try{
        RenderRepaintBoundary? boundary = globeKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
        if(boundary!=null){ var img=await boundary.toImage(pixelRatio:3.0); var byte=await img.toByteData(format: ui.ImageByteFormat.png); await File(globeImg).writeAsBytes(byte!.buffer.asUint8List()); }
      }catch(e){ debugPrint("screenshot globe fail $e"); }

      // 2. Trim audio dengan speed & pitch
      String filter="atempo=$speed"; if(pitch!=1.0) filter+=",asetrate=44100*$pitch,aresample=44100";
      await FFmpegKit.execute('-y -ss $s -t $dur -i "${audioFile!.path}" -filter:a "$filter" -c:a aac -b:a 128k "$trim"');

      // 3. Siapkan BG
      String bg=bgFile?.path??""; if(bg.isEmpty){ try{ var data=await DefaultAssetBundle.of(context).load('assets/images/bg.jpg'); File f=File('${tmp.path}/bg_$ts.jpg'); await f.writeAsBytes(data.buffer.asUint8List()); bg=f.path; }catch(_){} }

      // 4. Render video: BG + globe overlay + running text
      String cmd;
      if(File(globeImg).existsSync() && bg.isNotEmpty){
        cmd='-y -loop 1 -i "$bg" -i "$globeImg" -i "$trim" -filter_complex "[0][1]overlay=(W-w)/2:(H-h)/2-100:format=auto,drawtext=text=\'$runText\':fontcolor=white:fontsize=42:x=w-mod(t*200\\,w+tw):y=h-th-30:box=1:boxcolor=black@0.6" -c:v libx264 -preset ultrafast -pix_fmt yuv420p -c:a aac -shortest -t $dur "$out"';
      } else if(bg.isNotEmpty){
        cmd='-y -loop 1 -i "$bg" -i "$trim" -c:v libx264 -preset ultrafast -pix_fmt yuv420p -vf "scale=720:1280:force_original_aspect_ratio=increase,crop=720:1280,drawtext=text=\'$runText\':fontcolor=gold:fontsize=48:x=(w-text_w)/2:y=h-th-100:box=1:boxcolor=black@0.7" -c:a aac -shortest -t $dur "$out"';
      } else {
        cmd='-y -f lavfi -i color=c=black:s=720x1280:d=$dur -i "$trim" -c:v libx264 -preset ultrafast -pix_fmt yuv420p -vf "drawtext=text=\'$runText\':fontcolor=gold:fontsize=48:x=(w-text_w)/2:y=h-th-100" -c:a aac -shortest -t $dur "$out"';
      }
      var s2=await FFmpegKit.execute(cmd);
      if(ReturnCode.isSuccess(await s2.getReturnCode())){ setState((){outVideo=File(out); load=false; status="VIDEO JADI! Globe + BG + Musik!";}); }
      else{ setState((){load=false; status="Video gagal, coba lagi";}); }
    }catch(e){ setState((){load=false; status="Error $e";}); }
  }

  @override Widget build(BuildContext context){
    var th=themes[temaIdx];
    Widget bgWidget = bgFile!=null? Image.file(bgFile!,fit:BoxFit.cover,width:double.infinity,height:double.infinity) : Image.asset('assets/images/bg.jpg',fit:BoxFit.cover,width:double.infinity,height:double.infinity,errorBuilder:(_,__,___)=>Container(decoration:BoxDecoration(gradient:LinearGradient(colors:[Color(0xFF000000),Color(th.bg)],begin:Alignment.topCenter,end:Alignment.bottomCenter))));

    return Scaffold(backgroundColor:Colors.black, body:Stack(children:[
      Positioned.fill(child:bgWidget),
      // Tema
      Positioned(top:MediaQuery.of(context).padding.top+8,left:12,right:12,child:Container(padding:EdgeInsets.all(8),decoration:BoxDecoration(color:Colors.black.withOpacity(0.7),borderRadius:BorderRadius.circular(12),border:Border.all(color:Color(th.accent))),child:Column(children:[
        Row(children:[Icon(Icons.public,color:Color(th.accent)),SizedBox(width:6),Expanded(child:Text(th.name,style:TextStyle(color:Color(th.accent),fontWeight:FontWeight.bold))),Container(padding:EdgeInsets.symmetric(horizontal:8,vertical:3),decoration:BoxDecoration(color:Colors.green,borderRadius:BorderRadius.circular(20)),child:Text("GLOBE INTERAKTIF OK",style:TextStyle(fontSize:9)))]),
        SizedBox(height:6), SizedBox(height:32,child:ListView.builder(scrollDirection:Axis.horizontal,itemCount:themes.length,itemBuilder:(c,i)=>GestureDetector(onTap:()=>setState(()=>temaIdx=i),child:Container(margin:EdgeInsets.only(right:8),padding:EdgeInsets.symmetric(horizontal:14,vertical:6),decoration:BoxDecoration(color:i==temaIdx?Color(th.accent):Colors.white12,borderRadius:BorderRadius.circular(20),border:Border.all(color:Color(themes[i].accent))),child:Center(child:Text(themes[i].name.split(" ").first,style:TextStyle(fontSize:11,color:i==temaIdx?Colors.black:Colors.white))))))),
      ]))),

      // GLOBE INTERAKTIF - BISA GESER ATAS BAWAH KIRI KANAN
      Positioned(top:130,left:0,right:0,child:Center(child:Column(children:[
        RepaintBoundary(key:globeKey, child:GestureDetector(
          onPanStart:(_){ dragging=true; velX=0; },
          onPanUpdate:(d){
            setState((){
              rotY += d.delta.dx * 0.01;
              rotX += d.delta.dy * 0.01;
              rotX = rotX.clamp(-1.0,1.0);
            });
          },
          onPanEnd:(d){
            dragging=false;
            velX = d.velocity.pixelsPerSecond.dx * 0.00002;
            setState(()=>status="Geser OK - Vel ${velX.toStringAsFixed(4)}");
          },
          onDoubleTap:(){ setState(()=>temaIdx=(temaIdx+1)%themes.length); },
          child:Container(width:260,height:260,decoration:BoxDecoration(shape:BoxShape.circle,boxShadow:[BoxShadow(color:Color(th.accent).withOpacity(0.6),blurRadius:30,spreadRadius:5)]),child:ClipOval(child:CustomPaint(size:Size(260,260), painter:ProGlobePainter(rotX, rotY, th.globe, th.accent, customGlobePath)))),
        )),
        SizedBox(height:12),
        Text("⬆️⬇️⬅️➡️ GESER GLOBE • DoubleTap Ganti Tema",style:TextStyle(color:Color(th.accent),fontSize:11,fontWeight:FontWeight.bold)),
        if(audioFile!=null) Container(margin:EdgeInsets.only(top:8),height:45,padding:EdgeInsets.symmetric(horizontal:20),child:AudioFileWaveforms(size:Size(MediaQuery.of(context).size.width-40,45),playerController:player,waveformType:WaveformType.long,playerWaveStyle:PlayerWaveStyle(fixedWaveColor:Colors.white24,liveWaveColor:Color(th.accent)))),
      ]))),

      // Controls - SEMUA POINT MASUK
      SafeArea(child:Align(alignment:Alignment.bottomCenter,child:Container(margin:EdgeInsets.all(10),padding:EdgeInsets.all(12),decoration:BoxDecoration(color:Colors.black.withOpacity(0.85),borderRadius:BorderRadius.circular(18),border:Border.all(color:Color(th.accent))),child:Column(mainAxisSize:MainAxisSize.min,children:[
        if(audioFile!=null) RangeSlider(min:0,max:total>0?total:1,values:RangeValues(s.clamp(0,total),e.clamp(s,total)),activeColor:Color(th.accent),inactiveColor:Colors.white24, onChanged:(v){ if(v.end-v.start<=60) setState((){s=v.start; e=v.end;}); }),
        Row(children:[
          Expanded(child:ElevatedButton.icon(onPressed:pickAudio,icon:Icon(Icons.music_note,size:16),label:Text("UPLOAD",style:TextStyle(fontSize:10)),style:ElevatedButton.styleFrom(backgroundColor:Colors.white,foregroundColor:Colors.black,padding:EdgeInsets.symmetric(vertical:10)))),
          SizedBox(width:6),
          Expanded(child:ElevatedButton.icon(onPressed:createMusicTone,icon:Icon(Icons.auto_awesome,size:16),label:Text("CREATE",style:TextStyle(fontSize:10)),style:ElevatedButton.styleFrom(backgroundColor:Color(th.accent),foregroundColor:Colors.black,padding:EdgeInsets.symmetric(vertical:10)))),
          SizedBox(width:6),
          Expanded(child:ElevatedButton.icon(onPressed:toggleRec,icon:Icon(isRec?Icons.stop:Icons.mic,size:16),label:Text(isRec?"STOP":"REC",style:TextStyle(fontSize:10)),style:ElevatedButton.styleFrom(backgroundColor:isRec?Colors.red:Colors.orange,foregroundColor:Colors.white,padding:EdgeInsets.symmetric(vertical:10)))),
          SizedBox(width:6),
          Expanded(child:ElevatedButton.icon(onPressed:pickBg,icon:Icon(Icons.image,size:16),label:Text("BG",style:TextStyle(fontSize:10)),style:ElevatedButton.styleFrom(backgroundColor:Color(0xFF444444),foregroundColor:Colors.white,padding:EdgeInsets.symmetric(vertical:10)))),
        ]),
        SizedBox(height:8),
        Row(children:[
          Expanded(child:ElevatedButton.icon(onPressed:pickGlobeTex,icon:Icon(Icons.public,size:16),label:Text("GLOBE IMG",style:TextStyle(fontSize:10)),style:ElevatedButton.styleFrom(backgroundColor:Colors.amber,foregroundColor:Colors.black))),
          SizedBox(width:8),
          Expanded(flex:2,child:ElevatedButton.icon(onPressed:load?null:buatVideo,icon:load?SizedBox(width:14,height:14,child:CircularProgressIndicator(strokeWidth:2,color:Colors.black)):Icon(Icons.video_file,size:18),label:Text(load?"RENDERING...":"BUST VIDEO + GLOBE",style:TextStyle(fontSize:12,fontWeight:FontWeight.bold)),style:ElevatedButton.styleFrom(backgroundColor:Colors.greenAccent,foregroundColor:Colors.black,padding:EdgeInsets.symmetric(vertical:12)))),
        ]),
        SizedBox(height:6),
        Text(status,style:TextStyle(fontSize:10,color:Color(th.accent)),textAlign:TextAlign.center),
        if(outVideo!=null) Padding(padding:EdgeInsets.only(top:8),child:SizedBox(width:double.infinity,child:ElevatedButton.icon(onPressed:() async{ await Share.shareXFiles([XFile(outVideo!.path)],text:'${runText}\n#BABEINFO #${th.name}'); },icon:Icon(Icons.share),label:Text("SHARE VIDEO WA STATUS (dengan globe geser)",style:TextStyle(fontSize:11,fontWeight:FontWeight.bold)),style:ElevatedButton.styleFrom(backgroundColor:Color(0xFF25D366),foregroundColor:Colors.white,padding:EdgeInsets.symmetric(vertical:12))))),
      ])))),
    ]));
  }
  @override void dispose(){ ctrl.dispose(); player.dispose(); recorder.dispose(); super.dispose(); }
}

class ProGlobePainter extends CustomPainter{
  final double rotX, rotY; final int col; final int accent; final String? imgPath;
  ProGlobePainter(this.rotX,this.rotY,this.col,this.accent,this.imgPath);
  @override void paint(Canvas canvas, Size size){
    var center=Offset(size.width/2,size.height/2); var radius=size.width/2;
    // Base gold
    var basePaint=Paint()..shader=RadialGradient(colors:[Color(0xFFFFE082),Color(col),Color(0xFF8D6E00)], center:Alignment(-0.3,-0.3), radius:1.2).createShader(Rect.fromCircle(center:center,radius:radius));
    canvas.drawCircle(center, radius, basePaint);
    // Texture BABE.INFO - simulasi
    var textPaint=TextPainter(text:TextSpan(text:"BABE.INFO ",style:TextStyle(color:Colors.black.withOpacity(0.9),fontSize:18,fontWeight:FontWeight.w900,letterSpacing:1)), textDirection:TextDirection.ltr)..layout();
    var accentPaint=Paint()..color=Color(accent).withOpacity(0.15)..style=PaintingStyle.stroke..strokeWidth=1.2;
    // Akar hitam seperti foto 2
    var rootPaint=Paint()..color=Colors.black.withOpacity(0.8)..style=PaintingStyle.stroke..strokeWidth=1.8..strokeCap=StrokeCap.round;
    // Gambar garis meridian yang bisa digeser
    for(int lon=0; lon<12; lon++){
      double angle = rotY*2 + lon * (math.pi/6);
      double cosA = math.cos(angle);
      if(cosA> -0.2){
        var path=Path();
        for(double lat=-1.3; lat<=1.3; lat+=0.05){
          double y = center.dy + math.sin(lat+rotX)*radius*0.95;
          double xFactor = math.cos(lat+rotX);
          double x = center.dx + cosA * xFactor * radius*0.95;
          if(lat==-1.3) path.moveTo(x,y); else path.lineTo(x,y);
        }
        canvas.drawPath(path, accentPaint);
      }
    }
    // Latitude
    for(int i=1;i<5;i++){
      double r = radius * (i/5.0);
      var oval = Rect.fromCircle(center:center, radius: r * math.cos(rotX).abs()*0.8 + r*0.2);
      canvas.drawOval(oval, accentPaint);
    }
    // Tulis BABE.INFO berulang dengan rotasi
    for(int i=0;i<6;i++){
      double a = rotY + i*1.1;
      double x = center.dx + math.cos(a)*radius*0.55;
      double y = center.dy + math.sin(a*0.7 + rotX)*radius*0.4;
      if(x>20 && x<size.width-60){
        canvas.save();
        canvas.translate(x,y);
        canvas.rotate(math.sin(a)*0.3);
        textPaint.paint(canvas, Offset(0,0));
        canvas.restore();
      }
    }
    // Akar-akar hitam random
    var rnd=math.Random(42);
    for(int i=0;i<8;i++){
      var p=Path();
      double sx = center.dx + (rnd.nextDouble()-0.5)*radius*1.8;
      double sy = center.dy + (rnd.nextDouble()-0.5)*radius*1.8;
      p.moveTo(sx,sy);
      for(int j=0;j<5;j++){ p.lineTo(sx+rnd.nextDouble()*40-20, sy+rnd.nextDouble()*40-20); }
      canvas.drawPath(p, rootPaint);
    }
    // Glossy highlight
    var gloss=Paint()..shader=RadialGradient(colors:[Colors.white.withOpacity(0.5),Colors.transparent], center:Alignment(-0.4,-0.4), radius:0.8).createShader(Rect.fromCircle(center:center,radius:radius));
    canvas.drawCircle(center, radius, gloss);
    var border=Paint()..color=Color(accent)..style=PaintingStyle.stroke..strokeWidth=2.5;
    canvas.drawCircle(center, radius, border);
  }
  @override bool shouldRepaint(covariant ProGlobePainter old)=> old.rotX!=rotX || old.rotY!=rotY || old.col!=col;
}