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
  void paint(
    Canvas canvas,
    Size size,
  ) {
    if (size.isEmpty) {
      return;
    }

    final ui.FragmentShader shader =
        program.fragmentShader();

    // --------------------------------------------------
    // FLOAT UNIFORMS
    //
    // globe.frag:
    //
    // uniform vec2 iResolution;
    // uniform float iTime;
    // uniform float rotY;
    // uniform float windRot;
    // uniform float glow;
    // uniform sampler2D textTexture;
    // --------------------------------------------------

    // iResolution.x
    
    shader.setFloat(
      0, 
      size.width
      );
    // iResolution.y
    shader.setFloat(
      1, 
      size.height
      );

    // iTime
    shader.setFloat(
      2, time
      );

    // Rotasi globe
    shader.setFloat(
      3, 
      time * 0.55);

    // Atmosfer, texture, dan petir bergerak
    // berlawanan arah dengan globe
    shader.setFloat(
      4, 
      -time * 1.20);

    // Intensitas atmosfer
    shader.setFloat(
      5,
      3.5,
    );

    // --------------------------------------------------
    // IMAGE SAMPLER
    // --------------------------------------------------

    shader.setImageSampler(
      0,
      textTexture,
      );

    final Paint paint =
        Paint()
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
  Widget build(
    BuildContext context,
  ) {
    return SizedBox.expand(
      child: RepaintBoundary(
        child: CustomPaint(
          painter: GlobeShaderPainter(
            program: program,
            textTexture: textTexture,
            time: time,
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}
