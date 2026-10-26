
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

        if let controller =
            window?.rootViewController as? FlutterViewController {

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
                    let path = args["path"] as? String
                else {
                    result(FlutterError(
                        code: "INVALID_ARGS",
                        message: "Folder path required",
                        details: nil
                    ))
                    return
                }

                let url = URL(fileURLWithPath: path)
                let hasAccess = url.startAccessingSecurityScopedResource()

                defer {
                    if hasAccess {
                        url.stopAccessingSecurityScopedResource()
                    }
                }

                do {
                    let keys: Set<URLResourceKey> = [.isRegularFileKey]
                    guard let enumerator = FileManager.default.enumerator(
                        at: url,
                        includingPropertiesForKeys: Array(keys),
                        options: [.skipsHiddenFiles]
                    ) else {
                        result([])
                        return
                    }

                    let extensions: Set<String> = [
                        "mp3", "m4a", "aac", "wav",
                        "ogg", "flac", "aiff", "aif"
                    ]

                    var paths: [String] = []

                    for case let fileURL as URL in enumerator {
                        let values = try fileURL.resourceValues(forKeys: keys)

                        if values.isRegularFile == true,
                           extensions.contains(fileURL.pathExtension.lowercased()) {
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
        } else {
            print("[Raiko] FlutterViewController unavailable during launch")
        }

        return launched
    }
}
