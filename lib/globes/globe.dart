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
    final ui.FragmentShader shader =
        program.fragmentShader();

    // Float uniform:
    // 0 = iResolution.x
    // 1 = iResolution.y
    // 2 = iTime
    // 3 = rotY
    // 4 = windRot
    // 5 = glow

    shader.setFloat(0, size.width);
    shader.setFloat(1, size.height);
    shader.setFloat(2, time);
    shader.setFloat(3, time * 0.72);
    shader.setFloat(4, time * -1.0);
    shader.setFloat(5, 3.0);

    // Sampler index pertama
    shader.setImageSampler(0, textTexture);

    final Paint paint = Paint()
      ..shader = shader
      ..filterQuality = FilterQuality.high;

    canvas.drawRect(
      Offset.zero & size,
      paint,
    );
  }

  @override
  bool shouldRepaint(
    covariant GlobeShaderPainter oldDelegate,
  ) {
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
        size: Size.infinite,
        painter: GlobeShaderPainter(
          program: program,
          textTexture: textTexture,
          time: time,
        ),
      ),
    );
  }
}
