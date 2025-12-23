import 'package:flutter/material.dart';

// Widgets
import 'package:ar_flutter_plugin_2/widgets/ar_view.dart';

// Managers
import 'package:ar_flutter_plugin_2/managers/ar_session_manager.dart';
import 'package:ar_flutter_plugin_2/managers/ar_object_manager.dart';
import 'package:ar_flutter_plugin_2/managers/ar_anchor_manager.dart';
import 'package:ar_flutter_plugin_2/managers/ar_location_manager.dart';

// Datatypes / Models
import 'package:ar_flutter_plugin_2/datatypes/config_planedetection.dart';
import 'package:ar_flutter_plugin_2/datatypes/hittest_result_types.dart';
import 'package:ar_flutter_plugin_2/datatypes/node_types.dart';
import 'package:ar_flutter_plugin_2/models/ar_hittest_result.dart';
import 'package:ar_flutter_plugin_2/models/ar_anchor.dart';
import 'package:ar_flutter_plugin_2/models/ar_node.dart';

import 'package:vector_math/vector_math_64.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return const MaterialApp(debugShowCheckedModeBanner: false, home: ArHome());
  }
}

class ArHome extends StatefulWidget {
  const ArHome({super.key});
  @override
  State<ArHome> createState() => _ArHomeState();
}

class _ArHomeState extends State<ArHome> {
  ARSessionManager? arSessionManager;
  ARObjectManager? arObjectManager;
  ARAnchorManager? arAnchorManager;
  ARLocationManager? arLocationManager;

  ARAnchor? ultimoAnchor;

  String modeloSeleccionado = "assets/models/Carga_negativa.glb";

  @override
  void dispose() {
    // Importante: el dispose es del SessionManager (no de “ArFlutterPlugin”)
    arSessionManager?.dispose();
    super.dispose();
  }

  void onARViewCreated(
    ARSessionManager sessionManager,
    ARObjectManager objectManager,
    ARAnchorManager anchorManager,
    ARLocationManager locationManager,
  ) {
    arSessionManager = sessionManager;
    arObjectManager = objectManager;
    arAnchorManager = anchorManager;
    arLocationManager = locationManager;

    arSessionManager?.onInitialize(
      showPlanes: true,
      showWorldOrigin: false,
      showFeaturePoints: false,
      handleTaps: true,
      handlePans: true,
      handleRotation: true,
    );

    arObjectManager?.onInitialize();

    // ✅ Aquí se captura el tap en plano/punto (no es parámetro de ARView)
    arSessionManager?.onPlaneOrPointTap = (List<ARHitTestResult> hits) {
      _colocarModeloEnTap(hits);
    };
  }

  Future<void> _colocarModeloEnTap(List<ARHitTestResult> hits) async {
    if (hits.isEmpty) return;
    if (arAnchorManager == null || arObjectManager == null) return;

    final hit = hits.firstWhere(
      (h) => h.type == ARHitTestResultType.plane,
      orElse: () => hits.first,
    );

    // Dejar solo 1 modelo a la vez
    if (ultimoAnchor != null) {
      await arAnchorManager!.removeAnchor(ultimoAnchor!);
      ultimoAnchor = null;
    }

    final anchor = ARPlaneAnchor(transformation: hit.worldTransform);
    final okAnchor = await arAnchorManager!.addAnchor(anchor);
    if (okAnchor != true) return;

    ultimoAnchor = anchor;

    final node = ARNode(
      type: NodeType.localGLTF2,
      uri: modeloSeleccionado,
      scale: Vector3(0.25, 0.25, 0.25),
      position: Vector3(0, 0, 0),
      rotation: Vector4(1, 0, 0, 0),
    );

    final okNode = await arObjectManager!.addNode(node, planeAnchor: anchor);
    if (okNode != true) {
      arSessionManager!.onError?.call("No se pudo cargar: $modeloSeleccionado");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("ARCore prueba (ar_flutter_plugin_2)")),
      body: Stack(
        children: [
          ARView(
            onARViewCreated: onARViewCreated,
            planeDetectionConfig: PlaneDetectionConfig.horizontalAndVertical,
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      "Selecciona modelo y toca un plano para colocarlo",
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => setState(() {
                              modeloSeleccionado =
                                  "assets/models/Carga_negativa.glb";
                            }),
                            child: const Text("Carga_negativa"),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => setState(() {
                              modeloSeleccionado =
                                  "assets/models/Caso(-,-,-)_respecto_C1.glb";
                            }),
                            child: const Text("Caso animado"),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "Actual: $modeloSeleccionado",
                      style: const TextStyle(fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
