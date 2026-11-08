import Flutter
import UIKit
import Vision

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    
    let controller : FlutterViewController = window?.rootViewController as! FlutterViewController
    let channel = FlutterMethodChannel(name: "com.focusforge.ocr/engine", binaryMessenger: controller.binaryMessenger)
    
    channel.setMethodCallHandler { [weak self] (call, result) in
      guard let self = self else { return }
      if call.method == "recognizeText" {
        guard let args = call.arguments as? [String: Any],
              let filePath = args["filePath"] as? String else {
          result(FlutterError(code: "INVALID_ARGUMENTS", message: "filePath is required", details: nil))
          return
        }
        
        self.recognizeText(filePath: filePath) { text in
          if let text = text {
            result(text)
          } else {
            result(FlutterError(code: "OCR_FAILED", message: "Failed to recognize text on iOS", details: nil))
          }
        }
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func recognizeText(filePath: String, completion: @escaping (String?) -> Void) {
    guard let image = UIImage(contentsOfFile: filePath),
          let cgImage = image.cgImage else {
      completion(nil)
      return
    }
    
    let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
    let request = VNRecognizeTextRequest { (request, error) in
      if let error = error {
        print("Vision OCR error: \(error.localizedDescription)")
        completion(nil)
        return
      }
      
      guard let observations = request.results as? [VNRecognizedTextObservation] else {
        completion(nil)
        return
      }
      
      let recognizedStrings = observations.compactMap { observation in
        observation.topCandidates(1).first?.string
      }
      
      completion(recognizedStrings.joined(separator: "\n"))
    }
    
    request.recognitionLevel = .accurate
    request.usesLanguageCorrection = true
    
    do {
      try requestHandler.perform([request])
    } catch {
      print("Failed to perform Vision OCR: \(error.localizedDescription)")
      completion(nil)
    }
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
