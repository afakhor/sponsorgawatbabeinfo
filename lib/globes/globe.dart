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

    final center = Offset(
      size.width * 0.5,
      size.height * 0.345,
    );

    final globeRadius = math.min(size.width, size.height) * 0.255;

    // Background, marble, atmosphere, globe, crown and particles.
    final shader = program.fragmentShader();

    shader.setFloat(0, size.width);
    shader.setFloat(1, size.height);
    shader.setFloat(2, time);
    shader.setFloat(3, rotY);
    shader.setFloat(4, windRot);
    shader.setFloat(5, 1.35);

    canvas.drawRect(
      Offset.zero & size,
      Paint()..shader = shader,
    );

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

    final globeRect = Rect.fromCircle(
      center: center,
      radius: radius,
    );

    canvas.clipPath(
      Path()..addOval(globeRect),
    );

    // Posisi garis dibuat menyerupai pola tulisan melingkar.
    final bands = <double>[
      -0.86,
      -0.66,
      -0.45,
      -0.24,
      0.00,
      0.23,
      0.46,
      0.68,
      0.86,
    ];

    for (int i = 0; i < bands.length; i++) {
      final latitude = bands[i];

      final visibleWidthFactor = math.sqrt(
        math.max(0.0, 1.0 - latitude * latitude),
      );

      final lineY = center.dy + latitude * radius * 0.91;
      final lineWidth = radius * 2.0 * visibleWidthFactor;

      if (lineWidth < 18.0) continue;

      final distanceFromCenter = latitude.abs();

      // Garis tengah lebih besar, seperti pada gambar referensi.
      final centerFactor = 1.0 - distanceFromCenter;
      final fontSize = 15.0 + centerFactor * 20.0;

      final verticalScale = 0.72 + centerFactor * 0.28;
      final darken = 0.30 + centerFactor * 0.70;

      // Kecepatan tulisan mengikuti rotasi globe.
      final scroll =
          ((rotation * (0.72 + centerFactor * 0.35)) /
                  (math.pi * 2.0)) *
              lineWidth *
              2.0;

      final text = 'BABE.INFO   ' * 20;

      canvas.save();

      // Setiap garis dibuat semakin sempit di dekat kutub.
      final bandHeight = math.max(20.0, fontSize * 1.45);
      canvas.clipRect(
        Rect.fromCenter(
          center: Offset(center.dx, lineY),
          width: lineWidth + radius * 0.35,
          height: bandHeight,
        ),
      );

      final startX = center.dx - lineWidth - scroll;

      // Bayangan emboss bawah-kanan.
      _paintRepeatedText(
        canvas: canvas,
        text: text,
        x: startX + 2.2,
        y: lineY + 2.2,
        width: lineWidth * 3.0,
        fontSize: fontSize,
        color: const Color(0xFF160D02).withOpacity(0.95),
        scaleX: verticalScale,
      );

      // Bayangan lembut luar.
      _paintRepeatedText(
        canvas: canvas,
        text: text,
        x: startX,
        y: lineY + 1.0,
        width: lineWidth * 3.0,
        fontSize: fontSize,
        color: const Color(0xFF000000).withOpacity(0.48),
        scaleX: verticalScale,
      );

      // Highlight kiri-atas.
      _paintRepeatedText(
        canvas: canvas,
        text: text,
        x: startX - 0.9,
        y: lineY - 1.0,
        width: lineWidth * 3.0,
        fontSize: fontSize,
        color: Color.lerp(
          const Color(0xFF9C6715),
          const Color(0xFFFFF1A6),
          darken,
        )!.withOpacity(0.9),
        scaleX: verticalScale,
      );

      // Teks utama.
      _paintRepeatedText(
        canvas: canvas,
        text: text,
        x: startX,
        y: lineY,
        width: lineWidth * 3.0,
        fontSize: fontSize,
        color: Color.lerp(
          const Color(0xFF4B2705),
          const Color(0xFFE9B94D),
          darken,
        )!,
        scaleX: verticalScale,
      );

      canvas.restore();
    }

    canvas.restore();
  }

  void _paintRepeatedText({
    required Canvas canvas,
    required String text,
    required double x,
    required double y,
    required double width,
    required double fontSize,
    required Color color,
    required double scaleX,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: FontWeight.w900,
          fontFamily: 'serif',
          letterSpacing: 0.8,
          height: 0.90,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout(maxWidth: width);

    canvas.save();

    // Kompresi horizontal memberi kesan teks mengikuti permukaan bola.
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
          color: Color(0xFFE5B74D),
          fontSize: 45.0,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.4,
          fontFamily: 'serif',
          shadows: [
            Shadow(
              color: Color(0xFF4B2600),
              offset: Offset(2.0, 3.0),
              blurRadius: 1.0,
            ),
            Shadow(
              color: Color(0xFFFFE8A1),
              offset: Offset(-0.8, -0.8),
              blurRadius: 0.5,
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final titleX = (size.width - titlePainter.width) * 0.5;
    final titleY = size.height * 0.655;

    titlePainter.paint(canvas, Offset(titleX, titleY));

    final subtitlePainter = TextPainter(
      text: const TextSpan(
        text: '(n/) By Heru Wingchun',
        style: TextStyle(
          color: Color(0xFFF1D78B),
          fontSize: 15.0,
          fontWeight: FontWeight.w500,
          fontFamily: 'serif',
          letterSpacing: 0.7,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    subtitlePainter.paint(
      canvas,
      Offset(
        (size.width - subtitlePainter.width) * 0.5,
        titleY + titlePainter.height + 10.0,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant GlobeShaderPainter oldDelegate) {
    return oldDelegate.time != time ||
        oldDelegate.rotY != rotY ||
        oldDelegate.windRot != windRot ||
        oldDelegate.program != program;
  }
}

class GlobeShaderWidget extends StatelessWidget {
  final ui.FragmentProgram program;
  final double time;

  const GlobeShaderWidget({
    super.key,
    required this.program,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
    // Globe bergerak ke kanan.
    final rotY = time * 0.38;

    // Atmosfer dan awan bergerak ke kiri.
    final windRot = -time * 0.62;

    return RepaintBoundary(
      child: CustomPaint(
        painter: GlobeShaderPainter(
          program: program,
          time: time,
          rotY: rotY,
          windRot: windRot,
        ),
        size: Size.infinite,
      ),
    );
  }
}
