import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

void main() => runApp(const MaterialApp(debugShowCheckedModeBanner: false, home: SponsorBabePage()));

class SponsorBabePage extends StatefulWidget {
  const SponsorBabePage({super.key});
  @override State<SponsorBabePage> createState() => _SponsorBabePageState();
}

class _SponsorBabePageState extends State<SponsorBabePage> with TickerProviderStateMixin {
  ui.FragmentProgram? fragProg;
  late AnimationController timeCtrl, textCtrl, waveCtrl;
  final runTextCtrl = TextEditingController(text: "TERJEBAK PUSARAN BLACKHOLE ATMOSPHERE! BABE.INFO LUXURY! TERHIPNOTIS 60 DETIK!");
  GlobalKey globeKey = GlobalKey();
  double time = 0;
  bool fragReady = false;

  @override
  void initState() {
    super.initState();
    timeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 16))..addListener((){ setState(()=> time += 0.016); })..repeat();
    textCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 14))..repeat();
    waveCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat();
    loadFrag();
  }

  Future<void> loadFrag() async {
    try {
      fragProg = await ui.FragmentProgram.fromAsset('shaders/globe.frag');
      setState(()=> fragReady = true);
    } catch (e) {
      print("FRAG ERROR: $e");
      setState(()=> fragReady = false);
    }
  }

  @override void dispose() {
    timeCtrl.dispose(); textCtrl.dispose(); waveCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // FULL FRAG BLACKHOLE + GLOBE
          Positioned.fill(
            child: RepaintBoundary(
              key: globeKey,
              child: fragReady && fragProg != null
                  ? CustomPaint(
                      painter: FullBlackholeFragPainter(fragProg!, time),
                      size: Size.infinite,
                    )
                  : const Center(child: CircularProgressIndicator(color: Color(0xFFFFD700))),
            ),
          ),

          // UI BAWAH - TETAP
          SafeArea(
            child: Column(
              children: [
                const Spacer(),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black.withOpacity(0.82)])),
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
                      const SizedBox(height: 6),
                      SizedBox(height: 28, child: TextField(controller: runTextCtrl, style: const TextStyle(color: Colors.white, fontSize: 11), decoration: InputDecoration(hintText: "Input running text...", hintStyle: const TextStyle(color: Colors.white38, fontSize: 10), filled: true, fillColor: Colors.white10, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4)), onChanged: (_) => setState(() {}))),
                      const SizedBox(height: 8),
                      Container(height: 66, decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFD4AF37).withOpacity(0.5))), child: AnimatedBuilder(animation: waveCtrl, builder: (c, _) => CustomPaint(size: const Size(double.infinity, 66), painter: BlackholeWavePainter(waveCtrl.value)))),
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

class FullBlackholeFragPainter extends CustomPainter {
  final ui.FragmentProgram prog; 
  final double time;
  
  FullBlackholeFragPainter(this.prog, this.time);

  @override 
  void paint(Canvas canvas, Size size) {
    final shader = prog.fragmentShader();
    
    // Sesuai urutan di globe.frag - 5 uniform aja!
    shader.setFloat(0, size.width);   // iResolution.x
    shader.setFloat(1, size.height);  // iResolution.y
    shader.setFloat(2, time);         // iTime - detik berjalan
    shader.setFloat(3, time * 0.35);  // rotY - muter globe 0.35 speed (biar BABE.INFO keliatan jalan)
    shader.setFloat(4, 1.8);          // glow - NAIKIN JADI 1.8 BIAR ANGIN EMAS TERANG KAYA GAMBAR BOS!

    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
  }

  @override 
  bool shouldRepaint(covariant FullBlackholeFragPainter old) => old.time != time;
}