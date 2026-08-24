import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

class GlobeShaderPainter extends CustomPainter {
  final ui.FragmentProgram program; final double time, rotY, windRot;
  GlobeShaderPainter({required this.program, required this.time, required this.rotY, required this.windRot});
  @override void paint(Canvas canvas, Size size){
    final center = Offset(size.width/2, size.height*0.48);
    final globeR = math.min(size.width, size.height)*0.32;
    final shader = program.fragmentShader();
    shader.setFloat(0, size.width);
    shader.setFloat(1, size.height);
    shader.setFloat(2, time);
    shader.setFloat(3, rotY);
    shader.setFloat(4, windRot);
    shader.setFloat(5, 2.5); // glow lebih terang
    canvas.drawRect(Offset.zero & size, Paint()..shader=shader);

    // TEXT NEMPEL BOLA - CEPAT
    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center:center, radius:globeR)));
    final goldBg = Paint()..shader=RadialGradient(
      center: const Alignment(-0.3,-0.3), 
      colors: [const Color(0xFFFFE87A), const Color(0xFFFFD700), const Color(0xFF8B6914)],
    ).createShader(Rect.fromCircle(center:center, radius:globeR));
    canvas.drawCircle(center, globeR, goldBg);

    for(double yn=-0.85; yn<=0.85; yn+=0.28){
      double y = center.dy + yn*globeR;
      double sliceW = math.sqrt(math.max(0.0, 1.0 - yn*yn)) * globeR * 2;
      if(sliceW < 20) continue;
      double scale = 0.7 + 0.5*math.sqrt(1 - yn.abs());
      double fontSize = yn.abs() < 0.15 ? 30*scale : 18*scale;
      double scroll = (rotY * 80) % 180;
      _text(canvas, " BABE.INFO " * 10, Offset(center.dx - sliceW/2 - scroll - 1, y - 1), fontSize, const Color(0xFFFFF0A0).withOpacity(0.8));
      _text(canvas, " BABE.INFO " * 10, Offset(center.dx - sliceW/2 - scroll + 1.2, y + 1.2), fontSize, const Color(0xFF2A1F00));
      _text(canvas, " BABE.INFO " * 10, Offset(center.dx - sliceW/2 - scroll, y), fontSize, const Color(0xFF3D2E00));
    }
    canvas.restore();
  }
  void _text(Canvas c, String txt, Offset off, double s, Color col){
    final tp = TextPainter(text: TextSpan(text: txt, style: TextStyle(color:col, fontSize:s, fontWeight:FontWeight.w900, letterSpacing:1.0)), textDirection:TextDirection.ltr)..layout(maxWidth:800);
    tp.paint(c, off);
  }
  @override bool shouldRepaint(covariant GlobeShaderPainter old)=> old.time!=time;
}

class GlobeShaderWidget extends StatelessWidget {
  final ui.FragmentProgram program; final double time;
  const GlobeShaderWidget({super.key, required this.program, required this.time});
  @override Widget build(BuildContext context){
    // BOLA MENGGELEGAR CEPAT
    return CustomPaint(
      painter: GlobeShaderPainter(program:program, time:time, rotY:time*2.2, windRot:time*-1.8), 
      size:Size.infinite
    );
  }
}