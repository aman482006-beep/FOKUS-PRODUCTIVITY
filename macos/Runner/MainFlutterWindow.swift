import Cocoa
import FlutterMacOS
import Vision

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    // OCR Method Channel Setup
    let messenger = flutterViewController.engine.binaryMessenger
    let channel = FlutterMethodChannel(name: "com.focusforge.ocr/engine", binaryMessenger: messenger)
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
            result(FlutterError(code: "OCR_FAILED", message: "Failed to recognize text on macOS", details: nil))
          }
        }
      } else {
        result(FlutterMethodNotImplemented)
      }
    }

    super.awakeFromNib()
  }

  private func recognizeText(filePath: String, completion: @escaping (String?) -> Void) {
    let fileURL = URL(fileURLWithPath: filePath)
    guard let image = NSImage(contentsOf: fileURL),
          let tiffData = image.tiffRepresentation,
          let cgImage = NSBitmapImageRep(data: tiffData)?.cgImage else {
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
}
