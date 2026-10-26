
import UIKit
import Flutter
import UniformTypeIdentifiers

@main
@objc class AppDelegate: FlutterAppDelegate {
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions:
            [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        GeneratedPluginRegistrant.register(with: self)

        let launched = super.application(
            application,
            didFinishLaunchingWithOptions: launchOptions
        )

        guard let controller =
            window?.rootViewController as? FlutterViewController else {
            print("[Raiko] ERROR: FlutterViewController was not found.")
            return launched
        }

        let channel = FlutterMethodChannel(
            name: "com.raiko.app/ios_folder",
            binaryMessenger: controller.binaryMessenger
        )

        channel.setMethodCallHandler { call, result in
            guard call.method == "getFolderFiles" else {
                result(FlutterMethodNotImplemented)
                return
            }

            guard
                let args = call.arguments as? [String: Any],
                let folderPath = args["path"] as? String
            else {
                result(FlutterError(
                    code: "INVALID_ARGS",
                    message: "Folder path required",
                    details: nil
                ))
                return
            }

            let folderURL = URL(fileURLWithPath: folderPath)
            let hasAccess =
                folderURL.startAccessingSecurityScopedResource()

            defer {
                if hasAccess {
                    folderURL.stopAccessingSecurityScopedResource()
                }
            }

            do {
                let keys: Set<URLResourceKey> = [.isRegularFileKey]

                guard let enumerator = FileManager.default.enumerator(
                    at: folderURL,
                    includingPropertiesForKeys: Array(keys),
                    options: [.skipsHiddenFiles]
                ) else {
                    result([])
                    return
                }

                let allowedExtensions: Set<String> = [
                    "mp3", "m4a", "aac", "wav",
                    "ogg", "flac", "aiff", "aif"
                ]

                var paths: [String] = []

                for case let fileURL as URL in enumerator {
                    let values = try fileURL.resourceValues(
                        forKeys: keys
                    )

                    guard values.isRegularFile == true else {
                        continue
                    }

                    if allowedExtensions.contains(
                        fileURL.pathExtension.lowercased()
                    ) {
                        paths.append(fileURL.path)
                    }
                }

                result(paths)
            } catch {
                result(FlutterError(
                    code: "READ_ERROR",
                    message: error.localizedDescription,
                    details: nil
                ))
            }
        }

        return launched
    }
}
