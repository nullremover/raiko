import UIKit
import Flutter
import UniformTypeIdentifiers

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let controller : FlutterViewController = window?.rootViewController as! FlutterViewController
    let channel = FlutterMethodChannel(name: "com.raiko.app/ios_folder",
                                              binaryMessenger: controller.binaryMessenger)
    
    channel.setMethodCallHandler({
      (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
      if call.method == "getFolderFiles" {
        guard let args = call.arguments as? [String: Any],
              let folderPath = args["path"] as? String else {
          result(FlutterError(code: "INVALID_ARGS", message: "Folder path required", details: nil))
          return
        }
        
        let url = URL(fileURLWithPath: folderPath)
        
        // --- THIS IS THE SECRET SWIFT MAGIC FROM MISH! ---
        let hasAccess = url.startAccessingSecurityScopedResource()
        defer {
          if hasAccess {
            url.stopAccessingSecurityScopedResource()
          }
        }
        
        do {
          let fileManager = FileManager.default
          let keys: [URLResourceKey] = [.isRegularFileKey]
          guard let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: keys) else {
            result([])
            return
          }
          
          var filePaths: [String] = []
          for case let fileURL as URL in enumerator {
            filePaths.append(fileURL.path)
          }
          result(filePaths)
        } catch {
          result(FlutterError(code: "READ_ERROR", message: error.localizedDescription, details: nil))
        }
      } else {
        result(FlutterMethodNotImplemented)
      }
    })

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
