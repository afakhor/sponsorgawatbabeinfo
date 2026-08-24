import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

class GlobeShaderPainter extends CustomPainter {
  final ui.FragmentProgram program;
  final double time;
  final double rotY;
  final double windRot;

  const GlobeShaderPainter({
    required this.program,
    required this.time,
    required this.rotY,
    required this.windRot,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    // FIX 1: Posisi naik & bola jauh lebih kecil kayak ref gambar 2
    final center = Offset(
      size.width * 0.5,
      size.height * 0.40,
    );
    // Dulu 0.255 -> sekarang 0.185
    final globeRadius = math.min(size.width, size.height) * 0.185;

    final shader = program.fragmentShader();
    shader.setFloat(0, size.width);
    shader.setFloat(1, size.height);
    shader.setFloat(2, time);
    shader.setFloat(3, rotY);
    shader.setFloat(4, windRot);
    shader.setFloat(5, 1.15); // glow sedikit dikurangi biar tidak over

    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);

    _drawGlobeText(
      canvas: canvas,
      center: center,
      radius: globeRadius,
      rotation: rotY,
    );

    _drawBottomTitle(canvas, size);
  }

  void _drawGlobeText({
    required Canvas canvas,
    required Offset center,
    required double radius,
    required double rotation,
  }) {
    canvas.save();
    final globeRect = Rect.fromCircle(center: center, radius: radius);
    canvas.clipPath(Path()..addOval(globeRect));

    // FIX 2: Band lebih rapat, biar tekstur penuh 1 bola
    final bands = <double>[-0.82, -0.60, -0.35, -0.12, 0.10, 0.32, 0.55, 0.76];

    for (int i = 0; i < bands.length; i++) {
      final latitude = bands[i];
      final visibleWidthFactor = math.sqrt(math.max(0.0, 1.0 - latitude * latitude));
      final lineY = center.dy + latitude * radius * 0.88;
      final lineWidth = radius * 2.0 * visibleWidthFactor * 0.92;
      if (lineWidth < 15) continue;

      final centerFactor = 1.0 - latitude.abs();
      // FIX 3: TULISAN DIBESARKAN - ini yang kamu minta
      final fontSize = 14.0 + centerFactor * 22.0;
      final verticalScale = 0.55 + centerFactor * 0.45;
      final darken = 0.25 + centerFactor * 0.75;

      final scroll = ((rotation * (0.85 + centerFactor * 0.3)) / (math.pi * 2.0)) * lineWidth * 1.5;
      final text = 'BABE.INFO ' * 25;

      canvas.save();
      final bandHeight = math.max(18.0, fontSize * 1.35);
      canvas.clipRect(Rect.fromCenter(
        center: Offset(center.dx, lineY),
        width: lineWidth + radius * 0.2,
        height: bandHeight,
      ));

      final startX = center.dx - lineWidth * 0.8 - scroll;

      // Layer 1: Deep shadow untuk emboss dalam
      _paintRepeatedText(canvas: canvas, text: text, x: startX + 1.8, y: lineY + 1.8, width: lineWidth * 3.5, fontSize: fontSize, color: const Color(0xFF1A0E00).withOpacity(0.9), scaleX: verticalScale);
      // Layer 2: Outer glow soft
      _paintRepeatedText(canvas: canvas, text: text, x: startX, y: lineY + 0.5, width: lineWidth * 3.5, fontSize: fontSize, color: Colors.black.withOpacity(0.4), scaleX: verticalScale);
      // Layer 3: Highlight emas atas
      _paintRepeatedText(canvas: canvas, text: text, x: startX - 0.7, y: lineY - 0.8, width: lineWidth * 3.5, fontSize: fontSize, color: Color.lerp(const Color(0xFF8A5A10), const Color(0xFFFFF3B0), darken)!.withOpacity(0.85), scaleX: verticalScale);
      // Layer 4: Main text - warna emas tua menyatu dengan globe shader
      _paintRepeatedText(canvas: canvas, text: text, x: startX, y: lineY, width: lineWidth * 3.5, fontSize: fontSize, color: Color.lerp(const Color(0xFF3D1F00), const Color(0xFFFFD15C), darken)!, scaleX: verticalScale);

      canvas.restore();
    }
    canvas.restore();
  }

  void _paintRepeatedText({required Canvas canvas, required String text, required double x, required double y, required double width, required double fontSize, required Color color, required double scaleX}) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: FontWeight.w900,
          fontFamily: 'serif',
          letterSpacing: 0.6,
          height: 0.88,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout(maxWidth: width);

    canvas.save();
    canvas.translate(x, y);
    canvas.scale(scaleX, 1.0);
    painter.paint(canvas, Offset.zero);
    canvas.restore();
  }

  void _drawBottomTitle(Canvas canvas, Size size) {
    final titlePainter = TextPainter(
      text: const TextSpan(
        text: 'BABE.INFO',
        style: TextStyle(
          color: Color(0xFFFFD97A),
          fontSize: 52.0,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.2,
          fontFamily: 'serif',
          shadows: [
            Shadow(color: Color(0xFF3D1F00), offset: Offset(2.5, 2.5), blurRadius: 0),
            Shadow(color: Color(0xFFFFF1A0), offset: Offset(-1, -1), blurRadius: 0),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final titleX = (size.width - titlePainter.width) * 0.5;
    final titleY = size.height * 0.64;
    titlePainter.paint(canvas, Offset(titleX, titleY));

    final subtitlePainter = TextPainter(
      text: const TextSpan(
        text: '(n/) By Heru Wingchun',
        style: TextStyle(color: Color(0xFFF2D78B), fontSize: 15.0, fontWeight: FontWeight.w500, fontFamily: 'serif', letterSpacing: 0.7),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    subtitlePainter.paint(canvas, Offset((size.width - subtitlePainter.width) * 0.5, titleY + titlePainter.height + 8));
  }

  @override
  bool shouldRepaint(covariant GlobeShaderPainter oldDelegate) => oldDelegate.time!= time || oldDelegate.rotY!= rotY || oldDelegate.windRot!= windRot || oldDelegate.program!= program;
}

class GlobeShaderWidget extends StatelessWidget {
  final ui.FragmentProgram program;
  final double time;
  const GlobeShaderWidget({super.key, required this.program, required this.time});
  @override
  Widget build(BuildContext context) {
    final rotY = time * 0.32;
    final windRot = -time * 0.55;
    return RepaintBoundary(
      child: CustomPaint(
        painter: GlobeShaderPainter(program: program, time: time, rotY: rotY, windRot: windRot),
        size: Size.infinite,
      ),
    );
  }
}