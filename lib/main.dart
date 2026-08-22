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
final themes = [AppTheme("Lux Gold",0xFFD4AF37),AppTheme("Platinum",0xFFC0C0C0),AppTheme("Midnight",0xFF4FC3F7)];

void main()=>runApp(const MyApp());
class MyApp extends StatelessWidget{ const MyApp({super.key}); @override Widget build(BuildContext c)=>MaterialApp(debugShowCheckedModeBanner:false,theme:ThemeData.dark(),home:const GlobePage());}

class GlobePage extends StatefulWidget{const GlobePage({super.key});@override State<GlobePage> createState()=>_GlobePageState();}
class _GlobePageState extends State<GlobePage> with SingleTickerProviderStateMixin{
  int temaIdx=0; double rotX=0.3, rotY=0.0, scale=1.0; bool dragging=false;
  late AnimationController ctrl;
  File? audioFile, bgFile, outVideo; String? customGlobePath;
  final player=PlayerController(); final recorder=RecorderController();
  double total=30,s=0,e=10; bool load=false, isRec=false;
  String status="REAL 3D MATH - Geser!"; String runText="BABE.INFO";
  GlobalKey globeKey=GlobalKey();

  @override void initState(){
    super.initState();
    ctrl=AnimationController(vsync:this,duration:Duration(milliseconds:16))..addListener((){
      if(!dragging){ setState(()=> rotY+=0.015); }
    })..repeat();
    izin();
  }
  Future<void> izin() async{ try{ var i=await DeviceInfoPlugin().androidInfo; if(i.version.sdkInt>=33){await Permission.audio.request();await Permission.photos.request();await Permission.microphone.request();} else{await Permission.storage.request();await Permission.microphone.request();} }catch(_){} }

  Future<void> pickAudio() async{ var r=await FilePicker.platform.pickFiles(type: FileType.any); if(r==null) return; var p=r.files.single.path!; if(p.endsWith(".mp4")){ var tmp=await getTemporaryDirectory(); var out="${tmp.path}/ext.m4a"; await FFmpegKit.execute('-y -i "$p" -vn -c:a aac "$out"'); p=out; } File f=File(p); await player.preparePlayer(path:f.path,shouldExtractWaveform:true,noOfSamples:200); var d=await player.getDuration(DurationType.max); setState((){audioFile=f; total=(d/1000).toDouble(); s=0; e=total>60?60:total; status="Musik OK";}); }
  Future<void> createMusic() async{ var tmp=await getTemporaryDirectory(); var out="${tmp.path}/tone.m4a"; await FFmpegKit.execute('-y -f lavfi -i "sine=frequency=220:duration=8" -c:a aac "$out"'); File f=File(out); await player.preparePlayer(path:f.path,shouldExtractWaveform:true,noOfSamples:100); setState((){audioFile=f; total=8; s=0; e=8; status="CREATE MUSIK OK";}); }
  Future<void> pickBg() async{ var r=await FilePicker.platform.pickFiles(type: FileType.image); if(r==null) return; setState(()=>bgFile=File(r.files.single.path!)); }
  Future<void> pickGlobe() async{ var r=await FilePicker.platform.pickFiles(type: FileType.image); if(r==null) return; setState(()=>customGlobePath=r.files.single.path!); }
  Future<void> toggleRec() async{
    if(isRec){ var p=await recorder.stop(); if(p!=null){ File f=File(p); await player.preparePlayer(path:f.path,shouldExtractWaveform:true,noOfSamples:200); var d=await player.getDuration(DurationType.max); setState((){audioFile=f; total=(d/1000).toDouble(); s=0; e=total; isRec=false; status="REC OK";}); } else { setState((){isRec=false;}); } }
    else{ var tmp=await getTemporaryDirectory(); var path="${tmp.path}/rec.m4a"; await recorder.record(path: path); setState((){isRec=true; status="Recording...";}); }
  }
  Future<void> bustVideo() async{
    if(audioFile==null){ setState(()=>status="Pilih musik dulu!"); return; }
    setState((){load=true; status="RENDER REAL 3D...";});
    try{
      await player.stopPlayer(); var tmp=await getTemporaryDirectory(); var ts=DateTime.now().millisecondsSinceEpoch;
      String trim="${tmp.path}/trim_$ts.m4a"; String globeImg="${tmp.path}/globe_$ts.png"; String out="${tmp.path}/BABE_$ts.mp4"; double dur=e-s; if(dur<3) dur=5; if(dur>60) dur=10;
      try{ RenderRepaintBoundary? b=globeKey.currentContext?.findRenderObject() as RenderRepaintBoundary?; if(b!=null){ var img=await b.toImage(pixelRatio:3); var by=await img.toByteData(format: ui.ImageByteFormat.png); await File(globeImg).writeAsBytes(by!.buffer.asUint8List()); } }catch(_){}
      await FFmpegKit.execute('-y -ss $s -t $dur -i "${audioFile!.path}" -c:a aac "$trim"');
      String bg=bgFile?.path??""; if(bg.isEmpty){ try{ var data=await DefaultAssetBundle.of(context).load('assets/images/bg.jpg'); File f=File('${tmp.path}/bg_$ts.jpg'); await f.writeAsBytes(data.buffer.asUint8List()); bg=f.path; }catch(_){} }
      String cmd; if(File(globeImg).existsSync() && bg.isNotEmpty){ cmd='-y -loop 1 -i "$bg" -i "$globeImg" -i "$trim" -filter_complex "[0][1]overlay=(W-w)/2:(H-h)/2-100,drawtext=text=\'$runText\':fontcolor=gold:fontsize=48:x=w-mod(t*180\\,w+tw):y=h-th-40:box=1:boxcolor=black@0.6" -c:v libx264 -preset ultrafast -pix_fmt yuv420p -c:a aac -shortest -t $dur "$out"'; } else { cmd='-y -loop 1 -i "$bg" -i "$trim" -c:v libx264 -preset ultrafast -pix_fmt yuv420p -c:a aac -shortest -t $dur "$out"'; }
      var se=await FFmpegKit.execute(cmd); if(ReturnCode.isSuccess(await se.getReturnCode())){ setState((){outVideo=File(out); load=false; status="VIDEO REAL 3D JADI!";}); } else { setState((){load=false; status="Gagal";}); }
    }catch(e){ setState((){load=false; status="Error $e";}); }
  }

  @override Widget build(BuildContext context){
    var th=themes[temaIdx];
    Widget bgW = bgFile!=null? Image.file(bgFile!,fit:BoxFit.cover,width:double.infinity,height:double.infinity) : Image.asset('assets/images/bg.jpg',fit:BoxFit.cover,width:double.infinity,height:double.infinity,errorBuilder:(_,__,___)=>Container(color:Colors.black));
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children:[
        Positioned.fill(child: bgW),
        Positioned(top:MediaQuery.of(context).padding.top+8,left:10,right:10,child:Container(padding:EdgeInsets.all(10),decoration:BoxDecoration(color:Colors.black87,borderRadius:BorderRadius.circular(12),border:Border.all(color:Color(th.accent))),child:Row(children:[Icon(Icons.public,color:Color(th.accent)),SizedBox(width:8),Expanded(child:Text("REAL 3D MATH GLOBE • ${th.name}",style:TextStyle(color:Color(th.accent),fontWeight:FontWeight.bold))),Container(padding:EdgeInsets.symmetric(horizontal:8,vertical:4),decoration:BoxDecoration(color:Colors.green,borderRadius:BorderRadius.circular(20)),child:Text("3D OK",style:TextStyle(fontSize:9,color:Colors.white))) ]))),
        Positioned(top:120,left:0,right:0,child:Center(child:Column(children:[
          RepaintBoundary(key:globeKey, child:GestureDetector(
            onScaleStart: (_){ dragging=true; },
            onScaleUpdate: (d){ setState((){ rotY+=d.focalPointDelta.dx*0.01; rotX+=d.focalPointDelta.dy*0.01; rotX=rotX.clamp(-1.4,1.4); scale=(scale*d.scale).clamp(0.6,1.8); }); },
            onScaleEnd: (_){ dragging=false; },
            child:Transform(alignment:Alignment.center,transform: Matrix4.identity()..scale(scale),child:Container(width:300,height:300,child:CustomPaint(size:Size(300,300), painter:Real3DGlobePainter(rotX, rotY, th.accent, customGlobePath)))),
          )),
          SizedBox(height:12), Text("REAL 3D: rotX=${rotX.toStringAsFixed(2)} rotY=${rotY.toStringAsFixed(2)} • Geser Atas Bawah Kiri Kanan",style:TextStyle(color:Color(th.accent),fontSize:10,fontWeight:FontWeight.bold)),
          if(audioFile!=null) Container(margin:EdgeInsets.only(top:8),height:42,child:AudioFileWaveforms(size:Size(MediaQuery.of(context).size.width-40,42),playerController:player,waveformType:WaveformType.long,playerWaveStyle:PlayerWaveStyle(fixedWaveColor:Colors.white24,liveWaveColor:Color(th.accent)))),
        ]))),
        SafeArea(child:Align(alignment:Alignment.bottomCenter,child:Container(margin:EdgeInsets.all(10),padding:EdgeInsets.all(12),decoration:BoxDecoration(color:Colors.black.withOpacity(0.88),borderRadius:BorderRadius.circular(18),border:Border.all(color:Color(th.accent))),child:Column(mainAxisSize:MainAxisSize.min,children:[
          if(audioFile!=null) RangeSlider(min:0,max:total>0?total:1,values:RangeValues(s.clamp(0,total),e.clamp(s,total)),activeColor:Color(th.accent),onChanged:(v){ if(v.end-v.start<=60) setState((){s=v.start; e=v.end;}); }),
          Row(children:[
            Expanded(child:ElevatedButton(onPressed:pickAudio,child:Text("UPLOAD",style:TextStyle(fontSize:10)),style:ElevatedButton.styleFrom(backgroundColor:Colors.white,foregroundColor:Colors.black))),
            SizedBox(width:6), Expanded(child:ElevatedButton(onPressed:createMusic,child:Text("CREATE",style:TextStyle(fontSize:10)),style:ElevatedButton.styleFrom(backgroundColor:Color(th.accent),foregroundColor:Colors.black))),
            SizedBox(width:6), Expanded(child:ElevatedButton(onPressed:toggleRec,child:Text(isRec?"STOP":"REC",style:TextStyle(fontSize:10)),style:ElevatedButton.styleFrom(backgroundColor:isRec?Colors.red:Colors.orange))),
            SizedBox(width:6), Expanded(child:ElevatedButton(onPressed:pickBg,child:Text("BG",style:TextStyle(fontSize:10)))),
          ]),
          SizedBox(height:8), Row(children:[
            Expanded(child:ElevatedButton(onPressed:pickGlobe,child:Text("GLOBE IMG"))),
            SizedBox(width:8), Expanded(flex:2,child:ElevatedButton(onPressed:load?null:bustVideo,child:Text(load?"RENDER...":"BUST VIDEO + GLOBE REAL 3D"),style:ElevatedButton.styleFrom(backgroundColor:Colors.greenAccent,foregroundColor:Colors.black))),
          ]),
          SizedBox(height:6), Text(status,style:TextStyle(fontSize:10,color:Color(th.accent))),
          if(outVideo!=null) SizedBox(width:double.infinity,child:ElevatedButton.icon(onPressed:() async{ await Share.shareXFiles([XFile(outVideo!.path)],text:runText); },icon:Icon(Icons.share),label:Text("SHARE WA - VIDEO REAL 3D"),style:ElevatedButton.styleFrom(backgroundColor:Color(0xFF25D366)))),
        ])))),
      ]),
    );
  }
  @override void dispose(){ ctrl.dispose(); player.dispose(); recorder.dispose(); super.dispose(); }
}

// ========== REAL 3D MATH GLOBE PAINTER ==========
class Real3DGlobePainter extends CustomPainter{
  final double rotX, rotY; final int accent; final String? imgPath;
  Real3DGlobePainter(this.rotX,this.rotY,this.accent,this.imgPath);

  // Rotasi 3D pakai math
  List<double> rotate3D(double x,double y,double z){
    // rotY - yaw (kiri kanan)
    double cosY=math.cos(rotY); double sinY=math.sin(rotY);
    double x1 = x*cosY - z*sinY;
    double z1 = x*sinY + z*cosY;
    // rotX - pitch (atas bawah)
    double cosX=math.cos(rotX); double sinX=math.sin(rotX);
    double y1 = y*cosX - z1*sinX;
    double z2 = y*sinX + z1*cosX;
    return [x1,y1,z2];
  }

  @override void paint(Canvas canvas, Size size){
    var center=Offset(size.width/2,size.height/2);
    double radius=size.width*0.42;
    var bgPaint=Paint()..color=Colors.black..style=PaintingStyle.fill;
    canvas.drawCircle(center, radius+4, bgPaint);

    // 1. Gambar sphere base dengan shading 3D
    for(double r=radius; r>0; r-=1){
      double t=r/radius;
      double shade = 0.3 + 0.7 * (1 - t*0.7); // 3D shading
      var p=Paint()..color=Color.lerp(Color(0xFF8B6914), Color(0xFFFFD700), shade)!..style=PaintingStyle.stroke..strokeWidth=1.2;
      canvas.drawCircle(center, r, p);
    }

    // 2. Gambar lat/long grid REAL 3D pakai math
    var gridPaint=Paint()..color=Color(accent).withOpacity(0.25)..style=PaintingStyle.stroke..strokeWidth=0.8;
    // Longitude lines
    for(int lon=0; lon<12; lon++){
      double lonRad = lon * math.pi / 6;
      var path=Path();
      bool first=true;
      for(double lat=-math.pi/2; lat<=math.pi/2; lat+=0.05){
        double x = radius * math.cos(lat) * math.cos(lonRad);
        double y = radius * math.sin(lat);
        double z = radius * math.cos(lat) * math.sin(lonRad);
        var rot=rotate3D(x,y,z);
        // perspective projection
        double perspective = 300 / (300 + rot[2]);
        double sx = center.dx + rot[0]*perspective;
        double sy = center.dy + rot[1]*perspective;
        // hanya gambar sisi depan (z > -radius*0.5)
        if(rot[2] > -radius*0.3){
          if(first){ path.moveTo(sx,sy); first=false; } else { path.lineTo(sx,sy); }
        } else { first=true; }
      }
      canvas.drawPath(path, gridPaint);
    }
    // Latitude lines
    for(int latIdx=-4; latIdx<=4; latIdx++){
      if(latIdx==0) continue;
      double lat = latIdx * math.pi / 8;
      var path=Path(); bool first=true;
      for(double lon=0; lon<=2*math.pi; lon+=0.05){
        double x = radius * math.cos(lat) * math.cos(lon);
        double y = radius * math.sin(lat);
        double z = radius * math.cos(lat) * math.sin(lon);
        var rot=rotate3D(x,y,z);
        double perspective = 300 / (300 + rot[2]);
        double sx = center.dx + rot[0]*perspective;
        double sy = center.dy + rot[1]*perspective;
        if(rot[2] > -radius*0.2){
          if(first){ path.moveTo(sx,sy); first=false; } else { path.lineTo(sx,sy); }
        } else { first=true; }
      }
      canvas.drawPath(path, gridPaint);
    }

    // 3. BABE.INFO text wrapping REAL 3D di permukaan bola
    var textStyle=TextStyle(color:Colors.black.withOpacity(0.85),fontSize:14,fontWeight:FontWeight.w900,letterSpacing:0.5);
    List<String> texts=["BABE.INFO","BABE.INFO","BABE.INFO","BABE.INFO","BABE.INFO"];
    for(int i=0;i<texts.length;i++){
      double lat = (i-2)*0.4; // sebar vertikal
      for(int j=0;j<8;j++){
        double lon = j*math.pi/4 + rotY*0.5;
        double x = radius*0.85 * math.cos(lat) * math.cos(lon);
        double y = radius*0.85 * math.sin(lat);
        double z = radius*0.85 * math.cos(lat) * math.sin(lon);
        var rot=rotate3D(x,y,z);
        if(rot[2] > 0){ // hanya depan
          double perspective = 300 / (300 + rot[2]);
          double sx = center.dx + rot[0]*perspective;
          double sy = center.dy + rot[1]*perspective;
          double scale = perspective;
          if(sx>20 && sx<size.width-80 && sy>20 && sy<size.height-20){
            var tp=TextPainter(text:TextSpan(text:texts[i],style:textStyle.copyWith(fontSize:14*scale)),textDirection:TextDirection.ltr)..layout();
            canvas.save();
            canvas.translate(sx,sy);
            canvas.scale(scale);
            // rotasi text mengikuti bola
            canvas.rotate(rot[0]*0.002);
            tp.paint(canvas, Offset(-tp.width/2,-tp.height/2));
            canvas.restore();
          }
        }
      }
    }

    // 4. Akar hitam REAL 3D (seperti foto globe emas)
    var rootPaint=Paint()..color=Colors.black.withOpacity(0.75)..style=PaintingStyle.stroke..strokeWidth=1.6..strokeCap=StrokeCap.round;
    var rnd=math.Random(123);
    for(int i=0;i<10;i++){
      double lat = (rnd.nextDouble()-0.5)*math.pi;
      double lon = rnd.nextDouble()*2*math.pi;
      var path=Path(); bool first=true;
      double clat=lat, clon=lon;
      for(int k=0;k<12;k++){
        double x = radius * math.cos(clat) * math.cos(clon);
        double y = radius * math.sin(clat);
        double z = radius * math.cos(clat) * math.sin(clon);
        var rot=rotate3D(x,y,z);
        if(rot[2] > -radius*0.1){
          double persp = 300 / (300 + rot[2]);
          double sx=center.dx+rot[0]*persp; double sy=center.dy+rot[1]*persp;
          if(first){ path.moveTo(sx,sy); first=false; } else { path.lineTo(sx,sy); }
        }
        clat+=(rnd.nextDouble()-0.5)*0.2; clon+=(rnd.nextDouble()-0.5)*0.2;
      }
      canvas.drawPath(path, rootPaint);
    }

    // 5. Highlight glossy 3D + border
    var gloss=Paint()..shader=RadialGradient(colors:[Colors.white.withOpacity(0.45),Colors.transparent],center:Alignment(-0.35,-0.35),radius:0.75).createShader(Rect.fromCircle(center:center,radius:radius));
    canvas.drawCircle(center, radius, gloss);
    var border=Paint()..color=Color(accent)..style=PaintingStyle.stroke..strokeWidth=2.5;
    canvas.drawCircle(center, radius, border);
    var glow=Paint()..color=Color(accent).withOpacity(0.35)..style=PaintingStyle.stroke..strokeWidth=12..maskFilter=MaskFilter.blur(BlurStyle.normal,12);
    canvas.drawCircle(center, radius, glow);
  }
  @override bool shouldRepaint(covariant Real3DGlobePainter old)=> old.rotX!=rotX || old.rotY!=rotY;
}