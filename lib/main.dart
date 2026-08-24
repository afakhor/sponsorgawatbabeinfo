class BlackholeGlobePainter extends CustomPainter {
  final double anim, time;
  BlackholeGlobePainter(this.anim, this.time);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.42);
    final radius = size.width * 0.38;

    // 1. BLACKHOLE CORE - HITAM PEKAT DI BELAKANG GLOBE
    final blackHolePaint = Paint()..color = const Color(0xFF000000)..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius * 1.45, blackHolePaint);

    // 2. EVENT HORIZON - GLOW HITAM KE EMAS
    final horizonPaint = Paint()
      ..shader = RadialGradient(
        colors: [Colors.black, Colors.black, const Color(0xFF1A1200), const Color(0xFFFFD700).withOpacity(0.0)],
        stops: const [0.0, 0.65, 0.85, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius * 1.6))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20);
    canvas.drawCircle(center, radius * 1.6, horizonPaint);

    // 3. ACCRETION DISK - PUSARAN MAUT (3 lapis muter beda kecepatan)
    for (int i = 0; i < 4; i++) {
      double baseR = radius * (1.25 + i * 0.18);
      double speed = 0.5 + i * 0.35;
      double rot = anim * 2 * math.pi * speed;
      
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(rot);
      canvas.scale(1, 0.22 + i * 0.04);

      // Disk gradient emas menyala
      final diskPath = Path()..addOval(Rect.fromCircle(center: Offset.zero, radius: baseR));
      final diskPaint = Paint()
        ..shader = SweepGradient(
          colors: [
            const Color(0xFFFFD700).withOpacity(0.0),
            const Color(0xFFFFD700),
            const Color(0xFFFFA500),
            const Color(0xFFFFD700),
            const Color(0xFFFFF59D),
            const Color(0xFFFFD700).withOpacity(0.0),
          ],
          stops: const [0.0, 0.15, 0.35, 0.5, 0.7, 1.0],
          startAngle: 0,
          endAngle: math.pi * 2,
        ).createShader(Rect.fromCircle(center: Offset.zero, radius: baseR))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8 - i * 1.2
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 6);

      canvas.drawCircle(Offset.zero, baseR, diskPaint);
      
      // Partikel pusaran
      for (int j = 0; j < 8; j++) {
        double ang = j * math.pi / 4 + anim * 3;
        double x = math.cos(ang) * baseR;
        double y = math.sin(ang) * baseR * 0.3;
        canvas.drawCircle(Offset(x, y), 2.5, Paint()..color = const Color(0xFFFFF59D).withOpacity(0.8));
      }
      canvas.restore();
    }

    // 4. GLOBE UTAMA - Sekarang di depan blackhole, tapi ada shadow blackhole
    final globeRect = Rect.fromCircle(center: center, radius: radius);
    final globePaint = Paint()
      ..shader = RadialGradient(
        colors: [const Color(0xFFFFF59D), const Color(0xFFFFD700), const Color(0xFFB8860B), const Color(0xFF5D4E00)],
        stops: const [0.0, 0.25, 0.65, 1.0],
        center: const Alignment(-0.35, -0.45),
        radius: 1.1,
      ).createShader(globeRect)
      ..style = PaintingStyle.fill;

    // Shadow globe karena blackhole
    canvas.drawCircle(center + Offset(radius * 0.15, radius * 0.1), radius, Paint()..color = Colors.black.withOpacity(0.4)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15));
    canvas.drawCircle(center, radius, globePaint);

    // 5. LENSING EFFECT - Cahaya melengkung di pinggir globe
    final lensPaint = Paint()
      ..color = const Color(0xFFFFD700).withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawCircle(center, radius * 1.02, lensPaint);

    // 6. Garis longitude biar muter
    final linePaint = Paint()..color = Colors.black.withOpacity(0.22)..style = PaintingStyle.stroke..strokeWidth = 1;
    for (int i = 0; i < 12; i++) {
      double angle = (anim * 2 * math.pi + i * math.pi / 6) % (2 * math.pi);
      double x = math.cos(angle);
      if (x > -0.3) {
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
    for (double lat = -60; lat <= 60; lat += 30) {
      double y = center.dy + radius * math.sin(lat * math.pi / 180) * 0.8;
      double w = radius * math.cos(lat * math.pi / 180);
      canvas.drawOval(Rect.fromCenter(center: Offset(center.dx, y), width: w * 2, height: w * 0.3), linePaint);
    }

    // 7. GLOW DEPAN PALING GAWAT
    canvas.drawCircle(center, radius * 1.12, Paint()..color = const Color(0xFFFFD700).withOpacity(0.25)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 22));
    canvas.drawCircle(center + Offset(-radius * 0.32, -radius * 0.38), radius * 0.19, Paint()..color = Colors.white.withOpacity(0.55)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12));
  }

  @override bool shouldRepaint(covariant BlackholeGlobePainter old) => old.anim != anim;
}