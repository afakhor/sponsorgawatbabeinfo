import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:three_js/three_js.dart' as three;
import 'package:flutter_angle/flutter_angle.dart';
import 'package:ffmpeg_kit_flutter_new_audio/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_audio/return_code.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cross_file/cross_file.dart';
import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/rendering.dart';

void main()=>runApp(const MaterialApp(debugShowCheckedModeBanner:false, home: SponsorBabePage()));

class SponsorBabePage extends StatefulWidget{const SponsorBabePage({super.key});@override State<SponsorBabePage> createState()=>_SponsorBabePageState();}
class _SponsorBabePageState extends State<SponsorBabePage> with TickerProviderStateMixin{
  ui.FragmentProgram? shaderProg;
  three.ThreeJS? threeJS; three.WebGLRenderer? renderer; three.Scene? scene; three.PerspectiveCamera? camera; three.Mesh? globeMesh;
  late AnimationController shaderCtrl, waveCtrl, textCtrl;
  double rotX=0.3, rotY=0, time=0;
  File? audioFile, outVideo; bool loading=false;
  final player=PlayerController();
  final runTextCtrl=TextEditingController(text:"TERJEBAK PUSARAN BLACKHOLE ATMOSPHERE! BABE.INFO LUXURY! TERHIPNOTIS 60 DETIK!");
  GlobalKey globeKey=GlobalKey();
  String status="BLACKHOLE ATMOSPHERE READY";

  @override void initState(){
    super.initState();
    shaderCtrl=AnimationController(vsync:this, duration:const Duration(milliseconds:16))..addListener(()=>setState(()=>time+=0.016))..repeat();
    waveCtrl=AnimationController(vsync:this, duration:const Duration(milliseconds:900))..repeat();
    textCtrl=AnimationController(vsync:this, duration:const Duration(seconds:14))..repeat();
    loadShader(); initPerm();
    threeJS = three.ThreeJS(onSetupComplete:(){ setState((){}); }, setup: setupThree);
  }
  Future<void> initPerm() async{ try{ var i=await DeviceInfoPlugin().androidInfo; if(i.version.sdkInt>=33){ await [Permission.audio, Permission.photos].request(); } else { await Permission.storage.request(); } }catch(_){} }
  Future<void> loadShader() async{ try{ shaderProg=await ui.FragmentProgram.fromAsset('shaders/globe.frag'); }catch(_){} }

  Future<void> setupThree() async{
    scene=three.Scene(); scene!.background=three.Color.fromHex32(0xFF000000);
    camera=three.PerspectiveCamera(65, threeJS!.width/threeJS!.height, 0.1, 1000); camera!.position.z=4.5;
    renderer=three.WebGLRenderer(three.WebGLRendererOptions(antialias:true, alpha:true)); 
    renderer!.setSize(threeJS!.width, threeJS!.height);
    var geo=three.SphereGeometry(1.1, 64, 64);
    var mat=three.MeshStandardMaterial.fromMap({"color":0xFFD4AF37, "metalness":0.9, "roughness":0.25});
    globeMesh=three.Mesh(geo, mat); scene!.add(globeMesh);
    scene!.add(three.AmbientLight(0xffffff,0.8)); var dl=three.DirectionalLight(0xffffff,1.2); dl.position.setValues(3,4,5); scene!.add(dl);
    var ringGeo=three.RingGeometry(1.6,2.2,64); var ringMat=three.MeshBasicMaterial.fromMap({"color":0xFFD4AF37, "side":three.DoubleSide, "transparent":true, "opacity":0.6});
    var ring=three.Mesh(ringGeo, ringMat); ring.rotation.x=math.pi/2; ring.position.y=1.2; scene!.add(ring);
  }

  Future<void> pickAudio() async{ var r=await FilePicker.platform.pickFiles(type:FileType.audio); if(r==null)return; File f=File(r.files.single.path!); await player.preparePlayer(path:f.path, shouldExtractWaveform:true, noOfSamples:200); setState(()=>audioFile=f); }
  
  Future<void> bust60sBlackhole() async{
    if(audioFile==null){ setState(()=>status="UPLOAD AUDIO DULU!"); return; }
    setState((){loading=true; status="RENDER BLACKHOLE 60S...";});
    try{
      var tmp=await getTemporaryDirectory(); var ts=DateTime.now().millisecondsSinceEpoch;
      String trim="${tmp.path}/trim_$ts.m4a"; String globeImg="${tmp.path}/globe_$ts.png"; String out="${tmp.path}/BABE_BLACKHOLE_60S_$ts.mp4";
      await FFmpegKit.execute('-y -i "${audioFile!.path}" -filter:a "aloop=loop=-1:size=2e+09,atrim=0:60,afade=t=in:st=0:d=2,afade=t=out:st=58:d=2" -c:a aac "$trim"');
      try{ RenderRepaintBoundary? b=globeKey.currentContext?.findRenderObject() as RenderRepaintBoundary?; if(b!=null){ var img=await b.toImage(pixelRatio:3); var by=await img.toByteData(format:ui.ImageByteFormat.png); await File(globeImg).writeAsBytes(by!.buffer.asUint8List()); } }catch(_){}
      String bg=""; try{ var data=await DefaultAssetBundle.of(context).load('assets/images/bg.jpg'); File f=File('${tmp.path}/bg_$ts.jpg'); await f.writeAsBytes(data.buffer.asUint8List()); bg=f.path; }catch(_){}
      String cmd='-y -loop 1 -i "$bg" -loop 1 -i "$globeImg" -i "$trim" -filter_complex "[0]scale=720:1280,zoompan=z=\'1+0.0012*t\':d=1:s=720x1280:fps=30[base];[1]scale=520:520,rotate=0.03*PI*t:c=black@0:ow=rotw(0.03*PI*t):oh=roth(0.03*PI*t)[g];[base][g]overlay=(W-w)/2:(H-h)/2-140:format=auto,drawtext=text=\'BABE.INFO\':fontcolor=gold:fontsize=68:x=(w-text_w)/2:y=h-280:box=1:boxcolor=black@0.6:boxborderw=8:shadowcolor=black:shadowx=3:shadowy=3,drawtext=text=\'(n/) By Heru Wingchun\':fontcolor=#FFD700:fontsize=20:x=(w-text_w)/2:y=h-220" -c:v libx264 -preset ultrafast -pix_fmt yuv420p -c:a aac -t 60 "$out"';
      var s=await FFmpegKit.execute(cmd);
      if(ReturnCode.isSuccess(await s.getReturnCode())){ setState((){outVideo=File(out); loading=false; status="VIDEO BLACKHOLE 60S JADI!";}); } else { setState(()=>loading=false); }
    }catch(e){ setState(()=>loading=false); }
  }

  @override Widget build(BuildContext context){
    return Scaffold(backgroundColor:Colors.black, body:Stack(children:[
      if(shaderProg!=null) Positioned.fill(child: RepaintBoundary(key:globeKey, child:CustomPaint(size:Size.infinite, painter:BlackholeShaderPainter(shaderProg!, time, rotX, rotY)))),
      if(threeJS!=null) Positioned(top:80, left:0, right:0, height:360, child:threeJS!.build()),
      SafeArea(child:Column(children:[
        const Spacer(),
        Container(
          padding:const EdgeInsets.all(12),
          decoration:BoxDecoration(gradient:LinearGradient(begin:Alignment.topCenter, end:Alignment.bottomCenter, colors:[Colors.transparent, Colors.black.withOpacity(0.85)])),
          child:Column(children:[
            ShaderMask(shaderCallback:(b)=>const LinearGradient(colors:[Color(0xFFFFF59D),Color(0xFFFFD700),Color(0xFFB8860B)]).createShader(b), child:const Text("BABE.INFO", style:TextStyle(fontSize:46, fontWeight:FontWeight.w900, color:Colors.white, letterSpacing:3, shadows:[Shadow(color:Colors.black, offset:Offset(3,3), blurRadius:10), Shadow(color:Color(0xFFFFD700), blurRadius:25)]))),
            const Text("(n/) By Heru Wingchun", style:TextStyle(color:Color(0xFFFFD700), fontSize:13, fontStyle:FontStyle.italic)),
            const SizedBox(height:10),
            Container(height:38, width:double.infinity, decoration:BoxDecoration(color:Colors.black.withOpacity(0.7), border:const Border.symmetric(horizontal:BorderSide(color:Color(0xFFD4AF37))), boxShadow:[BoxShadow(color:const Color(0xFFD4AF37).withOpacity(0.4), blurRadius:15)]), child:ClipRect(child:AnimatedBuilder(animation:textCtrl, builder:(c,_){
              return Transform.translate(offset:Offset(MediaQuery.of(context).size.width - textCtrl.value*(MediaQuery.of(context).size.width+900),0), child: Text("${runTextCtrl.text}   •   ${runTextCtrl.text}", style:TextStyle(fontSize:20, fontWeight:FontWeight.bold, fontStyle:FontStyle.italic, color:const Color(0xFFFFD700), shadows:[Shadow(color:Colors.black, offset:const Offset(2,2), blurRadius:5), Shadow(color:const Color(0xFFD4AF37), blurRadius:15), Shadow(color:Colors.white.withOpacity(0.6* (0.5+0.5*math.sin(time*3))), blurRadius:8)])));
            }))),
            const SizedBox(height:6),
            SizedBox(height:28, child:TextField(controller:runTextCtrl, style:const TextStyle(color:Colors.white, fontSize:11), decoration:InputDecoration(hintText:"Input running text hipnotis...", hintStyle:const TextStyle(color:Colors.white38, fontSize:10), filled:true, fillColor:Colors.white10, border:OutlineInputBorder(borderRadius:BorderRadius.circular(8)), contentPadding:const EdgeInsets.symmetric(horizontal:8, vertical:4)), onChanged:(_)=>setState((){}))),
            const SizedBox(height:8),
            Container(height:66, decoration:BoxDecoration(color:Colors.black54, borderRadius:BorderRadius.circular(12), border:Border.all(color:const Color(0xFFD4AF37).withOpacity(0.5)), boxShadow:[BoxShadow(color:const Color(0xFFD4AF37).withOpacity(0.2), blurRadius:10)]), child:AnimatedBuilder(animation:waveCtrl, builder:(c,_){ return CustomPaint(size:const Size(double.infinity,66), painter:BlackholeWavePainter(waveCtrl.value, time)); })),
            const SizedBox(height:4), const Text("BLACKHOLE ATMOSPHERE • Headset 60 detik", style:TextStyle(color:Color(0xFFD4AF37), fontSize:9, fontStyle:FontStyle.italic)),
            const SizedBox(height:8),
            Row(children:[
              Expanded(child:ElevatedButton(onPressed:pickAudio, child:const Text("UPLOAD AUDIO", style:TextStyle(fontSize:9)))),
              const SizedBox(width:6),
              Expanded(flex:2, child:ElevatedButton(onPressed:loading?null:bust60sBlackhole, style:ElevatedButton.styleFrom(backgroundColor:const Color(0xFFFFD700), foregroundColor:Colors.black), child:Text(loading?"RENDER...":"BUST 60S BLACKHOLE GAWAT!", style:const TextStyle(fontWeight:FontWeight.w900, fontSize:11)))),
            ]),
            if(outVideo!=null) SizedBox(width:double.infinity, child:ElevatedButton.icon(onPressed:() async=>await Share.shareXFiles([XFile(outVideo!.path)], text:"BABE.INFO BLACKHOLE"), icon:const Icon(Icons.share), label:const Text("SHARE WA STATUS", style:TextStyle(fontWeight:FontWeight.bold)), style:ElevatedButton.styleFrom(backgroundColor:const Color(0xFF25D366), foregroundColor:Colors.white))),
            const SizedBox(height:4), Text(status, style:const TextStyle(color:Color(0xFFD4AF37), fontSize:10)),
          ]),
        ),
      ])),
    ]));
  }
}

class BlackholeShaderPainter extends CustomPainter{
  final ui.FragmentProgram prog; final double time, rotX, rotY;
  BlackholeShaderPainter(this.prog, this.time, this.rotX, this.rotY);
  @override void paint(Canvas canvas, Size size){
    var s=prog.fragmentShader(); s.setFloat(0,size.width); s.setFloat(1,size.height); s.setFloat(2,time); s.setFloat(3,rotX); s.setFloat(4,rotY); s.setFloat(5,1.0); s.setFloat(6,0.84); s.setFloat(7,0.0);
    canvas.drawRect(Offset.zero&size, Paint()..shader=s);
  }
  @override bool shouldRepaint(covariant BlackholeShaderPainter old)=>old.time!=time||old.rotX!=rotX||old.rotY!=rotY;
}
class BlackholeWavePainter extends CustomPainter{
  final double anim, time; BlackholeWavePainter(this.anim, this.time);
  @override void paint(Canvas canvas, Size size){
    var path=Path();
    for(double x=0;x<size.width;x+=2){
      double p=x/size.width;
      double suck=(1.0-p)*0.8;
      double w1=math.sin(p*8*math.pi + anim*2*math.pi + time*2)*14*(1.0-suck);
      double w2=math.sin(p*14*math.pi + anim*3*math.pi + time*3)*7;
      double y=size.height/2 + (w1+w2)* (0.5+0.5*math.sin(time));
      if(x==0) path.moveTo(x,y); else path.lineTo(x,y);
    }
    var glow=Paint()..color=const Color(0xFFFFD700).withOpacity(0.25)..style=PaintingStyle.stroke..strokeWidth=16..maskFilter=const MaskFilter.blur(BlurStyle.normal,12);
    canvas.drawPath(path, glow);
    var main=Paint()..color=const Color(0xFFFFD700)..style=PaintingStyle.stroke..strokeWidth=2.8..maskFilter=const MaskFilter.blur(BlurStyle.normal,1);
    canvas.drawPath(path, main);
  }
  @override bool shouldRepaint(covariant BlackholeWavePainter old)=>true;
}