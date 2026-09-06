import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../../../core/theme/mpesa_theme.dart';

class ArCampusMapView extends StatefulWidget {
  const ArCampusMapView({super.key});

  @override
  State<ArCampusMapView> createState() => _ArCampusMapViewState();
}

class _ArCampusMapViewState extends State<ArCampusMapView> {
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isCameraInitialized = false;

  final List<Map<String, dynamic>> _mockArMarkers = [
    {
      'title': 'Student Center Cafeteria',
      'discount': '20% OFF Meals',
      'wait_time': '5 mins',
      'top': 150.0,
      'left': 80.0,
      'color': Colors.blueAccent
    },
    {
      'title': 'Library Coffee Shop',
      'discount': 'Happy Hour - 50% OFF',
      'wait_time': '12 mins',
      'top': 400.0,
      'left': 200.0,
      'color': Colors.orangeAccent
    }
  ];

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras != null && _cameras!.isNotEmpty) {
        _cameraController = CameraController(
          _cameras![0],
          ResolutionPreset.high,
          enableAudio: false,
        );
        
        await _cameraController!.initialize();
        if (mounted) {
          setState(() {
            _isCameraInitialized = true;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Camera Error: $e')));
      }
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  Widget _buildArMarker(Map<String, dynamic> marker) {
    return Positioned(
      top: marker['top'],
      left: marker['left'],
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF131A2A).withOpacity(0.85),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: marker['color'], width: 2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(marker['title'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(marker['discount'], style: TextStyle(color: marker['color'], fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.timer, color: Colors.white54, size: 12),
                    const SizedBox(width: 4),
                    Text(marker['wait_time'], style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                )
              ],
            ),
          ),
          Container(
            width: 2,
            height: 40,
            color: marker['color'],
          ),
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: marker['color'],
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: (marker['color'] as Color).withOpacity(0.5), blurRadius: 10, spreadRadius: 4)
              ],
            ),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          if (_isCameraInitialized && _cameraController != null)
            SizedBox.expand(
              child: CameraPreview(_cameraController!),
            )
          else
            const Center(child: CircularProgressIndicator(color: MPesaTheme.primaryGreen)),
            
          // AR Markers
          ..._mockArMarkers.map((marker) => _buildArMarker(marker)),
          
          // UI Overlay Header
          Positioned(
            top: 50,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CircleAvatar(
                  backgroundColor: Colors.black54,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: MPesaTheme.primaryGreen),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.view_in_ar, color: MPesaTheme.primaryGreen, size: 16),
                      SizedBox(width: 8),
                      Text('AR Active', style: TextStyle(color: MPesaTheme.primaryGreen, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                const SizedBox(width: 40), // Balance out the back button
              ],
            ),
          ),
          
          // Bottom instruction
          const Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                'Point camera at campus buildings',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  shadows: [Shadow(color: Colors.black, blurRadius: 4)]
                ),
              ),
            ),
          )
        ],
      ),
    );
  }
}
