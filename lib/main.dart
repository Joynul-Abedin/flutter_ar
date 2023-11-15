// import 'dart:async';
//
// import 'package:ar_flutter_plugin/ar_flutter_plugin.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
//
// import 'objects_on_plane.dart';
//
// void main() {
//   WidgetsFlutterBinding.ensureInitialized();
//   runApp(const MyApp());
// }
//
// class MyApp extends StatefulWidget {
//   const MyApp({super.key});
//
//   @override
//   MyAppState createState() => MyAppState();
// }
//
// class MyAppState extends State<MyApp> {
//   String _platformVersion = 'Unknown';
//   static const String _title = 'AR Plugin Demo';
//
//   @override
//   void initState() {
//     super.initState();
//     initPlatformState();
//   }
//
//   // Platform messages are asynchronous, so we initialize in an async method.
//   Future<void> initPlatformState() async {
//     String platformVersion;
//     // Platform messages may fail, so we use a try/catch PlatformException.
//     try {
//       platformVersion = await ArFlutterPlugin.platformVersion;
//     } on PlatformException {
//       platformVersion = 'Failed to get platform version.';
//     }
//
//     // If the widget was removed from the tree while the asynchronous platform
//     // message was in flight, we want to discard the reply rather than calling
//     // setState to update our non-existent appearance.
//     if (!mounted) return;
//
//     setState(() {
//       _platformVersion = platformVersion;
//     });
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       home: Scaffold(
//         appBar: AppBar(
//           title: const Text(_title),
//         ),
//         body: Column(children: [
//           Text('Running on: $_platformVersion\n'),
//           const Expanded(
//             child: ExampleList(),
//           ),
//         ]),
//       ),
//     );
//   }
// }
//
// class ExampleList extends StatelessWidget {
//   const ExampleList({Key? key}) : super(key: key);
//
//   @override
//   Widget build(BuildContext context) {
//     final examples = [
//       Example(
//           'Anchors & Objects on Planes',
//           'Place 3D objects on detected planes using anchors',
//           () => Navigator.push(
//               context,
//               MaterialPageRoute(
//                   builder: (context) => const ObjectsOnPlanesWidget()))),
//     ];
//     return ListView(
//       children:
//           examples.map((example) => ExampleCard(example: example)).toList(),
//     );
//   }
// }
//
// class ExampleCard extends StatelessWidget {
//   ExampleCard({Key? key, required this.example}) : super(key: key);
//   final Example example;
//
//   @override
//   build(BuildContext context) {
//     return Card(
//       child: InkWell(
//         splashColor: Colors.blue.withAlpha(30),
//         onTap: () {
//           example.onTap();
//         },
//         child: ListTile(
//           title: Text(example.name),
//           subtitle: Text(example.description),
//         ),
//       ),
//     );
//   }
// }
//
// class Example {
//   const Example(this.name, this.description, this.onTap);
//   final String name;
//   final String description;
//   final Function onTap;
// }

import 'dart:io';

import 'package:ar_flutter_plugin/datatypes/config_planedetection.dart';
import 'package:ar_flutter_plugin/datatypes/hittest_result_types.dart';
import 'package:ar_flutter_plugin/datatypes/node_types.dart';
import 'package:ar_flutter_plugin/managers/ar_anchor_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_location_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_object_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_session_manager.dart';
import 'package:ar_flutter_plugin/models/ar_anchor.dart';
import 'package:ar_flutter_plugin/models/ar_hittest_result.dart';
import 'package:ar_flutter_plugin/models/ar_node.dart';
import 'package:ar_flutter_plugin/widgets/ar_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:vector_math/vector_math_64.dart' as vector;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final asset = 'marker.glb';
  late ARSessionManager arSessionManager;
  late ARObjectManager arObjectManager;
  late ARAnchorManager arAnchorManager;

  Future<void> _onARViewCreated(
    ARSessionManager arSessionManager,
    ARObjectManager arObjectManager,
    ARAnchorManager arAnchorManager,
    ARLocationManager arLocationManager,
  ) async {
    this.arSessionManager = arSessionManager;
    this.arObjectManager = arObjectManager;
    this.arAnchorManager = arAnchorManager;
    this.arSessionManager.onInitialize(
          handlePans: true,
          handleRotation: true,
          showWorldOrigin: true,
          customPlaneTexturePath: 'assets/images/triangle.png',
        );
    this.arObjectManager.onInitialize();
    this.arSessionManager.onPlaneOrPointTap = _onPlaneOrPointTapped;
  }

  Future<void> _onPlaneOrPointTapped(
    List<ARHitTestResult> hitTestResults,
  ) async {
    final singleHitTestResult = hitTestResults
        .firstWhere((result) => result.type == ARHitTestResultType.plane);
    final newAnchor =
        ARPlaneAnchor(transformation: singleHitTestResult.worldTransform);
    final didAddAnchor = await arAnchorManager.addAnchor(newAnchor);
    if (didAddAnchor == true) {
      await _copyAssetModelsToDocumentDirectory();
      final newNode = ARNode(
        type: NodeType.fileSystemAppFolderGLB,
        uri: asset,
        scale: vector.Vector3(0.5, 0.5, 0.5),
        position: vector.Vector3(0.0, 0.0, 0.0),
        rotation: vector.Vector4(1.0, 0.0, 0.0, 0.0),
      );
      final didAddNodeToAnchor =
          await arObjectManager.addNode(newNode, planeAnchor: newAnchor);
      if (didAddNodeToAnchor == false) {
        arSessionManager.onError('Adding Node to Anchor failed');
      }
    } else {
      arSessionManager.onError('Adding Anchor failed');
    }
  }

  Future<void> _copyAssetModelsToDocumentDirectory() async {
    final docDir = await getApplicationDocumentsDirectory();
    final docDirPath = docDir.path;
    final file = File('$docDirPath/$asset');
    final assetBytes = await rootBundle.load('assets/$asset');
    final buffer = assetBytes.buffer;
    await file.writeAsBytes(
      buffer.asUint8List(assetBytes.offsetInBytes, assetBytes.lengthInBytes),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.transparent,
        ),
        body: ARView(
          onARViewCreated: _onARViewCreated,
          planeDetectionConfig: PlaneDetectionConfig.horizontal,
        ),
      ),
    );
  }

  @override
  void dispose() {
    arSessionManager.dispose();
    super.dispose();
  }
}
