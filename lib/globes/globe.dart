import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

class GlobeShaderPainter extends CustomPainter {
  final ui.FragmentProgram program;
  final double time;
  final double rotY;
  final double windRot;

  GlobeShaderPainter({required this.program, required this.time, required this.rotY, required this.windRot});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width/2, size.height*0.38);
    final globeR = math.min(size.width, size.height)*0.26;

    // 1. Gambar shader marmer + angin + globe emas polos
    final shader = program.fragmentShader();
    shader.setFloat(0, size.width);
    shader.setFloat(1, size.height);
    shader.setFloat(2, time);
    shader.setFloat(3, rotY);
    shader.setFloat(4, windRot);
    shader.setFloat(5, 1.9);
    canvas.drawRect(Offset.zero & size, Paint()..shader=shader);

    // 2. OVERLAY TEXT 3D BABE.INFO - SUPER TAJAM
    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: center, radius: globeR)));

    // List baris latitude seperti di foto
    final bands = [-0.75, -0.45, -0.15, 0.15, 0.45, 0.75];
    for(int b=0; b<bands.length; b++){
      double yNorm = bands[b];
      double y = center.dy + yNorm*globeR*0.85;
      double sliceW = math.sqrt(math.max(0.0, 1.0 - yNorm*yNorm)) * globeR * 2;
      if(sliceW < 30) continue;

      // Perspektif: semakin ke tepi semakin kecil & gelap
      double scale = 0.6 + 0.4 * math.sqrt(1 - yNorm*yNorm.abs());
      double fontSize = (b==2 || b==3)? 26*scale : 16*scale; // tengah paling gede kayak foto
      if(b==2) fontSize = 32*scale; // baris tengah "BABE.INFO" besar

      // Rotasi globe: offset text bergeser
      double lonOffset = (rotY * (1.2 + b*0.1)) % (2*math.pi);
      double scrollX = (lonOffset / (2*math.pi)) * sliceW * 2.5;

      // Buat text berulang
      String baseText = "BABE.INFO ";
      String longText = baseText * 12;

      // Shadow emboss (bawah kanan gelap)
      _drawTextLine(canvas, longText, Offset(center.dx - sliceW/2 - scrollX + 1.2, y + 1.2), sliceW*3, fontSize, const Color(0xFF2A1F00), FontWeight.w900, 0.9);
      // Highlight emboss (atas kiri terang)
      _drawTextLine(canvas, longText, Offset(center.dx - sliceW/2 - scrollX - 0.8, y - 0.8), sliceW*3, fontSize, const Color(0xFFFFF0A0), FontWeight.w900, 0.7);
      // Text utama emas tua
      _drawTextLine(canvas, longText, Offset(center.dx - sliceW/2 - scrollX, y), sliceW*3, fontSize, Color.lerp(const Color(0xFF5A4100), const Color(0xFFD4AF37), scale)!, FontWeight.w900, 1.0);
    }
    canvas.restore();
  }

  void _drawTextLine(Canvas canvas, String text, Offset offset, double maxW, double size, Color color, FontWeight w, double opacity){
    final tp = TextPainter(
      text: TextSpan(text: text, style: TextStyle(color: color.withOpacity(opacity), fontSize: size, fontWeight: w, letterSpacing: 1.2, fontFamily: 'serif')),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout(maxWidth: maxW);
    tp.paint(canvas, offset);
  }

  @override bool shouldRepaint(covariant GlobeShaderPainter old) => old.time!= time;
}

class GlobeShaderWidget extends StatelessWidget {
  final ui.FragmentProgram program;
  final double time;
  const GlobeShaderWidget({super.key, required this.program, required this.time});
  @override Widget build(BuildContext context) {
    final rotY = time * 0.35; // KANAN
    final windRot = time * -0.28; // KIRI - BERLAWANAN!
    return CustomPaint(
      painter: GlobeShaderPainter(program: program, time: time, rotY: rotY, windRot: windRot),
      size: Size.infinite,
    );
  }
}