import 'package:flutter/material.dart';
import 'package:three_js/three_js.dart' as three;

void main() => runApp(MaterialApp(home: GlobePage()));

class GlobePage extends StatefulWidget { @override State<GlobePage> createState()=>_GlobePageState(); }
class _GlobePageState extends State<GlobePage> {
  late three.ThreeJS threeJs;
  @override void initState(){
    threeJs = three.ThreeJS(onSetupComplete: (){setState((){});}, setup: () async {
      threeJs.scene = three.Scene();
      threeJs.camera = three.PerspectiveCamera(50, threeJs.width/threeJs.height, 0.1, 100);
      threeJs.camera.position.z = 3;
      threeJs.scene.add(three.AmbientLight(0xffffff, 1));
      final geo = three.SphereGeometry(1, 32, 32);
      final mat = three.MeshStandardMaterial.fromMap({"color": 0xFFD700});
      final mesh = three.Mesh(geo, mat);
      threeJs.scene.add(mesh);
      threeJs.addAnimationEvent((dt){ mesh.rotation.y += 0.01; });
    });
    super.initState();
  }
  @override Widget build(BuildContext c) => Scaffold(body: threeJs.build());
}