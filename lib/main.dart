import 'dart:math' as math;
import 'package:flutter/material.dart';

void main() => runApp(const MaterialApp(debugShowCheckedModeBanner: false, home: SponsorBabePage()));

class SponsorBabePage extends StatefulWidget {
  const SponsorBabePage({super.key});
  @override State<SponsorBabePage> createState() => _SponsorBabePageState();
}

class _SponsorBabePageState extends State<SponsorBabePage> with TickerProviderStateMixin {
  late AnimationController globeCtrl, textCtrl, waveCtrl;
  final runTextCtrl = TextEditingController(text: "TERJEBAK PUSARAN BLACKHOLE ATMOSPHERE! BABE.INFO LUXURY! TERHIPNOTIS 60 DETIK!");
  GlobalKey globeKey = GlobalKey();
  double time = 0;

  @override void initState() {
    super.initState();
    globeCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 12))..repeat();
    waveCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat();
    textCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 14))..repeat();
  }

  @override void dispose() {
    globeCtrl.dispose(); waveCtrl.dispose(); textCtrl.dispose();
    super.dispose();
  }

  @override Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Background stars
          Positioned.fill(child: CustomPaint(painter: StarsPainter(time))),

          // GLOBE UTAMA - DI TENGAH, PASTI MUNCUL!
          Positioned.fill(
            child: RepaintBoundary(
              key: globeKey,
              child: AnimatedBuilder(
                animation: globeCtrl,
                builder: (c, _) {
                  return CustomPaint(
                    painter: BlackholeGlobePainter(globeCtrl.value, time),
                    size: Size.infinite,
                  );
                },
              ),
            ),
          ),

          // UI Bawah
          SafeArea(
            child: Column(
              children: [
                const Spacer(),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter, end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black.withOpacity(0.85)]
                    )
                  ),
                  child: Column(
                    children: [
                      ShaderMask(
                        shaderCallback: (b) => const LinearGradient(colors: [Color(0xFFFFF59D), Color(0xFFFFD700), Color(0xFFB8860B)]).createShader(b),
                        child: const Text("BABE.INFO", style: TextStyle(fontSize: 46, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 3, shadows: [Shadow(color: Colors.black, offset: Offset(3, 3), blurRadius: 10), Shadow(color: Color(0xFFFFD700), blurRadius: 25)])),
                      ),
                      const Text("(n/) By Heru Wingchun", style: TextStyle(color: Color(0xFFFFD700), fontSize: 13, fontStyle: FontStyle.italic)),
                      const SizedBox(height: 10),
                      // Running Text - Bos bilang sudah jalan
                      Container(
                        height: 38, width: double.infinity,
                        decoration: BoxDecoration(color: Colors.black.withOpacity(0.7), border: const Border.symmetric(horizontal: BorderSide(color: Color(0xFFD4AF37))), boxShadow: [BoxShadow(color: const Color(0xFFD4AF37).withOpacity(0.4), blurRadius: 15)]),
                        child: ClipRect(
                          child: AnimatedBuilder(animation: textCtrl, builder: (c, _) {
                            return Transform.translate(
                              offset: Offset(MediaQuery.of(context).size.width - textCtrl.value * (MediaQuery.of(context).size.width + 900), 0),
                              child: Text("${runTextCtrl.text}   •   ${runTextCtrl.text}", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, fontStyle: FontStyle.italic, color: Color(0xFFFFD700))),
                            );
                          }),
                        ),
                      ),
                      const SizedBox(height: 6),
                      SizedBox(height: 28, child: TextField(controller: runTextCtrl, style: const TextStyle(color: Colors.white, fontSize: 11), decoration: InputDecoration(hintText: "Input running text hipnotis...", hintStyle: const TextStyle(color: Colors.white38, fontSize: 10), filled: true, fillColor: Colors.white10, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4)), onChanged: (_) => setState(() {}))),
                      const SizedBox(height: 8),
                      Container(height: 66, decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFD4AF37).withOpacity(0.5))), child: AnimatedBuilder(animation: waveCtrl, builder: (c, _) { return CustomPaint(size: const Size(double.infinity, 66), painter: BlackholeWavePainter(waveCtrl.value, 0)); })),
                      const SizedBox(height: 8),
                      Row(children: [
                        Expanded(child: ElevatedButton(onPressed: () {}, child: const Text("UPLOAD AUDIO", style: TextStyle(fontSize: 9)))),
                        const SizedBox(width: 6),
                        Expanded(flex: 2, child: ElevatedButton(onPressed: () {}, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFD700), foregroundColor: Colors.black), child: const Text("RENDER BLACKHOLE 60S...", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11)))),
                      ]),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class BlackholeGlobePainter extends CustomPainter {
  final double anim, time;
  BlackholeGlobePainter(this.anim, this.time);

  @override void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.42);
    final radius = size.width * 0.38;

    // Blackhole shadow / accretion disk belakang
    final holePaint = Paint()..color = Colors.black..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius * 1.35, holePaint);

    // Accretion disk - cincin emas berputar
    for (int i = 0; i < 3; i++) {
      double r = radius * (1.15 + i * 0.12);
      double opacity = (0.5 - i * 0.15);
      final diskPaint = Paint()
        ..color = const Color(0xFFFFD700).withOpacity(opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2 + i * 1.5
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 4);
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(anim * 2 * math.pi * (0.3 + i * 0.2));
      canvas.scale(1, 0.25);
      canvas.drawCircle(Offset.zero, r, diskPaint);
      canvas.restore();
    }

    // Globe utama - gradient emas
    final globeRect = Rect.fromCircle(center: center, radius: radius);
    final globePaint = Paint()
      ..shader = RadialGradient(
        colors: [const Color(0xFFFFF59D), const Color(0xFFFFD700), const Color(0xFFB8860B), const Color(0xFF5D4E00)],
        stops: const [0.0, 0.3, 0.7, 1.0],
        center: Alignment(-0.3, -0.4),
      ).createShader(globeRect)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, radius, globePaint);

    // Garis latitude / longitude - biar keliatan muter
    final linePaint = Paint()
      ..color = Colors.black.withOpacity(0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (double lat = -60; lat <= 60; lat += 30) {
      double y = center.dy + radius * math.sin(lat * math.pi / 180) * 0.8;
      double w = radius * math.cos(lat * math.pi / 180);
      canvas.drawOval(Rect.fromCenter(center: Offset(center.dx, y), width: w * 2, height: w * 0.3), linePaint);
    }

    for (int i = 0; i < 12; i++) {
      double angle = (anim * 2 * math.pi + i * math.pi / 6) % (2 * math.pi);
      double x = math.cos(angle);
      if (x > -0.2) {
        Path p = Path();
        for (double yy = -1; yy <= 1; yy += 0.05) {
          double xx = x * math.sqrt(1 - yy * yy);
          double px = center.dx + xx * radius;
          double py = center.dy + yy * radius * 0.85;
          if (yy == -1) p.moveTo(px, py); else p.lineTo(px, py);
        }
        canvas.drawPath(p, linePaint);
      }
    }

    // Glow luar
    final glowPaint = Paint()
      ..color = const Color(0xFFFFD700).withOpacity(0.35)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 25);
    canvas.drawCircle(center, radius * 1.15, glowPaint);

    // Highlight specular
    final specPaint = Paint()..color = Colors.white.withOpacity(0.5)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    canvas.drawCircle(center + Offset(-radius * 0.3, -radius * 0.35), radius * 0.18, specPaint);
  }

  @override bool shouldRepaint(covariant BlackholeGlobePainter old) => old.anim != anim;
}

class StarsPainter extends CustomPainter {
  final double time;
  StarsPainter(this.time);
  @override void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white;
    final rnd = math.Random(42);
    for (int i = 0; i < 120; i++) {
      double x = rnd.nextDouble() * size.width;
      double y = rnd.nextDouble() * size.height * 0.7;
      double tw = (math.sin(time * 2 + i) * 0.5 + 0.5);
      paint.color = Colors.white.withOpacity(0.3 + tw * 0.7);
      canvas.drawCircle(Offset(x, y), rnd.nextDouble() * 1.2, paint);
    }
  }
  @override bool shouldRepaint(covariant StarsPainter old) => true;
}

class BlackholeWavePainter extends CustomPainter {
  final double anim, time;
  BlackholeWavePainter(this.anim, this.time);
  @override void paint(Canvas canvas, Size size) {
    var path = Path();
    for (double x = 0; x < size.width; x += 2) {
      double p = x / size.width;
      double w1 = math.sin(p * 8 * math.pi + anim * 2 * math.pi) * 14;
      double w2 = math.sin(p * 14 * math.pi + anim * 3 * math.pi) * 7;
      double y = size.height / 2 + (w1 + w2) * 0.5;
      if (x == 0) path.moveTo(x, y); else path.lineTo(x, y);
    }
    var glow = Paint()..color = const Color(0xFFFFD700).withOpacity(0.25)..style = PaintingStyle.stroke..strokeWidth = 16..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    canvas.drawPath(path, glow);
    var main = Paint()..color = const Color(0xFFFFD700)..style = PaintingStyle.stroke..strokeWidth = 2.8;
    canvas.drawPath(path, main);
  }
  @override bool shouldRepaint(covariant BlackholeWavePainter old) => true;
}