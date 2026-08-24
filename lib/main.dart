import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'globes/globe.dart';

void main() => runApp(const MaterialApp(debugShowCheckedModeBanner: false, home: SponsorBabePage()));

class SponsorBabePage extends StatefulWidget {
  const SponsorBabePage({super.key});
  @override State<SponsorBabePage> createState() => _SponsorBabePageState();
}

class _SponsorBabePageState extends State<SponsorBabePage> with TickerProviderStateMixin {
  ui.FragmentProgram? fragProg;
  late AnimationController timeCtrl, textCtrl, waveCtrl;
  final runTextCtrl = TextEditingController(text: "TERJEBAK PUSARAN BLACKHOLE ATMOSPHERE! BABE.INFO LUXURY! TERHIPNOTIS 60 DETIK!");
  double time = 0;

  @override
  void initState() {
    super.initState();
    timeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 16))
      ..addListener((){ time += 0.016; if(mounted) setState((){}); })..repeat();
    textCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 14))..repeat();
    waveCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat();
    _load();
  }

  Future<void> _load() async {
    fragProg = await ui.FragmentProgram.fromAsset('shaders/globe.frag');
    setState((){});
  }

  @override void dispose() {
    timeCtrl.dispose(); textCtrl.dispose(); waveCtrl.dispose();
    super.dispose();
  }

  @override Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: fragProg == null
              ? const Center(child: CircularProgressIndicator(color: Color(0xFFFFD700)))
              : GlobeShaderWidget(program: fragProg!, time: time),
          ),
          SafeArea(
            child: Column(
              children: [
                const Spacer(),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black.withOpacity(0.85)])),
                  child: Column(
                    children: [
                      ShaderMask(
                        shaderCallback: (b) => const LinearGradient(colors: [Color(0xFFFFF59D), Color(0xFFFFD700), Color(0xFFB8860B)]).createShader(b),
                        child: const Text("BABE.INFO", style: TextStyle(fontSize: 46, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 3, shadows: [Shadow(color: Colors.black, offset: Offset(3, 3), blurRadius: 10), Shadow(color: Color(0xFFFFD700), blurRadius: 25)])),
                      ),
                      const Text("(n/) By Heru Wingchun", style: TextStyle(color: Color(0xFFFFD700), fontSize: 13, fontStyle: FontStyle.italic)),
                      const SizedBox(height: 10),
                      Container(
                        height: 38, width: double.infinity,
                        decoration: BoxDecoration(color: Colors.black.withOpacity(0.7), border: const Border.symmetric(horizontal: BorderSide(color: Color(0xFFD4AF37))), boxShadow: [BoxShadow(color: const Color(0xFFD4AF37).withOpacity(0.4), blurRadius: 15)]),
                        child: ClipRect(
                          child: AnimatedBuilder(animation: textCtrl, builder: (c, _) {
                            return Transform.translate(offset: Offset(MediaQuery.of(context).size.width - textCtrl.value * (MediaQuery.of(context).size.width + 900), 0), child: Text("${runTextCtrl.text}   •   ${runTextCtrl.text}", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, fontStyle: FontStyle.italic, color: Color(0xFFFFD700))));
                          }),
                        ),
                      ),
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