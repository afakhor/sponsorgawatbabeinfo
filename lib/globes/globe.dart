import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

class GlobeShaderPainter extends CustomPainter {
  final ui.FragmentProgram program;
  final ui.Image textTexture;

  final double time;
  final double rotationX;
  final double rotationY;
  final double axisTilt;
  final double beatPulse;

  const GlobeShaderPainter({
    required this.program,
    required this.textTexture,
    required this.time,
    required this.rotationX,
    required this.rotationY,
    required this.axisTilt,
    required this.beatPulse,
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
    // URUTAN FLOAT SHADER
    // --------------------------------------------------
    //
    // 0 = iResolution.x
    // 1 = iResolution.y
    // 2 = iTime
    // 3 = rotY
    // 4 = windRot
    // 5 = glow
    // 6 = beatPulse
    // 7 = rotX
    // 8 = axisTilt
    //

    shader.setFloat(
      0,
      size.width,
    );

    shader.setFloat(
      1,
      size.height,
    );

    shader.setFloat(
      2,
      time,
    );

    // Rotasi globe dari satu jari dan inertia.
    // Tidak menggunakan beatPulse.
    shader.setFloat(
      3,
      rotationY,
    );

    // Gerakan texture normal.
    shader.setFloat(
      4,
      time * 1.20,
    );

    // Glow dasar.
    shader.setFloat(
      5,
      4.0,
    );

    // Beat hanya untuk efek wave/buih/atmosfer.
    shader.setFloat(
      6,
      beatPulse,
    );

    // Rotasi vertikal dari drag satu jari.
    shader.setFloat(
      7,
      rotationX,
    );

    // Kemiringan poros dari dua jari.
    shader.setFloat(
      8,
      axisTilt,
    );

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
        oldDelegate.time != time ||
        oldDelegate.rotationX !=
            rotationX ||
        oldDelegate.rotationY !=
            rotationY ||
        oldDelegate.axisTilt !=
            axisTilt ||
        oldDelegate.beatPulse !=
            beatPulse;
  }
}

class GlobeShaderWidget extends StatefulWidget {
  final ui.FragmentProgram program;
  final ui.Image textTexture;
  final double time;
  final double beatPulse;

  const GlobeShaderWidget({
    super.key,
    required this.program,
    required this.textTexture,
    required this.time,
    this.beatPulse = 0.0,
  });

  @override
  State<GlobeShaderWidget> createState() {
    return _GlobeShaderWidgetState();
  }
}

class _GlobeShaderWidgetState
    extends State<GlobeShaderWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController
      _inertiaController;

  late final AnimationController
      _axisResetController;

  // Rotasi globe.
  double _rotationX = 0.0;
  double _rotationY = 0.0;

  // Kemiringan/poros globe.
  double _axisTilt = 0.0;

  // Kecepatan rotasi terakhir.
  double _velocityX = 0.0;
  double _velocityY = 0.0;

  // Data posisi pointer.
  final Map<int, Offset> _pointers =
      <int, Offset>{};

  // Data dua jari.
  double? _lastTwoFingerAngle;
  Offset? _lastTwoFingerCenter;

  // Nilai poros sebelum reset.
  double _axisTiltAtReset = 0.0;

  @override
  void initState() {
    super.initState();

    _inertiaController =
        AnimationController(
      vsync: this,
      duration: const Duration(
        milliseconds: 700,
      ),
    );

    _axisResetController =
        AnimationController(
      vsync: this,
      duration: const Duration(
        milliseconds: 500,
      ),
    );

    _axisResetController.addListener(
      _animateAxisReset,
    );
  }

  // ==================================================
  // SATU JARI: ROTASI GLOBE
  // ==================================================

  void _handleOneFingerMove(
    Offset delta,
  ) {
    // Sensitivitas horizontal.
    const double horizontalSensitivity =
        0.010;

    // Sensitivitas vertikal.
    const double verticalSensitivity =
        0.008;

    final double deltaY =
        delta.dx *
        horizontalSensitivity;

    final double deltaX =
        delta.dy *
        verticalSensitivity;

    setState(() {
      _rotationY += deltaY;
      _rotationX += deltaX;

      // Batasi rotasi vertikal supaya globe
      // tidak terbalik terlalu ekstrem.
      _rotationX =
          _rotationX.clamp(
        -1.35,
        1.35,
      );

      // Kecepatan untuk inertia.
      _velocityY = deltaY;
      _velocityX = deltaX;
    });
  }

  // ==================================================
  // DUA JARI: POROS/KEMIRINGAN GLOBE
  // ==================================================

  void _handleTwoFingerMove() {
    if (_pointers.length < 2) {
      return;
    }

    final List<Offset> positions =
        _pointers.values.toList();

    final Offset first =
        positions[0];

    final Offset second =
        positions[1];

    final Offset vector =
        second - first;

    if (vector.distance < 1.0) {
      return;
    }

    final double angle =
        math.atan2(
      vector.dy,
      vector.dx,
    );

    final Offset center =
        Offset(
      (first.dx + second.dx) * 0.5,
      (first.dy + second.dy) * 0.5,
    );

    if (_lastTwoFingerAngle == null ||
        _lastTwoFingerCenter == null) {
      _lastTwoFingerAngle = angle;
      _lastTwoFingerCenter = center;
      return;
    }

    double angleDelta =
        angle -
        _lastTwoFingerAngle!;

    // Menghindari loncatan ketika sudut melewati
    // -PI ke PI.
    if (angleDelta > math.pi) {
      angleDelta -= 2.0 * math.pi;
    }

    if (angleDelta < -math.pi) {
      angleDelta += 2.0 * math.pi;
    }

    final Offset centerDelta =
        center -
        _lastTwoFingerCenter!;

    _lastTwoFingerAngle = angle;
    _lastTwoFingerCenter = center;

    setState(() {
      // Rotasi dua jari memutar poros globe.
      _axisTilt += angleDelta;

      // Gerakan dua jari naik/turun juga memberi
      // sedikit kemiringan poros.
      _axisTilt +=
          centerDelta.dy * 0.004;

      _axisTilt =
          _axisTilt.clamp(
        -1.50,
        1.50,
      );
    });
  }

  // ==================================================
  // POINTER DOWN
  // ==================================================

  void _onPointerDown(
    PointerDownEvent event,
  ) {
    _pointers[event.pointer] =
        event.position;

    _inertiaController.stop();
    _axisResetController.stop();

    if (_pointers.length >= 2) {
      _lastTwoFingerAngle = null;
      _lastTwoFingerCenter = null;
    }
  }

  // ==================================================
  // POINTER MOVE
  // ==================================================

  void _onPointerMove(
    PointerMoveEvent event,
  ) {
    if (!_pointers.containsKey(
      event.pointer,
    )) {
      return;
    }

    final Offset previous =
        _pointers[event.pointer]!;

    final Offset delta =
        event.position -
        previous;

    _pointers[event.pointer] =
        event.position;

    if (_pointers.length == 1) {
      _handleOneFingerMove(delta);
    } else if (_pointers.length >= 2) {
      _handleTwoFingerMove();
    }
  }

  // ==================================================
  // POINTER UP
  // ==================================================

  void _onPointerUp(
    PointerUpEvent event,
  ) {
    _pointers.remove(event.pointer);

    if (_pointers.length < 2) {
      _lastTwoFingerAngle = null;
      _lastTwoFingerCenter = null;
    }

    if (_pointers.isEmpty) {
      _startInertia();
      _startAxisReset();
    }
  }

  // ==================================================
  // POINTER CANCEL
  // ==================================================

  void _onPointerCancel(
    PointerCancelEvent event,
  ) {
    _pointers.remove(event.pointer);

    if (_pointers.isEmpty) {
      _lastTwoFingerAngle = null;
      _lastTwoFingerCenter = null;

      _startInertia();
      _startAxisReset();
    }
  }

  // ==================================================
  // INERTIA ROTASI SATU JARI
  // ==================================================

  void _startInertia() {
    if (_velocityX.abs() < 0.0001 &&
        _velocityY.abs() < 0.0001) {
      return;
    }

    _inertiaController
      ..stop()
      ..reset();

    _inertiaController.addListener(
      _animateInertia,
    );

    _inertiaController.forward();
  }

  void _animateInertia() {
    if (!mounted) {
      return;
    }

    if (_pointers.isNotEmpty) {
      _inertiaController.stop();
      return;
    }

    final double progress =
        _inertiaController.value;

    final double friction =
        1.0 -
        Curves.easeOut.transform(
          progress,
        );

    setState(() {
      _rotationY +=
          _velocityY *
          friction *
          0.35;

      _rotationX +=
          _velocityX *
          friction *
          0.35;

      _rotationX =
          _rotationX.clamp(
        -1.35,
        1.35,
      );
    });

    if (_inertiaController.isCompleted) {
      _inertiaController.removeListener(
        _animateInertia,
      );

      _velocityX = 0.0;
      _velocityY = 0.0;
    }
  }

  // ==================================================
  // RESET POROS SETELAH DUA JARI LEPAS
  // ==================================================

  void _startAxisReset() {
    if (_axisTilt.abs() < 0.0001) {
      _axisTilt = 0.0;
      return;
    }

    _axisTiltAtReset =
        _axisTilt;

    _axisResetController
      ..stop()
      ..reset()
      ..forward();
  }

  void _animateAxisReset() {
    if (!mounted) {
      return;
    }

    if (_pointers.isNotEmpty) {
      _axisResetController.stop();
      return;
    }

    final double progress =
        Curves.easeOutCubic.transform(
      _axisResetController.value,
    );

    setState(() {
      _axisTilt =
          _axisTiltAtReset *
          (1.0 - progress);
    });

    if (_axisResetController.isCompleted) {
      _axisTilt = 0.0;
    }
  }

  // ==================================================
  // BUILD
  // ==================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    return Listener(
      behavior:
          HitTestBehavior.opaque,
      onPointerDown:
          _onPointerDown,
      onPointerMove:
          _onPointerMove,
      onPointerUp:
          _onPointerUp,
      onPointerCancel:
          _onPointerCancel,
      child: SizedBox.expand(
        child: RepaintBoundary(
          child: CustomPaint(
            painter:
                GlobeShaderPainter(
              program: widget.program,
              textTexture:
                  widget.textTexture,
              time: widget.time,
              rotationX:
                  _rotationX,
              rotationY:
                  _rotationY,
              axisTilt:
                  _axisTilt,
              beatPulse:
                  widget.beatPulse,
            ),
            child:
                const SizedBox.expand(),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _inertiaController
        .removeListener(
      _animateInertia,
    );

    _axisResetController
        .removeListener(
      _animateAxisReset,
    );

    _inertiaController.dispose();
    _axisResetController.dispose();

    super.dispose();
  }
}
