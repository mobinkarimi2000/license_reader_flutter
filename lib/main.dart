import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:license_reader_flutter/iran_detecting.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Get available cameras
  final cameras = await availableCameras();

  runApp(PlateImageDetectorWidget());
}

// class LicensePlateReaderApp extends StatelessWidget {
//   final List<CameraDescription> cameras;

//   const LicensePlateReaderApp({super.key, required this.cameras});

//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: 'License Plate Reader',
//       theme: ThemeData(
//         primarySwatch: Colors.blue,
//         visualDensity: VisualDensity.adaptivePlatformDensity,
//       ),
//       home: LicensePlateReaderScreen(cameras: cameras),
//     );
//   }
// }

// class LicensePlateReaderScreen extends StatefulWidget {
//   final List<CameraDescription> cameras;

//   const LicensePlateReaderScreen({super.key, required this.cameras});

//   @override
//   State<LicensePlateReaderScreen> createState() =>
//       _LicensePlateReaderScreenState();
// }

// class _LicensePlateReaderScreenState extends State<LicensePlateReaderScreen> {
//   CameraController? _cameraController;
//   final TextRecognizer _textRecognizer = TextRecognizer();
//   final ImagePicker _imagePicker = ImagePicker();

//   String _recognizedText = '';
//   String _licensePlate = '';
//   bool _isProcessing = false;
//   bool _isCameraInitialized = false;

//   @override
//   void initState() {
//     super.initState();
//     _initializeCamera();
//   }

//   Future<void> _initializeCamera() async {
//     if (widget.cameras.isEmpty) return;

//     // Request camera permission
//     final cameraPermission = await Permission.camera.request();
//     if (cameraPermission != PermissionStatus.granted) {
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(content: Text('Camera permission is required')),
//         );
//       }
//       return;
//     }

//     _cameraController = CameraController(
//       widget.cameras.first,
//       ResolutionPreset.high,
//       enableAudio: false,
//     );

//     try {
//       await _cameraController!.initialize();
//       if (mounted) {
//         setState(() {
//           _isCameraInitialized = true;
//         });
//       }
//     } catch (e) {
//       print('Error initializing camera: $e');
//     }
//   }

//   Future<void> _captureAndProcessImage() async {
//     if (_cameraController == null || !_cameraController!.value.isInitialized) {
//       return;
//     }

//     setState(() {
//       _isProcessing = true;
//     });

//     try {
//       final XFile image = await _cameraController!.takePicture();
//       await _processImage(image.path);
//     } catch (e) {
//       print('Error capturing image: $e');
//       if (mounted) {
//         ScaffoldMessenger.of(
//           context,
//         ).showSnackBar(SnackBar(content: Text('Error capturing image: $e')));
//       }
//     } finally {
//       if (mounted) {
//         setState(() {
//           _isProcessing = false;
//         });
//       }
//     }
//   }

//   Future<void> _pickImageFromGallery() async {
//     setState(() {
//       _isProcessing = true;
//     });

//     try {
//       final XFile? image = await _imagePicker.pickImage(
//         source: ImageSource.gallery,
//       );
//       if (image != null) {
//         await _processImage(image.path);
//       }
//     } catch (e) {
//       print('Error picking image: $e');
//       if (mounted) {
//         ScaffoldMessenger.of(
//           context,
//         ).showSnackBar(SnackBar(content: Text('Error picking image: $e')));
//       }
//     } finally {
//       if (mounted) {
//         setState(() {
//           _isProcessing = false;
//         });
//       }
//     }
//   }

//   Future<void> _processImage(String imagePath) async {
//     try {
//       final inputImage = InputImage.fromFilePath(imagePath);
//       final RecognizedText recognizedText = await _textRecognizer.processImage(
//         inputImage,
//       );

//       String allText = recognizedText.text;
//       String detectedLicensePlate = _extractLicensePlate(allText);

//       if (mounted) {
//         setState(() {
//           _recognizedText = allText;
//           _licensePlate = detectedLicensePlate;
//         });
//       }
//     } catch (e) {
//       print('Error processing image: $e');
//       if (mounted) {
//         ScaffoldMessenger.of(
//           context,
//         ).showSnackBar(SnackBar(content: Text('Error processing image: $e')));
//       }
//     }
//   }

//   String _extractLicensePlate(String text) {
//     // Simple regex patterns for common license plate formats
//     final patterns = [
//       RegExp(r'\b[A-Z]{1,3}[0-9]{1,4}[A-Z]{0,3}\b'), // ABC123, AB1234, etc.
//       RegExp(r'\b[0-9]{1,3}[A-Z]{1,3}[0-9]{1,4}\b'), // 123ABC456, etc.
//       RegExp(r'\b[A-Z0-9]{5,8}\b'), // General alphanumeric 5-8 chars
//     ];

//     for (final pattern in patterns) {
//       final matches = pattern.allMatches(
//         text.replaceAll(' ', '').toUpperCase(),
//       );
//       if (matches.isNotEmpty) {
//         return matches.first.group(0) ?? '';
//       }
//     }

//     // If no pattern matches, return the first line that looks like it could be a license plate
//     final lines = text.split('\n');
//     for (final line in lines) {
//       final cleanLine = line.trim().replaceAll(' ', '').toUpperCase();
//       if (cleanLine.length >= 4 &&
//           cleanLine.length <= 10 &&
//           RegExp(r'^[A-Z0-9]+$').hasMatch(cleanLine)) {
//         return cleanLine;
//       }
//     }

//     return 'No license plate detected';
//   }

//   @override
//   void dispose() {
//     _cameraController?.dispose();
//     _textRecognizer.close();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('License Plate Reader'),
//         backgroundColor: Colors.blue,
//         foregroundColor: Colors.white,
//       ),
//       body: Column(
//         children: [
//           // Camera Preview
//           Expanded(
//             flex: 3,
//             child: Container(
//               width: double.infinity,
//               decoration: BoxDecoration(
//                 border: Border.all(color: Colors.grey),
//                 borderRadius: BorderRadius.circular(8),
//               ),
//               margin: const EdgeInsets.all(16),
//               child: _isCameraInitialized && _cameraController != null
//                   ? ClipRRect(
//                       borderRadius: BorderRadius.circular(8),
//                       child: CameraPreview(_cameraController!),
//                     )
//                   : const Center(
//                       child: Column(
//                         mainAxisAlignment: MainAxisAlignment.center,
//                         children: [
//                           Icon(Icons.camera_alt, size: 64, color: Colors.grey),
//                           SizedBox(height: 16),
//                           Text(
//                             'Camera not available',
//                             style: TextStyle(color: Colors.grey),
//                           ),
//                         ],
//                       ),
//                     ),
//             ),
//           ),

//           // Control Buttons
//           Padding(
//             padding: const EdgeInsets.symmetric(horizontal: 16),
//             child: Row(
//               mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//               children: [
//                 ElevatedButton.icon(
//                   onPressed: _isProcessing ? null : _captureAndProcessImage,
//                   icon: const Icon(Icons.camera),
//                   label: const Text('Capture'),
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: Colors.blue,
//                     foregroundColor: Colors.white,
//                   ),
//                 ),
//                 ElevatedButton.icon(
//                   onPressed: _isProcessing ? null : _pickImageFromGallery,
//                   icon: const Icon(Icons.photo_library),
//                   label: const Text('Gallery'),
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: Colors.green,
//                     foregroundColor: Colors.white,
//                   ),
//                 ),
//               ],
//             ),
//           ),

//           const SizedBox(height: 16),

//           // Processing Indicator
//           if (_isProcessing)
//             const Padding(
//               padding: EdgeInsets.all(16),
//               child: Row(
//                 mainAxisAlignment: MainAxisAlignment.center,
//                 children: [
//                   CircularProgressIndicator(),
//                   SizedBox(width: 16),
//                   Text('Processing image...'),
//                 ],
//               ),
//             ),

//           // Results
//           Expanded(
//             flex: 2,
//             child: Container(
//               width: double.infinity,
//               margin: const EdgeInsets.all(16),
//               padding: const EdgeInsets.all(16),
//               decoration: BoxDecoration(
//                 color: Colors.grey[100],
//                 borderRadius: BorderRadius.circular(8),
//                 border: Border.all(color: Colors.grey[300]!),
//               ),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   const Text(
//                     'Detected License Plate:',
//                     style: TextStyle(
//                       fontSize: 18,
//                       fontWeight: FontWeight.bold,
//                       color: Colors.blue,
//                     ),
//                   ),
//                   const SizedBox(height: 8),
//                   Container(
//                     width: double.infinity,
//                     padding: const EdgeInsets.all(12),
//                     decoration: BoxDecoration(
//                       color: Colors.white,
//                       borderRadius: BorderRadius.circular(4),
//                       border: Border.all(color: Colors.grey[400]!),
//                     ),
//                     child: Text(
//                       _licensePlate.isEmpty
//                           ? 'No license plate detected yet'
//                           : _licensePlate,
//                       style: TextStyle(
//                         fontSize: 24,
//                         fontWeight: FontWeight.bold,
//                         color: _licensePlate.isEmpty
//                             ? Colors.grey
//                             : Colors.black,
//                         letterSpacing: 2,
//                       ),
//                       textAlign: TextAlign.center,
//                     ),
//                   ),
//                   const SizedBox(height: 16),
//                   const Text(
//                     'All Detected Text:',
//                     style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
//                   ),
//                   const SizedBox(height: 8),
//                   Expanded(
//                     child: Container(
//                       width: double.infinity,
//                       padding: const EdgeInsets.all(8),
//                       decoration: BoxDecoration(
//                         color: Colors.white,
//                         borderRadius: BorderRadius.circular(4),
//                         border: Border.all(color: Colors.grey[400]!),
//                       ),
//                       child: SingleChildScrollView(
//                         child: Text(
//                           _recognizedText.isEmpty
//                               ? 'No text detected yet'
//                               : _recognizedText,
//                           style: TextStyle(
//                             fontSize: 12,
//                             color: _recognizedText.isEmpty
//                                 ? Colors.grey
//                                 : Colors.black87,
//                           ),
//                         ),
//                       ),
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
