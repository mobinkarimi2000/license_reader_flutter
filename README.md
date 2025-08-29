# License Plate Reader Flutter App

A Flutter application that uses camera and OCR (Optical Character Recognition) to read and detect license plates from images.

## Features

- **Real-time Camera Preview**: Live camera feed to capture license plate images
- **Image Capture**: Take photos directly from the camera
- **Gallery Selection**: Choose existing images from the device gallery
- **OCR Text Recognition**: Uses Google ML Kit to extract text from images
- **License Plate Detection**: Smart pattern matching to identify license plate numbers
- **Cross-platform**: Works on both Android and iOS

## How to Use

1. **Launch the App**: Open the License Plate Reader app
2. **Grant Permissions**: Allow camera and storage permissions when prompted
3. **Capture or Select Image**:
   - Tap "Capture" to take a photo with the camera
   - Tap "Gallery" to select an existing image from your photo library
4. **View Results**: The app will automatically process the image and display:
   - The detected license plate number (highlighted)
   - All text found in the image

## Technical Details

### Dependencies
- `camera`: Camera functionality
- `google_mlkit_text_recognition`: OCR text recognition
- `image_picker`: Image selection from gallery
- `permission_handler`: Runtime permission management
- `path_provider` & `path`: File system operations

### License Plate Detection Patterns
The app uses regex patterns to identify common license plate formats:
- Standard format: ABC123, AB1234
- Numeric-alpha format: 123ABC456
- General alphanumeric: 5-8 characters

### Permissions Required
- **Android**: Camera, Read/Write External Storage
- **iOS**: Camera Usage, Photo Library Usage

## Setup and Installation

1. Ensure Flutter is installed on your system
2. Clone or download this project
3. Run `flutter pub get` to install dependencies
4. Connect a device or start an emulator
5. Run `flutter run` to launch the app

## Platform Support

- ✅ Android
- ✅ iOS
- ⚠️ Web (limited camera support)
- ⚠️ Desktop (limited camera support)

## Notes

- Best results are achieved with clear, well-lit images
- The app works with various license plate formats but may need adjustment for specific regional formats
- OCR accuracy depends on image quality and lighting conditions
- The app processes images locally on the device for privacy

## Troubleshooting

- **Camera not working**: Check if camera permissions are granted
- **No text detected**: Ensure the image is clear and well-lit
- **License plate not recognized**: The detection patterns may need adjustment for your region's format

Enjoy using the License Plate Reader app!