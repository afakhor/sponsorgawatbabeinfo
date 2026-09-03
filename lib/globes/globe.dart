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

    final double safePulse =
        beatPulse.isFinite
            ? beatPulse.clamp(0.0, 1.0).toDouble()
            : 0.0;

    final double safeTime =
        time.isFinite ? time : 0.0;

    // Float index 0 dan 1: iResolution
    shader.setFloat(0, size.width);
    shader.setFloat(1, size.height);

    // Float index 2: iTime
    shader.setFloat(2, safeTime);

    // Float index 3: rotY
    shader.setFloat(3, rotationY);

    // Float index 4: windRot
    shader.setFloat(4, safeTime * 1.20);

    // Float index 5: glow
    // Jangan terlalu besar. Nilai 1.0 cukup.
    shader.setFloat(5, 1.0);

    // Float index 6: beatPulse
    shader.setFloat(6, safePulse);

    // Float index 7: rotX
    shader.setFloat(7, rotationX);

    // Float index 8: axisTilt
    shader.setFloat(8, axisTilt);

    // Sampler index 0: textTexture
    shader.setImageSampler(0, textTexture);

    final Paint paint = Paint()
      ..shader = shader
      ..blendMode = BlendMode.srcOver;

    // Jangan menggambar warna background apa pun di sini.
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
        oldDelegate.rotationX != rotationX ||
        oldDelegate.rotationY != rotationY ||
        oldDelegate.axisTilt != axisTilt ||
        oldDelegate.beatPulse != beatPulse;
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
    with TickerProviderStateMixin {
  late final AnimationController _inertiaController;
  late final AnimationController _axisResetController;

  double _rotationX = 0.0;
  double _rotationY = 0.0;
  double _axisTilt = 0.0;

  double _velocityX = 0.0;
  double _velocityY = 0.0;

  final Map<int, Offset> _pointers = <int, Offset>{};

  double? _lastTwoFingerAngle;
  Offset? _lastTwoFingerCenter;

  double _axisTiltAtReset = 0.0;

  @override
  void initState() {
    super.initState();

    _inertiaController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..addListener(_animateInertia);

    _axisResetController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..addListener(_animateAxisReset);
  }

  // ==================================================
  // SATU JARI
  // ==================================================

  void _handleOneFingerMove(Offset delta) {
    const double horizontalSensitivity = 0.010;
    const double verticalSensitivity = 0.008;

    final double horizontalDelta =
        delta.dx * horizontalSensitivity;

    final double verticalDelta =
        delta.dy * verticalSensitivity;

    setState(() {
      _rotationY += horizontalDelta;
      _rotationX += verticalDelta;

      _rotationX = _rotationX.clamp(
        -1.35,
        1.35,
      );

      _velocityY = horizontalDelta;
      _velocityX = verticalDelta;
    });
  }

  // ==================================================
  // DUA JARI
  // ==================================================

  void _handleTwoFingerMove() {
    if (_pointers.length < 2) {
      return;
    }

    final List<Offset> values =
        _pointers.values.toList();

    final Offset first = values[0];
    final Offset second = values[1];

    final Offset vector = second - first;

    if (vector.distance < 1.0) {
      return;
    }

    final double angle = math.atan2(
      vector.dy,
      vector.dx,
    );

    final Offset center = Offset(
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
        angle - _lastTwoFingerAngle!;

    if (angleDelta > math.pi) {
      angleDelta -= 2.0 * math.pi;
    }

    if (angleDelta < -math.pi) {
      angleDelta += 2.0 * math.pi;
    }

    final Offset centerDelta =
        center - _lastTwoFingerCenter!;

    _lastTwoFingerAngle = angle;
    _lastTwoFingerCenter = center;

    setState(() {
      _axisTilt += angleDelta;
      _axisTilt += centerDelta.dy * 0.004;

      _axisTilt = _axisTilt.clamp(
        -1.50,
        1.50,
      );
    });
  }

  // ==================================================
  // POINTER
  // ==================================================

  void _onPointerDown(PointerDownEvent event) {
    _pointers[event.pointer] = event.position;

    _inertiaController.stop();
    _axisResetController.stop();

    if (_pointers.length >= 2) {
      _lastTwoFingerAngle = null;
      _lastTwoFingerCenter = null;
    }
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (!_pointers.containsKey(event.pointer)) {
      return;
    }

    final Offset previous =
        _pointers[event.pointer]!;

    final Offset delta =
        event.position - previous;

    _pointers[event.pointer] = event.position;

    if (_pointers.length == 1) {
      _handleOneFingerMove(delta);
    } else {
      _handleTwoFingerMove();
    }
  }

  void _onPointerUp(PointerUpEvent event) {
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

  void _onPointerCancel(PointerCancelEvent event) {
    _pointers.remove(event.pointer);

    if (_pointers.isEmpty) {
      _lastTwoFingerAngle = null;
      _lastTwoFingerCenter = null;

      _startInertia();
      _startAxisReset();
    }
  }

  // ==================================================
  // INERSIA
  // ==================================================

  void _startInertia() {
    if (_velocityX.abs() < 0.0001 &&
        _velocityY.abs() < 0.0001) {
      return;
    }

    _inertiaController
      ..stop()
      ..reset()
      ..forward();
  }

  void _animateInertia() {
    if (!mounted || _pointers.isNotEmpty) {
      return;
    }

    final double progress =
        _inertiaController.value;

    final double friction =
        1.0 -
        Curves.easeOut.transform(progress);

    setState(() {
      _rotationY +=
          _velocityY * friction * 0.35;

      _rotationX +=
          _velocityX * friction * 0.35;

      _rotationX = _rotationX.clamp(
        -1.35,
        1.35,
      );
    });

    if (_inertiaController.isCompleted) {
      _velocityX = 0.0;
      _velocityY = 0.0;
    }
  }

  // ==================================================
  // RESET AXIS
  // ==================================================

  void _startAxisReset() {
    if (_axisTilt.abs() < 0.0001) {
      _axisTilt = 0.0;
      return;
    }

    _axisTiltAtReset = _axisTilt;

    _axisResetController
      ..stop()
      ..reset()
      ..forward();
  }

  void _animateAxisReset() {
    if (!mounted || _pointers.isNotEmpty) {
      return;
    }

    final double progress =
        Curves.easeOutCubic.transform(
      _axisResetController.value,
    );

    setState(() {
      _axisTilt =
          _axisTiltAtReset * (1.0 - progress);
    });

    if (_axisResetController.isCompleted) {
      _axisTilt = 0.0;
    }
  }

  // ==================================================
  // BUILD
  // ==================================================

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: _onPointerUp,
      onPointerCancel: _onPointerCancel,
      child: CustomPaint(
        painter: GlobeShaderPainter(
          program: widget.program,
          textTexture: widget.textTexture,
          time: widget.time,
          rotationX: _rotationX,
          rotationY: _rotationY,
          axisTilt: _axisTilt,
          beatPulse: widget.beatPulse,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }

  @override
  void dispose() {
    _inertiaController.dispose();
    _axisResetController.dispose();
    super.dispose();
  }
}
