import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart' as mlkit;

class OcrService {
  static const MethodChannel _channel = MethodChannel('com.focusforge.ocr/engine');

  /// Runs OCR on an image file using native platform engines.
  /// 
  /// - Windows: Uses native Windows.Media.Ocr
  /// - macOS: Uses native Vision.framework (VNRecognizeTextRequest)
  /// - iOS: Uses native Vision.framework (VNRecognizeTextRequest)
  /// - Android: Uses Google ML Kit Text Recognition
  static Future<String> recognizeTextFromImage(String filePath) async {
    if (kIsWeb) {
      return 'Web OCR is not supported yet.';
    }

    try {
      if (Platform.isWindows || Platform.isMacOS || Platform.isIOS) {
        final String? text = await _channel.invokeMethod<String>(
          'recognizeText',
          {'filePath': filePath},
        );
        return text ?? 'No text recognized.';
      } else if (Platform.isAndroid) {
        final inputImage = mlkit.InputImage.fromFilePath(filePath);
        final textRecognizer = mlkit.TextRecognizer(script: mlkit.TextRecognitionScript.latin);
        try {
          final mlkit.RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
          return recognizedText.text.isNotEmpty ? recognizedText.text : 'No text recognized.';
        } finally {
          await textRecognizer.close();
        }
      } else {
        return 'Unsupported platform for OCR.';
      }
    } on PlatformException catch (e) {
      return 'Native OCR failed: ${e.message}';
    } catch (e) {
      return 'OCR processing error: $e';
    }
  }

  /// Extracts text from a PDF file using pure Dart offline parser.
  static Future<String> extractTextFromPdf(String filePath) async {
    try {
      final File file = File(filePath);
      final List<int> bytes = await file.readAsBytes();
      
      // Load the PDF document
      final PdfDocument document = PdfDocument(inputBytes: bytes);
      
      // Extract all text
      final PdfTextExtractor extractor = PdfTextExtractor(document);
      final String text = extractor.extractText();
      
      // Dispose document
      document.dispose();
      
      return text.isNotEmpty ? text : 'PDF is empty or contains no embedded text (scanned PDF).';
    } catch (e) {
      return 'Failed to extract text from PDF: $e';
    }
  }

  /// Master method to extract text from a file based on its extension.
  static Future<String> processFile(String filePath) async {
    final File file = File(filePath);
    if (!await file.exists()) {
      return 'Error: File does not exist.';
    }

    final String extension = filePath.split('.').last.toLowerCase();
    
    if (extension == 'pdf') {
      return await extractTextFromPdf(filePath);
    } else if (['txt', 'md', 'csv', 'json', 'xml', 'yaml', 'ini'].contains(extension)) {
      try {
        return await file.readAsString();
      } catch (e) {
        return 'Failed to read text document: $e';
      }
    } else if (['png', 'jpg', 'jpeg', 'webp', 'bmp', 'tiff', 'gif'].contains(extension)) {
      return await recognizeTextFromImage(filePath);
    } else {
      // Fallback: assume it might be an image or try OCR
      return await recognizeTextFromImage(filePath);
    }
  }
}
