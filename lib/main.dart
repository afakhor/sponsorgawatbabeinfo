import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:audio_waveforms/audio_waveforms.dart';

class FinalBabePage extends StatefulWidget{const FinalBabePage({super.key});@override State<FinalBabePage> createState()=>_FinalBabePageState();}
class _FinalBabePageState extends State<FinalBabePage> with TickerProviderStateMixin{
  ui.FragmentProgram? program;
  late AnimationController ctrl, waveCtrl, textCtrl;
  double rotX=0.3, rotY=0.0, time=0;
  final player=PlayerController();
  final TextEditingController runTextCtrl=TextEditingController(text:"BABE.INFO - Bukan Sekedar Info, Ini LUXURY! ✨ Terhipnotis 60 Detik! 🌪️");

  @override void initState(){
    super.initState();
    ctrl=AnimationController(vsync:this, duration:Duration(milliseconds:16))..addListener(()=>setState(()=>time+=0.016))..repeat();
    waveCtrl=AnimationController(vsync:this, duration:Duration(milliseconds:800))..repeat();
    textCtrl=AnimationController(vsync:this, duration:Duration(seconds:12))..repeat();
    loadShader();
  }
  Future<void> loadShader() async{ program=await ui.FragmentProgram.fromAsset('shaders/globe.frag'); setState((){}); }

  @override Widget build(BuildContext context){
    if(program==null) return Scaffold(backgroundColor:Colors.black, body:Center(child:CircularProgressIndicator(color:Color(0xFFD4AF37))));
    
    return Scaffold(backgroundColor:Colors.black, body:Stack(children:[
      // 1. GLOBE SHADER TOPAN EMAS
      Positioned.fill(child:GestureDetector(
        onPanUpdate:(d){ setState((){ rotY+=d.delta.dx*0.01; rotX+=d.delta.dy*0.01; rotX=rotX.clamp(-1.4,1.4); }); },
        child:CustomPaint(size:Size.infinite, painter:GlobeShaderPainter(program!, time, rotX, rotY)),
      )),

      // 2. LAYOUT BAWAH - BABE.INFO + RUNNING TEXT + WAVE
      SafeArea(child:Align(alignment:Alignment.bottomCenter, child:Container(
        width:double.infinity,
        padding:EdgeInsets.fromLTRB(12,12,12,12+MediaQuery.of(context).padding.bottom),
        decoration:BoxDecoration(
          gradient:LinearGradient(begin:Alignment.topCenter,end:Alignment.bottomCenter,colors:[Colors.transparent, Colors.black.withOpacity(0.3), Colors.black.withOpacity(0.95)]),
        ),
        child:Column(mainAxisSize:MainAxisSize.min, children:[
          // BABE.INFO 3D GOLD
          ShaderMask(
            shaderCallback:(b)=>LinearGradient(colors:[Color(0xFFFFF59D), Color(0xFFFFD700), Color(0xFFB8860B)]).createShader(b),
            child:Text("BABE.INFO", style:TextStyle(fontSize:42, fontWeight:FontWeight.w900, color:Colors.white, letterSpacing:2, shadows:[Shadow(color:Colors.black, offset:Offset(2,2), blurRadius:8), Shadow(color:Color(0xFFD4AF37), blurRadius:20)])),
          ),
          Text("(n/) By Heru Wingchun", style:TextStyle(color:Color(0xFFFFD700), fontSize:13, fontStyle:FontStyle.italic, letterSpacing:1)),

          SizedBox(height:10),

          // RUNNING TEXT BOLD ITALIC SHADES 20px HIPNOTIS - INPUTAN BOS!
          Container(
            height:32,
            width:double.infinity,
            decoration:BoxDecoration(color:Colors.black.withOpacity(0.6), border:Border.symmetric(horizontal:BorderSide(color:Color(0xFFD4AF37).withOpacity(0.5))), boxShadow:[BoxShadow(color:Color(0xFFD4AF37).withOpacity(0.3), blurRadius:10)]),
            child:ClipRect(child:AnimatedBuilder(animation:textCtrl, builder:(c, _){
              return Transform.translate(offset:Offset( MediaQuery.of(context).size.width - (textCtrl.value * (MediaQuery.of(context).size.width + 800)), 0),
                child:Row(children:[
                  Text(runTextCtrl.text + "   •   " + runTextCtrl.text, 
                    style:TextStyle(
                      fontSize:20, // 20px
                      fontWeight:FontWeight.bold, // bold
                      fontStyle:FontStyle.italic, // italic
                      color:Color(0xFFFFD700),
                      shadows:[
                        Shadow(color:Colors.black, offset:Offset(2,2), blurRadius:4), // shades
                        Shadow(color:Color(0xFFD4AF37), offset:Offset(0,0), blurRadius:12),
                        Shadow(color:Colors.white.withOpacity(0.5* (0.5+0.5*math.sin(time*3))), offset:Offset(0,0), blurRadius:6), // hipnotis blink
                      ],
                    ),
                  ),
                ]),
              );
            })),
          ),

          SizedBox(height:6),
          // INPUT RUNNING TEXT
          SizedBox(height:30, child:TextField(controller:runTextCtrl, style:TextStyle(color:Colors.white, fontSize:11), decoration:InputDecoration(hintText:"Input running text hipnotis...", hintStyle:TextStyle(color:Colors.white38, fontSize:10), filled:true, fillColor:Colors.white10, border:OutlineInputBorder(borderRadius:BorderRadius.circular(8)), contentPadding:EdgeInsets.symmetric(horizontal:10, vertical:4)), onChanged:(_)=>setState((){}) )),

          SizedBox(height:10),

          // WAVE MUSIC MENGHIPNOTIS
          Container(
            height:60,
            decoration:BoxDecoration(color:Colors.black.withOpacity(0.5), borderRadius:BorderRadius.circular(12), border:Border.all(color:Color(0xFFD4AF37).withOpacity(0.4))),
            child:AnimatedBuilder(animation:waveCtrl, builder:(c, _){
              return CustomPaint(size:Size(MediaQuery.of(context).size.width-24, 60), painter:HypnoticWavePainter(waveCtrl.value, time));
            }),
          ),
          SizedBox(height:4),
          Text("🔊 Dengerin pakai headset - WAVE HIPNOTIS 60Hz", style:TextStyle(color:Color(0xFFD4AF37), fontSize:9, fontStyle:FontStyle.italic)),
        ]),
      ))),

      // Tombol BUST 60S
      Positioned(top:40, right:12, child:ElevatedButton(onPressed:(){}, child:Text("BUST 60S HIPNOTIS", style:TextStyle(fontSize:10, fontWeight:FontWeight.bold)), style:ElevatedButton.styleFrom(backgroundColor:Color(0xFFFFD700), foregroundColor:Colors.black))),
    ]));
  }
}

class GlobeShaderPainter extends CustomPainter{
  final ui.FragmentProgram program; final double time, rotX, rotY;
  GlobeShaderPainter(this.program, this.time, this.rotX, this.rotY);
  @override void paint(Canvas canvas, Size size){
    var shader=program.fragmentShader();
    shader.setFloat(0, size.width); shader.setFloat(1, size.height); shader.setFloat(2, time); shader.setFloat(3, rotX); shader.setFloat(4, rotY);
    shader.setFloat(5, 1.0); shader.setFloat(6, 0.84); shader.setFloat(7, 0.0);
    canvas.drawRect(Offset.zero & size, Paint()..shader=shader);
  }
  @override bool shouldRepaint(covariant GlobeShaderPainter old)=> old.time!=time || old.rotX!=rotX;
}

class HypnoticWavePainter extends CustomPainter{
  final double anim, time;
  HypnoticWavePainter(this.anim, this.time);
  @override void paint(Canvas canvas, Size size){
    var paint=Paint()..color=Color(0xFFFFD700)..style=PaintingStyle.stroke..strokeWidth=2.5..maskFilter=MaskFilter.blur(BlurStyle.normal,2);
    var path=Path();
    for(double x=0; x<size.width; x+=2){
      double progress=x/size.width;
      double wave1=math.sin((progress*6*math.pi) + anim*2*math.pi + time*2)*12;
      double wave2=math.sin((progress*10*math.pi) + anim*2*math.pi*1.5 + time*3)*6;
      double wave3=math.sin((progress*3*math.pi) + time)*4;
      double y=size.height/2 + wave1 + wave2 + wave3;
      // Hipnotis - amplitudo membesar di tengah
      double envelope=math.sin(progress*math.pi);
      y=size.height/2 + (y-size.height/2)*envelope;
      if(x==0) path.moveTo(x,y); else path.lineTo(x,y);
    }
    canvas.drawPath(path, paint);
    // Glow
    var glow=Paint()..color=Color(0xFFFFD700).withOpacity(0.3)..style=PaintingStyle.stroke..strokeWidth=12..maskFilter=MaskFilter.blur(BlurStyle.normal,12);
    canvas.drawPath(path, glow);
  }
  @override bool shouldRepaint(covariant HypnoticWavePainter old)=> old.anim!=old.anim;
}