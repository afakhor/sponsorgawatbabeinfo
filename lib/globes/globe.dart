import 'dart:ui' as ui;
import 'package:flutter/material.dart';

class GlobeShaderPainter extends CustomPainter {
  final ui.FragmentProgram program;
  final ui.Image textTexture;
  final double time;

  const GlobeShaderPainter({
    required this.program,
    required this.textTexture,
    required this.time,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final shader = program.fragmentShader();

    // Urutan uniform float:
    // 0 = iResolution.x
    // 1 = iResolution.y
    // 2 = iTime
    // 3 = rotY
    // 4 = windRot
    // 5 = glow

    shader.setFloat(0, size.width);
    shader.setFloat(1, size.height);
    shader.setFloat(2, time);
    shader.setFloat(3, time * 0.75);
    shader.setFloat(4, time * -1.2);
    shader.setFloat(5, 2.2);

    // Sampler pertama: babe_info.png
    shader.setImageSampler(0, textTexture);

    final paint = Paint()
      ..shader = shader
      ..filterQuality = FilterQuality.high;

    canvas.drawRect(
      Offset.zero & size,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant GlobeShaderPainter oldDelegate) {
    return oldDelegate.program != program ||
        oldDelegate.textTexture != textTexture ||
        oldDelegate.time != time;
  }
}

class GlobeShaderWidget extends StatelessWidget {
  final ui.FragmentProgram program;
  final ui.Image textTexture;
  final double time;

  const GlobeShaderWidget({
    super.key,
    required this.program,
    required this.textTexture,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: GlobeShaderPainter(
          program: program,
          textTexture: textTexture,
          time: time,
        ),
        size: Size.infinite,
      ),
    );
  }
}
