import 'dart:ui' as ui;
import 'package:flutter/material.dart';

class GlobeShaderPainter extends CustomPainter {
  final ui.FragmentProgram program;
  final double time;
  final double rotY;
  final double windRot;
  final double glow;

  GlobeShaderPainter({
    required this.program,
    required this.time,
    required this.rotY,
    required this.windRot,
    this.glow = 1.8,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final shader = program.fragmentShader();
    shader.setFloat(0, size.width);
    shader.setFloat(1, size.height);
    shader.setFloat(2, time);
    shader.setFloat(3, rotY);      // globe ke kanan
    shader.setFloat(4, windRot);   // atmosfer ke kiri
    shader.setFloat(5, glow);
    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(covariant GlobeShaderPainter old) =>
      old.time != time || old.rotY != rotY || old.windRot != windRot;
}

class GlobeShaderWidget extends StatelessWidget {
  final ui.FragmentProgram program;
  final double time;
  const GlobeShaderWidget({super.key, required this.program, required this.time});

  @override
  Widget build(BuildContext context) {
    // BERLAWANAN: rotY positif, windRot negatif
    final rotY = time * 0.35;
    final windRot = time * -0.28; // <--- MINUS ini kuncinya
    return CustomPaint(
      painter: GlobeShaderPainter(
        program: program,
        time: time,
        rotY: rotY,
        windRot: windRot,
        glow: 1.9,
      ),
      size: Size.infinite,
    );
  }
}