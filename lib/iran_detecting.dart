import 'package:flutter/material.dart';
import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:image_picker/image_picker.dart';
import 'package:camera/camera.dart';
import 'dart:io';
import 'dart:typed_data';

class IranianPlateImageDetector {
  static final TextRecognizer _textRecognizer = TextRecognizer();

  /// Detects Iranian license plates from an image file
  static Future<List<DetectedPlate>> detectPlatesFromImage(
    String imagePath,
  ) async {
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final recognizedText = await _textRecognizer.processImage(inputImage);

      return _extractPlatesFromRecognizedText(recognizedText);
    } catch (e) {
      print('Error detecting plates from image: $e');
      return [];
    }
  }

  /// Detects Iranian license plates from image bytes
  static Future<List<DetectedPlate>> detectPlatesFromBytes(
    Uint8List imageBytes,
  ) async {
    try {
      final inputImage = InputImage.fromBytes(
        bytes: imageBytes,
        metadata: InputImageMetadata(
          size: Size(800, 600), // Default size, adjust as needed
          rotation: InputImageRotation.rotation0deg,
          format: InputImageFormat.yuv420,
          bytesPerRow: 800,
        ),
      );

      final recognizedText = await _textRecognizer.processImage(inputImage);
      return _extractPlatesFromRecognizedText(recognizedText);
    } catch (e) {
      print('Error detecting plates from bytes: $e');
      return [];
    }
  }

  /// Extracts plates from ML Kit recognized text
  static List<DetectedPlate> _extractPlatesFromRecognizedText(
    RecognizedText recognizedText,
  ) {
    List<DetectedPlate> detectedPlates = [];

    for (TextBlock block in recognizedText.blocks) {
      for (TextLine line in block.lines) {
        String lineText = line.text;

        // Clean and preprocess the text
        String cleanedText = _preprocessText(lineText);

        // Try to find Iranian plates in this line
        List<String> platesInLine = _detectIranianPlatesInText(cleanedText);

        for (String plate in platesInLine) {
          detectedPlates.add(
            DetectedPlate(
              plateNumber: plate,
              confidence: _calculateConfidence(plate, lineText),
              boundingBox: line.boundingBox,
              plateType: _getPlateType(plate),
            ),
          );
        }
      }
    }

    // Sort by confidence and remove duplicates
    detectedPlates.sort((a, b) => b.confidence.compareTo(a.confidence));
    return _removeDuplicates(detectedPlates);
  }

  /// Preprocesses text to improve plate detection
  static String _preprocessText(String text) {
    // Replace common OCR misreadings
    String processed = text
        .replaceAll('O', '0') // O -> 0
        .replaceAll('o', '0') // o -> 0
        .replaceAll('I', '1') // I -> 1
        .replaceAll('l', '1') // l -> 1
        .replaceAll('S', '5') // S -> 5 (sometimes)
        .replaceAll('B', '8') // B -> 8 (sometimes)
        .replaceAll(
          RegExp(r'[^\u0600-\u06FF\u0750-\u077F\w\s\-]'),
          ' ',
        ); // Keep only Persian, English, digits, spaces, hyphens

    return processed.trim();
  }

  /// Detects Iranian plates in text using regex patterns
  static List<String> _detectIranianPlatesInText(String text) {
    List<String> detectedPlates = [];

    // Standard Iranian plate pattern: XX YYY ZZ
    RegExp standardPattern = RegExp(
      r'\b\d{2}[\s\-]?[آ-ی]{3}[\s\-]?\d{2}\b',
      caseSensitive: false,
    );

    // Standard with English letters: XX ABC ZZ
    RegExp standardEnglishPattern = RegExp(
      r'\b\d{2}[\s\-]?[A-Z]{3}[\s\-]?\d{2}\b',
      caseSensitive: false,
    );

    // Public service: XXX YY ZZ
    RegExp publicServicePattern = RegExp(
      r'\b\d{3}[\s\-]?[آ-یA-Z]{2}[\s\-]?\d{2}\b',
      caseSensitive: false,
    );

    // Temporary: T XXX YYY
    RegExp temporaryPattern = RegExp(
      r'\b[Tt][\s\-]?\d{3}[\s\-]?[آ-یA-Z]{3}\b',
      caseSensitive: false,
    );

    // Police: پ XXX YYY or P XXX YYY
    RegExp policePattern = RegExp(
      r'\b[پP][\s\-]?\d{3}[\s\-]?[آ-یA-Z]{3}\b',
      caseSensitive: false,
    );

    // Motorcycle: XXXX YY
    RegExp motorcyclePattern = RegExp(
      r'\b\d{4}[\s\-]?[آ-یA-Z]{2}\b',
      caseSensitive: false,
    );

    // Collect all matches
    detectedPlates.addAll(_getMatches(standardPattern, text));
    detectedPlates.addAll(_getMatches(standardEnglishPattern, text));
    detectedPlates.addAll(_getMatches(publicServicePattern, text));
    detectedPlates.addAll(_getMatches(temporaryPattern, text));
    detectedPlates.addAll(_getMatches(policePattern, text));
    detectedPlates.addAll(_getMatches(motorcyclePattern, text));

    return detectedPlates;
  }

  /// Helper to extract regex matches
  static List<String> _getMatches(RegExp pattern, String text) {
    return pattern.allMatches(text).map((match) => match.group(0)!).toList();
  }

  /// Calculates confidence score for detected plate
  static double _calculateConfidence(String plate, String originalText) {
    double confidence = 0.7; // Base confidence

    // Increase confidence if plate follows exact format
    if (_isExactFormat(plate)) confidence += 0.2;

    // Increase confidence if found in clean context
    if (originalText.length == plate.length) confidence += 0.1;

    return confidence.clamp(0.0, 1.0);
  }

  /// Checks if plate follows exact Iranian format
  static bool _isExactFormat(String plate) {
    String normalized = plate.replaceAll(RegExp(r'[\s\-]+'), '');

    return RegExp(
          r'^\d{2}[آ-یA-Z]{3}\d{2}$',
          caseSensitive: false,
        ).hasMatch(normalized) ||
        RegExp(
          r'^\d{3}[آ-یA-Z]{2}\d{2}$',
          caseSensitive: false,
        ).hasMatch(normalized) ||
        RegExp(
          r'^[Tt]\d{3}[آ-یA-Z]{3}$',
          caseSensitive: false,
        ).hasMatch(normalized) ||
        RegExp(
          r'^[پP]\d{3}[آ-یA-Z]{3}$',
          caseSensitive: false,
        ).hasMatch(normalized) ||
        RegExp(
          r'^\d{4}[آ-یA-Z]{2}$',
          caseSensitive: false,
        ).hasMatch(normalized);
  }

  /// Gets the type of plate
  static String _getPlateType(String plate) {
    String normalizedPlate = plate.replaceAll(RegExp(r'[\s\-]+'), '');

    if (RegExp(
      r'^\d{2}[آ-یA-Z]{3}\d{2}$',
      caseSensitive: false,
    ).hasMatch(normalizedPlate)) {
      return 'Standard';
    } else if (RegExp(
      r'^\d{3}[آ-یA-Z]{2}\d{2}$',
      caseSensitive: false,
    ).hasMatch(normalizedPlate)) {
      return 'Public Service';
    } else if (RegExp(
      r'^[Tt]\d{3}[آ-یA-Z]{3}$',
      caseSensitive: false,
    ).hasMatch(normalizedPlate)) {
      return 'Temporary';
    } else if (RegExp(
      r'^[پP]\d{3}[آ-یA-Z]{3}$',
      caseSensitive: false,
    ).hasMatch(normalizedPlate)) {
      return 'Police';
    } else if (RegExp(
      r'^\d{4}[آ-یA-Z]{2}$',
      caseSensitive: false,
    ).hasMatch(normalizedPlate)) {
      return 'Motorcycle';
    }

    return 'Unknown';
  }

  /// Removes duplicate plates based on similarity
  static List<DetectedPlate> _removeDuplicates(List<DetectedPlate> plates) {
    List<DetectedPlate> uniquePlates = [];

    for (DetectedPlate plate in plates) {
      bool isDuplicate = uniquePlates.any(
        (existing) =>
            _areSimilarPlates(existing.plateNumber, plate.plateNumber),
      );

      if (!isDuplicate) {
        uniquePlates.add(plate);
      }
    }

    return uniquePlates;
  }

  /// Checks if two plates are similar (to handle OCR variations)
  static bool _areSimilarPlates(String plate1, String plate2) {
    String normalized1 = plate1
        .replaceAll(RegExp(r'[\s\-]+'), '')
        .toUpperCase();
    String normalized2 = plate2
        .replaceAll(RegExp(r'[\s\-]+'), '')
        .toUpperCase();

    return normalized1 == normalized2;
  }

  /// Dispose of resources
  static void dispose() {
    _textRecognizer.close();
  }
}

/// Model class for detected plate information
class DetectedPlate {
  final String plateNumber;
  final double confidence;
  final Rect boundingBox;
  final String plateType;

  DetectedPlate({
    required this.plateNumber,
    required this.confidence,
    required this.boundingBox,
    required this.plateType,
  });

  @override
  String toString() {
    return 'DetectedPlate(plate: $plateNumber, confidence: ${(confidence * 100).toStringAsFixed(1)}%, type: $plateType)';
  }
}

/// Example widget demonstrating image-based plate detection
class PlateImageDetectorWidget extends StatefulWidget {
  @override
  _PlateImageDetectorWidgetState createState() =>
      _PlateImageDetectorWidgetState();
}

class _PlateImageDetectorWidgetState extends State<PlateImageDetectorWidget> {
  File? _selectedImage;
  List<DetectedPlate> _detectedPlates = [];
  bool _isProcessing = false;
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImageFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
          _detectedPlates = [];
        });
        await _processImage();
      }
    } catch (e) {
      _showError('Failed to pick image: $e');
    }
  }

  Future<void> _pickImageFromCamera() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
          _detectedPlates = [];
        });
        await _processImage();
      }
    } catch (e) {
      _showError('Failed to take photo: $e');
    }
  }

  Future<void> _processImage() async {
    if (_selectedImage == null) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      List<DetectedPlate> plates =
          await IranianPlateImageDetector.detectPlatesFromImage(
            _selectedImage!.path,
          );

      setState(() {
        _detectedPlates = plates;
        _isProcessing = false;
      });

      if (plates.isEmpty) {
        _showMessage('No Iranian license plates detected in the image.');
      }
    } catch (e) {
      setState(() {
        _isProcessing = false;
      });
      _showError('Error processing image: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.blue),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Iranian Plate Image Detector'),
        backgroundColor: Colors.blue,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image selection buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _pickImageFromGallery,
                    icon: Icon(Icons.photo_library),
                    label: Text('Gallery'),
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _pickImageFromCamera,
                    icon: Icon(Icons.camera_alt),
                    label: Text('Camera'),
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),

            SizedBox(height: 20),

            // Selected image display
            if (_selectedImage != null) ...[
              Container(
                height: 250,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    _selectedImage!,
                    fit: BoxFit.contain,
                    width: double.infinity,
                  ),
                ),
              ),
              SizedBox(height: 16),
            ],

            // Processing indicator
            if (_isProcessing) ...[
              Center(
                child: Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Processing image...', style: TextStyle(fontSize: 16)),
                  ],
                ),
              ),
            ],

            // Results
            if (!_isProcessing && _detectedPlates.isNotEmpty) ...[
              Text(
                'Detected License Plates:',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 12),

              ListView.builder(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                itemCount: _detectedPlates.length,
                itemBuilder: (context, index) {
                  DetectedPlate plate = _detectedPlates[index];

                  return Card(
                    margin: EdgeInsets.symmetric(vertical: 6),
                    elevation: 3,
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                _getIconForPlateType(plate.plateType),
                                color: Colors.blue,
                                size: 24,
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  plate.plateNumber,
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Type: ${plate.plateType}',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                'Confidence: ${(plate.confidence * 100).toStringAsFixed(1)}%',
                                style: TextStyle(
                                  color: plate.confidence > 0.8
                                      ? Colors.green
                                      : Colors.orange,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],

            // Instructions
            if (_selectedImage == null && !_isProcessing) ...[
              Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: Column(
                  children: [
                    Icon(Icons.directions_car, size: 48, color: Colors.blue),
                    SizedBox(height: 16),
                    Text(
                      'Iranian License Plate Detector',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Select an image from your gallery or take a photo to detect Iranian license plates automatically.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Supports: Standard, Police, Temporary, Public Service, and Motorcycle plates',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  IconData _getIconForPlateType(String plateType) {
    switch (plateType.toLowerCase()) {
      case 'police':
        return Icons.local_police;
      case 'motorcycle':
        return Icons.motorcycle;
      case 'temporary':
        return Icons.schedule;
      case 'public service':
        return Icons.business;
      default:
        return Icons.directions_car;
    }
  }

  @override
  void dispose() {
    super.dispose();
  }
}

/// Additional utility class for batch processing
class BatchPlateDetector {
  /// Process multiple images and return all detected plates
  static Future<Map<String, List<DetectedPlate>>> detectPlatesInBatch(
    List<String> imagePaths,
  ) async {
    Map<String, List<DetectedPlate>> results = {};

    for (String imagePath in imagePaths) {
      try {
        List<DetectedPlate> plates =
            await IranianPlateImageDetector.detectPlatesFromImage(imagePath);
        results[imagePath] = plates;
      } catch (e) {
        print('Error processing $imagePath: $e');
        results[imagePath] = [];
      }
    }

    return results;
  }

  /// Get statistics from batch processing
  static Map<String, dynamic> getBatchStatistics(
    Map<String, List<DetectedPlate>> batchResults,
  ) {
    int totalImages = batchResults.length;
    int imagesWithPlates = batchResults.values
        .where((plates) => plates.isNotEmpty)
        .length;
    int totalPlatesDetected = batchResults.values.fold(
      0,
      (sum, plates) => sum + plates.length,
    );

    Map<String, int> plateTypeCount = {};
    for (List<DetectedPlate> plates in batchResults.values) {
      for (DetectedPlate plate in plates) {
        plateTypeCount[plate.plateType] =
            (plateTypeCount[plate.plateType] ?? 0) + 1;
      }
    }

    return {
      'totalImages': totalImages,
      'imagesWithPlates': imagesWithPlates,
      'totalPlatesDetected': totalPlatesDetected,
      'detectionRate': totalImages > 0
          ? (imagesWithPlates / totalImages * 100).toStringAsFixed(1) + '%'
          : '0%',
      'plateTypeDistribution': plateTypeCount,
    };
  }
}

// Usage example:
// 
// To use this detector:
// 1. Add dependencies to pubspec.yaml:
//    google_ml_kit: ^0.16.0
//    image_picker: ^1.0.4
//    camera: ^0.10.5+5
//
// 2. Add permissions to android/app/src/main/AndroidManifest.xml:
//    <uses-permission android:name="android.permission.CAMERA" />
//    <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
//
// 3. For iOS, add to ios/Runner/Info.plist:
//    <key>NSCameraUsageDescription</key>
//    <string>This app needs camera access to detect license plates</string>
//    <key>NSPhotoLibraryUsageDescription</key>
//    <string>This app needs photo library access to analyze images</string>
//
// 4. Example usage:
//    List<DetectedPlate> plates = await IranianPlateImageDetector.detectPlatesFromImage(imagePath);