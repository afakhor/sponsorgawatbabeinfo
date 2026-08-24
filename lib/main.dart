import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'globes/globe.dart';

void main()=>runApp(const MaterialApp(debugShowCheckedModeBanner:false, home:SponsorBabePage()));

class SponsorBabePage extends StatefulWidget { const SponsorBabePage({super.key}); @override State<SponsorBabePage> createState()=>_SponsorBabePageState(); }

class _SponsorBabePageState extends State<SponsorBabePage> with TickerProviderStateMixin {
  ui.FragmentProgram? fragProg; double time=0;
  late AnimationController timeCtrl;
  @override void initState(){ 
    super.initState(); 
    timeCtrl=AnimationController(vsync:this, duration: const Duration(milliseconds:16))
      ..addListener((){time+=0.016; if(mounted) setState((){});})..repeat(); 
    _load(); 
  }
  Future<void> _load() async { 
    fragProg = await ui.FragmentProgram.fromAsset('shaders/globe.frag'); 
    setState((){}); 
  }
  @override void dispose(){ timeCtrl.dispose(); super.dispose(); }
  @override Widget build(BuildContext context){
    return Scaffold(
      backgroundColor: Colors.black,
      // CUMA BOLA DOANG, GAK ADA TEXT TENGAH LAGI
      body: fragProg==null 
        ? const Center(child:CircularProgressIndicator(color:Color(0xFFFFD700))) 
        : GlobeShaderWidget(program:fragProg!, time:time),
    );
  }
}