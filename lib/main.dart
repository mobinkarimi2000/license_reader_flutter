import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Get available cameras
  final cameras = await availableCameras();

  runApp(MyApp(cameras: cameras));
}

class MyApp extends StatelessWidget {
  final List<CameraDescription> cameras;

  const MyApp({Key? key, required this.cameras}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'License Plate Reader',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: LicensePlateReaderScreen(cameras: cameras),
    );
  }
}

class LicensePlateReaderScreen extends StatefulWidget {
  final List<CameraDescription> cameras;

  const LicensePlateReaderScreen({Key? key, required this.cameras})
    : super(key: key);

  @override
  State<LicensePlateReaderScreen> createState() =>
      _LicensePlateReaderScreenState();
}

class _LicensePlateReaderScreenState extends State<LicensePlateReaderScreen> {
  CameraController? _cameraController;
  final TextRecognizer _textRecognizer = TextRecognizer();
  final ImagePicker _imagePicker = ImagePicker();
  bool _isInitialized = false;
  bool _isProcessing = false;
  String _detectedText = '';
  List<String> _detectedPlates = [];

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    // Request camera permission
    final status = await Permission.camera.request();
    if (status != PermissionStatus.granted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Camera permission is required')),
      );
      return;
    }

    if (widget.cameras.isNotEmpty) {
      _cameraController = CameraController(
        widget.cameras[0],
        ResolutionPreset.high,
        enableAudio: false,
      );

      try {
        await _cameraController!.initialize();
        setState(() {
          _isInitialized = true;
        });
      } catch (e) {
        print('Error initializing camera: $e');
      }
    }
  }

  Future<void> _captureAndProcessImage() async {
    if (_cameraController == null ||
        !_cameraController!.value.isInitialized ||
        _isProcessing) {
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      final XFile image = await _cameraController!.takePicture();
      await _processImage(image.path);

      // Clean up the temporary image file
      await File(image.path).delete();
    } catch (e) {
      print('Error processing image: $e');
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _pickFromGallery() async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 100,
      );

      if (image != null) {
        await _processImage(image.path);
      } else {
        setState(() {
          _isProcessing = false;
        });
      }
    } catch (e) {
      print('Error picking from gallery: $e');
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _processImage(String imagePath) async {
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final RecognizedText recognizedText = await _textRecognizer.processImage(
        inputImage,
      );

      String detectedText = recognizedText.text;
      List<String> possiblePlates = _extractLicensePlates(detectedText);

      setState(() {
        _detectedText = detectedText;
        _detectedPlates = possiblePlates;
        _isProcessing = false;
      });
    } catch (e) {
      print('Error processing image: $e');
      setState(() {
        _isProcessing = false;
      });
    }
  }

  List<String> _extractLicensePlates(String text) {
    List<String> plates = [];

    // License plate patterns for different regions
    List<RegExp> patterns = [
      // Iranian license plate patterns
      RegExp(
        r'[۰-۹]{2}\s*[آ-ی]\s*[۰-۹]{3}\s*[۰-۹]{2}',
      ), // Persian digits: ۱۲ الف ۳۴۵ ۶۷
      RegExp(r'\d{2}\s*[آ-ی]\s*\d{3}\s*\d{2}'), // Mixed: 12 الف 345 67
      RegExp(r'[۰-۹]{2}[آ-ی][۰-۹]{3}[۰-۹]{2}'), // Persian no spaces: ۱۲الف۳۴۵۶۷
      RegExp(r'\d{2}[آ-ی]\d{3}\d{2}'), // Mixed no spaces: 12الف34567
      RegExp(r'[۰-۹]{3}\s*[آ-ی]\s*[۰-۹]{2}'), // Older format: ۱۲۳ الف ۴۵
      RegExp(r'\d{3}\s*[آ-ی]\s*\d{2}'), // Older format: 123 الف 45
      // International/Western patterns
      RegExp(r'[A-Z]{2,3}\s*\d{3,4}', caseSensitive: false), // AB 123, ABC 1234
      RegExp(r'\d{3}\s*[A-Z]{3}', caseSensitive: false), // 123 ABC
      RegExp(
        r'[A-Z]{1,2}\d{1,2}\s*[A-Z]{3}',
        caseSensitive: false,
      ), // A1 ABC, AB12 XYZ
      RegExp(
        r'\d{1,3}[A-Z]{1,3}\d{1,3}',
        caseSensitive: false,
      ), // 1A2B3, 12AB34
      RegExp(r'[A-Z0-9]{5,8}', caseSensitive: false), // General alphanumeric
    ];

    for (RegExp pattern in patterns) {
      Iterable<RegExpMatch> matches = pattern.allMatches(text);
      for (RegExpMatch match in matches) {
        String plate = match.group(0)!.replaceAll(' ', '');

        // Validate Iranian plates specifically
        if (_isIranianPlate(plate)) {
          String normalizedPlate = _normalizeIranianPlate(plate);
          if (!plates.contains(normalizedPlate)) {
            plates.add(normalizedPlate);
          }
        }
        // Validate international plates
        else if (_isInternationalPlate(plate)) {
          String normalizedPlate = plate.toUpperCase();
          if (normalizedPlate.length >= 5 &&
              normalizedPlate.length <= 8 &&
              !plates.contains(normalizedPlate)) {
            plates.add(normalizedPlate);
          }
        }
      }
    }

    return plates;
  }

  bool _isIranianPlate(String plate) {
    // Check if contains Persian characters or digits
    return plate.contains(RegExp(r'[آ-ی۰-۹]')) &&
        (plate.length >= 6 && plate.length <= 10);
  }

  bool _isInternationalPlate(String plate) {
    // Check if contains only Latin characters and digits
    return RegExp(r'^[A-Za-z0-9]+$').hasMatch(plate);
  }

  String _normalizeIranianPlate(String plate) {
    // Convert Persian digits to English digits for display consistency
    Map<String, String> persianToEnglish = {
      '۰': '0',
      '۱': '1',
      '۲': '2',
      '۳': '3',
      '۴': '4',
      '۵': '5',
      '۶': '6',
      '۷': '7',
      '۸': '8',
      '۹': '9',
    };

    String normalized = plate;
    persianToEnglish.forEach((persian, english) {
      normalized = normalized.replaceAll(persian, english);
    });

    return normalized;
  }

  bool _isIranianPlateDisplay(String plate) {
    // Check if the plate contains Persian/Arabic characters
    return plate.contains(RegExp(r'[آ-ی]'));
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _textRecognizer.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('License Plate Reader'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Column(
        children: [
          // Camera Preview
          Expanded(
            flex: 3,
            child: Container(
              width: double.infinity,
              child: _isInitialized && _cameraController != null
                  ? CameraPreview(_cameraController!)
                  : const Center(child: CircularProgressIndicator()),
            ),
          ),

          // Controls
          Container(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isProcessing
                            ? null
                            : _captureAndProcessImage,
                        icon: _isProcessing
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.camera_alt),
                        label: Text(
                          _isProcessing ? 'Processing...' : 'Take Photo',
                        ),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isProcessing ? null : _pickFromGallery,
                        icon: const Icon(Icons.photo_library),
                        label: const Text('From Gallery'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                if (_detectedPlates.isNotEmpty) ...[
                  const Text(
                    'Detected License Plates:',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ..._detectedPlates.map(
                    (plate) => Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        border: Border.all(color: Colors.green.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  plate,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                                if (_isIranianPlateDisplay(plate))
                                  const Text(
                                    'Iranian License Plate',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.green,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              // Copy to clipboard functionality
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Copied: $plate')),
                              );
                            },
                            icon: const Icon(Icons.copy),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Raw Text Output (for debugging)
          if (_detectedText.isNotEmpty)
            Expanded(
              flex: 1,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  border: Border(top: BorderSide(color: Colors.grey.shade300)),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Raw Detected Text:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(_detectedText, style: const TextStyle(fontSize: 12)),
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
